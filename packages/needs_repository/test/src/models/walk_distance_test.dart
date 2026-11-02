import 'package:flutter_test/flutter_test.dart';
import 'package:needs_repository/needs_repository.dart';

void main() {
  group(WalkDistance, () {
    group('fromBlocks', () {
      test('is ${WalkDistance.near} up to 5 blocks', () {
        expect(WalkDistance.fromBlocks(0), equals(WalkDistance.near));
        expect(WalkDistance.fromBlocks(5), equals(WalkDistance.near));
      });

      test('is ${WalkDistance.medium} past 5 and up to 10 blocks', () {
        expect(WalkDistance.fromBlocks(5.1), equals(WalkDistance.medium));
        expect(WalkDistance.fromBlocks(10), equals(WalkDistance.medium));
      });

      test('is ${WalkDistance.far} past 10 blocks', () {
        expect(WalkDistance.fromBlocks(10.1), equals(WalkDistance.far));
        expect(WalkDistance.fromBlocks(122.9), equals(WalkDistance.far));
      });
    });

    group('fromBlocks with a farther walk', () {
      test('scales the bands to 15 blocks', () {
        expect(
          WalkDistance.fromBlocks(7.5, maxBlocks: 15),
          equals(WalkDistance.near),
        );
        expect(
          WalkDistance.fromBlocks(13, maxBlocks: 15),
          equals(WalkDistance.medium),
        );
        expect(
          WalkDistance.fromBlocks(15.1, maxBlocks: 15),
          equals(WalkDistance.far),
        );
      });
    });

    group('nearest', () {
      test('is the shortest walk, or far with none', () {
        expect(
          WalkDistance.nearest(const [WalkDistance.far, WalkDistance.near]),
          WalkDistance.near,
        );
        expect(
          WalkDistance.nearest(const [WalkDistance.medium, WalkDistance.far]),
          WalkDistance.medium,
        );
        expect(WalkDistance.nearest(const []), WalkDistance.far);
      });
    });

    group('forMember', () {
      const blocksFrom = {'solymar-sur': 9.1, 'solymar-norte': 0};

      test("reads the walk from the member's barrio", () {
        expect(
          WalkDistance.forMember(
            memberBarrio: 'solymar-sur',
            blocksFrom: blocksFrom,
          ),
          equals(WalkDistance.medium),
        );
        expect(
          WalkDistance.forMember(
            memberBarrio: 'solymar-norte',
            blocksFrom: blocksFrom,
          ),
          equals(WalkDistance.near),
        );
      });

      test('bands the walk by the farthest one given', () {
        expect(
          WalkDistance.forMember(
            memberBarrio: 'palermo',
            blocksFrom: const {'palermo': 13},
            maxBlocks: 15,
          ),
          equals(WalkDistance.medium),
        );
      });

      test(
        'is ${WalkDistance.far} when the table does not list the barrio',
        () {
          expect(
            WalkDistance.forMember(
              memberBarrio: 'el-pinar-sur',
              blocksFrom: blocksFrom,
            ),
            equals(WalkDistance.far),
          );
        },
      );
    });
  });
}
