part of 'buddy_cubit.dart';

/// Whether the choice could be read.
enum BuddyStatus { loading, ready, failure }

/// What is being saved on the buddy card.
enum BuddySaving {
  /// "Elegir": the member picked in the list.
  choose,

  /// "Ahora no": nobody.
  notNow,
}

final class const BuddyState({
  final BuddyStatus status = BuddyStatus.loading,

  /// Whether it is time to choose, who could be chosen, and who is.
  final BuddyOptions? options,

  /// Who is picked in the list, before "Elegir".
  final String? selected,

  /// "Cambiar" was tapped: the list shows again.
  final bool changing = false,

  /// What is on its way, if anything.
  final BuddySaving? saving,

  /// The last choice wasn't saved.
  final bool saveFailed = false,

  /// The buddy card: someone who chose this member missed a week.
  final BuddyAsk? ask,

  /// WhatsApp opens on this phone; never on web.
  final bool canWhatsApp = false,
}) extends Equatable {
  BuddyState copyWith({
    BuddyStatus? status,
    BuddyOptions? options,
    String? Function()? selected,
    bool? changing,
    BuddySaving? Function()? saving,
    bool? saveFailed,
    BuddyAsk? Function()? ask,
    bool? canWhatsApp,
  }) => BuddyState(
    status: status ?? this.status,
    options: options ?? this.options,
    selected: selected == null ? this.selected : selected(),
    changing: changing ?? this.changing,
    saving: saving == null ? this.saving : saving(),
    saveFailed: saveFailed ?? this.saveFailed,
    ask: ask == null ? this.ask : ask(),
    canWhatsApp: canWhatsApp ?? this.canWhatsApp,
  );

  @override
  List<Object?> get props => [
    status,
    options,
    selected,
    changing,
    saving,
    saveFailed,
    ask,
    canWhatsApp,
  ];
}
