# device_store

Data layer. A thin client over [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
for string values that stay on this device: `read(key)`, `write(key, value)`, `delete(key)`.

- **iOS:** `IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)`, not
  synchronised with iCloud, not restored to another device.
- **Android:** `AndroidOptions()`, the plugin's recommended default (RSA OAEP key wrapping,
  AES-GCM data). The app must also turn backup off in its manifest (`allowBackup="false"`,
  `dataExtractionRules`, `fullBackupContent`), or a restore fails to unwrap the key.
- **Web:** the plugin's web storage is experimental and needs HTTPS; values are known to this
  browser only.

It holds no domain logic and logs nothing. Only bootstrap constructs it; repositories receive it
through their constructor. `const DeviceStore()` uses the real plugin; tests pass a mocked
`FlutterSecureStorage` as `secureStorage`.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
