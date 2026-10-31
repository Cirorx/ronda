import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cuaderno/cubit/erase_cuaderno_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Ajustes → Tus datos: "Tu cuaderno" says where it is (on this phone
/// only) and "Borrar mi cuaderno" deletes all of it in one action, after
/// one question.
class const EraseCuadernoSection({super.key}) extends StatelessWidget {
  /// Maestro's handle on "Borrar mi cuaderno".
  static const identifier = 'data.eraseCuaderno';

  /// Maestro's handle on the confirmation's "Borrar".
  static const confirmIdentifier = 'data.eraseCuaderno.confirm';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EraseCuadernoCubit(
        uid: context.read<AppBloc>().state.user.id,
        cuadernoRepository: context.read<CuadernoRepository>(),
      ),
      child: const _EraseCuadernoView(),
    );
  }
}

class const _EraseCuadernoView() extends StatelessWidget {
  Future<void> _confirm(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<EraseCuadernoCubit>();
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cuadernoEraseConfirmTitle),
        content: Text(l10n.cuadernoEraseConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cuadernoEraseCancel),
          ),
          MergeSemantics(
            child: Semantics(
              identifier: EraseCuadernoSection.confirmIdentifier,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.cuadernoEraseConfirm),
              ),
            ),
          ),
        ],
      ),
    );
    if (sure ?? false) await cubit.erase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final status = context.watch<EraseCuadernoCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.sm,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.cuadernoEraseTitle, style: textTheme.titleMedium),
        ),
        Text(l10n.cuadernoEraseBody, style: textTheme.bodyLarge),
        MergeSemantics(
          child: Semantics(
            identifier: EraseCuadernoSection.identifier,
            child: OutlinedButton(
              onPressed: status == EraseCuadernoStatus.erasing
                  ? null
                  : () => _confirm(context),
              child: Text(l10n.cuadernoErase),
            ),
          ),
        ),
        switch (status) {
          EraseCuadernoStatus.erased => StatusLine(l10n.cuadernoErased),
          EraseCuadernoStatus.failed => StatusLine(l10n.cuadernoEraseFailed),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}
