import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cuaderno/cuaderno.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockCuadernoRepository extends Mock implements CuadernoRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(CuadernoPage, () {
    testWidgets('provides the cuaderno and the voice line over the '
        'repositories, and opens the cuaderno', (tester) async {
      final appBloc = _MockAppBloc();
      final cuaderno = _MockCuadernoRepository();
      final ronda = _MockRondaRepository();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'demo-uid'),
        ),
      );
      when(() => cuaderno.changes)
          .thenAnswer((_) => const Stream<void>.empty());
      when(() => cuaderno.read('demo-uid'))
          .thenAnswer((_) async => Cuaderno.empty);
      when(() => ronda.watchThisWeek('demo-uid'))
          .thenAnswer((_) => Stream.value(null));

      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CuadernoRepository>.value(value: cuaderno),
            RepositoryProvider<RondaRepository>.value(value: ronda),
          ],
          child: BlocProvider<AppBloc>.value(
            value: appBloc,
            child: const CuadernoPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CuadernoView), findsOneWidget);
      final context = tester.element(find.byType(CuadernoView));
      expect(
        context.read<CuadernoCubit>().state.status,
        equals(CuadernoStatus.ready),
      );
      expect(
        context.read<LineVoiceCubit>().state.status,
        equals(LineVoiceStatus.ready),
      );
      expect(CuadernoPage.path, equals('/ronda/cuaderno'));
    });
  });
}
