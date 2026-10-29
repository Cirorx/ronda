# share_sheet

Data layer. Opens the phone's share sheet with one file over
[share_plus](https://pub.dev/packages/share_plus), so a person can print it, send it or save it
with the apps they already use. Built for the "Un mate de más" flyer's [Imprimir o compartir].

| Member | Does |
|---|---|
| `shareFile(bytes, fileName:, mimeType:, title:)` | Opens the sheet; `false` when the person closed it |

It holds no domain logic and logs nothing. Only bootstrap constructs it; `flyer_repository`
receives it through its constructor. Tests pass a mocked `SharePlus`.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
