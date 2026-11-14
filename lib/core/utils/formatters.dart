import 'package:intl/intl.dart';

String formatMoney(num amount, {required String symbol, int decimals = 2}) {
  return NumberFormat.currency(
    locale: 'en',
    symbol: symbol,
    decimalDigits: decimals,
  ).format(amount);
}

String formatMoneyCompact(num amount, {required String symbol}) {
  final absolute = amount.abs();
  if (absolute >= 1000000) {
    return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) {
    return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
  }
  return '$symbol${amount.toStringAsFixed(0)}';
}

String formatNumber(num amount) => NumberFormat.decimalPattern('en').format(amount);

String formatPercent(double value) {
  final text = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
  return '$text%';
}

String formatDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

String formatDateTime(DateTime date) =>
    DateFormat('d MMM yyyy, HH:mm').format(date);

String formatShortDate(DateTime date) => DateFormat('d MMM').format(date);

String formatMonth(DateTime date) => DateFormat('MMMM yyyy').format(date);

String formatDayLabel(DateTime date) => DateFormat('EEE').format(date);

String saleNumberFor(DateTime date) {
  final day = DateFormat('yyMMdd').format(date);
  final suffix = (date.microsecondsSinceEpoch % 100000).toString().padLeft(
    5,
    '0',
  );
  return 'ES-$day-$suffix';
}

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

String initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'ES';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
