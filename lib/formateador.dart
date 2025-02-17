import 'package:intl/intl.dart';

String formatMonto(String value) {
  // Permitir solo números y un punto decimal
  String sanitized = value.replaceAll(RegExp(r'[^\d.]'), '');
  
  // Separar parte entera y decimal
  List<String> parts = sanitized.split('.');
  String integerPart = parts[0].replaceAll(RegExp(r'\D'), '');
  String decimalPart = parts.length > 1 ? parts[1] : '';

  // Formatear parte entera
  String formatted = NumberFormat('#,###').format(int.tryParse(integerPart) ?? 0);
  
  // Agregar parte decimal si existe
  if (decimalPart.isNotEmpty) {
    decimalPart = decimalPart.length > 2 ? decimalPart.substring(0, 2) : decimalPart;
    formatted += '.$decimalPart';
  }
  
  return formatted;
}