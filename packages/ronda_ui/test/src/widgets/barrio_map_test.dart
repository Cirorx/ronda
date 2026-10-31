import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

/// A 1×1 transparent PNG: tiles that need no network.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const MapCoordinate _centre = (lat: -34.8, lng: -55.885);

void main() {
  group(BarrioMap, () {
    final asked = <(int, int, int)>[];

    ImageProvider tile(int zoom, int x, int y) {
      asked.add((zoom, x, y));
      return MemoryImage(_pixel);
    }

    setUp(asked.clear);

    test('turns degrees into tiles and back', () {
      final tiles = BarrioMap.toTiles(_centre, 16);
      final back = BarrioMap.fromTiles(tiles, 16);

      expect(tiles.dx, closeTo(22594.45, 0.01));
      expect(back.lat, closeTo(_centre.lat, 1e-9));
      expect(back.lng, closeTo(_centre.lng, 1e-9));
    });

    test("asks OpenStreetMap's tiles, naming Ronda", () {
      final image = BarrioMap.osmTile(16, 1, 2) as NetworkImage;

      expect(image.url, 'https://tile.openstreetmap.org/16/1/2.png');
      expect(image.headers, {'User-Agent': BarrioMap.userAgent});
    });

    testWidgets('draws a square of tiles around the centre, with the '
        'attribution', (tester) async {
      await tester.pumpApp(
        BarrioMap(
          centre: _centre,
          attribution: '© colaboradores de OpenStreetMap',
          semanticLabel: 'Mapa del barrio',
          tileImage: tile,
        ),
      );

      expect(asked, hasLength(16));
      final middle = BarrioMap.toTiles(_centre, 16);
      expect(asked.first, (
        16,
        (middle.dx - 2).round(),
        (middle.dy - 2).round(),
      ));
      expect(find.text('© colaboradores de OpenStreetMap'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Mapa del barrio')), findsOneWidget);
      expect(find.byIcon(Icons.place), findsNothing);
    });

    testWidgets('a tap drops the pin where it landed', (tester) async {
      MapCoordinate? tapped;
      await tester.pumpApp(
        BarrioMap(
          centre: _centre,
          attribution: 'OSM',
          semanticLabel: 'Mapa',
          tileImage: tile,
          onTapped: (point) => tapped = point,
        ),
      );

      final map = tester.getRect(find.byType(InteractiveViewer));
      final middle = BarrioMap.toTiles(_centre, 16);
      final origin = Offset(
        (middle.dx - 2).roundToDouble(),
        (middle.dy - 2).roundToDouble(),
      );
      final spot = map.topLeft + (middle - origin) * (map.width / 4);
      await tester.tapAt(spot);

      expect(tapped!.lat, closeTo(_centre.lat, 1e-4));
      expect(tapped!.lng, closeTo(_centre.lng, 1e-4));
    });

    testWidgets('shows a pin, and does nothing on a tap without a '
        'callback', (tester) async {
      await tester.pumpApp(
        BarrioMap(
          centre: _centre,
          attribution: 'OSM',
          semanticLabel: 'Mapa',
          tileImage: tile,
          pin: _centre,
        ),
      );
      await tester.tap(find.byType(InteractiveViewer), warnIfMissed: false);

      expect(find.byIcon(Icons.place), findsOneWidget);
    });

    testWidgets('leaves a plain square where a tile fails', (tester) async {
      await tester.pumpApp(
        BarrioMap(
          centre: _centre,
          attribution: 'OSM',
          semanticLabel: 'Mapa',
          tileImage: (_, _, _) => MemoryImage(Uint8List.fromList([1, 2, 3])),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(find.byType(ColoredBox), findsWidgets);
      expect(kIsWeb, isFalse);
    });
  });
}
