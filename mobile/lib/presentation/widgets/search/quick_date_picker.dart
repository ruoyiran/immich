import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';

sealed class DateFilterInputModel {
  DateTimeRange<DateTime> asDateTimeRange();

  String asHumanReadable(BuildContext context) {
    final date = asDateTimeRange();
    final inclusiveEnd = date.end.subtract(const Duration(microseconds: 1));
    if (date.start.year == inclusiveEnd.year &&
        date.start.month == inclusiveEnd.month &&
        date.start.day == inclusiveEnd.day) {
      return DateFormat.yMMMd().format(date.start.toLocal());
    } else {
      return 'search_filter_date_interval'.t(
        context: context,
        args: {
          "start": DateFormat.yMMMd().format(date.start.toLocal()),
          "end": DateFormat.yMMMd().format(inclusiveEnd.toLocal()),
        },
      );
    }
  }
}

enum CalendarPeriod { day, week, month }

class CalendarPeriodDateFilter extends DateFilterInputModel {
  final DateTime anchor;
  final CalendarPeriod period;

  CalendarPeriodDateFilter(this.anchor, this.period);

  @override
  DateTimeRange<DateTime> asDateTimeRange() {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    return switch (period) {
      CalendarPeriod.day => DateTimeRange(start: day, end: day.add(const Duration(days: 1))),
      CalendarPeriod.week => () {
        final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
        return DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
      }(),
      CalendarPeriod.month => DateTimeRange(
        start: DateTime(day.year, day.month),
        end: DateTime(day.year, day.month + 1),
      ),
    };
  }
}

class RecentMonthRangeFilter extends DateFilterInputModel {
  final int monthDelta;
  RecentMonthRangeFilter(this.monthDelta);

  @override
  DateTimeRange<DateTime> asDateTimeRange() {
    final now = DateTime.now();
    // Note that DateTime's constructor properly handles month overflow.
    final from = DateTime(now.year, now.month - monthDelta, 1);
    return DateTimeRange<DateTime>(start: from, end: now);
  }

  @override
  String asHumanReadable(BuildContext context) {
    return 'last_months'.t(context: context, args: {"count": monthDelta.toString()});
  }
}

class YearFilter extends DateFilterInputModel {
  final int year;
  YearFilter(this.year);

  @override
  DateTimeRange<DateTime> asDateTimeRange() {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year + 1, 1, 1);
    return DateTimeRange<DateTime>(start: from, end: to);
  }

  @override
  String asHumanReadable(BuildContext context) {
    return 'in_year'.tr(namedArgs: {"year": year.toString()});
  }
}

class CustomDateFilter extends DateFilterInputModel {
  final DateTime start;
  final DateTime end;

  CustomDateFilter(this.start, this.end);

  factory CustomDateFilter.fromRange(DateTimeRange<DateTime> range) {
    return CustomDateFilter(range.start, range.end);
  }

  @override
  DateTimeRange<DateTime> asDateTimeRange() {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day + 1);
    return DateTimeRange<DateTime>(start: normalizedStart, end: normalizedEnd);
  }
}

enum _QuickPickerType { day, week, month, last1Month, last3Months, last9Months, year, custom }

class QuickDatePicker extends HookWidget {
  QuickDatePicker({
    super.key,
    required this.currentInput,
    required this.onSelect,
    required this.onRequestPicker,
    required this.onRequestPeriodPicker,
  }) : _selection = _selectionFromModel(currentInput),
       _initialYear = _initialYearFromModel(currentInput);

  final Function() onRequestPicker;
  final Function(CalendarPeriod period) onRequestPeriodPicker;
  final Function(DateFilterInputModel range) onSelect;

  final DateFilterInputModel? currentInput;
  final _QuickPickerType? _selection;
  final int _initialYear;

  // Generate a list of recent years from 2000 to the current year (including the current one)
  final List<int> _recentYears = List.generate(1 + DateTime.now().year - 2000, (index) {
    return index + 2000;
  });

  static int _initialYearFromModel(DateFilterInputModel? model) {
    return model?.asDateTimeRange().start.year ?? DateTime.now().year;
  }

  static _QuickPickerType? _selectionFromModel(DateFilterInputModel? model) {
    if (model is RecentMonthRangeFilter) {
      return switch (model.monthDelta) {
        1 => _QuickPickerType.last1Month,
        3 => _QuickPickerType.last3Months,
        9 => _QuickPickerType.last9Months,
        _ => _QuickPickerType.custom,
      };
    } else if (model is CalendarPeriodDateFilter) {
      return switch (model.period) {
        CalendarPeriod.day => _QuickPickerType.day,
        CalendarPeriod.week => _QuickPickerType.week,
        CalendarPeriod.month => _QuickPickerType.month,
      };
    } else if (model is YearFilter) {
      return _QuickPickerType.year;
    } else if (model is CustomDateFilter) {
      return _QuickPickerType.custom;
    }
    return null;
  }

  Text _monthLabel(BuildContext context, int monthsFromNow) =>
      const Text('last_months').t(context: context, args: {"count": monthsFromNow.toString()});

  Widget _yearPicker(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Row(
      children: [
        const Text("in_year_selector").tr(),
        const SizedBox(width: 15),
        Expanded(
          child: DropdownMenu(
            initialSelection: _initialYear,
            menuStyle: MenuStyle(maximumSize: WidgetStateProperty.all(Size(size.width, size.height * 0.5))),
            dropdownMenuEntries: _recentYears.map((e) => DropdownMenuEntry(value: e, label: e.toString())).toList(),
            onSelected: (year) {
              if (year == null) {
                return;
              }
              onSelect(YearFilter(year));
            },
          ),
        ),
      ],
    );
  }

  // We want the exact date picker to always be selectable.
  // Even if it's already toggled it should always open the full date picker, RadioListTiles don't do that by default
  // so we wrap it in a InkWell
  Widget _exactPicker(BuildContext context) {
    final hasPreviousInput = currentInput != null && currentInput is CustomDateFilter;

    return InkWell(
      onTap: onRequestPicker,
      child: IgnorePointer(
        ignoring: true,
        child: RadioListTile(
          title: const Text('pick_custom_range').tr(),
          subtitle: hasPreviousInput ? Text(currentInput!.asHumanReadable(context)) : null,
          secondary: hasPreviousInput ? const Icon(Icons.edit) : null,
          value: _QuickPickerType.custom,
          toggleable: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Scrollbar(
        // Depending on the screen size the last option might get cut off
        // Add a clear visual cue that there are more options when scrolling
        // When the screen size is large enough the scrollbar is hidden automatically
        trackVisibility: true,
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: RadioGroup(
            onChanged: (value) {
              if (value == null) {
                return;
              }
              final _ = switch (value) {
                _QuickPickerType.custom => onRequestPicker(),
                _QuickPickerType.day => onRequestPeriodPicker(CalendarPeriod.day),
                _QuickPickerType.week => onRequestPeriodPicker(CalendarPeriod.week),
                _QuickPickerType.month => onRequestPeriodPicker(CalendarPeriod.month),
                _QuickPickerType.last1Month => onSelect(RecentMonthRangeFilter(1)),
                _QuickPickerType.last3Months => onSelect(RecentMonthRangeFilter(3)),
                _QuickPickerType.last9Months => onSelect(RecentMonthRangeFilter(9)),
                // When a year is selected the combobox triggers onSelect() on its own.
                // Here we handle the radio button being selected which can only ever be the initial year
                _QuickPickerType.year => onSelect(YearFilter(_initialYear)),
              };
            },
            groupValue: _selection,
            child: Column(
              children: [
                RadioListTile(title: const Text('day').tr(), value: _QuickPickerType.day, toggleable: true),
                RadioListTile(title: const Text('week').tr(), value: _QuickPickerType.week, toggleable: true),
                RadioListTile(title: const Text('month').tr(), value: _QuickPickerType.month, toggleable: true),
                RadioListTile(title: _monthLabel(context, 1), value: _QuickPickerType.last1Month, toggleable: true),
                RadioListTile(title: _monthLabel(context, 3), value: _QuickPickerType.last3Months, toggleable: true),
                RadioListTile(title: _monthLabel(context, 9), value: _QuickPickerType.last9Months, toggleable: true),
                RadioListTile(title: _yearPicker(context), value: _QuickPickerType.year, toggleable: true),
                _exactPicker(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
