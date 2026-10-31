import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/view/ronda_objects.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/cubit/onboarding_cubit.dart';
import 'package:ronda/onboarding/widgets/onboarding_labels.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_objects}
/// The side panel of onboarding on a desktop window: the chosen pretexts
/// and what the person brings, drawn as the ronda's objects
/// ([RondaObjectIcon]) with their names, filling in as they are chosen.
/// Before anything is chosen it shows the whole set and says what will
/// show up there.
///
/// It is an illustration of answers the screen already reads out, so
/// screen readers skip it.
/// {@endtemplate}
class const OnboardingObjects({super.key}) extends StatelessWidget {
  /// {@macro onboarding_objects}
  this;

  /// The side of an object's drawing.
  static const double objectSize = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final (pretexts, brings) = context
        .select<OnboardingCubit, (Set<Pretext>, Set<Bring>)>(
          (cubit) => (cubit.state.pretexts, cubit.state.brings),
        );
    final empty = pretexts.isEmpty && brings.isEmpty;

    Widget section(String title, List<(RondaObject?, String)> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.sm,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Wrap(
          spacing: spacing.md,
          runSpacing: spacing.md,
          children: [
            for (final (object, label) in items)
              _Object(object: object, label: label),
          ],
        ),
      ],
    );

    return ExcludeSemantics(
      child: ListView(
        padding: EdgeInsetsDirectional.symmetric(vertical: spacing.lg),
        children: [
          Text(l10n.onboardingObjectsTitle, style: theme.textTheme.titleLarge),
          SizedBox(height: spacing.md),
          RondaSwap(
            layoutBuilder: RondaSwap.topStartLayout,
            child: empty
                ? Column(
                    key: const ValueKey('empty'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: spacing.md,
                    children: [
                      Text(
                        l10n.onboardingObjectsBody,
                        style: theme.textTheme.bodyLarge,
                      ),
                      IconTheme(
                        data: IconThemeData(color: theme.colorScheme.outline),
                        child: Wrap(
                          spacing: spacing.md,
                          runSpacing: spacing.md,
                          children: [
                            for (final object in RondaObject.values)
                              RondaObjectIcon(object, size: objectSize),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('chosen'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: spacing.lg,
                    children: [
                      if (pretexts.isNotEmpty)
                        section(l10n.onboardingObjectsDo, [
                          for (final pretext in Pretext.values)
                            if (pretexts.contains(pretext))
                              (pretext.object, l10n.pretext(pretext)),
                        ]),
                      if (brings.isNotEmpty)
                        section(l10n.onboardingObjectsBring, [
                          for (final bring in Bring.values)
                            if (brings.contains(bring))
                              (bring.object, l10n.bring(bring)),
                        ]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One chosen thing: its drawing, when it has one, over its name.
class const _Object({
  required final RondaObject? object,
  required final String label,
}) extends StatelessWidget {
  /// Widest an object's name runs before it wraps.
  static const double width = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        spacing: context.appSpacing.xs,
        children: [
          SizedBox.square(
            dimension: OnboardingObjects.objectSize,
            child: switch (object) {
              final object? => IconTheme(
                data: IconThemeData(color: theme.colorScheme.primary),
                child: RondaObjectIcon(
                  object,
                  size: OnboardingObjects.objectSize,
                ),
              ),
              null => null,
            },
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
