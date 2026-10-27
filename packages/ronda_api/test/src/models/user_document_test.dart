import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  final acceptedAt = DateTime(2026, 10, 27, 18, 30);

  group(TermsRecord, () {
    group('fromJson', () {
      test('reads the version and the acceptance time', () {
        expect(
          TermsRecord.fromJson({
            'version': '2026-10-27',
            'acceptedAt': Timestamp.fromDate(acceptedAt),
          }),
          equals(TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt)),
        );
      });

      test('returns null for anything else', () {
        expect(TermsRecord.fromJson(null), isNull);
        expect(TermsRecord.fromJson({'version': '2026-10-27'}), isNull);
        expect(
          TermsRecord.fromJson({'version': 1, 'acceptedAt': Timestamp.now()}),
          isNull,
        );
      });
    });

    test('toJson stores acceptedAt as a $Timestamp', () {
      expect(
        TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt).toJson(),
        equals({
          'version': '2026-10-27',
          'acceptedAt': Timestamp.fromDate(acceptedAt),
        }),
      );
    });
  });

  group(UserDocument, () {
    group('fromJson', () {
      test('reads a document holding only the terms', () {
        expect(
          UserDocument.fromJson({
            'terms': {
              'version': '2026-10-27',
              'acceptedAt': Timestamp.fromDate(acceptedAt),
            },
          }),
          equals(
            UserDocument(
              terms: TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
            ),
          ),
        );
      });

      test('skips fields of the wrong type', () {
        expect(
          UserDocument.fromJson(const {
            'firstName': 7,
            'ageBand': true,
            'barrio': ['solymar-norte'],
            'slots': 'thu-afternoon',
            'pretexts': ['mate', 3],
            'brings': null,
            'createdAt': '2026-10-27',
          }),
          equals(const UserDocument(pretexts: ['mate'])),
        );
      });
    });
  });
}
