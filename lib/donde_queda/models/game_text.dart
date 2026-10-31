import 'package:formz/formz.dart';

/// Why a [GameText] is not valid.
enum GameTextError {
  /// Nothing but spaces, where something is needed.
  empty,

  /// Longer than [GameText.maxLength].
  tooLong,
}

/// One line typed for ¿Dónde queda?: what the photo is (needed) or the hint
/// (optional). Spaces and line breaks collapse into single spaces; [text]
/// is what is sent. The server checks the words themselves.
class GameText extends FormzInput<String, GameTextError> {
  /// An untouched field; [optional] for the hint.
  const new pure({this.optional = false}) : super.pure('');

  /// A field the person typed in.
  const new dirty(super.value, {this.optional = false}) : super.dirty();

  /// The longest line taken; `functions/donde_queda.py` holds the same.
  static const maxLength = 80;

  /// Whether it may stay empty.
  final bool optional;

  /// The line as it is sent.
  String get text =>
      value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

  @override
  GameTextError? validator(String value) {
    final line = value
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .join(' ');
    if (line.isEmpty && !optional) return GameTextError.empty;
    if (line.length > maxLength) return GameTextError.tooLong;
    return null;
  }
}
