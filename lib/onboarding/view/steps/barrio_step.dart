import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿En qué barrio estás?": only the barrio, never an address.
///
/// 71 barrios are too many to scan, so a search field narrows them (accents
/// and case aside: "maronas" finds Maroñas) and they come grouped by area,
/// Ciudad de la Costa first.
class const BarrioStep({super.key}) extends StatefulWidget {
  /// Prefix of every chip's semantics identifier.
  static const identifier = 'onboarding.barrio';

  /// Semantics identifier of the search field.
  static const searchIdentifier = 'onboarding.barrio.search';

  /// Whether [barrio] answers the search [query].
  static bool matches(Barrio barrio, String query) =>
      _fold(barrio.label).contains(_fold(query.trim()));

  static String _fold(String text) => text
      .toLowerCase()
      .split('')
      .map((letter) => _plain[letter] ?? letter)
      .join();

  static const _plain = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  @override
  State<BarrioStep> createState() => _BarrioStepState();
}

class _BarrioStepState extends State<BarrioStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final barrio = context.select<OnboardingCubit, Barrio?>(
      (cubit) => cubit.state.barrio,
    );
    final found = [
      for (final option in Barrio.values)
        if (BarrioStep.matches(option, _query)) option,
    ];
    return OnboardingQuestion(
      step: OnboardingStep.barrio,
      title: l10n.barrioTitle,
      body: l10n.barrioBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.md,
        children: [
          Semantics(
            identifier: BarrioStep.searchIdentifier,
            child: TextField(
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: l10n.barrioSearchLabel,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (query) => setState(() => _query = query),
            ),
          ),
          if (found.isEmpty)
            Semantics(
              liveRegion: true,
              child: Text(l10n.barrioNoMatch, style: textTheme.bodyMedium),
            ),
          for (final area in BarrioArea.values)
            if (found.where((option) => option.area == area).toList()
                case final inArea when inArea.isNotEmpty) ...[
              Semantics(
                header: true,
                child: Text(l10n.barrioArea(area), style: textTheme.titleSmall),
              ),
              ChipPicker(
                identifier: BarrioStep.identifier,
                multiSelect: false,
                options: [
                  for (final option in inArea)
                    ChipPickerOption(
                      value: option.name,
                      label: l10n.barrio(option),
                    ),
                ],
                selected: {?barrio?.name},
                onChanged: (names) => context
                    .read<OnboardingCubit>()
                    .barrioChanged(Barrio.values.byName(names.single)),
              ),
            ],
        ],
      ),
    );
  }
}
