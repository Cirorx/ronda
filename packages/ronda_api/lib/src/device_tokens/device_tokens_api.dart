import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ronda_api/src/ronda_api.dart';

/// Where the sender finds a member's phones: one document per FCM token
/// under `users/{uid}/tokens`, with the platform it runs on and when it was
/// saved (`docs/ARCHITECTURE.md` § Data model). No client reads them back.
extension DeviceTokensApi on RondaApi {
  /// The subcollection of `users/{uid}` that holds the tokens.
  static const tokensCollection = 'tokens';

  /// Writes `users/{uid}/tokens/{token}` = exactly `{platform, updatedAt}`,
  /// stamped with the server's time; saving the same token again refreshes
  /// it.
  ///
  /// [platform] is `android`, `ios` or `web`. The token is the document id,
  /// so a failed write's error can carry it: callers must not log errors
  /// from this method.
  Future<void> saveDeviceToken({
    required String uid,
    required String token,
    required String platform,
  }) => firestore
      .collection(RondaApi.usersCollection)
      .doc(uid)
      .collection(tokensCollection)
      .doc(token)
      .set({'platform': platform, 'updatedAt': FieldValue.serverTimestamp()});
}
