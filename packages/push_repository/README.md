# push_repository

Repository layer. This phone's push notifications for a member, over `push_client`,
`ronda_api` and `device_store`.

| Member | Does |
|---|---|
| `permission()` | `PushPermission`: allowed, notAsked, refused (the phone can ask again) or blocked |
| `askPermission()` | The system's prompt, from a tap |
| `registerDevice(uid)` | Saves this phone's FCM token as `users/{uid}/tokens/{token}` = `{platform, updatedAt}` |
| `keepDeviceRegistered(uid)` | Saves every refreshed token while listened to |
| `unregisterDevice(uid)` | Before sign-out: deletes `users/{uid}/tokens/{token}`, then the FCM token itself (nothing on a browser that never allowed notifications) |
| `promptSnoozed()` / `snoozePrompt()` | "Ahora no" on the card, remembered on the phone (`push.promptSnoozedAt`) for `promptSnooze`, 7 days |

The token never leaves this package: callers get none, and `RegisterDeviceFailure` /
`UnregisterDeviceFailure` / `SnoozePromptFailure` / `PushPermissionFailure` carry no detail. Tests run `ronda_api` over `fake_cloud_firestore`.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
