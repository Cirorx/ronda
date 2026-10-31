import 'dart:async';
import 'dart:typed_data';

import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/cuaderno/cuaderno.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockCuadernoRepository extends Mock implements CuadernoRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

const _uid = 'demo-001';

/// Friday 30/10; the ronda meets on Saturday 31/10.
final _friday = DateTime(2026, 10, 30, 18, 20);
final _saturday = DateTime(2026, 10, 31);

CuadernoEntry _line(int day, [String? text]) =>
    CuadernoEntry(day: DateTime(2026, 10, day), text: text ?? 'línea $day');

Cuaderno _book(List<int> days, {int? bring}) => Cuaderno(
  entries: [for (final day in days) _line(day)],
  bringDay: bring == null ? null : DateTime(2026, 10, bring),
);

void main() {
  group(CuadernoCubit, () {
    late CuadernoRepository repository;
    late RondaRepository rondaRepository;
    late StreamController<void> changes;
    late StreamController<ThisWeek?> weeks;
    late Cuaderno stored;
    late DateTime now;

    setUpAll(() => registerFallbackValue(Postcard(Uint8List(0))));

    setUp(() {
      repository = _MockCuadernoRepository();
      rondaRepository = _MockRondaRepository();
      changes = StreamController<void>.broadcast();
      weeks = StreamController<ThisWeek?>.broadcast();
      addTearDown(changes.close);
      addTearDown(weeks.close);
      stored = _book([29, 27, 20]);
      now = _friday;
      when(() => repository.changes).thenAnswer((_) => changes.stream);
      when(() => repository.read(_uid)).thenAnswer((_) async => stored);
      when(() => rondaRepository.watchThisWeek(_uid))
          .thenAnswer((_) => weeks.stream);
    });

    CuadernoCubit build() => CuadernoCubit(
      uid: _uid,
      cuadernoRepository: repository,
      rondaRepository: rondaRepository,
      now: () => now,
    );

    Future<CuadernoCubit> started() async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.started();
      return cubit;
    }

    Future<void> meetingOn(DateTime? date) async {
      weeks.add(
        date == null
            ? null
            : ThisWeek(
                rondaId: 'r1',
                pretextId: 'mate',
                barrioId: 'el-pinar-sur',
                slotDayId: 'sat',
                slotBandId: 'afternoon',
                myBrings: const [],
                week: '2026-W44',
                date: date,
              ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    test('starts loading, with nothing in it', () {
      expect(build().state, equals(const CuadernoState()));
    });

    group('started', () {
      test('reads the cuaderno from the phone, as of today', () async {
        final cubit = await started();

        expect(cubit.state.status, equals(CuadernoStatus.ready));
        expect(cubit.state.cuaderno, equals(stored));
        expect(cubit.state.today, equals(DateTime(2026, 10, 30)));
      });

      test("follows the ronda's next meeting", () async {
        final cubit = await started();

        await meetingOn(_saturday);
        expect(cubit.state.meetingDate, equals(_saturday));

        await meetingOn(null);
        expect(cubit.state.meetingDate, isNull);
      });

      test("has no meeting when the ronda can't be read", () async {
        final cubit = await started();
        await meetingOn(_saturday);

        weeks.addError(Exception('x'));
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.meetingDate, isNull);
      });

      test('reads again when the cuaderno changes', () async {
        final cubit = await started();
        stored = _book([30, 29, 27, 20]);

        changes.add(null);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.cuaderno.entries, hasLength(4));
      });

      test("fails, with the error, when the phone's store does", () async {
        when(() => repository.read(_uid)).thenThrow(Exception('keychain'));
        final errors = <Object>[];
        final cubit = build();
        addTearDown(cubit.close);
        await runZonedGuarded(cubit.started, (error, _) => errors.add(error));

        expect(cubit.state.status, equals(CuadernoStatus.failure));
      });

      test('"Probar de nuevo" reads it again', () async {
        when(() => repository.read(_uid)).thenThrow(Exception('keychain'));
        final cubit = build();
        addTearDown(cubit.close);
        await runZonedGuarded(cubit.started, (_, _) {});
        when(() => repository.read(_uid)).thenAnswer((_) async => stored);

        await cubit.retry();

        expect(cubit.state.status, equals(CuadernoStatus.ready));
      });

      test('does nothing once closed', () async {
        final reading = Completer<Cuaderno>();
        when(() => repository.read(_uid)).thenAnswer((_) => reading.future);
        final cubit = build();
        final start = cubit.started();
        await cubit.close();
        reading.complete(stored);

        await start;

        expect(cubit.state.status, equals(CuadernoStatus.loading));
      });
    });

    group('writeToday', () {
      setUp(() {
        when(
          () => repository.saveEntry(
            _uid,
            day: any(named: 'day'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) async => stored);
      });

      test('writes the line for today and says so', () async {
        final cubit = await started();
        final states = <CuadernoState>[];
        final subscription = cubit.stream.listen(states.add);

        await cubit.writeToday('  El jacarandá floreció. ');
        await subscription.cancel();

        verify(
          () => repository.saveEntry(
            _uid,
            day: DateTime(2026, 10, 30),
            text: '  El jacarandá floreció. ',
          ),
        ).called(1);
        expect(states.first.writing, isTrue);
        expect(cubit.state.writing, isFalse);
        expect(cubit.state.wrote, isTrue);
      });

      test('ignores an empty line', () async {
        final cubit = await started();

        await cubit.writeToday('   ');

        verifyNever(
          () => repository.saveEntry(
            any(),
            day: any(named: 'day'),
            text: any(named: 'text'),
          ),
        );
      });

      test('says when it could not be saved', () async {
        when(
          () => repository.saveEntry(
            _uid,
            day: any(named: 'day'),
            text: any(named: 'text'),
          ),
        ).thenThrow(Exception('x'));
        final cubit = await started();

        await runZonedGuarded(() => cubit.writeToday('uno'), (_, _) {});

        expect(cubit.state.failure, equals(CuadernoFailure.write));
        expect(cubit.state.writing, isFalse);
        expect(cubit.state.wrote, isFalse);
      });

      test('does not report back once closed', () async {
        final saving = Completer<Cuaderno>();
        when(
          () => repository.saveEntry(
            _uid,
            day: any(named: 'day'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) => saving.future);
        final cubit = await started();
        final writing = cubit.writeToday('uno');
        await cubit.close();
        saving.complete(stored);

        await writing;

        expect(cubit.state.wrote, isFalse);
      });

      test('does not report a failure back once closed', () async {
        final saving = Completer<Cuaderno>();
        when(
          () => repository.saveEntry(
            _uid,
            day: any(named: 'day'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) => saving.future);
        final cubit = await started();
        final writing = cubit.writeToday('uno');
        await cubit.close();
        saving.completeError(Exception('x'));

        await runZonedGuarded(() => writing, (_, _) {});

        expect(cubit.state.failure, isNull);
      });
    });

    group('the lines', () {
      final entry = _line(29);

      setUp(() {
        when(() => repository.deleteEntry(_uid, any()))
            .thenAnswer((_) async => stored);
        when(() => repository.bring(_uid, any()))
            .thenAnswer((_) async => stored);
        when(
          () => repository.saveEntry(
            _uid,
            day: any(named: 'day'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) async => stored);
      });

      test('deletes a line', () async {
        final cubit = await started();

        await cubit.deleteEntry(entry);

        verify(() => repository.deleteEntry(_uid, entry.day)).called(1);
      });

      test('puts a deleted line back as it was', () async {
        final cubit = await started();

        await cubit.restoreEntry(entry);

        verify(
          () => repository.saveEntry(_uid, day: entry.day, text: 'línea 29'),
        ).called(1);
      });

      test('chooses a line to bring, and none', () async {
        final cubit = await started();

        await cubit.bringToggled(entry, bring: true);
        await cubit.bringToggled(entry, bring: false);

        verify(() => repository.bring(_uid, entry.day)).called(1);
        verify(() => repository.bring(_uid, null)).called(1);
      });

      test('says when the phone could not change it', () async {
        when(() => repository.deleteEntry(_uid, any()))
            .thenThrow(Exception('x'));
        final cubit = await started();

        await runZonedGuarded(() => cubit.deleteEntry(entry), (_, _) {});

        expect(cubit.state.failure, equals(CuadernoFailure.write));
      });

      test('says nothing once closed', () async {
        final deleting = Completer<Cuaderno>();
        when(() => repository.deleteEntry(_uid, any()))
            .thenAnswer((_) => deleting.future);
        final cubit = await started();
        final pending = cubit.deleteEntry(entry);
        await cubit.close();
        deleting.completeError(Exception('x'));

        await pending;

        expect(cubit.state.failure, isNull);
      });
    });

    group('the postcard', () {
      final postcard = Postcard(Uint8List.fromList([1, 2, 3]));

      setUp(() {
        when(() => repository.makePostcard(any()))
            .thenAnswer((_) async => postcard);
        when(() => repository.sharePostcard(any(), title: any(named: 'title')))
            .thenAnswer((_) async => true);
      });

      test(
        'is offered the day before the meeting, with lines this week',
        () async {
          final cubit = await started();
          await meetingOn(_saturday);

          expect(cubit.state.postcardOffered, isTrue);
        },
      );

      test('is offered on the day of the meeting too', () async {
        now = _saturday;
        final cubit = await started();
        await meetingOn(_saturday);

        expect(cubit.state.postcardOffered, isTrue);
      });

      test('is not offered earlier in the week', () async {
        now = DateTime(2026, 10, 29);
        final cubit = await started();
        await meetingOn(_saturday);

        expect(cubit.state.postcardOffered, isFalse);
      });

      test('is not offered after the meeting', () async {
        now = DateTime(2026, 11);
        final cubit = await started();
        await meetingOn(_saturday);

        expect(cubit.state.postcardOffered, isFalse);
      });

      test(
        'is not offered with no ronda, or before the cuaderno is read',
        () async {
          final cubit = await started();

          expect(cubit.state.postcardOffered, isFalse);
          expect(const CuadernoState().postcardOffered, isFalse);
          expect(const CuadernoState().weekLines, isEmpty);
          expect(const CuadernoState().todaysLine, isNull);
        },
      );

      test('is not offered when the week has no lines', () async {
        stored = _book([20]);
        final cubit = await started();
        await meetingOn(_saturday);

        expect(cubit.state.postcardOffered, isFalse);
      });

      test(
        'is drawn from the last seven days of lines, and only those',
        () async {
          final cubit = await started();
          await meetingOn(_saturday);

          await cubit.postcardRequested();

          verify(() => repository.makePostcard(['línea 27', 'línea 29']))
              .called(1);
          expect(cubit.state.postcard, equals(postcard));
          expect(cubit.state.makingPostcard, isFalse);
        },
      );

      test('is not asked for when it is not offered', () async {
        final cubit = await started();

        await cubit.postcardRequested();

        verifyNever(() => repository.makePostcard(any()));
      });

      test('says while it is being drawn, and asks once', () async {
        final drawing = Completer<Postcard>();
        when(() => repository.makePostcard(any()))
            .thenAnswer((_) => drawing.future);
        final cubit = await started();
        await meetingOn(_saturday);

        final first = cubit.postcardRequested();
        await cubit.postcardRequested();

        expect(cubit.state.makingPostcard, isTrue);
        drawing.complete(postcard);
        await first;
        verify(() => repository.makePostcard(any())).called(1);
      });

      test('says when there was nothing to draw', () async {
        when(() => repository.makePostcard(any()))
            .thenThrow(const NothingToDrawFailure());
        final cubit = await started();
        await meetingOn(_saturday);

        await cubit.postcardRequested();

        expect(cubit.state.failure, equals(CuadernoFailure.nothingToDraw));
        expect(cubit.state.makingPostcard, isFalse);
      });

      test('says when it could not be drawn', () async {
        when(() => repository.makePostcard(any()))
            .thenThrow(const MakePostcardFailure());
        final cubit = await started();
        await meetingOn(_saturday);

        await cubit.postcardRequested();

        expect(cubit.state.failure, equals(CuadernoFailure.postcard));
      });

      test('says nothing once closed', () async {
        final drawing = Completer<Postcard>();
        when(() => repository.makePostcard(any()))
            .thenAnswer((_) => drawing.future);
        final cubit = await started();
        await meetingOn(_saturday);
        final pending = cubit.postcardRequested();
        await cubit.close();
        drawing.completeError(const MakePostcardFailure());

        await pending;

        expect(cubit.state.failure, isNull);
      });

      test('does not report a postcard back once closed', () async {
        final drawing = Completer<Postcard>();
        when(() => repository.makePostcard(any()))
            .thenAnswer((_) => drawing.future);
        final cubit = await started();
        await meetingOn(_saturday);
        final pending = cubit.postcardRequested();
        await cubit.close();
        drawing.complete(postcard);

        await pending;

        expect(cubit.state.postcard, isNull);
      });

      test('is saved to the phone through the share sheet', () async {
        final cubit = await started();
        await meetingOn(_saturday);
        await cubit.postcardRequested();

        await cubit.shareRequested(title: 'Postal');

        verify(() => repository.sharePostcard(postcard, title: 'Postal'))
            .called(1);
      });

      test('is not shared when there is none', () async {
        final cubit = await started();

        await cubit.shareRequested(title: 'Postal');

        verifyNever(
          () => repository.sharePostcard(any(), title: any(named: 'title')),
        );
      });

      test('says when the share sheet did not open', () async {
        when(() => repository.sharePostcard(any(), title: any(named: 'title')))
            .thenThrow(const SharePostcardFailure());
        final cubit = await started();
        await meetingOn(_saturday);
        await cubit.postcardRequested();

        await cubit.shareRequested(title: 'Postal');

        expect(cubit.state.failure, equals(CuadernoFailure.share));
      });

      test('says nothing of a share that ends once closed', () async {
        final sharing = Completer<bool>();
        when(() => repository.sharePostcard(any(), title: any(named: 'title')))
            .thenAnswer((_) => sharing.future);
        final cubit = await started();
        await meetingOn(_saturday);
        await cubit.postcardRequested();
        final pending = cubit.shareRequested(title: 'Postal');
        await cubit.close();
        sharing.completeError(const SharePostcardFailure());

        await pending;

        expect(cubit.state.failure, isNull);
      });
    });
  });
}
