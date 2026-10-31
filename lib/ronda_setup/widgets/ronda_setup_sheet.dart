import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda/ronda_setup/cubit/ronda_setup_cubit.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// One ronda's public place, hour and hosts, in a sheet over the admin's
/// list: the place's name and how to find it, the hour (every half hour
/// inside the band, or none), who opens and who closes (a member, or
/// nobody). "Guardar" sends all three, felt as a commit ([RondaHaptics]);
/// the sheet closes once they are saved and says why when they aren't: on
/// the field at fault when there is one (a place that reads like a home,
/// the same person opening and closing), in a note otherwise.
class RondaSetupSheet extends StatefulWidget {
  const new({required this.ronda, super.key});

  /// The ronda being set.
  final RondaSetup ronda;

  /// Maestro's handles on the sheet's fields and button.
  static const placeIdentifier = 'setup.place';
  static const landmarkIdentifier = 'setup.landmark';
  static const hourIdentifier = 'setup.hour';
  static const anfitrionIdentifier = 'setup.anfitrion';
  static const colaIdentifier = 'setup.cola';
  static const saveIdentifier = 'setup.save';

  /// Lines a field's error may take before it is cut: enough for the
  /// longest one at 200% text on a phone.
  static const errorMaxLines = 8;

  /// Opens the sheet for [ronda] over [context]'s [RondaSetupCubit].
  static Future<void> show(BuildContext context, RondaSetup ronda) async {
    final cubit = context.read<RondaSetupCubit>();
    await showRondaSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: RondaSetupSheet(ronda: ronda),
      ),
    );
    cubit.sheetClosed();
  }

  @override
  State<RondaSetupSheet> createState() => _RondaSetupSheetState();
}

class _RondaSetupSheetState extends State<RondaSetupSheet> {
  late final _place = TextEditingController(text: widget.ronda.placeName);
  late final _landmark = TextEditingController(
    text: widget.ronda.placeLandmark,
  );
  late String? _hour = widget.ronda.hour;
  late String? _anfitrion = _known(widget.ronda.anfitrionUid);
  late String? _cola = _known(widget.ronda.colaUid);

  /// The place's words changed since the server last refused them, so its
  /// error no longer describes them.
  bool _placeEdited = false;

  @override
  void dispose() {
    _place.dispose();
    _landmark.dispose();
    super.dispose();
  }

  bool get _sameHost => _anfitrion != null && _anfitrion == _cola;

  void _placeChanged(String _) {
    if (!_placeEdited) setState(() => _placeEdited = true);
  }

  Future<void> _save() {
    _placeEdited = false;
    String? text(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    return context.read<RondaSetupCubit>().save(
      rondaId: widget.ronda.rondaId,
      placeName: text(_place),
      placeLandmark: text(_landmark),
      hour: _hour,
      anfitrionUid: _anfitrion,
      colaUid: _cola,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final state = context.watch<RondaSetupCubit>().state;
    final ronda = widget.ronda;
    final hours = hourChoices(ronda.slotBandId);
    final members = [
      DropdownMenuItem<String?>(child: Text(l10n.setupNobody)),
      for (final member in ronda.members)
        DropdownMenuItem(value: member.uid, child: Text(member.firstName)),
    ];

    Widget field(String identifier, Widget child) =>
        Semantics(identifier: identifier, child: child);

    final notPublic =
        state.saveFailure == HostsFailureReason.notPublic && !_placeEdited;
    final sameHost = _sameHost ? l10n.setupSameHost : null;

    return BlocListener<RondaSetupCubit, RondaSetupState>(
      listenWhen: (previous, current) =>
          previous.saving && !current.saving && current.saveFailure == null,
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
              // The title, and a close button for a mouse, which can't tap
              // the sheet's handle.
              Row(
                spacing: spacing.xs,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.rondaLineOf(
                          slotDayId: ronda.slotDayId,
                          slotBandId: ronda.slotBandId,
                          pretextId: ronda.pretextId,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const CloseButton(),
                ],
              ),
              field(
                RondaSetupSheet.placeIdentifier,
                TextField(
                  controller: _place,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _placeChanged,
                  decoration: InputDecoration(
                    labelText: l10n.setupPlaceName,
                    hintText: l10n.setupPlaceHint,
                    errorText: notPublic ? l10n.setupNotPublic : null,
                    errorMaxLines: RondaSetupSheet.errorMaxLines,
                  ),
                ),
              ),
              field(
                RondaSetupSheet.landmarkIdentifier,
                TextField(
                  controller: _landmark,
                  maxLength: 80,
                  onChanged: _placeChanged,
                  decoration: InputDecoration(
                    labelText: l10n.setupLandmark,
                    hintText: l10n.setupLandmarkHint,
                  ),
                ),
              ),
              field(
                RondaSetupSheet.hourIdentifier,
                DropdownButtonFormField<String?>(
                  initialValue: hours.contains(_hour) ? _hour : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.setupHour),
                  items: [
                    DropdownMenuItem<String?>(child: Text(l10n.setupNoHour)),
                    for (final hour in hours)
                      DropdownMenuItem(value: hour, child: Text(hour)),
                  ],
                  onChanged: (hour) => setState(() => _hour = hour),
                ),
              ),
              field(
                RondaSetupSheet.anfitrionIdentifier,
                DropdownButtonFormField<String?>(
                  initialValue: _anfitrion,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.setupAnfitrion,
                    errorText: sameHost,
                    errorMaxLines: RondaSetupSheet.errorMaxLines,
                  ),
                  items: members,
                  onChanged: (uid) => setState(() => _anfitrion = uid),
                ),
              ),
              field(
                RondaSetupSheet.colaIdentifier,
                DropdownButtonFormField<String?>(
                  initialValue: _cola,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.setupCola,
                    errorText: sameHost,
                    errorMaxLines: RondaSetupSheet.errorMaxLines,
                  ),
                  items: members,
                  onChanged: (uid) => setState(() => _cola = uid),
                ),
              ),
              if (state.saveFailure case final reason?
                  when reason != HostsFailureReason.notPublic)
                NoteBanner(
                  variant: NoteBannerVariant.warning,
                  message: l10n.setupSaveError,
                ),
              MergeSemantics(
                child: Semantics(
                  identifier: RondaSetupSheet.saveIdentifier,
                  child: FilledButton(
                    onPressed: RondaHaptics.onCommit(
                      state.saving || _sameHost ? null : _save,
                    ),
                    child: Text(
                      state.saving ? l10n.setupSaving : l10n.setupSave,
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

  /// [uid] when it is still a member, so the picker never holds a value it
  /// has no item for.
  String? _known(String? uid) =>
      widget.ronda.members.any((member) => member.uid == uid) ? uid : null;
}
