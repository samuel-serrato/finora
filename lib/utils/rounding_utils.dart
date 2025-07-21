// lib/utils/rounding_utils.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Asegúrate de importar tu UserDataProvider aquí.
// La ruta puede variar según la estructura de tu proyecto.
import '../providers/user_data_provider.dart'; 

/// Aplica un redondeo personalizado a un valor numérico basado en un umbral.
///
/// Si el valor es un [double], se redondea hacia arriba (ceil) si su parte decimal
/// es mayor o igual al umbral definido en [UserDataProvider], de lo contrario
/// se redondea hacia abajo (floor).
///
/// También puede manejar recursivamente listas y mapas.
///
/// - [valor]: El valor a redondear (puede ser int, double, List, Map).
/// - [context]: El BuildContext para acceder al UserDataProvider.
/// - Retorna el valor redondeado como `dynamic`.
dynamic redondearDecimales(dynamic valor, BuildContext context) {
  // Obtenemos el umbral de redondeo del provider. listen: false es crucial aquí.
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  final double umbralRedondeo = userData.redondeo;

  if (valor is double) {
    // Manejar casos de "casi" enteros para evitar errores de punto flotante
    if ((valor - valor.truncateToDouble()).abs() < 0.000001) {
      return valor.truncateToDouble();
    } else {
      double parteDecimal = valor - valor.truncateToDouble();

      // Aplicar la lógica de redondeo según el umbral
      if (parteDecimal >= umbralRedondeo) {
        return valor.ceilToDouble();
      } else {
        return valor.floorToDouble();
      }
    }
  } else if (valor is int) {
    // Convertir enteros a double para consistencia
    return valor.toDouble();
  } else if (valor is List) {
    // Aplicar la función recursivamente a cada elemento de la lista
    return valor.map((e) => redondearDecimales(e, context)).toList();
  } else if (valor is Map) {
    // Aplicar la función recursivamente a cada valor del mapa
    return valor.map<String, dynamic>(
      (key, value) => MapEntry(key, redondearDecimales(value, context)),
    );
  }
  
  // Si no es un tipo manejable, devolver el valor original
  return valor;
}