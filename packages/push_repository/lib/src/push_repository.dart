import 'package:push_client/push_client.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda_api/ronda_api.dart';

/// {@template push_repository}
/// This phone's push notifications for a member.
///
/// It asks the notification permission through [PushClient] and saves the
/// phone's FCM token under `users/{uid}/tokens/{token}` with its platform
/// through [RondaApi], so the server can reach the member. The token never
/// leaves this class: callers get no token, and failures carry no detail.
/// {@endtemplate}
class PushRepository {
  /// {@macro push_repository}
  const new({required this._pushClient, required this._rondaApi});

  final PushClient _pushClient;
  final RondaApi _rondaApi;

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
