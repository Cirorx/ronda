// The client reads tokens through firebase_messaging's deprecated getToken
// API on purpose (see PushClient.token), so the tests stub it.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_client/push_client.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging;

class _MockNotifications extends Mock
    implements FlutterLocalNotificationsPlugin;

class _MockAndroidNotifications extends Mock
    implements AndroidFlutterLocalNotificationsPlugin;

class _MockNotificationSettings extends Mock implements NotificationSettings;

const _invitation = RemoteMessage(
  messageId: 'message-1',
  data: {'title': 'Jueves 16:00 · mate', 'body': '¿Venís?'},
);

void main() {
  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const AndroidNotificationChannel('id', 'name'));
    registerFallbackValue(const NotificationDetails());
  });

  group(PushClient, () {
    late FirebaseMessaging messaging;
    late FlutterLocalNotificationsPlugin notifications;
    late AndroidFlutterLocalNotificationsPlugin android;
    late StreamController<RemoteMessage> foreground;

    setUp(() {
      messaging = _MockFirebaseMessaging();
      notifications = _MockNotifications();
      android = _MockAndroidNotifications();
      foreground = StreamController<RemoteMessage>.broadcast();
      addTearDown(foreground.close);
      when(() => notifications.initialize(settings: any(named: 'settings')))
          .thenAnswer((_) async => true);
      when(
        () => notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);
      when(() => android.createNotificationChannel(any()))
          .thenAnswer((_) async {});
      when(
        () => notifications.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
        ),
      ).thenAnswer((_) async {});
    });

    PushClient buildSubject({
      bool isWeb = false,
      TargetPlatform targetPlatform = TargetPlatform.android,
      String? vapidKey,
    }) => PushClient(
      messaging: messaging,
      notifications: notifications,
      vapidKey: vapidKey,
      foregroundMessages: foreground.stream,
      isWeb: isWeb,
      targetPlatform: targetPlatform,
    );

    void verifyNothingShown() => verifyNever(
      () => notifications.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
      ),
    );

    test('reads the platform it runs on when none is given', () {
      expect(
        PushClient(messaging: messaging, notifications: notifications).platform,
        isA<PushPlatform>(),
      );
    });

    group('platform', () {
      test('is android on an Android phone', () {
        expect(buildSubject().platform, equals(PushPlatform.android));
      });

      test('is ios on an iPhone', () {
        expect(
          buildSubject(targetPlatform: TargetPlatform.iOS).platform,
          equals(PushPlatform.ios),
        );
      });

      test('is web in a browser, whatever the device', () {
        expect(
          buildSubject(
            isWeb: true,
            targetPlatform: TargetPlatform.iOS,
          ).platform,
          equals(PushPlatform.web),
        );
      });
    });

    group('initialize', () {
      test('creates the high-importance rsvp channel with the given name '
          'and asks for nothing', () async {
        await buildSubject().initialize(
          channelName: 'Tu ronda de la semana',
          channelDescription: 'La pregunta del martes',
        );

        final settings =
            verify(
                  () => notifications.initialize(
                    settings: captureAny(named: 'settings'),
                  ),
                ).captured.single
                as InitializationSettings;
        expect(
          settings.android?.defaultIcon,
          equals(PushClient.notificationIcon),
        );
        expect(settings.iOS?.requestAlertPermission, isFalse);
        expect(settings.iOS?.requestBadgePermission, isFalse);
        expect(settings.iOS?.requestSoundPermission, isFalse);
        final channel =
            verify(() => android.createNotificationChannel(captureAny()))
                    .captured
                    .single
                as AndroidNotificationChannel;
        expect(channel.id, equals(PushClient.rsvpChannelId));
        expect(channel.name, equals('Tu ronda de la semana'));
        expect(channel.description, equals('La pregunta del martes'));
        expect(channel.importance, equals(Importance.high));
      });

      test('creates no channel off Android', () async {
        when(
          () => notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(null);

        await buildSubject(targetPlatform: TargetPlatform.iOS)
            .initialize(channelName: 'name', channelDescription: 'description');

        verifyNever(() => android.createNotificationChannel(any()));
      });

      test('does nothing on web', () async {
        await buildSubject(isWeb: true)
            .initialize(channelName: 'name', channelDescription: 'description');

        verifyNever(
          () => notifications.initialize(settings: any(named: 'settings')),
        );
      });
    });

    group('authorization', () {
      final cases = {
        AuthorizationStatus.authorized: PushAuthorization.authorized,
        AuthorizationStatus.provisional: PushAuthorization.authorized,
        AuthorizationStatus.notDetermined: PushAuthorization.notDetermined,
        AuthorizationStatus.denied: PushAuthorization.denied,
        AuthorizationStatus.deniedPermanently:
            PushAuthorization.deniedPermanently,
      };

      NotificationSettings settings(AuthorizationStatus status) {
        final settings = _MockNotificationSettings();
        when(() => settings.authorizationStatus).thenReturn(status);
        return settings;
      }

      for (final MapEntry(key: status, value: expected) in cases.entries) {
        test('returns $expected for $status, without asking', () async {
          when(messaging.getNotificationSettings)
              .thenAnswer((_) async => settings(status));

          expect(await buildSubject().authorization(), equals(expected));
          verifyNever(messaging.requestPermission);
        });

        test('requestAuthorization returns $expected for $status', () async {
          when(messaging.requestPermission)
              .thenAnswer((_) async => settings(status));

          expect(await buildSubject().requestAuthorization(), equals(expected));
        });
      }
    });

    group('token', () {
      setUp(() {
        when(
          () => messaging.getToken(
            vapidKey: any(named: 'vapidKey'),
            serviceWorkerScriptPath: any(named: 'serviceWorkerScriptPath'),
          ),
        ).thenAnswer((_) async => 'fake-token');
      });

      test('returns the FCM token, without a VAPID key on a phone', () async {
        expect(
          await buildSubject(vapidKey: 'fake-vapid').token(),
          equals('fake-token'),
        );
        verify(() => messaging.getToken()).called(1);
      });

      test('passes the VAPID key and the service worker on web', () async {
        await buildSubject(isWeb: true, vapidKey: 'fake-vapid').token();

        verify(
          () => messaging.getToken(
            vapidKey: 'fake-vapid',
            serviceWorkerScriptPath: PushClient.webWorkerScript,
          ),
        ).called(1);
      });

      test('passes no key on web while there is none', () async {
        await buildSubject(isWeb: true, vapidKey: '').token();
        await buildSubject(isWeb: true).token();

        verify(
          () => messaging.getToken(
            serviceWorkerScriptPath: PushClient.webWorkerScript,
          ),
        ).called(2);
      });
    });

    group('tokenRefreshes', () {
      test("are FCM's new tokens", () {
        when(() => messaging.onTokenRefresh)
            .thenAnswer((_) => Stream.value('fake-new-token'));

        expect(
          buildSubject().tokenRefreshes,
          emitsInOrder(['fake-new-token', emitsDone]),
        );
      });
    });

    group('showMessage', () {
      test('draws a data-only message on the rsvp channel', () async {
        await buildSubject().showMessage(_invitation);

        final details =
            verify(
                  () => notifications.show(
                    id: 'message-1'.hashCode,
                    title: 'Jueves 16:00 · mate',
                    body: '¿Venís?',
                    notificationDetails: captureAny(
                      named: 'notificationDetails',
                    ),
                  ),
                ).captured.single
                as NotificationDetails;
        expect(details.android?.channelId, equals(PushClient.rsvpChannelId));
        expect(details.android?.icon, equals(PushClient.notificationIcon));
        expect(details.android?.importance, equals(Importance.high));
        expect(details.android?.priority, equals(Priority.high));
      });

      test('leaves a notification message to Android, which already showed '
          'it', () async {
        await buildSubject().showMessage(
          const RemoteMessage(
            notification: RemoteNotification(title: 'Prueba', body: 'Hola'),
          ),
        );

        verifyNothingShown();
      });

      test('shows nothing for a message without a title and a body', () async {
        await buildSubject().showMessage(
          const RemoteMessage(data: {'title': 'Solo título'}),
        );

        verifyNothingShown();
      });

      test('shows nothing on web', () async {
        await buildSubject(isWeb: true).showMessage(_invitation);

        verifyNothingShown();
      });
    });

    group('showForegroundMessages', () {
      test('draws every message that arrives while the app is open, '
          'notification messages included', () async {
        final subscription = buildSubject().showForegroundMessages();
        addTearDown(() => subscription?.cancel());

        foreground
          ..add(_invitation)
          ..add(
            const RemoteMessage(
              messageId: 'message-2',
              notification: RemoteNotification(title: 'Prueba', body: 'Hola'),
            ),
          );
        await pumpEventQueue();

        verify(
          () => notifications.show(
            id: 'message-1'.hashCode,
            title: 'Jueves 16:00 · mate',
            body: '¿Venís?',
            notificationDetails: any(named: 'notificationDetails'),
          ),
        ).called(1);
        verify(
          () => notifications.show(
            id: 'message-2'.hashCode,
            title: 'Prueba',
            body: 'Hola',
            notificationDetails: any(named: 'notificationDetails'),
          ),
        ).called(1);
      });

      test('listens to nothing on web', () {
        expect(buildSubject(isWeb: true).showForegroundMessages(), isNull);
        expect(foreground.hasListener, isFalse);
      });
    });
  });
}
