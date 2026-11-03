import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/admin/cubit/auto_form_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Rondas que se arman solas": the switch for the `auto_form` job and the
/// minutes the admin has to stop a proposal before it approves itself,
/// with Guardar. Reads the [AutoFormCubit] above.
class const AutoFormSection({super.key}) extends StatelessWidget {
  /// Maestro's handles on the switch, the field and the button.
  static const switchIdentifier = 'admin_auto_form_switch';
  static const holdIdentifier = 'admin_auto_form_hold';
  static const saveIdentifier = 'admin_auto_form_save';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final cubit = context.read<AutoFormCubit>();
    final state = context.watch<AutoFormCubit>().state;
    final settings = state.settings;
    final valid = state.draftMinutes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.adminAutoFormTitle, style: textTheme.titleMedium),
        ),
        Text(l10n.adminAutoFormBody, style: textTheme.bodyMedium),
        switch (state.status) {
          AutoFormStatus.loading => LoadingStatus(l10n.adminLoading),
          AutoFormStatus.failure => StatusLine(
            l10n.adminAutoFormLoadError,
            style: textTheme.bodyMedium,
          ),
          AutoFormStatus.ready => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.xs,
            children: [
              Semantics(
                identifier: switchIdentifier,
                child: SwitchListTile(
                  contentPadding: EdgeInsetsDirectional.zero,
                  title: Text(l10n.adminAutoFormSwitch),
                  value: settings?.enabled ?? false,
                  onChanged: state.saving
                      ? null
                      : (enabled) => cubit.enabledToggled(enabled: enabled),
                ),
              ),
              Semantics(
                identifier: holdIdentifier,
                child: TextFormField(
                  key: ValueKey(settings?.holdMinutes),
                  initialValue: state.holdText,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.adminAutoFormHold,
                    errorText: valid ? null : l10n.adminAutoFormHoldInvalid,
                  ),
                  onChanged: cubit.holdChanged,
                ),
              ),
              MergeSemantics(
                child: Semantics(
                  identifier: saveIdentifier,
                  child: OutlinedButton(
                    onPressed: state.saving || !valid
                        ? null
                        : RondaHaptics.onCommit(cubit.holdSaved),
                    child: Text(l10n.adminAutoFormSave),
                  ),
                ),
              ),
            ],
          ),
        },
        if (state.saveFailed)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.adminActionError,
          ),
      ],
    );
  }
}
