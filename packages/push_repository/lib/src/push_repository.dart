import 'dart:async';

import 'package:device_store/device_store.dart';
import 'package:push_client/push_client.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda_api/ronda_api.dart';

/// {@template push_repository}
/// This phone's push notifications for a member.
///
/// It asks the notification permission through [PushClient] and saves the
/// phone's FCM token under `users/{uid}/tokens/{token}` with its platform
/// through [RondaApi], so the server can reach the member, and deletes both
/// when the member signs out. It also remembers on the phone, through
/// [DeviceStore], when "Ahora no" was tapped on the card that asks. The
/// token never leaves this class: callers get no token, and failures carry
/// no detail.
/// {@endtemplate}
class PushRepository {
  /// {@macro push_repository}
  const new({
    required this._pushClient,
    required this._rondaApi,
    required this._deviceStore,
    this._now = DateTime.now,
  });

  final PushClient _pushClient;
  final RondaApi _rondaApi;
  final DeviceStore _deviceStore;
  final DateTime Function() _now;

  /// The device-store key that holds when "Ahora no" was last tapped, as an
  /// ISO 8601 UTC time.
  static const promptSnoozeKey = 'push.promptSnoozedAt';

  /// How long "Ahora no" keeps the card away (an owner's call, #51).
  static const promptSnooze = Duration(days: 7);

  /// How long each step of [unregisterDevice] may take before it gives up,
  /// so signing out never waits on a phone without network.
  static const unregisterTimeout = Duration(seconds: 5);

  /// Whether notifications are allowed, without asking.
  ///
  /// Throws a [PushPermissionFailure] when it can't be read.
  Future<PushPermission> permission() async {
    try {
      return (await _pushClient.authorization()).toPermission();
    } on Exception {
      throw const PushPermissionFailure();
    }
  }

  /// Shows the system's prompt and returns the answer; call it from a tap.
  ///
  /// Throws a [PushPermissionFailure] when the prompt fails.
  Future<PushPermission> askPermission() async {
    try {
      return (await _pushClient.requestAuthorization()).toPermission();
    } on Exception {
      throw const PushPermissionFailure();
    }
  }

  /// Saves this phone's token for [uid], so the server can send to it.
  ///
  /// Throws a [RegisterDeviceFailure] when there is no token or the write
  /// fails (no network, no Play services, an iPhone without APNs).
  Future<void> registerDevice(String uid) async {
    final String? token;
    try {
      token = await _pushClient.token();
    } on Exception {
      throw const RegisterDeviceFailure();
    }
    if (token == null) throw const RegisterDeviceFailure();
    await _save(uid, token);
  }

  /// Saves every new token FCM gives this phone for [uid], for as long as
  /// the stream is listened to. Each save is one event; a save that fails
  /// is a [RegisterDeviceFailure] error on the stream.
  Stream<void> keepDeviceRegistered(String uid) =>
      _pushClient.tokenRefreshes.asyncMap((token) => _save(uid, token));

  /// Forgets this phone for [uid], before they sign out: deletes
  /// `users/{uid}/tokens/{token}` while [uid] is still signed in (only they
  /// may), then the token itself, so whoever signs in next on this phone
  /// gets a new one and none of [uid]'s pushes. The token is deleted even
  /// when its document can't be, so a document left behind reaches nobody.
  ///
  /// On a browser that never allowed notifications it does nothing: there
  /// is no token, and asking for one would open the browser's prompt. Each
  /// step gives up after [unregisterTimeout].
  ///
  /// Throws an [UnregisterDeviceFailure] when either step fails.
  Future<void> unregisterDevice(String uid) async {
    var failed = false;
    try {
      if (_pushClient.platform == PushPlatform.web &&
          await _pushClient.authorization() != PushAuthorization.authorized) {
        return;
      }
      final token = await _pushClient.token().timeout(unregisterTimeout);
      if (token != null) {
        await _rondaApi
            .deleteDeviceToken(uid: uid, token: token)
            .timeout(unregisterTimeout);
      }
    } on Exception {
      failed = true;
    }
    try {
      await _pushClient.deleteToken().timeout(unregisterTimeout);
    } on Exception {
      failed = true;
    }
    if (failed) throw const UnregisterDeviceFailure();
  }

  /// Whether "Ahora no" was tapped on this phone less than [promptSnooze]
  /// ago. `false` when it never was, or what is stored can't be read.
  Future<bool> promptSnoozed() async {
    final String? stored;
    try {
      stored = await _deviceStore.read(promptSnoozeKey);
    } on Exception {
      return false;
    }
    final snoozedAt = stored == null ? null : DateTime.tryParse(stored);
    if (snoozedAt == null) return false;
    final age = _now().difference(snoozedAt);
    return !age.isNegative && age < promptSnooze;
  }

  /// Remembers on this phone that "Ahora no" was tapped now.
  ///
  /// Throws a [SnoozePromptFailure] when it can't be stored.
  Future<void> snoozePrompt() async {
    try {
      await _deviceStore.write(
        promptSnoozeKey,
        _now().toUtc().toIso8601String(),
      );
    } on Exception {
      throw const SnoozePromptFailure();
    }
  }

  Future<void> _save(String uid, String token) async {
    try {
      await _rondaApi.saveDeviceToken(
        uid: uid,
        token: token,
        platform: _pushClient.platform.name,
      );
    } on Exception {
      throw const RegisterDeviceFailure();
    }
  }
}

extension on PushAuthorization {
  PushPermission toPermission() => switch (this) {
    PushAuthorization.authorized => PushPermission.allowed,
    PushAuthorization.notDetermined => PushPermission.notAsked,
    PushAuthorization.denied => PushPermission.refused,
    PushAuthorization.deniedPermanently => PushPermission.blocked,
  };
}
