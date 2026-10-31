import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cuaderno/cuaderno.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockCuadernoRepository extends Mock implements CuadernoRepository;

void main() {
  group(EraseCuadernoSection, () {
    late CuadernoRepository repository;

    setUp(() {
      repository = _MockCuadernoRepository();
      when(() => repository.clear('demo-uid')).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, {Locale? locale}) async {
      final appBloc = _MockAppBloc();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'demo-uid'),
        ),
      );
      await tester.pumpApp(
        RepositoryProvider<CuadernoRepository>.value(
          value: repository,
          child: BlocProvider<AppBloc>.value(
            value: appBloc,
            child: const Scaffold(body: EraseCuadernoSection()),
          ),
        ),
        locale: locale ?? rioplatense,
      );
    }

    testWidgets('says where the cuaderno is', (tester) async {
      await pump(tester);

      expect(find.text('Tu cuaderno'), findsOneWidget);
      expect(
        find.text(
          'Está solo en este teléfono: nosotros no lo vemos ni lo podemos '
          'borrar por vos.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('deletes it in one action, after one question', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Borrar mi cuaderno'));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrás todo tu cuaderno?'), findsOneWidget);
      verifyNever(() => repository.clear(any()));

      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      verify(() => repository.clear('demo-uid')).called(1);
      expect(find.text('Se borró tu cuaderno.'), findsOneWidget);
    });

    testWidgets('keeps it when the person backs out', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Borrar mi cuaderno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dejarlo'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.clear(any()));
      expect(find.text('Se borró tu cuaderno.'), findsNothing);
    });

    testWidgets('keeps it when the question is dismissed', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Borrar mi cuaderno'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      verifyNever(() => repository.clear(any()));
    });

    testWidgets('says when it could not', (tester) async {
      when(() => repository.clear('demo-uid')).thenThrow(Exception('x'));
      await pump(tester);

      await tester.tap(find.text('Borrar mi cuaderno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos borrarlo. Probá de nuevo.'), findsOneWidget);
      tester.takeException();
    });

    testWidgets('in English', (tester) async {
      await pump(tester, locale: const Locale('en'));

      expect(find.text('Delete my notebook'), findsOneWidget);
    });
  });
}
