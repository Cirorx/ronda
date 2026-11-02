import 'package:flutter/services.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/models/models.dart';
import 'package:ronda/onboarding/widgets/onboarding_labels.dart';
import 'package:ronda_ui/ronda_ui.dart';

// The pickers behind onboarding's questions, with no cubit of their own:
// onboarding's steps and "Mis datos" both hold what is picked and pass it in.

/// The first name field, validated as a [FirstName].
class const FirstNameField({
  required final FirstName value,
  required final ValueChanged<String> onChanged,
  required final String identifier,
  final bool autofocus = false,
  final ValueChanged<String>? onSubmitted,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = value.isPure ? null : value.error;
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: TextFormField(
          initialValue: value.value,
          autofocus: autofocus,
          autofillHints: const [AutofillHints.givenName],
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            LengthLimitingTextInputFormatter(FirstName.maxLength),
          ],
          decoration: InputDecoration(
            labelText: l10n.firstNameLabel,
            errorText: switch (error) {
              FirstNameValidationError.empty => l10n.firstNameErrorEmpty,
              FirstNameValidationError.tooLong => l10n.firstNameErrorTooLong(
                FirstName.maxLength,
              ),
              FirstNameValidationError.invalid => l10n.firstNameErrorInvalid,
              null => null,
            },
          ),
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
        ),
      ),
    );
  }
}

/// One age band of [AgeBand.values].
class const AgeBandPicker({
  required final AgeBand? selected,
  required final ValueChanged<AgeBand> onChanged,
  required final String identifier,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ChipPicker(
      identifier: identifier,
      multiSelect: false,
      options: [
        for (final band in AgeBand.values)
          ChipPickerOption(value: band.name, label: l10n.ageBand(band)),
      ],
      selected: {?selected?.name},
      onChanged: (names) => onChanged(AgeBand.values.byName(names.single)),
    );
  }
}

/// Any pretexts of [Pretext.values].
class const PretextsPicker({
  required final Set<Pretext> selected,
  required final ValueChanged<Set<Pretext>> onChanged,
  required final String identifier,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ChipPicker(
      identifier: identifier,
      options: [
        for (final pretext in Pretext.values)
          ChipPickerOption(value: pretext.name, label: l10n.pretext(pretext)),
      ],
      selected: {for (final pretext in selected) pretext.name},
      onChanged: (names) =>
          onChanged({for (final name in names) Pretext.values.byName(name)}),
    );
  }
}

/// Any of [Bring.values].
class const BringsPicker({
  required final Set<Bring> selected,
  required final ValueChanged<Set<Bring>> onChanged,
  required final String identifier,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ChipPicker(
      identifier: identifier,
      options: [
        for (final bring in Bring.values)
          ChipPickerOption(value: bring.name, label: l10n.bring(bring)),
      ],
      selected: {for (final bring in selected) bring.name},
      onChanged: (names) =>
          onChanged({for (final name in names) Bring.values.byName(name)}),
    );
  }
}

/// The week's day × time band grid.
class const SlotsPicker({
  required final Set<Slot> selected,
  required final ValueChanged<Set<Slot>> onChanged,
  required final String identifier,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SlotGrid(
      identifier: identifier,
      dayLabels: [for (final day in SlotDay.values) l10n.slotDay(day)],
      bandLabels: [for (final band in SlotBand.values) l10n.slotBand(band)],
      cellSemanticsLabel: (day, band) =>
          l10n.slot(Slot(SlotDay.values[day], SlotBand.values[band])),
      selected: {
        for (final slot in selected)
          (day: slot.day.index, band: slot.band.index),
      },
      onChanged: (cells) => onChanged({
        for (final cell in cells)
          Slot(SlotDay.values[cell.day], SlotBand.values[cell.band]),
      }),
    );
  }
}

/// One barrio of 71, found by a search field (accents and case aside:
/// "maronas" finds Maroñas) and grouped by area, Ciudad de la Costa first.
/// [excluded] is left out (casa, when picking trabajo).
class const BarrioPicker({
  required final Barrio? selected,
  required final ValueChanged<Barrio> onChanged,
  required final String identifier,
  required final String searchIdentifier,
  final Barrio? excluded,
  super.key,
}) extends StatefulWidget {
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
  State<BarrioPicker> createState() => _BarrioPickerState();
}

class _BarrioPickerState extends State<BarrioPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final found = [
      for (final option in Barrio.values)
        if (option != widget.excluded && BarrioPicker.matches(option, _query))
          option,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.md,
      children: [
        Semantics(
          identifier: widget.searchIdentifier,
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
              identifier: widget.identifier,
              multiSelect: false,
              options: [
                for (final option in inArea)
                  ChipPickerOption(
                    value: option.name,
                    label: l10n.barrio(option),
                  ),
              ],
              selected: {?widget.selected?.name},
              onChanged: (names) =>
                  widget.onChanged(Barrio.values.byName(names.single)),
            ),
          ],
      ],
    );
  }
}
