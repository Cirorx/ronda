part of 'report_cubit.dart';

/// Whether the screen has what it needs to show.
enum ReportStatus {
  /// Reading who "¿Con quién?" offers and the receipts.
  loading,

  /// Read; a failed read leaves only "Alguien de afuera" and no receipts.
  ready,
}

/// Where sending the form is.
enum ReportSendStatus {
  /// Not sent yet.
  idle,

  /// On its way.
  sending,

  /// Saved on the server: the form is empty again and a receipt shows.
  sent,

  /// It didn't go through.
  failed,

  /// Five reports today already.
  tooMany,
}

/// What the person is doing with one receipt.
enum ReceiptAction {
  /// Adding words to it.
  adding,

  /// Withdrawing it.
  withdrawing,

  /// The words were added.
  added,

  /// The last step on it failed.
  failed,
}

final class const ReportState({
  final ReportStatus status = ReportStatus.loading,

  /// Who "¿Con quién?" offers besides "Alguien de afuera".
  final List<ReportPerson> people = const [],

  /// The person's own receipts, newest first.
  final List<ReportReceipt> receipts = const [],

  /// The tags picked.
  final Set<ReportTag> tags = const {},

  /// Who it was with: a uid, `''` for "Alguien de afuera", `null` while
  /// nobody is picked.
  final String? aboutUid,

  /// The words.
  final ReportText text = const ReportText.pure(),

  /// The words "Agregar algo" adds to a receipt's report.
  final ReportText addition = const ReportText.pure(),

  final ReportSendStatus send = ReportSendStatus.idle,

  /// The receipt being acted on, and what is happening to it.
  final String? receiptId,
  final ReceiptAction? receiptAction,
}) extends Equatable {
  /// Whether [ReportCubit.submitted] would send: someone picked, a tag or
  /// some words, the words not too long, and nothing on its way.
  bool get canSend =>
      aboutUid != null &&
      (tags.isNotEmpty || text.words.isNotEmpty) &&
      text.isValid &&
      send != ReportSendStatus.sending;

  /// Whether "Agregar algo" would send: some words, not too long.
  bool get canAdd =>
      addition.words.isNotEmpty &&
      addition.isValid &&
      receiptAction != ReceiptAction.adding;

  /// The receipts still open: the ones that can take more or be withdrawn.
  List<ReportReceipt> get openReceipts => [
    for (final receipt in receipts)
      if (!receipt.withdrawn) receipt,
  ];

  ReportState copyWith({
    ReportStatus? status,
    List<ReportPerson>? people,
    List<ReportReceipt>? receipts,
    Set<ReportTag>? tags,
    String? Function()? aboutUid,
    ReportText? text,
    ReportText? addition,
    ReportSendStatus? send,
    String? Function()? receiptId,
    ReceiptAction? Function()? receiptAction,
  }) => ReportState(
    status: status ?? this.status,
    people: people ?? this.people,
    receipts: receipts ?? this.receipts,
    tags: tags ?? this.tags,
    aboutUid: aboutUid == null ? this.aboutUid : aboutUid(),
    text: text ?? this.text,
    addition: addition ?? this.addition,
    send: send ?? this.send,
    receiptId: receiptId == null ? this.receiptId : receiptId(),
    receiptAction: receiptAction == null ? this.receiptAction : receiptAction(),
  );

  @override
  List<Object?> get props => [
    status,
    people,
    receipts,
    tags,
    aboutUid,
    text,
    addition,
    send,
    receiptId,
    receiptAction,
  ];
}
