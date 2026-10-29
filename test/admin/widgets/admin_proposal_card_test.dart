import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

void main() {
  group(AdminProposalCard, () {
    Future<void> pump(WidgetTester tester, ProposedRonda ronda) =>
        tester.pumpApp(
          Scaffold(
            body: SingleChildScrollView(child: AdminProposalCard(ronda: ronda)),
          ),
        );

    ProposedMember member(
      String name,
      String band, {
      double blocks = 1,
      bool? plusOneInGroup,
    }) => ProposedMember(
      uid: 'demo-$name',
      firstName: name,
      ageBandId: band,
      distanceBlocks: blocks,
      plusOneInGroup: plusOneInGroup,
    );

    ProposedRonda ronda(
      List<ProposedMember> members, {
      String barrio = 'lagomar-sur',
      String pretext = 'mate',
      String slot = 'sat-afternoon',
    }) => ProposedRonda(
      seatId: '${barrio}_${pretext}_$slot',
      barrioId: barrio,
      pretextId: pretext,
      slotId: slot,
      members: members,
    );

    group('renders', () {
      testWidgets('what, where, when and each member', (tester) async {
        await pump(tester, AdminFixtures.ronda);

        expect(find.text('Mate en la rambla · Lagomar Sur'), findsOneWidget);
        expect(find.text('Sábado a la tarde'), findsOneWidget);
        expect(find.byType(PersonRow), findsNWidgets(3));
        expect(find.text('Marta'), findsOneWidget);
        expect(find.textContaining('en su barrio'), findsOneWidget);
        expect(find.textContaining('a 1 cuadra'), findsOneWidget);
        expect(find.textContaining('a 4 cuadras'), findsOneWidget);
      });

      testWidgets('the three checks it keeps', (tester) async {
        await pump(tester, AdminFixtures.ronda);

        expect(
          find.text('Todos viven a menos de 10 cuadras del punto'),
          findsOneWidget,
        );
        expect(find.text('Hay al menos dos de 60 o más'), findsOneWidget);
        expect(find.text('Marta y su invitado van juntos'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNWidgets(3));
        expect(find.bySemanticsLabel(RegExp('^Se cumple: ')), findsNWidgets(3));
      });

      testWidgets('the checks it breaks', (tester) async {
        await pump(
          tester,
          ronda([
            member('Ana', '60-69', blocks: 11, plusOneInGroup: false),
            member('Beto', '30-39'),
          ]),
        );

        expect(
          find.text('Alguien vive a más de 10 cuadras del punto'),
          findsOneWidget,
        );
        expect(find.text('Hay una sola persona de 60 o más'), findsOneWidget);
        expect(find.text('Ana va sin su invitado'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNWidgets(3));
        expect(
          find.bySemanticsLabel(RegExp('^No se cumple: ')),
          findsNWidgets(3),
        );
      });

      testWidgets('no 60+ check when nobody is 60 or over', (tester) async {
        await pump(tester, ronda([member('Beto', '30-39')]));

        expect(find.textContaining('60 o más'), findsNothing);
      });

      testWidgets('unknown ids as they are', (tester) async {
        await pump(
          tester,
          ronda(
            [member('Beto', '90-99')],
            barrio: 'pocitos',
            pretext: 'ajedrez',
            slot: 'someday',
          ),
        );

        expect(find.text('ajedrez · pocitos'), findsOneWidget);
        expect(find.text('someday'), findsOneWidget);
        expect(find.textContaining('90-99'), findsOneWidget);
      });
    });
  });
}
