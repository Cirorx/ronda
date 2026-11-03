import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:ronda/settings/models/report_text.dart';
import 'package:safety_repository/safety_repository.dart';

part 'report_state.dart';

/// "Contar algo que pasó": the form (tags, "¿Con quién?", the words), its
/// sending, and the person's own receipts with "Agregar algo" and
/// "Retirar".
///
/// The server decides who may be named and keeps the report from everyone
/// but the admin; the receipt never says what the admin did.
class ReportCubit extends Cubit<ReportState> implements StepNamed {
  new({required this._safetyRepository, required this._uid})
    : super(const ReportState());

  final SafetyRepository _safetyRepository;
  final String _uid;
  StreamSubscription<List<ReportReceipt>>? _receipts;

  /// Reads who "¿Con quién?" offers and follows the receipts. A failed read
  /// leaves "Alguien de afuera" alone, so a report can always be sent.
  void load() {
    unawaited(_receipts?.cancel());
    _receipts = _safetyRepository
        .watchReceipts(_uid)
        .listen(
          (receipts) => emit(state.copyWith(receipts: receipts)),
          onError: addError,
        );
    unawaited(_readPeople());
  }

  Future<void> _readPeople() async {
    List<ReportPerson> people;
    try {
      people = await _safetyRepository.reportPeople();
    } on SafetyFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      people = const [];
    }
    if (isClosed) return;
    emit(state.copyWith(status: ReportStatus.ready, people: people));
  }

  /// Picks [tag], or drops it if it was picked.
  void tagToggled(ReportTag tag) {
    final tags = {...state.tags};
    if (!tags.remove(tag)) tags.add(tag);
    emit(state.copyWith(tags: tags, send: ReportSendStatus.idle));
  }

  /// Who it was with: [uid], or `''` for "Alguien de afuera".
  void aboutChosen(String uid) =>
      emit(state.copyWith(aboutUid: () => uid, send: ReportSendStatus.idle));

  /// The words changed.
  void textChanged(String value) => emit(
    state.copyWith(text: ReportText.dirty(value), send: ReportSendStatus.idle),
  );

  /// Sends the report; once saved the form is empty again.
  Future<void> submitted() async {
    final about = state.aboutUid;
    if (!state.canSend || about == null) return;
    emit(state.copyWith(send: ReportSendStatus.sending));
    try {
      await _safetyRepository.sendReport(
        text: state.text.words,
        tags: state.tags,
        aboutUid: about,
      );
      emit(
        state.copyWith(
          send: ReportSendStatus.sent,
          tags: const {},
          aboutUid: () => null,
          text: const ReportText.pure(),
        ),
      );
    } on SafetyFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          send: error.reason == SafetyFailureReason.tooMany
              ? ReportSendStatus.tooMany
              : ReportSendStatus.failed,
        ),
      );
    }
  }

  /// The words "Agregar algo" would add changed.
  void additionChanged(String value) =>
      emit(state.copyWith(addition: ReportText.dirty(value)));

  /// "Agregar algo": adds the words typed to receipt [reportId]'s report;
  /// once saved they are cleared.
  Future<void> addedTo(String reportId) async {
    if (!state.canAdd) return;
    final words = state.addition.words;
    await _act(
      reportId,
      ReceiptAction.adding,
      () => _safetyRepository.addToReport(reportId: reportId, text: words),
      done: ReceiptAction.added,
    );
    if (state.receiptAction == ReceiptAction.added) {
      emit(state.copyWith(addition: const ReportText.pure()));
    }
  }

  /// "Retirar" on receipt [reportId]'s report.
  Future<void> withdrawn(String reportId) => _act(
    reportId,
    ReceiptAction.withdrawing,
    () => _safetyRepository.withdrawReport(reportId),
  );

  Future<void> _act(
    String reportId,
    ReceiptAction action,
    Future<void> Function() call, {
    ReceiptAction? done,
  }) async {
    emit(
      state.copyWith(receiptId: () => reportId, receiptAction: () => action),
    );
    try {
      await call();
      emit(
        state.copyWith(
          receiptId: () => done == null ? null : reportId,
          receiptAction: () => done,
        ),
      );
    } on SafetyFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(receiptAction: () => ReceiptAction.failed));
    }
  }

  @override
  Future<void> close() async {
    await _receipts?.cancel();
    await super.close();
  }

  @override
  String get reportStep => 'ReportCubit';
}
