# push_client

Data layer. Firebase Cloud Messaging and the phone's notifications for Ronda, over
[firebase_messaging](https://pub.dev/packages/firebase_messaging) and
[flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications).

| Member | Does |
|---|---|
| `initialize(channelName:, channelDescription:)` | Prepares the notifications plugin and creates the high-importance `rsvp` Android channel; asks for nothing. A no-op on web |
| `authorization()` | Whether notifications are allowed, without asking |
| `requestAuthorization()` | The system's prompt (Android 13+, iOS, web); call it from a tap |
| `token()` | The FCM registration token; on web with the VAPID key and the `firebase-messaging-sw.js` worker |
| `tokenRefreshes` | A new token whenever FCM rotates it |
| `showMessage(message)` | Draws a data-only message on `rsvp`: the background handler's body |
| `showForegroundMessages()` | Draws every message while the app is open |
| `platform` | `android`, `ios` or `web`, saved with the token |

It holds no domain logic and logs nothing; the token it returns must never reach a log. Only
bootstrap constructs it (`lib/bootstrap.dart`, which also holds the top-level background
handler); `push_repository` receives it through its constructor. Tests pass mocked plugins.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
