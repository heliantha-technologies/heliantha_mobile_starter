import 'package:intl/intl.dart';

String formatMoney(
  double value, {
  required String currency,
  String? symbol,
  int decimalDigits = 2,
  bool includeCurrency = true,
}) {
  final displayCurrency =
      (symbol?.trim().isNotEmpty == true) ? symbol!.trim() : currency.trim();
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: includeCurrency ? displayCurrency : '',
    decimalDigits: decimalDigits,
  ).format(value);
}
