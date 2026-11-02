import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_data/cubit/my_data_cubit.dart';
import 'package:ronda/my_data/widgets/anchor_section.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Mis datos": first name, age band, casa and trabajo, what they'd like to
/// do, when they can and what they bring, with onboarding's pickers. Opened
/// from Mi ronda's app bar ([homePath]) and from Ajustes ([settingsPath]).
class const MyDataPage({super.key}) extends StatelessWidget {
  /// The route's segment, under `/ronda` and under `/ajustes`.
  static const segment = 'mis-datos';
  static const homePath = '/ronda/$segment';
  static const settingsPath = '/ajustes/$segment';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = MyDataCubit(
          uid: context.read<AppBloc>().state.user.id,
          profileRepository: context.read<ProfileRepository>(),
          needsRepository: context.read<NeedsRepository>(),
          rondaRepository: context.read<RondaRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const MyDataView(),
    );
  }
}

/// Mis datos' content: one scrolling column of questions and «Guardar».
class const MyDataView({super.key}) extends StatelessWidget {
  /// Maestro's handles.
  static const firstNameIdentifier = 'myData.firstName';
  static const ageBandIdentifier = 'myData.ageBand';
  static const pretextsIdentifier = 'myData.pretexts';
  static const slotsIdentifier = 'myData.slots';
  static const bringsIdentifier = 'myData.brings';
  static const saveIdentifier = 'myData.save';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select<MyDataCubit, MyDataStatus>(
      (cubit) => cubit.state.status,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myDataTitle)),
      body: ReadableColumn(
        child: switch (status) {
          MyDataStatus.loading => Center(
            child: LoadingStatus(l10n.myDataLoading),
          ),
          MyDataStatus.loadFailure => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: context.appSpacing.sm,
              children: [
                StatusLine(l10n.myDataLoadError, textAlign: TextAlign.center),
                OutlinedButton(
                  onPressed: context.read<MyDataCubit>().load,
                  child: Text(l10n.myDataRetry),
                ),
              ],
            ),
          ),
          _ => const _Form(),
        },
      ),
    );
  }
}

class const _Form() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<MyDataCubit>().state;
    final cubit = context.read<MyDataCubit>();

    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(top: spacing.lg),
      child: Semantics(
        header: true,
        child: Text(text, style: textTheme.titleMedium),
      ),
    );

    return ListView(
      padding: EdgeInsets.all(spacing.md),
      children: [
        Text(l10n.myDataIntro, style: textTheme.bodyLarge),
        heading(l10n.firstNameTitle),
        SizedBox(height: spacing.sm),
        FirstNameField(
          identifier: MyDataView.firstNameIdentifier,
          value: state.firstName,
          onChanged: cubit.firstNameChanged,
        ),
        heading(l10n.ageBandTitle),
        SizedBox(height: spacing.sm),
        AgeBandPicker(
          identifier: MyDataView.ageBandIdentifier,
          selected: state.ageBand,
          onChanged: cubit.ageBandChanged,
        ),
        heading(l10n.myDataPlacesTitle),
        const AnchorSection(),
        if (state.seated && state.changesMatching)
          Padding(
            padding: EdgeInsets.only(top: spacing.sm),
            child: NoteBanner(message: l10n.myDataSeatedNote),
          ),
        heading(l10n.pretextsTitle),
        SizedBox(height: spacing.sm),
        PretextsPicker(
          identifier: MyDataView.pretextsIdentifier,
          selected: state.pretexts,
          onChanged: cubit.pretextsChanged,
        ),
        heading(l10n.slotsTitle),
        SizedBox(height: spacing.sm),
        SlotsPicker(
          identifier: MyDataView.slotsIdentifier,
          selected: state.slots,
          onChanged: cubit.slotsChanged,
        ),
        heading(l10n.bringsTitle),
        SizedBox(height: spacing.sm),
        BringsPicker(
          identifier: MyDataView.bringsIdentifier,
          selected: state.brings,
          onChanged: cubit.bringsChanged,
        ),
        SizedBox(height: spacing.lg),
        Semantics(
          identifier: MyDataView.saveIdentifier,
          child: FilledButton(
            onPressed: state.isComplete && !state.status.isUnderway
                ? cubit.save
                : null,
            child: Text(l10n.myDataSave),
          ),
        ),
        SizedBox(height: spacing.sm),
        if (switch (state.status) {
              MyDataStatus.saving => l10n.myDataSaving,
              MyDataStatus.saved => l10n.myDataSaved,
              MyDataStatus.saveFailure => l10n.myDataSaveError,
              _ when !state.isComplete => l10n.myDataIncomplete,
              _ => null,
            }
            case final line?)
          StatusLine(line, textAlign: TextAlign.center),
      ],
    );
  }
}
