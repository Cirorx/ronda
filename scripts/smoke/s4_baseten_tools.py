# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["openai>=1.100"]
# ///
"""Smoke test 4: Muse Spark Open on Baseten calls a tool, at low and xhigh effort,
streamed and not, then answers the second turn. Flags raw `<atem:` text (a failed tool parse).

    uv run scripts/smoke/s4_baseten_tools.py [model]
"""

import json
import sys

from _env import BASETEN_BASE, Timer, key
from openai import OpenAI

MODEL = sys.argv[1] if len(sys.argv) > 1 else "meta-models/muse-spark-open-1026"
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_forecast",
            "description": "Hourly rain probability for a barrio on a date",
            "parameters": {
                "type": "object",
                "properties": {
                    "barrio": {"type": "string"},
                    "date": {"type": "string"},
                    "reason": {"type": "string"},
                },
                "required": ["barrio", "date", "reason"],
                "additionalProperties": False,
            },
        },
    }
]
ASK = [
    {
        "role": "user",
        "content": (
            "¿Va a llover el miércoles 2026-10-28 de tarde en Solymar? Consultá el pronóstico."
        ),
    }
]
client = OpenAI(base_url=BASETEN_BASE, api_key=key("BASETEN_API_KEY"))


def plain(effort: str):
    r = client.chat.completions.create(
        model=MODEL, tools=TOOLS, messages=ASK, extra_body={"reasoning_effort": effort}
    )
    m = r.choices[0].message
    calls = [(c.id, c.function.name, c.function.arguments) for c in m.tool_calls or []]
    return calls, m.content or "", r.usage


def streamed(effort: str):
    parts: dict[int, list[str]] = {}
    names: dict[int, str] = {}
    ids: dict[int, str] = {}
    content: list[str] = []
    stream = client.chat.completions.create(
        model=MODEL,
        tools=TOOLS,
        messages=ASK,
        stream=True,
        extra_body={"reasoning_effort": effort},
    )
    for chunk in stream:
        if not chunk.choices:
            continue
        d = chunk.choices[0].delta
        content.append(d.content or "")
        for tc in d.tool_calls or []:
            ids[tc.index] = tc.id or ids.get(tc.index, "")
            names[tc.index] = (tc.function and tc.function.name) or names.get(tc.index, "")
            parts.setdefault(tc.index, []).append((tc.function and tc.function.arguments) or "")
    calls = [(ids[i], names[i], "".join(parts[i])) for i in parts]
    return calls, "".join(content), None


def verdict(calls, content) -> str:
    if "<atem:" in content:
        return "FAIL raw <atem: text"
    if len(calls) != 1 or calls[0][1] != "get_forecast":
        return f"FAIL no single tool call: {content[:120]!r}"
    try:
        return "ok " + json.dumps(json.loads(calls[0][2]), ensure_ascii=False)
    except json.JSONDecodeError:
        return f"FAIL arguments not JSON: {calls[0][2][:120]!r}"


last = None
for effort in ("low", "xhigh"):
    for fn in (plain, streamed):
        with Timer() as t:
            calls, content, usage = fn(effort)
        print(f"{effort:5} {fn.__name__:8} {t.s:5} s  {verdict(calls, content)}  {usage or ''}")
        if fn is plain and effort == "low" and calls:
            last = calls[0]

if last:
    call_id, name, args = last
    turn = [
        *ASK,
        {
            "role": "assistant",
            "content": "",
            "tool_calls": [
                {"id": call_id, "type": "function", "function": {"name": name, "arguments": args}}
            ],
        },
        {"role": "tool", "tool_call_id": call_id, "content": json.dumps({"p_rain": 80})},
    ]
    with Timer() as t:
        r = client.chat.completions.create(
            model=MODEL, tools=TOOLS, messages=turn, extra_body={"reasoning_effort": "low"}
        )
    answer = r.choices[0].message.content or ""
    flag = "FAIL raw <atem:" if "<atem:" in answer else "ok"
    print(f"second turn {t.s} s {flag}: {answer[:200]!r}", r.usage)
