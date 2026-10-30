"""The model behind the organiser, behind one small interface (`ModelClient`).

`ChatModel` speaks OpenAI-compatible Chat Completions, streamed, with tools and a low reasoning
effort, as `scripts/smoke/s4_baseten_tools.py` does: Muse Spark Open on Baseten
(`meta-models/muse-spark-open-1026`) and Spark 1.3 on the Meta Model API take the same request.
Baseten parses Spark Open's own ("ATEM") tool-call format into `tool_calls`; raw `<atem:` text
in the answer means that parse failed, and counts as the model being unavailable.

`FallbackModel` moves to Spark 1.3 for the rest of a run when Spark Open fails
(docs/MODELS.md). The tests use scripted fakes of the client; nothing here runs in them.
"""

import logging
import os
from collections.abc import Iterable
from dataclasses import dataclass, field
from typing import Any, Protocol

log = logging.getLogger(__name__)

BASETEN_BASE = "https://inference.baseten.co/v1"
META_BASE = "https://api.meta.ai/v1"
SPARK_OPEN = "meta-models/muse-spark-open-1026"
SPARK = "muse-spark-1.3"
EFFORT = "low"
"""Spark Open defaults to `xhigh`; `low` called the tool right in the smoke test, in 1 to 3 s."""

ATEM = "<atem:"


class ModelUnavailable(RuntimeError):
    """The model failed, or answered in a way the loop can't use."""


@dataclass(frozen=True)
class ToolCall:
    """One tool call as the model wrote it: `arguments` is the raw JSON text."""

    id: str
    name: str
    arguments: str


@dataclass(frozen=True)
class Turn:
    """One answer: words, tool calls, or both, and which model gave it."""

    content: str = ""
    tool_calls: tuple[ToolCall, ...] = field(default_factory=tuple)
    model: str = ""

    def message(self) -> dict:
        """The assistant message that carries this turn into the next request."""
        message: dict[str, Any] = {"role": "assistant", "content": self.content}
        if self.tool_calls:
            message["tool_calls"] = [
                {
                    "id": call.id,
                    "type": "function",
                    "function": {"name": call.name, "arguments": call.arguments},
                }
                for call in self.tool_calls
            ]
        return message


class ModelClient(Protocol):
    """What the agent loop needs from a model."""

    @property
    def name(self) -> str: ...

    def complete(self, messages: list[dict], tools: list[dict]) -> Turn: ...


class ChatModel:
    """One OpenAI-compatible endpoint and model, streamed."""

    def __init__(self, client: Any, model: str, effort: str = EFFORT) -> None:
        self._client = client
        self._model = model
        self._effort = effort

    @property
    def name(self) -> str:
        return self._model

    def complete(self, messages: list[dict], tools: list[dict]) -> Turn:
        """One streamed answer to `messages`, with `tools` on offer.

        Raises `ModelUnavailable` for any error of the SDK or the connection, and for raw ATEM
        text.
        """
        import httpx
        import openai

        try:
            stream = self._client.chat.completions.create(
                model=self._model,
                messages=messages,
                tools=tools,
                stream=True,
                extra_body={"reasoning_effort": self._effort},
            )
            turn = collect(stream, self._model)
        except (openai.OpenAIError, httpx.HTTPError) as error:
            raise ModelUnavailable(type(error).__name__) from error
        if ATEM in turn.content:
            raise ModelUnavailable("raw ATEM text in the answer")
        return turn


def collect(chunks: Iterable[Any], model: str) -> Turn:
    """A `Turn` from streamed chunks: the words joined, and each tool call's id, name and
    argument fragments gathered by its index (the id and name arrive on its first fragment)."""
    content: list[str] = []
    ids: dict[int, str] = {}
    names: dict[int, str] = {}
    parts: dict[int, list[str]] = {}
    for chunk in chunks:
        if not chunk.choices:
            continue
        delta = chunk.choices[0].delta
        content.append(delta.content or "")
        for call in delta.tool_calls or []:
            ids[call.index] = call.id or ids.get(call.index, "")
            function = call.function
            names[call.index] = (function and function.name) or names.get(call.index, "")
            parts.setdefault(call.index, []).append((function and function.arguments) or "")
    calls = tuple(
        ToolCall(ids[i] or f"call_{i}", names[i], "".join(parts[i])) for i in sorted(parts)
    )
    return Turn(content="".join(content), tool_calls=calls, model=model)


class FallbackModel:
    """`primary` until it fails once, then `fallback` for the rest of the run."""

    def __init__(self, primary: ModelClient, fallback: ModelClient) -> None:
        self._primary = primary
        self._fallback = fallback
        self._failed = False

    @property
    def name(self) -> str:
        return (self._fallback if self._failed else self._primary).name

    def complete(self, messages: list[dict], tools: list[dict]) -> Turn:
        if not self._failed:
            try:
                return self._primary.complete(messages, tools)
            except ModelUnavailable as error:
                log.warning("%s failed (%s); falling back", self._primary.name, error)
                self._failed = True
        return self._fallback.complete(messages, tools)


def from_environment(*, timeout: float = 60, max_retries: int = 1) -> ModelClient:
    """Spark Open on Baseten, falling back to Spark 1.3, with the keys the function's secrets
    put in the environment (`BASETEN_API_KEY`, `MODEL_API_KEY`); each request gives up after
    `timeout` seconds and `max_retries` retries. Raises `ModelUnavailable` when either key is
    missing."""
    from openai import OpenAI

    baseten, meta = os.environ.get("BASETEN_API_KEY"), os.environ.get("MODEL_API_KEY")
    if not baseten or not meta:
        raise ModelUnavailable("model keys missing")
    limits = {"timeout": timeout, "max_retries": max_retries}
    return FallbackModel(
        ChatModel(OpenAI(base_url=BASETEN_BASE, api_key=baseten, **limits), SPARK_OPEN),
        ChatModel(OpenAI(base_url=META_BASE, api_key=meta, **limits), SPARK),
    )
