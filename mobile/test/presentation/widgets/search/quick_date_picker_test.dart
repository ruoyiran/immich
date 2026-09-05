import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/presentation/widgets/search/quick_date_picker.dart';

void main() {
  test('calendar period filters produce half-open day, week, month, and year ranges', () {
    final anchor = DateTime(2024, 5, 15, 18, 30);

    expect(
      CalendarPeriodDateFilter(anchor, CalendarPeriod.day).asDateTimeRange(),
      DateTimeRange(start: DateTime(2024, 5, 15), end: DateTime(2024, 5, 16)),
    );
    expect(
      CalendarPeriodDateFilter(anchor, CalendarPeriod.week).asDateTimeRange(),
      DateTimeRange(start: DateTime(2024, 5, 13), end: DateTime(2024, 5, 20)),
    );
    expect(
      CalendarPeriodDateFilter(anchor, CalendarPeriod.month).asDateTimeRange(),
      DateTimeRange(start: DateTime(2024, 5), end: DateTime(2024, 6)),
    );
    expect(YearFilter(2024).asDateTimeRange(), DateTimeRange(start: DateTime(2024), end: DateTime(2025)));
  });

  test('custom picker includes the complete final calendar day', () {
    final range = CustomDateFilter(DateTime(2024, 5, 10), DateTime(2024, 5, 12)).asDateTimeRange();
    expect(range.start, DateTime(2024, 5, 10));
    expect(range.end, DateTime(2024, 5, 13));
  });
}
