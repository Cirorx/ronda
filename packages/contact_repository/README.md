# contact_repository

Repository layer. How a member reaches a person: a mail to Ronda's contact address, or a call
to a helpline, over `link_opener`.

| Member | Does |
|---|---|
| `email` | The contact address, set at build time with `--dart-define=RONDA_CONTACT_EMAIL` (default `hola@ciroapps.com`, in `lib/bootstrap.dart`) |
| `writeEmail(subject:, body:)` | Opens the mail app on a mail to `email` |
| `callHelpline(helpline)` | Opens the dialer on a `Helpline`: 0800 0767, *0767 or 911 |

Nothing is sent from here: the person sends the mail or places the call in their own app. A
`ContactFailure` (no detail) means no app opened.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
