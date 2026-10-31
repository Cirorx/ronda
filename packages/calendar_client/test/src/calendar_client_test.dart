import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:calendar_client/calendar_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CalendarClient, () {
    final event = CalendarEvent(
      title: 'Caminar 30 minutos por la rambla',
      start: DateTime(2026, 11, 3, 19),
      end: DateTime(2026, 11, 3, 20),
      location: 'la parada 23',
    );
    late List<Event> added;
    late List<({String fileName, String contents, String mimeType})> saved;

    CalendarClient build({
      bool web = false,
      Future<bool> Function(Event)? addEvent,
      Future<void> Function({
        required String fileName,
        required String contents,
        required String mimeType,
      })?
      download,
    }) => CalendarClient(
      addEvent:
          addEvent ??
          (event) async {
            added.add(event);
            return true;
          },
      download:
          download ??
          ({required fileName, required contents, required mimeType}) async {
            saved.add((
              fileName: fileName,
              contents: contents,
              mimeType: mimeType,
            ));
          },
      now: () => DateTime.utc(2026, 11, 1, 15),
      newUid: () => 'uid-1@ronda.uy',
      isWeb: web,
    );

    setUp(() {
      added = [];
      saved = [];
    });

    group('on a phone', () {
      test('opens the calendar with the event and an alert an hour '
          'before', () async {
        final outcome = await build().add(event);

        expect(outcome, equals(CalendarOutcome.opened));
        final opened = added.single;
        expect(opened.title, equals(event.title));
        expect(opened.location, equals('la parada 23'));
        expect(opened.startDate, equals(event.start));
        expect(opened.endDate, equals(event.end));
        expect(opened.iosParams.reminder, equals(CalendarClient.reminder));
        expect(saved, isEmpty);
      });

      test('throws when the calendar did not open', () {
        expect(
          build(addEvent: (_) async => false).add(event),
          throwsA(isA<CalendarUnavailableException>()),
        );
      });

      test('throws the same when the plugin fails', () {
        expect(
          build(addEvent: (_) async => throw StateError('no calendar'))
              .add(event),
          throwsA(isA<CalendarUnavailableException>()),
        );
      });
    });

    group('on the web', () {
      test('downloads the event as an .ics file', () async {
        final outcome = await build(web: true).add(event);

        expect(outcome, equals(CalendarOutcome.downloaded));
        final file = saved.single;
        expect(file.fileName, equals(CalendarClient.fileName));
        expect(file.mimeType, equals('text/calendar'));
        expect(file.contents, contains('UID:uid-1@ronda.uy'));
        expect(file.contents, contains('DTSTART:20261103T190000'));
        expect(added, isEmpty);
      });

      test('throws when the download fails', () {
        expect(
          build(
            web: true,
            download: ({
              required fileName,
              required contents,
              required mimeType,
            }) => throw StateError('blocked'),
          ).add(event),
          throwsA(isA<CalendarUnavailableException>()),
        );
      });
    });

    test(
      'gives each file its own random id and the real clock by default',
      () async {
        final files = <String>[];
        final client = CalendarClient(
          download:
              ({
                required fileName,
                required contents,
                required mimeType,
              }) async {
                files.add(contents);
              },
          isWeb: true,
        );

        await client.add(event);
        await client.add(event);

        final ids = [
          for (final file in files)
            RegExp(r'UID:([0-9a-f]{24}@ronda\.uy)').firstMatch(file)!.group(1),
        ];
        expect(ids, hasLength(2));
        expect(ids.first, isNot(equals(ids.last)));
      },
    );

    test('a browser-only download is unavailable off the web', () {
      expect(
        CalendarClient(isWeb: true).add(event),
        throwsA(isA<CalendarUnavailableException>()),
      );
    });

    test('events with the same words and times are equal', () {
      expect(
        CalendarEvent(title: 'a', start: event.start, end: event.end),
        equals(CalendarEvent(title: 'a', start: event.start, end: event.end)),
      );
    });

    test('its failure has a name', () {
      expect(
        const CalendarUnavailableException().toString(),
        equals('CalendarUnavailableException'),
      );
    });
  });
}
