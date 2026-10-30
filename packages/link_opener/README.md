# link_opener

Data layer. Hands a `mailto:`, `tel:` or `https:` link to the app the phone uses for it (the
mail app, the dialer, the browser) over [url_launcher](https://pub.dev/packages/url_launcher).
Built for Ajustes: writing to Ronda and calling the helplines.

| Member | Does |
|---|---|
| `open(uri)` | Opens the link outside the app; `false` when no app takes it |

It holds no domain logic and logs nothing. Only bootstrap constructs it; `contact_repository`
receives it through its constructor. Tests pass a stand-in `launch` function.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
