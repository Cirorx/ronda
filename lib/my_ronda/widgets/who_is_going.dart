import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/view/ronda_objects.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template who_is_going}
/// "Quiénes van" for this week: the yeses by first name, as initials, with
/// their role and what they bring, and only counts for the rest. It sits
/// on the week's card on a phone, and beside it on a desktop window, where
/// each row also draws what that neighbour brings ([showObjects]).
/// {@endtemplate}
class const WhoIsGoing({
  /// The week.
  required final ThisWeek week,

  /// The member using the app, shown as "Vos".
  required final String uid,

  /// Whether each row ends with the objects that neighbour brings.
  final bool showObjects = false,
  super.key,
}) extends StatelessWidget {
  /// {@macro who_is_going}
  this;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final counts = l10n.counts(
      week,
      answered: week.myAnswer != null || week.pausedUntil != null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.appSpacing.md,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.thisWeekWhoTitle, style: textTheme.titleSmall),
        ),
        if (week.going.isNotEmpty)
          _Going(week: week, uid: uid, showObjects: showObjects),
        RondaSwap(
          layoutBuilder: RondaSwap.topStartLayout,
          child: Text(
            counts,
            key: ValueKey(counts),
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// "Quiénes van": a row per yes. Someone who joins while the card is up
/// grows into the list ([_Arriving]); the rows there from the start don't
/// move.
class const _Going({
  required final ThisWeek week,
  required final String uid,
  required final bool showObjects,
}) extends StatefulWidget {
  @override
  State<_Going> createState() => _GoingState();
}

class _GoingState extends State<_Going> {
  Set<String> _arriving = const {};

  @override
  void didUpdateWidget(_Going oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = {for (final person in oldWidget.week.going) person.uid};
    _arriving = {
      for (final person in widget.week.going)
        if (!before.contains(person.uid)) person.uid,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final week = widget.week;
    return Column(
      children: [
        for (final (index, person) in week.going.indexed)
          _Arriving(
            key: ValueKey(person.uid),
            arriving: _arriving.contains(person.uid),
            child: PersonRow(
              initial: person.firstName.isEmpty
                  ? '?'
                  : person.firstName.characters.first.toUpperCase(),
              name: person.uid == widget.uid
                  ? l10n.thisWeekYou
                  : person.firstName,
              detail: l10n.roleAndBrings(week, person),
              isYou: person.uid == widget.uid,
              showDivider: index < week.going.length - 1,
              trailing: widget.showObjects
                  ? _Objects(brings: person.brings)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// A seat filling: a row that [arriving] opens from nothing to its height
/// and fades in on the standard spring; any other row is simply there.
class const _Arriving({
  required final bool arriving,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<_Arriving> createState() => _ArrivingState();
}

class _ArrivingState extends State<_Arriving> {
  late double _shown = widget.arriving ? 0 : 1;

  @override
  void initState() {
    super.initState();
    if (!widget.arriving) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SpringBuilder(
      value: _shown,
      builder: (context, value, child) {
        final shown = value.clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: shown,
            child: Opacity(opacity: shown, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// What a neighbour brings, drawn: the things among their brings that are
/// things.
class const _Objects({required final List<String> brings})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.primary),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: context.appSpacing.xxs,
        children: [
          for (final id in brings)
            if (Bring.fromId(id)?.object case final object?)
              RondaObjectIcon(object),
        ],
      ),
    );
  }
}
