// getToken and onTokenRefresh are deprecated in firebase_messaging 17 for
// the installation-id register()/onRegistered API. The console's test message
// and the HTTP v1 API address registration tokens, so Ronda keeps them until
// the sender moves to installation ids.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

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

/// {@template rsvp_action_labels}
/// What the "Voy" and "Esta no" buttons on the weekly push say, in the
/// phone's language.
/// {@endtemplate}
class const RsvpActionLabels({
  /// "Voy".
  required final String yes,

  /// "Esta no".
  required final String no,
}) {
  /// {@macro rsvp_action_labels}
  this;
}

/// {@template rsvp_action}
/// One tap on "Voy" or "Esta no" in the weekly push: which ronda, which
/// meeting's week, and the answer.
/// {@endtemplate}
class const RsvpAction({
  /// The ronda's id.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W44`), as the push carried it.
  required final String week,

  /// Whether the tap was "Voy".
  required final bool going,
}) {
  /// {@macro rsvp_action}
  this;
}

/// {@template seguimos_action_labels}
/// What the "Sí" and "No" buttons on the ¿seguimos? push say, in the
/// phone's language.
/// {@endtemplate}
class const SeguimosActionLabels({
  /// "Sí".
  required final String yes,

  /// "No".
  required final String no,
}) {
  /// {@macro seguimos_action_labels}
  this;
}

/// {@template seguimos_action}
/// One tap on "Sí" or "No" in the ¿seguimos? push: which ronda, and the
/// answer. It carries no date: the server refuses it once the question has
/// closed.
/// {@endtemplate}
class const SeguimosAction({
  /// The ronda's id.
  required final String rondaId,

  /// Whether the tap was "Sí".
  required final bool yes,
}) {
  /// {@macro seguimos_action}
  this;
}

/// {@template bench_offer_action_labels}
/// What the "Lo tomo" and "Esta vez no" buttons on the offer of a freed seat
/// say, in the phone's language.
/// {@endtemplate}
class const BenchOfferActionLabels({
  /// "Lo tomo".
  required final String take,

  /// "Esta vez no".
  required final String pass,
}) {
  /// {@macro bench_offer_action_labels}
  this;
}

/// {@template bench_offer_action}
/// One tap on "Lo tomo" or "Esta vez no" in the offer of a freed seat: which
/// offer, and the answer. The server refuses it once the offer is over.
/// {@endtemplate}
class const BenchOfferAction({
  /// The offer's id.
  required final String offerId,

  /// Whether the tap was "Lo tomo".
  required final bool take,
}) {
  /// {@macro bench_offer_action}
  this;
}

/// {@template push_tap}
/// A tap on a notification's body (not on one of its buttons) that should
/// open a screen of its own: which kind of push, its ronda and its
/// meeting's week.
/// {@endtemplate}
class const PushTap({
  /// The push's `data.type` (`attendance`).
  required final String type,

  /// The ronda's id.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W45`).
  required final String week,
}) {
  /// {@macro push_tap}
  this;
}

/// {@template push_client}
/// Firebase Cloud Messaging and the phone's notifications for Ronda.
///
/// Holds the FCM token, the notification permission and the high-importance
/// [rsvpChannelId] channel every Ronda notification goes to on Android.
/// Messages arrive data-only on Android (`docs/STACK.md` § Push), so the
/// phone draws them with flutter_local_notifications: [showMessage] does it
/// in the background isolate, [showForegroundMessages] while the app is
/// open. The weekly RSVP push (`data.type == "rsvp"`) gets "Voy" and
/// "Esta no" buttons that answer without opening the app: a tap reaches the
/// handler given to [initialize] in a background isolate, and
/// [rsvpActionFrom] reads it. The ¿seguimos? push (`data.type ==
/// "seguimos"`) gets "Sí" and "No" the same way, read by
/// [seguimosActionFrom]. The offer of a freed seat (`data.type ==
/// "benchOffer"`) gets "Lo tomo" and "Esta vez no", read by
/// [benchOfferActionFrom]. A tap on the body of the attendance ask
/// (`data.type == "attendance"`) comes out of [taps], or [launchTap] when it
/// started the app, so the app opens the roll instead of Mi ronda. On web,
/// notifications are the service worker's and the browser's.
///
/// It logs nothing, and the token it returns must never reach a log either.
/// {@endtemplate}
class PushClient {
  /// {@macro push_client}
  new({
    required this._messaging,
    required this._notifications,
    this._vapidKey,
    this._rsvpLabels,
    this._seguimosLabels,
    this._benchOfferLabels,
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

  /// The RSVP buttons' labels; without them the weekly push shows no
  /// buttons (a tap on it still opens the card).
  final RsvpActionLabels? _rsvpLabels;

  /// The ¿seguimos? buttons' labels; without them that push shows no
  /// buttons (a tap on it still opens the card).
  final SeguimosActionLabels? _seguimosLabels;

  /// The offer's buttons' labels; without them that push shows no buttons
  /// (a tap on it still opens Mi ronda, where the offer is).
  final BenchOfferActionLabels? _benchOfferLabels;

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

  /// `data.type` of the weekly RSVP push (`functions/rsvp.py`).
  static const rsvpType = 'rsvp';

  /// The "Voy" button's action id.
  static const rsvpYesAction = 'rsvp.yes';

  /// The "Esta no" button's action id.
  static const rsvpNoAction = 'rsvp.no';

  /// `data.type` of the ¿seguimos? push (`functions/seguimos.py`).
  static const seguimosType = 'seguimos';

  /// `data.type` of "¿Quién vino hoy?" (`functions/attendance.py`), whose
  /// tap opens the roll ([taps]).
  static const attendanceType = 'attendance';

  final _taps = StreamController<PushTap>.broadcast();

  /// Taps on the body of a notification that opens a screen of its own,
  /// while the app runs (in front or behind).
  Stream<PushTap> get taps => _taps.stream;

  /// The "Sí" button's action id on the ¿seguimos? push.
  static const seguimosYesAction = 'seguimos.yes';

  /// The "No" button's action id on the ¿seguimos? push.
  static const seguimosNoAction = 'seguimos.no';

  /// `data.type` of the offer of a freed seat (`functions/bench.py`).
  static const benchOfferType = 'benchOffer';

  /// The "Lo tomo" button's action id.
  static const benchTakeAction = 'bench.take';

  /// The "Esta vez no" button's action id.
  static const benchPassAction = 'bench.pass';

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
  ///
  /// [onRsvpAction] runs in a background isolate when "Voy" or "Esta no" is
  /// tapped, even with the app closed; it must be a top-level or static
  /// function marked `@pragma('vm:entry-point')`.
  Future<void> initialize({
    required String channelName,
    required String channelDescription,
    DidReceiveBackgroundNotificationResponseCallback? onRsvpAction,
  }) async {
    if (_isWeb) return;
    await _notifications.initialize(
      onDidReceiveBackgroundNotificationResponse: onRsvpAction,
      onDidReceiveNotificationResponse: (response) {
        if (tapFrom(response) case final tap?) _taps.add(tap);
      },
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

  /// The tap that started the app, when a notification [taps] would route
  /// did; `null` otherwise, and on web.
  Future<PushTap?> launchTap() async {
    if (_isWeb) return null;
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return tapFrom(details.notificationResponse);
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

  /// Deletes this app instance's FCM token: nothing sent to it arrives any
  /// more, and the next [token] is a new one. On web it also drops the
  /// browser's push subscription.
  Future<void> deleteToken() => _messaging.deleteToken();

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
  /// with neither is not shown. The weekly RSVP push gets "Voy" and
  /// "Esta no", carrying its ronda and week to [rsvpActionFrom]; the
  /// ¿seguimos? push gets "Sí" and "No", carrying its ronda to
  /// [seguimosActionFrom].
  Future<void> _show(RemoteMessage message) async {
    final data = message.data;
    final title = data['title'] ?? message.notification?.title;
    final body = data['body'] ?? message.notification?.body;
    if (title is! String || body is! String) return;
    final buttons = _buttons(data);
    await _notifications.show(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      payload: buttons?.payload ?? _tapPayload(data),
      notificationDetails: NotificationDetails(
        android: _details(body: body, actions: buttons?.actions ?? const []),
      ),
    );
  }

  ({String payload, List<AndroidNotificationAction> actions})? _buttons(
    Map<String, dynamic> data,
  ) => switch (data) {
    {'type': benchOfferType, 'offerId': final String offerId}
        when _benchOfferLabels != null =>
      (
        payload: jsonEncode({'offerId': offerId}),
        actions: [
          AndroidNotificationAction(benchTakeAction, _benchOfferLabels.take),
          AndroidNotificationAction(benchPassAction, _benchOfferLabels.pass),
        ],
      ),
    _ => _answerButtons(data),
  };

  ({String payload, List<AndroidNotificationAction> actions})? _answerButtons(
    Map<String, dynamic> data,
  ) => switch ((data, _rsvpLabels, _seguimosLabels)) {
    (
      {
        'type': rsvpType,
        'rondaId': final String rondaId,
        'week': final String week,
      },
      final RsvpActionLabels labels,
      _,
    ) =>
      (
        payload: jsonEncode({'rondaId': rondaId, 'week': week}),
        actions: [
          AndroidNotificationAction(rsvpYesAction, labels.yes),
          AndroidNotificationAction(rsvpNoAction, labels.no),
        ],
      ),
    (
      {'type': seguimosType, 'rondaId': final String rondaId},
      _,
      final SeguimosActionLabels labels,
    ) =>
      (
        payload: jsonEncode({'rondaId': rondaId}),
        actions: [
          AndroidNotificationAction(seguimosYesAction, labels.yes),
          AndroidNotificationAction(seguimosNoAction, labels.no),
        ],
      ),
    _ => null,
  };

  /// What a tap on the body carries to [tapFrom]: the attendance ask's ronda
  /// and week; `null` for every other push.
  static String? _tapPayload(Map<String, dynamic> data) => switch (data) {
    {
      'type': attendanceType,
      'rondaId': final String rondaId,
      'week': final String week,
    } =>
      jsonEncode({'type': attendanceType, 'rondaId': rondaId, 'week': week}),
    _ => null,
  };

  /// The screen a tap on a notification's body opens, or `null` for a tap
  /// on a button, a push that opens Mi ronda, or a malformed payload.
  static PushTap? tapFrom(NotificationResponse? response) {
    if (response == null || response.actionId != null) return null;
    try {
      if (jsonDecode(response.payload ?? '') case {
        'type': attendanceType,
        'rondaId': final String rondaId,
        'week': final String week,
      }) {
        return PushTap(type: attendanceType, rondaId: rondaId, week: week);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// Shows a plain notification [id] on the [rsvpChannelId] channel, in
  /// place of any showing with that id: what became of a tap on "Voy" or
  /// "Esta no". A no-op on web.
  Future<void> showNotice({
    required int id,
    required String title,
    required String body,
  }) async {
    if (_isWeb) return;
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _details(body: body)),
    );
  }

  static AndroidNotificationDetails _details({
    required String body,
    List<AndroidNotificationAction> actions = const [],
  }) => AndroidNotificationDetails(
    rsvpChannelId,
    fallbackChannelName,
    icon: notificationIcon,
    importance: Importance.high,
    priority: Priority.high,
    // Expanded, the whole body shows: ¿seguimos? ends on who sees the answer.
    styleInformation: BigTextStyleInformation(body),
    // Each button answers in the background (no app opens) and takes the
    // notification away.
    actions: actions,
  );

  /// The answer in a tap on "Voy" or "Esta no", or `null` for any other
  /// tap (the notification itself, a malformed payload).
  static RsvpAction? rsvpActionFrom(NotificationResponse response) {
    final going = switch (response.actionId) {
      rsvpYesAction => true,
      rsvpNoAction => false,
      _ => null,
    };
    if (going == null) return null;
    try {
      if (jsonDecode(response.payload ?? '') case {
        'rondaId': final String rondaId,
        'week': final String week,
      }) {
        return RsvpAction(rondaId: rondaId, week: week, going: going);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// The answer in a tap on "Lo tomo" or "Esta vez no" in the offer of a
  /// freed seat, or `null` for any other tap.
  static BenchOfferAction? benchOfferActionFrom(NotificationResponse response) {
    final take = switch (response.actionId) {
      benchTakeAction => true,
      benchPassAction => false,
      _ => null,
    };
    if (take == null) return null;
    try {
      if (jsonDecode(response.payload ?? '') case {
        'offerId': final String offerId,
      }) {
        return BenchOfferAction(offerId: offerId, take: take);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// The answer in a tap on "Sí" or "No" in the ¿seguimos? push, or `null`
  /// for any other tap.
  static SeguimosAction? seguimosActionFrom(NotificationResponse response) {
    final yes = switch (response.actionId) {
      seguimosYesAction => true,
      seguimosNoAction => false,
      _ => null,
    };
    if (yes == null) return null;
    try {
      if (jsonDecode(response.payload ?? '') case {
        'rondaId': final String rondaId,
      }) {
        return SeguimosAction(rondaId: rondaId, yes: yes);
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
