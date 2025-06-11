// 1. Nueva clase para el objeto "Moratorios" del JSON
import 'package:finora/models/parseHelper.dart';

class Moratorios {
  // <--- NUEVO
  final double moratoriosAPagar; // Los generados

  Moratorios({required this.moratoriosAPagar});

  factory Moratorios.fromJson(Map<String, dynamic> json) {
    return Moratorios(
      moratoriosAPagar: ParseHelpers.parseDouble(json['moratoriosAPagar']),
    );
  }
}