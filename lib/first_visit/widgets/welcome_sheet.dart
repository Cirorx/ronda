import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/first_visit/cubit/first_visit_cubit.dart';
import 'package:ronda/first_visit/widgets/asi_va_a_ser.dart';
import 'package:ronda/first_visit/widgets/first_visit_labels.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Quién espera a Nico?", in a sheet over Mi ronda for the ronda's
/// anfitrión or cola: [Espero yo] or another member, how to recognise
/// whoever waits, and, under it, what Nico will see, drawn as the words are
/// typed. It closes once saved, and says why when the gates held the line.
/// Saving is a commit, felt on the tap, with a ring on «Guardar».
class WelcomeSheet extends StatefulWidget {
  const new({required this.uid, required this.welcome, super.key});

  /// The host choosing.
  final String uid;

  /// The newcomer's welcome.
  final Welcome welcome;

  /// Maestro's handles on the choices, the line and the button.
  static const myselfIdentifier = 'welcome.myself';
  static String memberIdentifier(String uid) => 'welcome.$uid';
  static const signIdentifier = 'welcome.sign';
  static const saveIdentifier = 'welcome.save';

  /// Opens the sheet for [welcome] over [context], on the [FirstVisitCubit]
  /// above it.
  static Future<void> show(
    BuildContext context, {
    required String uid,
    required Welcome welcome,
  }) {
    final cubit = context.read<FirstVisitCubit>()..sheetOpened();
    return showRondaSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: WelcomeSheet(uid: uid, welcome: welcome),
      ),
    );
  }

  @override
  State<WelcomeSheet> createState() => _WelcomeSheetState();
}

class _WelcomeSheetState extends State<WelcomeSheet> {
  /// The pick so far: the last one, else the host when they can wait, else
  /// the first member who can.
  late String _waiter = switch (widget.welcome) {
    Welcome(picked: true, :final waiter?) => waiter.uid,
    _ when _canWait => widget.uid,
    Welcome(:final choices) => choices.firstOrNull?.uid ?? widget.uid,
  };
  late final _sign = TextEditingController(text: widget.welcome.sign);

  @override
  void dispose() {
    _sign.dispose();
    super.dispose();
  }

  /// The other members the host could pick.
  List<SetupMember> get _others => [
    for (final member in widget.welcome.choices)
      if (member.uid != widget.uid) member,
  ];

  /// Whether the host is in for the meeting, so can wait themself.
  bool get _canWait =>
      widget.welcome.choices.any((member) => member.uid == widget.uid);

  String? get _waiterName => widget.welcome.choices
      .where((member) => member.uid == _waiter)
      .firstOrNull
      ?.firstName;

  void _save() {
    unawaited(RondaHaptics.commit());
    unawaited(
      context.read<FirstVisitCubit>().picked(
        widget.welcome,
        waiterUid: _waiter,
        sign: _sign.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<FirstVisitCubit>().state;
    final saving = state.save == WelcomeSaveStatus.saving;
    final welcome = widget.welcome;

    return BlocListener<FirstVisitCubit, FirstVisitState>(
      listenWhen: (previous, current) =>
          previous.save != current.save &&
          current.save == WelcomeSaveStatus.saved,
      listener: (context, _) => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: spacing.md,
          end: spacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + spacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.sm,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.welcomeSheetTitle(welcome.newcomerName),
                  style: textTheme.titleMedium,
                ),
              ),
              Text(l10n.welcomeQuestion(welcome), style: textTheme.bodyMedium),
              RadioGroup<String>(
                groupValue: _waiter,
                onChanged: (uid) => setState(() => _waiter = uid!),
                child: Column(
                  children: [
                    for (final (uid, label, identifier) in [
                      if (_canWait)
                        (
                          widget.uid,
                          l10n.welcomeSheetMyself,
                          WelcomeSheet.myselfIdentifier,
                        ),
                      for (final member in _others)
                        (
                          member.uid,
                          member.firstName,
                          WelcomeSheet.memberIdentifier(member.uid),
                        ),
                    ])
                      PressScale(
                        // Full width: the sheet would clip a ring outside it.
                        ringInset: true,
                        child: MergeSemantics(
                          child: Semantics(
                            identifier: identifier,
                            child: RadioListTile<String>(
                              value: uid,
                              title: Text(label),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                identifier: WelcomeSheet.signIdentifier,
                child: TextField(
                  controller: _sign,
                  maxLength: 60,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.welcomeSheetSign,
                    hintText: l10n.welcomeSheetSignHint,
                  ),
                ),
              ),
              Text(
                l10n.welcomeSheetPreview(welcome.newcomerName),
                style: textTheme.labelLarge,
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: AsiVaASer(
                    waiterName: _waiterName,
                    sign: _sign.text,
                    placeName: welcome.placeName,
                    placeLandmark: welcome.placeLandmark,
                  ),
                ),
              ),
              if (state.failure case final reason?
                  when state.save == WelcomeSaveStatus.failed)
                NoteBanner(
                  variant: NoteBannerVariant.warning,
                  message: l10n.welcomeFailure(reason),
                ),
              MergeSemantics(
                child: Semantics(
                  identifier: WelcomeSheet.saveIdentifier,
                  liveRegion: saving,
                  child: IgnorePointer(
                    ignoring: saving,
                    child: FilledButton(
                      onPressed: saving ? () {} : _save,
                      child: BusyLabel(
                        saving
                            ? l10n.welcomeSheetSaving
                            : l10n.welcomeSheetSave,
                        busy: saving,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
