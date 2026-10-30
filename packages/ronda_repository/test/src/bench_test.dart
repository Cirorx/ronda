import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProposalsApi extends Mock implements ProposalsApi;

class _MockRondasApi extends Mock implements RondasApi;

final _deadline = DateTime.utc(2026, 11, 4, 20);

BenchOfferDocument _offer(String id, String date, String status) =>
    BenchOfferDocument(
      id: id,
      rondaId: 'r1',
      week: '2026-W45',
      date: date,
      pretext: 'mate',
      slotDay: 'thu',
      slotBand: 'afternoon',
      deadline: _deadline,
      status: status,
      hour: '16:00',
      placeName: 'frente al quiosco',
      placeLandmark: 'al lado de la parada',
    );

const _nearby = NearbyRondaDocument(
  rondaId: 'r2',
  pretext: 'truco',
  barrio: 'el-pinar-norte',
  slotDay: 'thu',
  slotBand: 'evening',
  placesLeft: 3,
  next: '2026-11-05',
);

WaitingDocument _waiting({
  String status = 'open',
  String deadline = '2026-11-01',
  List<NearbyRondaDocument> alternatives = const [],
  String? choice,
}) => WaitingDocument(
  seatId: 'el-pinar-sur_mate_sat-afternoon',
  barrio: 'el-pinar-sur',
  pretext: 'mate',
  slot: 'sat-afternoon',
  count: 5,
  threshold: 6,
  deadline: deadline,
  start: '2026-11-07',
  status: status,
  alternatives: alternatives,
  choice: choice,
);

Matcher _failsWith(RsvpFailureReason reason) =>
    throwsA(isA<RsvpFailure>().having((f) => f.reason, 'reason', reason));

void main() {
  group('RondaRepository bench and waiting list', () {
    late RondasApi rondasApi;
    late RondaRepository subject;

    setUp(() {
      rondasApi = _MockRondasApi();
      subject = RondaRepository(
        proposalsApi: _MockProposalsApi(),
        rondasApi: rondasApi,
      );
    });

    group('watchBenchOffers', () {
      test('turns each offer into its status, newest meeting first', () {
        when(() => rondasApi.watchOffers('demo-201')).thenAnswer(
          (_) => Stream.value([
            _offer('a', '2026-10-29', 'taken'),
            _offer('b', '2026-11-05', 'pending'),
            _offer('c', '2026-11-05', 'expired'),
            _offer('d', 'not a date', 'pending'),
          ]),
        );

        expect(
          subject.watchBenchOffers('demo-201'),
          emits([
            BenchOffer(
              offerId: 'b',
              rondaId: 'r1',
              date: DateTime(2026, 11, 5),
              pretextId: 'mate',
              slotDayId: 'thu',
              slotBandId: 'afternoon',
              deadline: _deadline,
              status: BenchOfferStatus.pending,
              hour: '16:00',
              placeName: 'frente al quiosco',
              placeLandmark: 'al lado de la parada',
            ),
            isA<BenchOffer>()
                .having((o) => o.offerId, 'offerId', 'c')
                .having((o) => o.status, 'status', BenchOfferStatus.over),
            isA<BenchOffer>()
                .having((o) => o.status, 'status', BenchOfferStatus.taken)
                .having((o) => o.props.length, 'props', 11),
          ]),
        );
      });

      test('errors with an RsvpFailure when the read fails', () {
        when(() => rondasApi.watchOffers('demo-201'))
            .thenAnswer((_) => Stream.error(const FormatException('shape')));

        expect(
          subject.watchBenchOffers('demo-201'),
          emitsError(isA<RsvpFailure>()),
        );
      });
    });

    group('answerBenchOffer', () {
      test('answers through answer_bench_offer', () async {
        when(() => rondasApi.answerBenchOffer(offerId: 'b', take: true))
            .thenAnswer((_) async {});

        await subject.answerBenchOffer(offerId: 'b', take: true);

        verify(() => rondasApi.answerBenchOffer(offerId: 'b', take: true))
            .called(1);
      });

      test('says when the offer is over', () {
        when(
          () => rondasApi.answerBenchOffer(offerId: 'b', take: false),
        ).thenThrow(
          FirebaseException(plugin: 'functions', code: 'failed-precondition'),
        );

        expect(
          subject.answerBenchOffer(offerId: 'b', take: false),
          _failsWith(RsvpFailureReason.passed),
        );
      });
    });

    group('watchWaiting', () {
      test('reads the list with its counts and dates', () {
        when(() => rondasApi.watchWaiting('demo-201'))
            .thenAnswer((_) => Stream.value(_waiting()));

        expect(
          subject.watchWaiting('demo-201'),
          emits(
            Waiting(
              pretextId: 'mate',
              barrioId: 'el-pinar-sur',
              slotDayId: 'sat',
              slotBandId: 'afternoon',
              count: 5,
              threshold: 6,
              deadline: DateTime(2026, 11),
              start: DateTime(2026, 11, 7),
              status: WaitingStatus.open,
            ),
          ),
        );
      });

      test('reads a round that didnt fill with its nearby ronda', () async {
        when(() => rondasApi.watchWaiting('demo-201')).thenAnswer(
          (_) => Stream.value(
            _waiting(
              status: 'didntFill',
              alternatives: const [_nearby],
              choice: 'wait',
            ),
          ),
        );

        final waiting = (await subject.watchWaiting('demo-201').first)!;

        expect(waiting.status, WaitingStatus.didntFill);
        expect(waiting.nearby?.rondaId, 'r2');
        expect(waiting.nearby?.next, DateTime(2026, 11, 5));
        expect(waiting.choice, WaitlistChoice.wait);
        expect(waiting.missing, 1);
        expect(waiting.props.length, 11);
      });

      test('reads an unknown status as open and nothing missing past full', () {
        final full = Waiting(
          pretextId: 'mate',
          barrioId: 'b',
          slotDayId: 'sat',
          slotBandId: 'afternoon',
          count: 7,
          threshold: 6,
          deadline: _never,
          start: _never,
          status: WaitingStatus.full,
        );
        expect(full.missing, 0);
        when(() => rondasApi.watchWaiting('demo-201')).thenAnswer(
          (_) => Stream.value(
            _waiting(
              status: 'later',
              alternatives: const [
                NearbyRondaDocument(
                  rondaId: 'r2',
                  pretext: 'truco',
                  barrio: 'b',
                  slotDay: 'thu',
                  slotBand: 'evening',
                  placesLeft: 1,
                  next: 'soon',
                ),
              ],
            ),
          ),
        );

        expect(
          subject.watchWaiting('demo-201'),
          emits(
            isA<Waiting>()
                .having((w) => w.status, 'status', WaitingStatus.open)
                .having((w) => w.nearby, 'nearby', isNull),
          ),
        );
      });

      test('emits null while they wait on no list or the dates are bad', () {
        when(() => rondasApi.watchWaiting('demo-201')).thenAnswer(
          (_) => Stream.fromIterable([null, _waiting(deadline: 'someday')]),
        );

        expect(subject.watchWaiting('demo-201'), emitsInOrder([null, null]));
      });

      test('errors with an RsvpFailure when the read fails', () {
        when(() => rondasApi.watchWaiting('demo-201'))
            .thenAnswer((_) => Stream.error(const FormatException('shape')));

        expect(
          subject.watchWaiting('demo-201'),
          emitsError(isA<RsvpFailure>()),
        );
      });
    });

    group('chooseAfterWaitlist', () {
      test('records the pick through answer_waitlist', () async {
        when(() => rondasApi.answerWaitlist('join')).thenAnswer((_) async {});

        await subject.chooseAfterWaitlist(WaitlistChoice.join);

        verify(() => rondasApi.answerWaitlist('join')).called(1);
      });

      test('says when there is nothing to choose any more', () {
        when(() => rondasApi.answerWaitlist('wait')).thenThrow(
          FirebaseException(plugin: 'functions', code: 'failed-precondition'),
        );

        expect(
          subject.chooseAfterWaitlist(WaitlistChoice.wait),
          _failsWith(RsvpFailureReason.passed),
        );
      });
    });
  });
}

final _never = DateTime(2026);
