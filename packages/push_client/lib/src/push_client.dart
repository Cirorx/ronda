// getToken and onTokenRefresh are deprecated in firebase_messaging 17 for
// the installation-id register()/onRegistered API. The console's test message
// and the HTTP v1 API address registration tokens, so Ronda keeps them until
// the sender moves to installation ids.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Where this app instance runs, as a token is saved with it: the sender
/// builds a different payload per platform.
enum PushPlatform {
  /// An Android phone.
  android,

  /// An iPhone (push needs the paid Apple Developer Program).
  ios,

  /// A browser.
  web,
}

/// Whether this app may show notifications.
enum PushAuthorization {
  /// Allowed (on iOS, also "provisional": delivered quietly).
  authorized,

  /// Never asked.
  notDetermined,

  /// Refused, but the system will still show its prompt again (Android 13+).
  denied,

  /// Refused, and the system won't ask again: only the phone's settings
  /// turn notifications on.
  deniedPermanently,
}

/// {@template push_client}
/// Firebase Cloud Messaging and the phone's notifications for Ronda.
///
/// Holds the FCM token, the notification permission and the high-importance
/// [rsvpChannelId] channel every Ronda notification goes to on Android.
/// Messages arrive data-only on Android (`docs/STACK.md` § Push), so the
/// phone draws them with flutter_local_notifications: [showMessage] does it
/// in the background isolate, [showForegroundMessages] while the app is
/// open. On web, notifications are the service worker's and the browser's.
///
/// It logs nothing, and the token it returns must never reach a log either.
/// {@endtemplate}
class PushClient {
  /// {@macro push_client}
  new({
    required this._messaging,
    required this._notifications,
    this._vapidKey,
    this._foregroundMessages,
    this._isWeb = kIsWeb,
    TargetPlatform? targetPlatform,
  }) : _targetPlatform = targetPlatform ?? defaultTargetPlatform;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _notifications;

  /// The web push certificate's public key (Cloud Messaging → Web Push
  /// certificates in the console); empty until the owner makes one. Not a
  /// secret: browsers receive it to subscribe.
  final String? _vapidKey;

  /// `FirebaseMessaging.onMessage` unless a test passes its own.
  final Stream<RemoteMessage>? _foregroundMessages;
  final bool _isWeb;
  final TargetPlatform _targetPlatform;

  /// The Android channel every Ronda notification uses, high importance so
  /// "¿Venís?" makes a sound and peeks over the screen. The manifest names it
  /// as FCM's default channel, so a notification message (the console's
  /// test message) lands on it too.
  static const rsvpChannelId = 'rsvp';

  /// The status-bar icon, `android/app/src/main/res/drawable/`.
  static const notificationIcon = 'ic_notification';

  /// The channel's name until the app creates it with a localized one (only
  /// a background message arriving before the app ever started needs it).
  static const fallbackChannelName = 'Ronda';

  /// The service worker on web, `web/firebase-messaging-sw.js`. Given as a
  /// relative path it resolves against the page's base href, so it works
  /// under `/app/` too (Firebase's default is the origin's root).
  static const webWorkerScript = 'firebase-messaging-sw.js';

  /// Where this app instance runs.
  PushPlatform get platform => switch (_targetPlatform) {
    _ when _isWeb => PushPlatform.web,
    TargetPlatform.iOS => PushPlatform.ios,
    _ => PushPlatform.android,
  };

  /// Prepares the phone's notifications and creates the [rsvpChannelId]
  /// channel named [channelName] (shown in the phone's settings), without
  /// asking for any permission. A no-op on web.
  Future<void> initialize({
    required String channelName,
    required String channelDescription,
  }) async {
    if (_isWeb) return;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(notificationIcon),
        // The permission is asked from a tap, never at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            rsvpChannelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );
  }

  /// Whether notifications are allowed, without asking.
  Future<PushAuthorization> authorization() async =>
      _authorization(await _messaging.getNotificationSettings());

  /// Shows the system's permission prompt (Android 13+, iOS, web) and returns
  /// the answer. Call it from a tap: browsers ignore it otherwise.
  Future<PushAuthorization> requestAuthorization() async =>
      _authorization(await _messaging.requestPermission());

  static PushAuthorization _authorization(NotificationSettings settings) =>
      switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushAuthorization.authorized,
        AuthorizationStatus.notDetermined => PushAuthorization.notDetermined,
        AuthorizationStatus.denied => PushAuthorization.denied,
        AuthorizationStatus.deniedPermanently =>
          PushAuthorization.deniedPermanently,
      };

  /// This app instance's FCM registration token, or `null` when there is
  /// none. On web it uses the VAPID key when one was given, and registers
  /// [webWorkerScript].
  ///
  /// The token addresses this phone: never log it.
  Future<String?> token() => _isWeb
      ? _messaging.getToken(
          vapidKey: (_vapidKey?.isNotEmpty ?? false) ? _vapidKey : null,
          serviceWorkerScriptPath: webWorkerScript,
        )
      : _messaging.getToken();

  /// A new token whenever FCM rotates this app instance's token.
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  /// Shows every message that arrives while the app is open: Android shows
  /// nothing on its own then, not even a notification message. Does nothing
  /// on web. Cancel the subscription to stop.
  StreamSubscription<RemoteMessage>? showForegroundMessages() {
    if (_isWeb) return null;
    return (_foregroundMessages ?? FirebaseMessaging.onMessage).listen(
      (message) => unawaited(_show(message)),
    );
  }

  /// Shows a message that arrived while the app was in the background or
  /// closed: the body of the background handler.
  ///
  /// Only data-only messages: Android already showed a notification message
  /// itself, on the channel the manifest names.
  Future<void> showMessage(RemoteMessage message) async {
    if (_isWeb || message.notification != null) return;
    await _show(message);
  }

  /// Draws [message] on the [rsvpChannelId] channel: `title` and `body` from
  /// its data (Ronda's own payload), else from its notification. A message
  /// with neither is not shown.
  Future<void> _show(RemoteMessage message) async {
    final data = message.data;
    final title = data['title'] ?? message.notification?.title;
    final body = data['body'] ?? message.notification?.body;
    if (title is! String || body is! String) return;
    await _notifications.show(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          rsvpChannelId,
          fallbackChannelName,
          icon: notificationIcon,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
