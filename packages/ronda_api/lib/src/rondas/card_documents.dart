/// {@template card_view_document}
/// One `rondas/{id}/views/card` document, in its wire shape: the weekly card
/// the organiser composed for the phone to draw with genui (`weekly_card.py`).
///
/// `status` is `agent` when [messages] carry the card as A2UI messages, and
/// `template` when the phone shows the fixed card instead ([reason] says why).
/// {@endtemplate}
class const CardViewDocument({
  /// The ISO week the card is for (`2026-W45`).
  required final String week,

  /// `agent` or `template`.
  required final String status,

  /// The A2UI messages, in order, for the `agent` status; empty otherwise.
  required final List<Map<String, Object?>> messages,

  /// Why the template shows, when it does.
  final String reason = '',
}) {
  /// {@macro card_view_document}
  this;

  /// Reads the document from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {'week': final String week, 'status': final String status}) {
      return CardViewDocument(
        week: week,
        status: status,
        messages: switch (json['messages']) {
          final List<Object?> messages => [
            for (final message in messages)
              switch (message) {
                final Map<Object?, Object?> message => {
                  for (final MapEntry(:key, :value) in message.entries)
                    key.toString(): value,
                },
                _ => throw const FormatException('a message is not an object'),
              },
          ],
          _ => const [],
        },
        reason: switch (json['reason']) {
          final String reason => reason,
          _ => '',
        },
      );
    }
    throw const FormatException('views/card has another shape');
  }
}
