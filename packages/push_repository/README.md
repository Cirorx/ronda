# push_repository

Repository layer. This phone's push notifications for a member, over `push_client` and
`ronda_api`.

| Member | Does |
|---|---|
| `permission()` | `PushPermission`: allowed, notAsked, refused (the phone can ask again) or blocked |
| `askPermission()` | The system's prompt, from a tap |
| `registerDevice(uid)` | Saves this phone's FCM token as `users/{uid}/tokens/{token}` = `{platform, updatedAt}` |
| `keepDeviceRegistered(uid)` | Saves every refreshed token while listened to |

The token never leaves this package: callers get none, and `RegisterDeviceFailure` /
`PushPermissionFailure` carry no detail. Tests run `ronda_api` over `fake_cloud_firestore`.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
