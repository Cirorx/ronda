import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda_ui/src/extensions/build_context_extensions.dart';
import 'package:ronda_ui/src/theme/app_radius.dart';

/// A point on a map, in degrees.
typedef MapCoordinate = ({double lat, double lng});

/// Where a map tile's image comes from, by zoom and tile column and row.
typedef MapTileImage = ImageProvider Function(int zoom, int x, int y);

/// {@template barrio_map}
/// A small map of one barrio from OpenStreetMap's tiles: a square of
/// [tilesAcross] × [tilesAcross] tiles at [zoom] around [centre], where a
/// tap drops the pin ([onTapped]) and pinching zooms in to place it well.
///
/// It needs no map package: the tiles are web Mercator, drawn as images
/// side by side, and a tap is turned back into degrees. [attribution] is
/// always drawn on the map (ODbL), and on phones every tile request names
/// Ronda in its user agent, as OSM's tile policy asks.
/// {@endtemplate}
class const BarrioMap({
  /// The middle of the map: the barrio's centroid.
  required final MapCoordinate centre,

  /// "© colaboradores de OpenStreetMap", drawn in a corner.
  required final String attribution,

  /// What a screen reader says the map is.
  required final String semanticLabel,

  /// The tile zoom level.
  final int zoom = 16,

  /// How many tiles the square is across.
  final int tilesAcross = 4,

  /// The pin, if one is dropped.
  final MapCoordinate? pin,

  /// Called with where a tap landed; without it the map only shows.
  final ValueChanged<MapCoordinate>? onTapped,

  /// The tiles' images; OpenStreetMap's by default.
  final MapTileImage tileImage = osmTile,
  super.key,
}) extends StatelessWidget {
  /// {@macro barrio_map}
  this;

  /// The side of one tile, in its own pixels.
  static const double tileSize = 256;

  /// Who the tile requests say they come from (OSM's tile usage policy).
  static const userAgent = 'Ronda/1.0 (+https://github.com/Cirorx/ronda)';

  /// The tile at [zoom], [x], [y] from tile.openstreetmap.org.
  static ImageProvider osmTile(int zoom, int x, int y) => NetworkImage(
    'https://tile.openstreetmap.org/$zoom/$x/$y.png',
    // Browsers send their own user agent and refuse to have it set.
    headers: kIsWeb ? null : const {'User-Agent': userAgent},
  );

  /// [point] in tile units at [zoom] (web Mercator).
  static Offset toTiles(MapCoordinate point, int zoom) {
    final scale = math.pow(2, zoom).toDouble();
    final lat = point.lat * math.pi / 180;
    final x = (point.lng + 180) / 360 * scale;
    final y =
        (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * scale;
    return Offset(x, y);
  }

  /// The point at [tiles] (tile units at [zoom]), in degrees.
  static MapCoordinate fromTiles(Offset tiles, int zoom) {
    final scale = math.pow(2, zoom).toDouble();
    final n = math.pi - 2 * math.pi * tiles.dy / scale;
    final lat = 180 / math.pi * math.atan((math.exp(n) - math.exp(-n)) / 2);
    return (lat: lat, lng: tiles.dx / scale * 360 - 180);
  }

  /// The first tile column and row of the square: [centre] sits in its
  /// middle tile area.
  ({int x, int y}) get _origin {
    final middle = toTiles(centre, zoom);
    return (
      x: (middle.dx - tilesAcross / 2).round(),
      y: (middle.dy - tilesAcross / 2).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final origin = _origin;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          final tile = side / tilesAcross;
          Offset local(MapCoordinate point) {
            final at = toTiles(point, zoom);
            return Offset((at.dx - origin.x) * tile, (at.dy - origin.y) * tile);
          }

          final pinAt = switch (pin) {
            final pin? => local(pin),
            null => null,
          };
          return Semantics(
            container: true,
            image: true,
            label: semanticLabel,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                children: [
                  InteractiveViewer(
                    maxScale: 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: onTapped == null
                          ? null
                          : (details) => onTapped!(
                              fromTiles(
                                Offset(
                                  origin.x + details.localPosition.dx / tile,
                                  origin.y + details.localPosition.dy / tile,
                                ),
                                zoom,
                              ),
                            ),
                      child: SizedBox.square(
                        dimension: side,
                        child: Stack(
                          children: [
                            for (var row = 0; row < tilesAcross; row++)
                              for (
                                var column = 0;
                                column < tilesAcross;
                                column++
                              )
                                Positioned(
                                  left: column * tile,
                                  top: row * tile,
                                  width: tile,
                                  height: tile,
                                  child: Image(
                                    image: tileImage(
                                      zoom,
                                      origin.x + column,
                                      origin.y + row,
                                    ),
                                    fit: BoxFit.fill,
                                    excludeFromSemantics: true,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, _, _) => ColoredBox(
                                      color: scheme.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                            if (pinAt != null)
                              Positioned(
                                left: pinAt.dx - 20,
                                top: pinAt.dy - 40,
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.place,
                                  size: 40,
                                  color: scheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: scheme.surface.withValues(alpha: 0.85),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.appSpacing.xs,
                          vertical: context.appSpacing.xxs,
                        ),
                        child: Text(
                          attribution,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
