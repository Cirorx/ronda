// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// Hand-written in the generator's shape: widgetbook is not in the local pub
// cache yet. Regenerate with `dart run build_runner build
// --delete-conflicting-outputs` once `flutter pub get` has run here.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:widgetbook/widgetbook.dart' as _widgetbook;
import 'package:widgetbook_catalog/widgetbook/use_cases/chip_picker.dart'
    as _widgetbook_catalog_widgetbook_use_cases_chip_picker;
import 'package:widgetbook_catalog/widgetbook/use_cases/note_banner.dart'
    as _widgetbook_catalog_widgetbook_use_cases_note_banner;
import 'package:widgetbook_catalog/widgetbook/use_cases/person_row.dart'
    as _widgetbook_catalog_widgetbook_use_cases_person_row;
import 'package:widgetbook_catalog/widgetbook/use_cases/read_back_card.dart'
    as _widgetbook_catalog_widgetbook_use_cases_read_back_card;
import 'package:widgetbook_catalog/widgetbook/use_cases/rsvp_bar.dart'
    as _widgetbook_catalog_widgetbook_use_cases_rsvp_bar;
import 'package:widgetbook_catalog/widgetbook/use_cases/seat_row.dart'
    as _widgetbook_catalog_widgetbook_use_cases_seat_row;
import 'package:widgetbook_catalog/widgetbook/use_cases/slot_grid.dart'
    as _widgetbook_catalog_widgetbook_use_cases_slot_grid;
import 'package:widgetbook_catalog/widgetbook/use_cases/step_sheet.dart'
    as _widgetbook_catalog_widgetbook_use_cases_step_sheet;
import 'package:widgetbook_catalog/widgetbook/use_cases/terms_note.dart'
    as _widgetbook_catalog_widgetbook_use_cases_terms_note;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookFolder(
    name: 'widgets',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'ChipPicker',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'multi select',
            builder: _widgetbook_catalog_widgetbook_use_cases_chip_picker
                .multiSelect,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'single select',
            builder: _widgetbook_catalog_widgetbook_use_cases_chip_picker
                .singleSelect,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'NoteBanner',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'all variants',
            builder: _widgetbook_catalog_widgetbook_use_cases_note_banner
                .allVariants,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'PersonRow',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'quiénes van',
            builder:
                _widgetbook_catalog_widgetbook_use_cases_person_row.quienesVan,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'ReadBackCard',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'default',
            builder: _widgetbook_catalog_widgetbook_use_cases_read_back_card
                .readBackCard,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'RsvpBar',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'default',
            builder: _widgetbook_catalog_widgetbook_use_cases_rsvp_bar.rsvpBar,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'SeatRow',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'cerca tuyo',
            builder:
                _widgetbook_catalog_widgetbook_use_cases_seat_row.cercaTuyo,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'SlotGrid',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'default',
            builder:
                _widgetbook_catalog_widgetbook_use_cases_slot_grid.slotGrid,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'StepSheet',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'inline',
            builder: _widgetbook_catalog_widgetbook_use_cases_step_sheet.inline,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'modal',
            builder: _widgetbook_catalog_widgetbook_use_cases_step_sheet.modal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'TermsNote',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'default',
            builder:
                _widgetbook_catalog_widgetbook_use_cases_terms_note.termsNote,
          ),
        ],
      ),
    ],
  ),
];
