part of 'error_log_cubit.dart';

/// Whether the log can show the reports.
enum ErrorLogStatus {
  /// Reading.
  loading,

  /// [ErrorLogState.errors] are the newest reports.
  ready,

  /// The account isn't the admin.
  forbidden,

  /// The log couldn't be read.
  failure,
}

/// The reports of one code on one screen, newest first.
final class const ErrorGroup(
  /// What went wrong.
  final String code,

  /// Where.
  final String screen,

  /// Its reports, newest first.
  final List<ClientError> errors,
) extends Equatable {
  /// What identifies the group.
  String get key => keyOf(code, screen);

  /// How many times it was reported.
  int get count => errors.length;

  /// The newest report.
  ClientError get latest => errors.first;

  /// The platforms that reported it, in the order they first show.
  List<String> get platforms => errors.map((e) => e.platform).toSet().toList();

  /// Whether any of its reports stopped the app.
  bool get fatal => errors.any((error) => error.fatal);

  /// The key of a group.
  static String keyOf(String code, String screen) => '$code\n$screen';

  @override
  List<Object?> get props => [code, screen, errors];
}

final class const ErrorLogState({
  final ErrorLogStatus status = ErrorLogStatus.loading,

  /// The newest reports, newest first.
  final List<ClientError> errors = const [],

  /// The open group's key, if one is open.
  final String? openGroup,
}) extends Equatable {
  /// The reports grouped by code and screen, the most recently seen first.
  List<ErrorGroup> get groups {
    final byKey = <String, List<ClientError>>{};
    for (final error in errors) {
      byKey
          .putIfAbsent(ErrorGroup.keyOf(error.code, error.screen), () => [])
          .add(error);
    }
    return [
      for (final group in byKey.values)
        ErrorGroup(group.first.code, group.first.screen, group),
    ];
  }

  /// The open group, while it still has reports.
  ErrorGroup? get group =>
      groups.where((group) => group.key == openGroup).firstOrNull;

  @override
  List<Object?> get props => [status, errors, openGroup];
}
