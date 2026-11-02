import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/my_ronda/agent_card/agent_card_surface.dart';
import 'package:ronda/my_ronda/agent_card/ronda_card_catalog.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

const _week = '2026-W45';
const _surface = 'card-$_week';

Map<String, Object?> _create({String catalogId = rondaCardCatalogId}) => {
  'version': 'v0.9',
  'createSurface': {'surfaceId': _surface, 'catalogId': catalogId},
};

Map<String, Object?> _update(List<Map<String, Object?>> components) => {
  'version': 'v0.9',
  'updateComponents': {'surfaceId': _surface, 'components': components},
};

Map<String, Object?> _root(List<String> children) => {
  'id': 'root',
  'component': RondaCardComponents.card,
  'children': children,
};

const _rsvp = <String, Object?>{'id': 'rsvp', 'component': 'Rsvp'};

const _rain = <String, Object?>{
  'id': 'rain',
  'component': 'RainNotice',
  'title': 'Puede llover',
  'text': 'El jueves a las 16 hay 80% de lluvia. Si llueve, el salón.',
};

const _host = <String, Object?>{
  'id': 'host',
  'component': 'HostOfWeek',
  'title': 'Quién abre',
  'text': 'Esta semana abre Mirta.',
};

AgentCard _card(List<Map<String, Object?>> messages) =>
    AgentCard(week: _week, messages: messages);

/// The card the server stores for a rainy week with a host.
final AgentCard _rainyCard = _card([
  _create(),
  _update([
    _root(['rain', 'host', 'rsvp']),
    _rain,
    _host,
    _rsvp,
  ]),
]);

void main() {
  group(AgentCardSurface, () {
    Future<void> pump(WidgetTester tester, AgentCard card) => tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: AgentCardSurface(
            card: card,
            rsvp: (_) => const Text('¿Venís?'),
            fallback: (_) => const Text('la tarjeta fija'),
          ),
        ),
      ),
    );

    testWidgets('draws the blocks the organiser composed, in order, and '
        'the RSVP block from the app', (tester) async {
      await pump(tester, _rainyCard);
      await tester.pump();

      expect(find.text('Puede llover'), findsOneWidget);
      expect(find.text('Quién abre'), findsOneWidget);
      expect(find.text('Esta semana abre Mirta.'), findsOneWidget);
      expect(find.text('¿Venís?'), findsOneWidget);
      expect(find.text('la tarjeta fija'), findsNothing);
      expect(find.byType(NoteBanner), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Puede llover')).dy,
        lessThan(tester.getTopLeft(find.text('Quién abre')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Quién abre')).dy,
        lessThan(tester.getTopLeft(find.text('¿Venís?')).dy),
      );
      expect(
        find.bySemanticsIdentifier(AgentCardSurface.identifier),
        findsOneWidget,
      );
    });

    testWidgets('draws every block kind of the catalog', (tester) async {
      await pump(
        tester,
        _card([
          _create(),
          _update([
            _root(['newcomer', 'despues', 'bench', 'rsvp']),
            {
              'id': 'newcomer',
              'component': 'Newcomer',
              'title': 'Alguien nuevo',
              'text': 'Se suma Facu.',
            },
            {
              'id': 'despues',
              'component': 'DespuesSpot',
              'title': 'Después',
              'text': 'Bizcochos en lo de Mirta.',
            },
            {
              'id': 'bench',
              'component': 'BenchNudge',
              'title': 'Lista de espera',
              'text': 'Si no venís, avisá.',
            },
            _rsvp,
          ]),
        ]),
      );
      await tester.pump();

      expect(find.text('Se suma Facu.'), findsOneWidget);
      expect(find.text('Bizcochos en lo de Mirta.'), findsOneWidget);
      expect(find.text('Si no venís, avisá.'), findsOneWidget);
      expect(find.byType(NoteBanner), findsNWidgets(3));
    });

    group('falls back to the template', () {
      Future<void> expectFallback(
        WidgetTester tester,
        List<Map<String, Object?>> messages,
      ) async {
        await pump(tester, _card(messages));
        await tester.pump();
        await tester.pump();

        expect(find.text('la tarjeta fija'), findsOneWidget);
        expect(find.byType(NoteBanner), findsNothing);
        expect(
          find.bySemanticsIdentifier(AgentCardSurface.identifier),
          findsNothing,
        );
      }

      testWidgets('without messages', (tester) => expectFallback(tester, []));

      testWidgets(
        'when a message does not parse',
        (tester) => expectFallback(tester, [
          {'createSurface': <String, Object?>{}},
        ]),
      );

      testWidgets(
        'when a message has the wrong shape',
        (tester) => expectFallback(tester, [
          {'version': 'v0.9', 'createSurface': 'x'},
        ]),
      );

      testWidgets(
        'when the surface is for another catalog',
        (tester) => expectFallback(tester, [
          _create(catalogId: 'com.example.other'),
          _update([
            _root(['rsvp']),
            _rsvp,
          ]),
        ]),
      );

      testWidgets(
        'when a component is outside the catalog',
        (tester) => expectFallback(tester, [
          _create(),
          _update([
            _root(['map', 'rsvp']),
            {'id': 'map', 'component': 'Map', 'pins': <Object?>[]},
            _rsvp,
          ]),
        ]),
      );

      testWidgets(
        'when a block lacks its title',
        (tester) => expectFallback(tester, [
          _create(),
          _update([
            _root(['rain', 'rsvp']),
            {'id': 'rain', 'component': 'RainNotice', 'text': 'Llueve.'},
            _rsvp,
          ]),
        ]),
      );

      testWidgets(
        'when the root names a block that is not there',
        (tester) => expectFallback(tester, [
          _create(),
          _update([
            _root(['rain', 'rsvp']),
            _rsvp,
          ]),
        ]),
      );

      testWidgets(
        'when the root has no block ids',
        (tester) => expectFallback(tester, [
          _create(),
          _update([
            {'id': 'root', 'component': 'RondaCard', 'children': 'rsvp'},
            _rsvp,
          ]),
        ]),
      );

      testWidgets(
        'when the components come before their surface',
        (tester) => expectFallback(tester, [
          _update([
            _root(['rsvp']),
            _rsvp,
          ]),
        ]),
      );
    });

    testWidgets('loads a new card from scratch', (tester) async {
      await pump(tester, _rainyCard);
      await tester.pump();
      expect(find.text('Puede llover'), findsOneWidget);

      await pump(
        tester,
        _card([
          _create(),
          _update([
            _root(['host', 'rsvp']),
            _host,
            _rsvp,
          ]),
        ]),
      );
      await tester.pump();

      expect(find.text('Puede llover'), findsNothing);
      expect(find.text('Quién abre'), findsOneWidget);
      expect(find.text('¿Venís?'), findsOneWidget);
    });
  });
}
