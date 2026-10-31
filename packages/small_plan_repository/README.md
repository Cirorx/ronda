# small_plan_repository

Repository layer. Algo chico esta semana: one small plan a week with a day, a time and a place.

| Member | Does |
|---|---|
| `current(uid)` | What Mi ronda shows: the offer, this week's plan, last week's question asked once, or nothing |
| `suggestions()` | Three ideas from `suggest_small_plans` |
| `shapeText(uid, text)` / `shapeVoiceNote(uid)` | What the member typed or said, shaped into a plan (or why it was dropped) |
| `startVoiceNote()`, `voiceLevels()`, `discardVoiceNote()` | The recorder, as `OnboardingRepository` has it |
| `save`, `answerFollowUp`, `skipThisWeek` | The plan on the phone, under the member's uid |
| `addToCalendar(plan, title:)` | The phone's calendar, or an `.ics` file on web |

The plan lives in `device_store` only; the two callables keep nothing. Nothing is sent before
`users/{uid}.terms` exists, and nothing older than last week is kept.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
