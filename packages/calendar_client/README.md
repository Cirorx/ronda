# calendar_client

Data layer. Adds one event to the phone's own calendar over
[add_2_calendar](https://pub.dev/packages/add_2_calendar), so a plan's reminder is the person's and
Ronda sends none. Built for Algo chico esta semana's [Agregar al calendario].

| Member | Does |
|---|---|
| `add(event)` | On a phone, opens the calendar app with the event filled in (`CalendarOutcome.opened`); on web, downloads it as an `.ics` file (`downloaded`); throws `CalendarUnavailableException` when neither works |
| `buildIcs(event, stamp:, uid:)` | The `.ics` text (RFC 5545): floating start and end, escaped and folded |

It holds no domain logic and logs nothing. Only bootstrap constructs it; `small_plan_repository`
receives it through its constructor. The browser download sits behind a conditional import
(`package:web`), so the VM tests never load it. Android needs the `INSERT` event intent in the
manifest's `<queries>`; iOS needs `NSCalendarsUsageDescription` (`docs/STACK.md` § Algo chico esta
semana).

## Tests

```sh
very_good test --coverage --min-coverage 100
```
