/// {@template register_device_failure}
/// This phone's token could not be read or saved. It carries no detail on
/// purpose: the token addresses the phone and must not reach a log.
/// {@endtemplate}
class RegisterDeviceFailure implements Exception {
  /// {@macro register_device_failure}
  const new();
}

/// {@template push_permission_failure}
/// The notification permission could not be read or asked.
/// {@endtemplate}
class PushPermissionFailure implements Exception {
  /// {@macro push_permission_failure}
  const new();
}
