import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';
import 'package:ronda/my_ronda/agent_card/ronda_card_catalog.dart';
import 'package:ronda_repository/ronda_repository.dart';

/// The weekly card the organiser composed, drawn with genui from
/// [rondaCardCatalog]: the stored A2UI messages and nothing else. The phone
/// never calls a model here; the RSVP block is the app's own ([rsvp]).
///
/// Anything it can't draw shows [fallback] (the template) instead: a message
/// that doesn't parse, a surface for another catalog, a component outside the
/// catalog or with the wrong data, or an error the surface reports while it
/// builds. A new [card] is loaded from scratch.
class AgentCardSurface extends StatefulWidget {
  /// Creates the surface for [card].
  const new({
    required this.card,
    required this.rsvp,
    required this.fallback,
    super.key,
  });

  /// The card as stored by the server.
  final AgentCard card;

  /// Builds "¿Venís?" where the card's RSVP block goes.
  final WidgetBuilder rsvp;

  /// Builds what shows when the card can't be drawn.
  final WidgetBuilder fallback;

  /// Maestro's handle on a card the organiser composed.
  static const identifier = 'thisWeek.agent';

  @override
  State<AgentCardSurface> createState() => _AgentCardSurfaceState();
}

class _AgentCardSurfaceState extends State<AgentCardSurface> {
  SurfaceController? _controller;
  StreamSubscription<ChatMessage>? _reports;
  String? _surfaceId;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AgentCardSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card != widget.card) {
      _unload();
      _load();
    }
  }

  @override
  void dispose() {
    _unload();
    super.dispose();
  }

  /// Feeds the stored messages to a fresh controller; a surface that isn't
  /// there once they are all in means the template.
  void _load() {
    final controller = SurfaceController(
      catalogs: [rondaCardCatalog(rsvp: widget.rsvp)],
    );
    _controller = controller;
    _failed = false;
    _surfaceId = null;
    // The card never talks to a model: anything the controller would send
    // back (an error it reports, an action) means it can't be drawn.
    _reports = controller.onSubmit.listen((_) => _fail());
    try {
      for (final json in widget.card.messages) {
        final message = a2ui.A2uiMessage.fromJson(json);
        if (message is a2ui.CreateSurfaceMessage) {
          if (message.catalogId != rondaCardCatalogId) {
            throw FormatException('not our catalog: ${message.catalogId}');
          }
          _surfaceId = message.surfaceId;
        }
        controller.handleMessage(message);
      }
    } on Object {
      _failed = true;
    }
    final surfaceId = _surfaceId;
    if (surfaceId == null || !controller.activeSurfaceIds.contains(surfaceId)) {
      _failed = true;
    }
  }

  void _unload() {
    unawaited(_reports?.cancel());
    _reports = null;
    _controller?.dispose();
    _controller = null;
  }

  void _fail() {
    if (_failed || !mounted) return;
    setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final surfaceId = _surfaceId;
    if (_failed || controller == null || surfaceId == null) {
      return widget.fallback(context);
    }
    return Semantics(
      container: true,
      identifier: AgentCardSurface.identifier,
      child: Surface(
        surfaceContext: controller.contextFor(surfaceId),
        defaultBuilder: widget.fallback,
      ),
    );
  }
}
