import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/attendance/cubit/attendance_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Quién vino hoy?": the host's «Vino» / «No vino» for each person at
/// ronda [rondaId]'s meeting of [week] (`docs/PRODUCT.md` § The weekly
/// loop). "Nadie más ve esta lista.": the rules let only the ronda's
/// anfitrión and cola, and the admin, read it.
class const AttendancePage({
  /// The ronda.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W45`).
  required final String week,
  super.key,
}) extends StatelessWidget {
  /// The host's route; the push's link and Mi ronda open it.
  static const path = '/asistencia/:rondaId/:week';

  /// The admin's route, under `/admin` so a profile-less owner gets in.
  static const adminSegment = 'asistencia/:rondaId/:week';

  /// Where ronda [rondaId]'s roll for [week] is; under `/admin` with
  /// [admin].
  static String location(String rondaId, String week, {bool admin = false}) =>
      '${admin ? '/admin' : ''}/asistencia/'
      '${Uri.encodeComponent(rondaId)}/${Uri.encodeComponent(week)}';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AttendanceCubit(
        rondaId: rondaId,
        week: week,
        rondaRepository: context.read<RondaRepository>(),
      )..subscribe(),
      child: const AttendanceView(),
    );
  }
}

/// The meeting, "Nadie más ve esta lista.", how many are marked, and one
/// row per person with «Vino» and «No vino».
class const AttendanceView({super.key}) extends StatelessWidget {
  /// Maestro's handle on a person's «Vino» ([came]) or «No vino» button.
  static String markIdentifier(String uid, {required bool came}) =>
      'roll.$uid.${came ? 'came' : 'no'}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AttendanceCubit>().state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rollTitle)),
      body: SafeArea(
        child: switch ((state.status, state.roll)) {
          (AttendanceStatus.ready, final roll?) => _Roll(state, roll),
          (AttendanceStatus.loading, _) => const Center(
            child: CircularProgressIndicator(),
          ),
          (AttendanceStatus.failure, _) => _Message(
            l10n.rollLoadError,
            action: OutlinedButton(
              onPressed: context.read<AttendanceCubit>().subscribe,
              child: Text(l10n.adminRetry),
            ),
          ),
          _ => _Message(l10n.rollNone),
        },
      ),
    );
  }
}

class const _Message(final String message, {final Widget? action})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: spacing.md,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class const _Roll(final AttendanceState state, final AttendanceRoll roll)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    return ListView(
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        // The server's es-419 line: "Jueves 16:00 · mate en la rambla · …".
        Text(roll.line, style: textTheme.titleMedium),
        SizedBox(height: spacing.sm),
        NoteBanner(
          variant: NoteBannerVariant.keptOnPhone,
          message: l10n.rollPrivate,
        ),
        SizedBox(height: spacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.rollMarked(state.markedCount, roll.people.length),
            style: textTheme.bodyLarge,
          ),
        ),
        if (state.tapFailure case final reason?) ...[
          SizedBox(height: spacing.sm),
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: reason == HostsFailureReason.passed
                ? l10n.rollPassed
                : l10n.rollSaveError,
          ),
        ],
        SizedBox(height: spacing.sm),
        for (final person in roll.people)
          _Person(person: person, mark: state.markOf(person.uid)),
      ],
    );
  }
}

class const _Person({
  required final SetupMember person,
  required final bool? mark,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final cubit = context.read<AttendanceCubit>();

    Widget button({required bool came}) {
      final selected = mark == came;
      final label = Text(came ? l10n.rollCame : l10n.rollDidntCome);
      void onPressed() => cubit.marked(person.uid, came: came);
      return MergeSemantics(
        child: Semantics(
          identifier: AttendanceView.markIdentifier(person.uid, came: came),
          selected: selected,
          child: selected
              ? FilledButton(onPressed: onPressed, child: label)
              : OutlinedButton(onPressed: onPressed, child: label),
        ),
      );
    }

    final buttons = [button(came: true), button(came: false)];
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.xs,
        children: [
          Semantics(
            header: true,
            label: l10n.rollPerson(person.firstName, switch (mark) {
              true => l10n.rollCame,
              false => l10n.rollDidntCome,
              null => l10n.rollUnmarked,
            }),
            excludeSemantics: true,
            child: Text(
              person.firstName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (context.usesLargeText)
            ...buttons
          else
            Row(
              spacing: spacing.xs,
              children: [for (final b in buttons) Expanded(child: b)],
            ),
        ],
      ),
    );
  }
}
