import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockContactRepository extends Mock implements ContactRepository;

class _MockContactCubit extends MockCubit<ContactState> implements ContactCubit;

const _email = 'hola@example.com';

/// The screen's list, not the selectable text's own scrollable.
final Finder _list = find.byType(Scrollable).first;

void main() {
  late AppBloc appBloc;

  setUp(() {
    appBloc = _MockAppBloc();
    whenListen(
      appBloc,
      const Stream<AppState>.empty(),
      initialState: const AppState(
        status: AppStatus.authenticated,
        user: User(id: 'demo-uid'),
      ),
    );
  });

  group(YourDataPage, () {
    testWidgets('provides a $ContactCubit over the repository', (tester) async {
      final repository = _MockContactRepository();
      when(() => repository.email).thenReturn(_email);

      await tester.pumpApp(
        RepositoryProvider<ContactRepository>.value(
          value: repository,
          child: BlocProvider.value(
            value: appBloc,
            child: const YourDataPage(),
          ),
        ),
      );

      expect(find.byType(YourDataView), findsOneWidget);
    });
  });

  group(YourDataView, () {
    late ContactCubit cubit;

    setUp(() {
      cubit = _MockContactCubit();
      when(() => cubit.state).thenReturn(const ContactState(email: _email));
      when(
        () => cubit.emailTapped(
          subject: any(named: 'subject'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, {Locale locale = rioplatense}) =>
        tester.pumpApp(
          BlocProvider.value(
            value: appBloc,
            child: BlocProvider.value(
              value: cubit,
              child: const YourDataView(),
            ),
          ),
          locale: locale,
        );

    testWidgets('lists what Ronda keeps and what it does not', (tester) async {
      const account =
          'Tu cuenta de Google, para que entres, y un código para mandarle '
          'avisos a este teléfono.';
      await pump(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Tus datos'),
        ),
        findsOneWidget,
      );
      for (final text in [
        'Lo que Ronda guarda de vos',
        'Tu nombre de pila, tu edad más o menos y tu barrio.',
        'Tus días y horarios, las actividades que elegiste y lo que traés.',
        'Tu ronda y tus respuestas: si vas cada semana y si seguís.',
        account,
        'Cuándo aceptaste las condiciones.',
        'Lo que no guardamos',
        'Tu audio: se borra apenas lo leemos.',
        'Lo que te complica ir: queda solo en este teléfono.',
      ]) {
        await tester.scrollUntilVisible(
          find.text(text),
          100,
          scrollable: _list,
        );
        expect(find.text(text), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.text('Para cambiar o borrar tus datos, escribinos a $_email.'),
        100,
        scrollable: _list,
      );
      expect(find.textContaining('se guardan en Brasil'), findsOneWidget);
    });

    testWidgets('in English', (tester) async {
      await pump(tester, locale: const Locale('en'));

      expect(find.text('What Ronda keeps about you'), findsOneWidget);
    });

    testWidgets('writes a mail that names the account', (tester) async {
      await pump(tester);
      final button = find.bySemanticsIdentifier(YourDataView.emailIdentifier);
      await tester.scrollUntilVisible(button, 100, scrollable: _list);

      await tester.tap(button);

      verify(
        () => cubit.emailTapped(
          subject: 'Ronda: mis datos',
          body:
              'Mi cuenta de Ronda (dejá esta línea, así te encontramos): '
              'demo-uid',
        ),
      ).called(1);
    });
  });
}
