import 'package:flutter_test/flutter_test.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/agent_trace/agent_trace.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

final _at = DateTime(2026, 11, 4, 22, 0, 3);

void main() {
  group(AgentStepTile, () {
    Future<void> pump(WidgetTester tester, AgentStep step) => tester.pumpApp(
      Scaffold(body: SingleChildScrollView(child: AgentStepTile(step))),
    );

    testWidgets('a model answer: which model, how long, the calls', (
      tester,
    ) async {
      await pump(
        tester,
        AgentStep(
          n: 1,
          at: _at,
          kind: AgentStepKind.model,
          model: 'meta-models/muse-spark-open-1026',
          latency: const Duration(milliseconds: 1240),
          tool: 'get_sunset, count_rsvps',
          summary: 'Listo.',
        ),
      );

      expect(find.text('1 · 22:00'), findsOneWidget);
      expect(
        find.text('meta-models/muse-spark-open-1026 · 1.2 s'),
        findsOneWidget,
      );
      expect(find.text('Llama a get_sunset, count_rsvps'), findsOneWidget);
      expect(find.text('Listo.'), findsOneWidget);
    });

    testWidgets('a quiet model answer shows only itself', (tester) async {
      await pump(
        tester,
        AgentStep(n: 2, at: _at, kind: AgentStepKind.model, model: 'm'),
      );

      expect(find.textContaining('Llama a'), findsNothing);
    });

    testWidgets('a tool call: its reason, arguments and result', (
      tester,
    ) async {
      await pump(
        tester,
        AgentStep(
          n: 3,
          at: _at,
          kind: AgentStepKind.tool,
          tool: 'propose_move',
          arguments: '{"place_id": "salon-pinar"}',
          reason: 'llueve 80%',
          summary: 'No propuso nada.',
          refused: true,
        ),
      );

      expect(find.text('propose_move'), findsOneWidget);
      expect(find.text('Por qué: llueve 80%'), findsOneWidget);
      expect(find.text('{"place_id": "salon-pinar"}'), findsOneWidget);
      expect(find.text('No propuso nada.'), findsOneWidget);
      expect(find.text('No lo hizo'), findsOneWidget);
    });

    testWidgets('a bare tool call shows its result only', (tester) async {
      await pump(
        tester,
        AgentStep(
          n: 4,
          at: _at,
          kind: AgentStepKind.tool,
          tool: 'count_rsvps',
          summary: 'Contó.',
        ),
      );

      expect(find.textContaining('Por qué'), findsNothing);
      expect(find.text('No lo hizo'), findsNothing);
    });

    testWidgets('a message to the host that went out', (tester) async {
      await pump(
        tester,
        AgentStep(
          n: 5,
          at: _at,
          kind: AgentStepKind.message,
          toName: 'Mirta',
          toHost: true,
          text: 'Jueves 16:00 · lluvia 80%.',
          outcome: MessageOutcome.sent,
        ),
      );

      expect(find.text('Para Mirta, que abre'), findsOneWidget);
      expect(find.text('«Jueves 16:00 · lluvia 80%.»'), findsOneWidget);
      expect(find.text('Salió'), findsOneWidget);
    });

    testWidgets('a message held at night says when it could go', (
      tester,
    ) async {
      await pump(
        tester,
        AgentStep(
          n: 6,
          at: _at,
          kind: AgentStepKind.message,
          toName: 'Jorge',
          text: 'Mañana llueve.',
          outcome: MessageOutcome.held,
          heldBecause: 'fuera de horario',
          releaseAt: DateTime(2026, 11, 5, 9),
        ),
      );

      expect(find.text('Para Jorge'), findsOneWidget);
      expect(
        find.textContaining('Frenado: fuera de horario. Podría salir el'),
        findsOneWidget,
      );
      expect(find.textContaining(RegExp(r'a las 0?9:00\.$')), findsOneWidget);
    });

    testWidgets('a message held by another gate says why', (tester) async {
      await pump(
        tester,
        AgentStep(
          n: 7,
          at: _at,
          kind: AgentStepKind.message,
          outcome: MessageOutcome.held,
          heldBecause: 'tiene un emoji (🧉)',
        ),
      );

      expect(find.text('Frenado: tiene un emoji (🧉).'), findsOneWidget);
    });

    for (final (outcome, line) in [
      (MessageOutcome.unreachable, 'No llegó: ningún teléfono lo tomó.'),
      (MessageOutcome.skipped, 'Emulador: no se manda nada.'),
    ]) {
      testWidgets('a message ${outcome.name} says so', (tester) async {
        await pump(
          tester,
          AgentStep(
            n: 8,
            at: _at,
            kind: AgentStepKind.message,
            outcome: outcome,
          ),
        );

        expect(find.text(line), findsOneWidget);
      });
    }

    testWidgets('a message without an outcome shows none', (tester) async {
      await pump(tester, AgentStep(n: 9, at: _at, kind: AgentStepKind.message));

      expect(find.byType(NoteBanner), findsNothing);
    });

    for (final (kind, line) in [
      (AgentStepKind.stop, 'Se detuvo: tope'),
      (AgentStepKind.host, 'tope'),
      (AgentStepKind.note, 'tope'),
      (AgentStepKind.other, 'tope'),
    ]) {
      testWidgets('a ${kind.name} step shows its words', (tester) async {
        await pump(
          tester,
          AgentStep(n: 10, at: _at, kind: kind, summary: 'tope'),
        );

        expect(find.text(line), findsOneWidget);
      });
    }
  });
}
