import 'package:intl/intl.dart';

String formatMonto(String value) {
  if (value.isEmpty) return '';
  final formatter = NumberFormat('#,###', 'en_US');
  String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
  try {
    double number = double.parse(cleaned);
    return formatter.format(number);
  } catch (e) {
    return '';
  }
}
