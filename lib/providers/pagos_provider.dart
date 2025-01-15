import 'package:flutter/material.dart';
import 'package:money_facil/models/pago_seleccionado.dart';

class PagosProvider with ChangeNotifier {
  List<PagoSeleccionado> _pagosSeleccionados = [];

  List<PagoSeleccionado> get pagosSeleccionados => _pagosSeleccionados;

  // Método para agregar un nuevo pago
  void agregarPago(PagoSeleccionado nuevoPago) {
    _pagosSeleccionados.add(nuevoPago);
    notifyListeners(); // Asegúrate de notificar a los listeners para actualizar el UI
  }
  void eliminarPago(PagoSeleccionado pago) {
    _pagosSeleccionados.removeWhere((p) => p.semana == pago.semana);
    notifyListeners();
  }

  void limpiarPagos() {
    _pagosSeleccionados.clear();
    notifyListeners();
  }

  // Método para agregar un abono a un pago seleccionado
  void agregarAbono(int semana, Map<String, dynamic> abono) {
    var pago = _pagosSeleccionados.firstWhere(
      (p) => p.semana == semana,
      orElse: () => throw Exception('Pago no encontrado'),
    );
    pago.abonos.add(abono);
    notifyListeners();
  }


  // Puedes agregar más funciones según lo necesites
}

