import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The catalog's id, the one the server names in its `createSurface`
/// (`functions/weekly_card.py`, `CATALOG_ID`). A card for any other catalog
/// is not drawn.
const rondaCardCatalogId = 'uy.ronda.card';

/// The component names the server writes (`weekly_card.COMPONENTS`).
abstract final class RondaCardComponents {
  /// The root: a column of the blocks, in reading order.
  static const card = 'RondaCard';

  /// "¿Venís?" with Voy and Esta no, drawn by the app from its own state.
  static const rsvp = 'Rsvp';

  /// The hourly forecast and the alternative plan.
  static const rain = 'RainNotice';

  /// Who opens this week.
  static const host = 'HostOfWeek';

  /// Someone new joins.
  static const newcomer = 'Newcomer';

  /// The después, never with an address.
  static const despues = 'DespuesSpot';

  /// A seat goes to the bench when someone says "esta no".
  static const bench = 'BenchNudge';
}

/// Ronda's own genui catalog for the weekly card: the blocks the organiser
/// may compose, each drawn with a `ronda_ui` widget, and nothing else (no
/// core catalog, no text field, no image, no link).
///
/// Every notice block takes a `title` and a `text`; the server has already
/// run both through the gates. The RSVP block has no data: [rsvp] builds it
/// from the app's own state, so a tap goes through the RSVP path and never
/// back to a model.
Catalog rondaCardCatalog({required WidgetBuilder rsvp}) => Catalog([
  CatalogItem(
    name: RondaCardComponents.card,
    dataSchema: S.object(
      description: 'The card: its blocks in reading order.',
      properties: {
        'children': S.list(items: S.string(description: 'A block id.')),
      },
      required: ['children'],
    ),
    widgetBuilder: (itemContext) {
      final children = switch (_data(itemContext)['children']) {
        final List<Object?> ids when ids.every((id) => id is String) => [
          for (final id in ids) id! as String,
        ],
        _ => throw const FormatException('RondaCard needs block ids'),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: itemContext.buildContext.appSpacing.md,
        children: [for (final id in children) itemContext.buildChild(id)],
      );
    },
  ),
  CatalogItem(
    name: RondaCardComponents.rsvp,
    dataSchema: S.object(description: '¿Venís?, drawn by the app.'),
    widgetBuilder: (itemContext) => rsvp(itemContext.buildContext),
  ),
  _notice(
    RondaCardComponents.rain,
    variant: NoteBannerVariant.warning,
    icon: Icons.umbrella,
  ),
  _notice(RondaCardComponents.host, icon: Icons.waving_hand),
  _notice(RondaCardComponents.newcomer, icon: Icons.person_add),
  _notice(RondaCardComponents.despues, icon: Icons.coffee),
  _notice(RondaCardComponents.bench, icon: Icons.event_seat),
], catalogId: rondaCardCatalogId);

/// A notice block: a title and a text on a [NoteBanner].
CatalogItem _notice(
  String name, {
  required IconData icon,
  NoteBannerVariant variant = NoteBannerVariant.info,
}) => CatalogItem(
  name: name,
  dataSchema: S.object(
    description: 'A notice: a short title and one or two sentences.',
    properties: {'title': S.string(), 'text': S.string()},
    required: ['title', 'text'],
  ),
  widgetBuilder: (itemContext) {
    if (_data(itemContext) case {
      'title': final String title,
      'text': final String text,
    }) {
      return NoteBanner(
        title: title,
        message: text,
        variant: variant,
        icon: icon,
      );
    }
    throw FormatException('$name needs a title and a text');
  },
);

Map<String, Object?> _data(CatalogItemContext itemContext) {
  if (itemContext.data case final Map<String, Object?> data) return data;
  throw const FormatException('a block is not an object');
}
