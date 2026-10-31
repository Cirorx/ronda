import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/despues_cubit.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Hay después esta semana?", in a sheet over Mi ronda for this week's
/// host: [Esta semana no], a public place nearby, or someone's home (whose,
/// and the address). Someone else's home is asked first. The sheet closes
/// once it is saved and says why when it isn't.
///
/// A field it needs says so under itself once the person leaves it empty
/// or tries to save, and stops saying so as soon as it is filled in. Saving
/// is a commit, felt on the tap, with a progress ring on «Guardar».
class DespuesSheet extends StatefulWidget {
  const new({required this.uid, required this.week, super.key});

  /// The host reading it.
  final String uid;

  /// The week it sets the después for.
  final ThisWeek week;

  /// Maestro's handles on the sheet's choices, fields and button.
  static String kindIdentifier(DespuesKind kind) => 'despues.${kind.name}';
  static const whatIdentifier = 'despues.what';
  static const whereIdentifier = 'despues.where';
  static const whoseIdentifier = 'despues.whose';
  static const addressIdentifier = 'despues.address';
  static const saveIdentifier = 'despues.save';

  /// Opens the sheet for [week] over [context].
  static Future<void> show(
    BuildContext context, {
    required String uid,
    required ThisWeek week,
  }) {
    final repository = context.read<RondaRepository>();
    return showRondaSheet<void>(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => DespuesCubit(
          rondaId: week.rondaId,
          week: week.week!,
          rondaRepository: repository,
        ),
        child: DespuesSheet(uid: uid, week: week),
      ),
    );
  }

  @override
  State<DespuesSheet> createState() => _DespuesSheetState();
}

class _DespuesSheetState extends State<DespuesSheet> {
  late DespuesKind _kind = widget.week.despues?.kind ?? DespuesKind.none;
  late final _what = TextEditingController(text: widget.week.despues?.what);
  late final _where = TextEditingController(text: widget.week.despues?.where);
  late final _address = TextEditingController(
    text: widget.week.despues?.address,
  );
  late String _whose = _known(widget.week.despues?.homeOf?.uid);

  /// The fields the person has been in and left.
  final _left = <DespuesField>{};

  /// Whether «Guardar» was tapped: every empty field it needs says so.
  bool _tried = false;

  @override
  void dispose() {
    _what.dispose();
    _where.dispose();
    _address.dispose();
    super.dispose();
  }

  /// Who could host it at home: the host, and the members who said "voy";
  /// never a guest from the bench, who is no member.
  List<GoingNeighbour> get _others => [
    for (final person in widget.week.going)
      if (person.uid != widget.uid && !person.guest) person,
  ];

  String _known(String? uid) =>
      _others.any((person) => person.uid == uid) ? uid! : widget.uid;

  Set<DespuesField> get _missing => DespuesCubit.missingFields(
    kind: _kind,
    what: _what.text,
    where: _where.text,
    address: _address.text,
  );

  void _save() {
    setState(() => _tried = true);
    if (_missing.isEmpty) unawaited(RondaHaptics.commit());
    unawaited(
      context.read<DespuesCubit>().save(
        kind: _kind,
        what: _what.text,
        where: _where.text,
        homeOfUid: _whose,
        address: _address.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<DespuesCubit>().state;

    Widget field(String identifier, Widget child) =>
        Semantics(identifier: identifier, child: child);

    final missing = _missing;
    final tried = _tried || state.missing;

    /// What shows under [field]: that it is needed, once the person left it
    /// empty or tried to save, until it is filled in.
    String? errorFor(DespuesField field) =>
        missing.contains(field) && (tried || _left.contains(field))
        ? l10n.despuesFieldMissing
        : null;

    /// [child], noting when the person leaves [field].
    Widget leaving(DespuesField field, Widget child) => Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused) setState(() => _left.add(field));
      },
      child: child,
    );

    void edited(String _) => setState(() {});

    return BlocListener<DespuesCubit, DespuesState>(
      listenWhen: (previous, current) => !previous.saved && current.saved,
      listener: (context, _) => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: spacing.md,
          end: spacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + spacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.sm,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.despuesSet, style: textTheme.titleMedium),
              ),
              Text(l10n.despuesSheetBody, style: textTheme.bodyMedium),
              RadioGroup<DespuesKind>(
                groupValue: _kind,
                onChanged: (kind) => setState(() => _kind = kind!),
                child: Column(
                  children: [
                    for (final (kind, label) in [
                      (DespuesKind.none, l10n.despuesKindNone),
                      (DespuesKind.place, l10n.despuesKindPlace),
                      (DespuesKind.home, l10n.despuesKindHome),
                    ])
                      PressScale(
                        // Full width: the sheet would clip a ring outside it.
                        ringInset: true,
                        child: MergeSemantics(
                          child: Semantics(
                            identifier: DespuesSheet.kindIdentifier(kind),
                            child: RadioListTile<DespuesKind>(
                              value: kind,
                              title: Text(label),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_kind != DespuesKind.none)
                field(
                  DespuesSheet.whatIdentifier,
                  leaving(
                    DespuesField.what,
                    TextField(
                      controller: _what,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: edited,
                      decoration: InputDecoration(
                        labelText: l10n.despuesWhat,
                        hintText: l10n.despuesWhatHint,
                        errorText: errorFor(DespuesField.what),
                      ),
                    ),
                  ),
                ),
              if (_kind == DespuesKind.place)
                field(
                  DespuesSheet.whereIdentifier,
                  leaving(
                    DespuesField.where,
                    TextField(
                      controller: _where,
                      maxLength: 60,
                      onChanged: edited,
                      decoration: InputDecoration(
                        labelText: l10n.despuesWhere,
                        hintText: l10n.despuesWhereHint,
                        errorText: errorFor(DespuesField.where),
                      ),
                    ),
                  ),
                ),
              if (_kind == DespuesKind.home) ...[
                field(
                  DespuesSheet.whoseIdentifier,
                  DropdownButtonFormField<String>(
                    initialValue: _whose,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.despuesWhose,
                      helperText: l10n.despuesWhoseNote,
                      helperMaxLines: 3,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: widget.uid,
                        child: Text(l10n.despuesMine),
                      ),
                      for (final person in _others)
                        DropdownMenuItem(
                          value: person.uid,
                          child: Text(person.firstName),
                        ),
                    ],
                    onChanged: (uid) => setState(() => _whose = uid!),
                  ),
                ),
                field(
                  DespuesSheet.addressIdentifier,
                  leaving(
                    DespuesField.address,
                    TextField(
                      controller: _address,
                      maxLength: 80,
                      onChanged: edited,
                      decoration: InputDecoration(
                        labelText: l10n.despuesAddress,
                        hintText: l10n.despuesAddressHint,
                        helperText: l10n.despuesAddressNote,
                        helperMaxLines: 3,
                        errorText: errorFor(DespuesField.address),
                        errorMaxLines: 3,
                      ),
                    ),
                  ),
                ),
              ],
              if (state.failure case final reason?)
                NoteBanner(
                  variant: NoteBannerVariant.warning,
                  message: reason == HostsFailureReason.notPublic
                      ? l10n.despuesRefused
                      : l10n.despuesSaveError,
                ),
              MergeSemantics(
                child: Semantics(
                  identifier: DespuesSheet.saveIdentifier,
                  liveRegion: state.saving,
                  child: IgnorePointer(
                    ignoring: state.saving,
                    child: FilledButton(
                      onPressed: state.saving ? () {} : _save,
                      child: BusyLabel(
                        state.saving ? l10n.despuesSaving : l10n.despuesSave,
                        busy: state.saving,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
