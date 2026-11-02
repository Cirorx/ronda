import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAdminAccessCubit extends MockCubit<AdminAccess>
    implements AdminAccessCubit;

void main() {
  group(AdminGate, () {
    late AdminAccessCubit adminAccess;

    setUp(() {
      adminAccess = _MockAdminAccessCubit();
    });

    Future<void> pumpGate(WidgetTester tester, {Locale? locale}) =>
        tester.pumpApp(
          BlocProvider.value(
            value: adminAccess,
            child: const AdminGate(child: Text('panel')),
          ),
          locale: locale ?? rioplatense,
        );

    testWidgets('builds the screen for the admin', (tester) async {
      when(() => adminAccess.state).thenReturn(AdminAccess.admin);

      await pumpGate(tester);

      expect(find.text('panel'), findsOneWidget);
      expect(find.byType(LoadingStatus), findsNothing);
    });

    for (final access in [
      AdminAccess.signedOut,
      AdminAccess.checking,
      AdminAccess.member,
    ]) {
      testWidgets('never builds the screen while $access', (tester) async {
        when(() => adminAccess.state).thenReturn(access);

        await pumpGate(tester);

        expect(find.text('panel'), findsNothing);
        expect(find.text('Revisando esta cuenta…'), findsOneWidget);
      });
    }

    testWidgets('says so in English', (tester) async {
      when(() => adminAccess.state).thenReturn(AdminAccess.checking);

      await pumpGate(tester, locale: const Locale('en'));

      expect(find.text('Checking this account…'), findsOneWidget);
    });

    testWidgets('builds the screen once the claim is read', (tester) async {
      whenListen(
        adminAccess,
        Stream.value(AdminAccess.admin),
        initialState: AdminAccess.checking,
      );

      await pumpGate(tester);
      expect(find.text('panel'), findsNothing);
      await tester.pump();

      expect(find.text('panel'), findsOneWidget);
    });
  });
}
