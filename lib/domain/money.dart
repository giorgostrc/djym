import 'package:intl/intl.dart';
import 'package:loggym/domain/unit_system.dart';

String formatMoney(int cents, String currencyCode) =>
    NumberFormat.simpleCurrency(name: currencyCode).format(cents / 100);

int? parseMoney(String text) {
  final amount = parseDecimal(text);
  return amount == null ? null : (amount * 100).round();
}
