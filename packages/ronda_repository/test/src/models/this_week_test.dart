import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_repository/ronda_repository.dart';

void main() {
  group(ThisWeek, () {
    ThisWeek week({
      bool keepsNewcomerSeat = true,
      Host? anfitrion,
      Host? cola,
    }) => ThisWeek(
      rondaId: 'r1',
      pretextId: 'mate',
      barrioId: 'el-pinar-sur',
      slotDayId: 'thu',
      slotBandId: 'afternoon',
      myBrings: const [],
      anfitrion: anfitrion,
      cola: cola,
      keepsNewcomerSeat: keepsNewcomerSeat,
    );

    const jorge = Host(uid: 'demo-102', firstName: 'Jorge');
    const ana = Host(uid: 'demo-103', firstName: 'Ana');

    group('makesMateFlyer', () {
      test('is true for the anfitrión and the cola', () {
        final hosted = week(anfitrion: jorge, cola: ana);

        expect(hosted.makesMateFlyer('demo-102'), isTrue);
        expect(hosted.makesMateFlyer('demo-103'), isTrue);
      });

      test('is true for the one host it has', () {
        expect(week(cola: ana).makesMateFlyer('demo-103'), isTrue);
        expect(week(anfitrion: jorge).makesMateFlyer('demo-103'), isFalse);
      });

      test('is false for a member who is not a host', () {
        expect(
          week(anfitrion: jorge, cola: ana).makesMateFlyer('demo-104'),
          isFalse,
        );
      });

      test('is true for any member while the ronda has no hosts', () {
        expect(week().makesMateFlyer('demo-104'), isTrue);
      });

      test('is false for everyone before the newcomer seat', () {
        final early = week(keepsNewcomerSeat: false, anfitrion: jorge);

        expect(early.makesMateFlyer('demo-102'), isFalse);
        expect(
          week(keepsNewcomerSeat: false).makesMateFlyer('demo-104'),
          isFalse,
        );
      });
    });
  });
}
