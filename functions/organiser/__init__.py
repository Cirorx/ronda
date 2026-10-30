"""The organiser agent (docs/ARCHITECTURE.md § Organiser agent): a model on Baseten that calls
Ronda's tools, with every outgoing message checked by gates in code.

- `model`: the model client interface, Muse Spark Open on Baseten, streamed, falling back to
  Spark 1.3 on the Meta Model API.
- `agent`: the loop. It validates every tool call with pydantic, retries once with the
  validation error, and stops at a step cap.
- `tools`: the tools the model may call, each idempotent, with a required `reason`.
- `gates` and `text`: the rules every message passes before it leaves.
- `outbox`: composes, gates and sends one message, and records it as sent ("Salió") or held
  ("Frenado").
- `trace`: the admin's trace (`agent_runs/{id}/steps/{n}`) and the members' acta.
- `weather`: Open-Meteo's forecast and sunset.
"""
