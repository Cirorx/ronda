import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿En qué barrio estás?": only the barrio, never an address. Trabajo, a
/// second barrio, is added later from "Mis datos".
///
/// 71 barrios are too many to scan, so the [BarrioPicker] narrows them with
/// a search field and groups them by area.
class const BarrioStep({super.key}) extends StatelessWidget {
  /// Prefix of every chip's semantics identifier.
  static const identifier = 'onboarding.barrio';

  /// Semantics identifier of the search field.
  static const searchIdentifier = 'onboarding.barrio.search';

  /// Whether [barrio] answers the search [query].
  static bool matches(Barrio barrio, String query) =>
      BarrioPicker.matches(barrio, query);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final barrio = context.select<OnboardingCubit, Barrio?>(
      (cubit) => cubit.state.barrio,
    );
    return OnboardingQuestion(
      step: OnboardingStep.barrio,
      title: l10n.barrioTitle,
      body: l10n.barrioBody,
      child: BarrioPicker(
        identifier: identifier,
        searchIdentifier: searchIdentifier,
        selected: barrio,
        onChanged: context.read<OnboardingCubit>().barrioChanged,
      ),
    );
  }
}
