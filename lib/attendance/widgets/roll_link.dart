import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/attendance/cubit/attendance_cubit.dart';
import 'package:ronda/attendance/view/attendance_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Quién vino hoy?" on the Mi ronda card, for the ronda's anfitrión and
/// cola only, once the attendance job wrote the meeting's roll: a tap on
/// the push opens Mi ronda on Android, so this is how the host gets there.
/// It shows nothing until then, and nothing if the roll can't be read.
class const RollLink({
  /// The ronda.
  required final String rondaId,

  /// The meeting's ISO week.
  required final String week,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on the link.
  static const identifier = 'myRonda.roll';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey('$rondaId/$week'),
      create: (context) => AttendanceCubit(
        rondaId: rondaId,
        week: week,
        rondaRepository: context.read<RondaRepository>(),
      )..subscribe(),
      child: _Link(rondaId: rondaId, week: week),
    );
  }
}

class const _Link({required final String rondaId, required final String week})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AttendanceCubit>().state;
    final roll = state.roll;
    if (state.status != AttendanceStatus.ready || roll == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.appSpacing.xxs,
      children: [
        MergeSemantics(
          child: Semantics(
            identifier: RollLink.identifier,
            child: FilledButton(
              onPressed: () =>
                  context.push(AttendancePage.location(rondaId, week)),
              child: Text(l10n.rollTitle),
            ),
          ),
        ),
        Text(
          l10n.rollMarked(state.markedCount, roll.people.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
