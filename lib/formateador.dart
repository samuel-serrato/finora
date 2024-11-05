import 'package:intl/intl.dart';

String formatMonto(String value) {
  // Eliminamos todo lo que no sea número
  String sanitized = value.replaceAll(RegExp(r'[^\d]'), '');

  // Convertimos el texto a un número y lo formateamos
  if (sanitized.isNotEmpty) {
    final number = int.parse(sanitized);
    return NumberFormat('#,###').format(number);
  }
  return '';
}
