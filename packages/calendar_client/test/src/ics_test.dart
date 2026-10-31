import 'package:calendar_client/calendar_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(buildIcs, () {
    final event = CalendarEvent(
      title: 'Caminar 30 minutos por la rambla',
      start: DateTime(2026, 11, 3, 19),
      end: DateTime(2026, 11, 3, 20),
      location: 'la parada 23',
    );
    final stamp = DateTime.utc(2026, 11, 1, 15, 30, 5);

    test('writes one event with floating times, a stamp in UTC and a '
        'place', () {
      expect(
        buildIcs(event, stamp: stamp, uid: 'abc@ronda.uy'),
        equals(
          [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'PRODID:-//Ronda//Algo chico//ES',
            'CALSCALE:GREGORIAN',
            'BEGIN:VEVENT',
            'UID:abc@ronda.uy',
            'DTSTAMP:20261101T153005Z',
            'DTSTART:20261103T190000',
            'DTEND:20261103T200000',
            'SUMMARY:Caminar 30 minutos por la rambla',
            'LOCATION:la parada 23',
            'END:VEVENT',
            'END:VCALENDAR',
            '',
          ].join('\r\n'),
        ),
      );
    });

    test('leaves the location out when there is none or it is empty', () {
      for (final location in <String?>[null, '']) {
        final ics = buildIcs(
          CalendarEvent(
            title: event.title,
            start: event.start,
            end: event.end,
            location: location,
          ),
          stamp: stamp,
          uid: 'abc',
        );

        expect(ics, isNot(contains('LOCATION')));
      }
    });

    test('escapes backslashes, semicolons, commas and new lines', () {
      final ics = buildIcs(
        CalendarEvent(
          title:
              r'Plaza; rambla, y\o'
              '\nluego',
          start: event.start,
          end: event.end,
        ),
        stamp: stamp,
        uid: 'abc',
      );

      expect(ics, contains(r'SUMMARY:Plaza\; rambla\, y\\o\nluego'));
    });

    test('turns a Windows new line into one escaped new line', () {
      final ics = buildIcs(
        CalendarEvent(title: 'uno\r\ndos', start: event.start, end: event.end),
        stamp: stamp,
        uid: 'abc',
      );

      expect(ics, contains(r'SUMMARY:uno\ndos'));
    });

    test('folds a line longer than 75 characters, each fold starting '
        'with a space', () {
      final ics = buildIcs(
        CalendarEvent(title: 'a' * 200, start: event.start, end: event.end),
        stamp: stamp,
        uid: 'abc',
      );

      final lines = ics.split('\r\n');
      final summary = lines.indexWhere((line) => line.startsWith('SUMMARY:'));
      final folded = [
        lines[summary],
        for (var i = summary + 1; lines[i].startsWith(' '); i++) lines[i],
      ];
      expect(folded.every((line) => line.length <= 75), isTrue);
      expect(
        folded.map((line) => line.replaceFirst(RegExp('^ '), '')).join(),
        equals('SUMMARY:${'a' * 200}'),
      );
      expect(folded, hasLength(greaterThan(2)));
    });
  });
}
