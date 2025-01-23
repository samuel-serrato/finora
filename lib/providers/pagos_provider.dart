import 'package:flutter/material.dart';
import 'package:money_facil/models/pago_seleccionado.dart';
import 'package:uuid/uuid.dart'; // Asegúrate de añadir esta dependencia si usas UUID


class PagosProvider with ChangeNotifier {
  List<PagoSeleccionado> _pagosSeleccionados = [];
  List<PagoSeleccionado> _pagosOriginales = [];  // Nueva lista para los pagos originales

  List<PagoSeleccionado> get pagosSeleccionados => _pagosSeleccionados;
    List<PagoSeleccionado> get pagosOriginales => _pagosOriginales;  // Getter público


  // Método para cargar los pagos
  void cargarPagos(List<PagoSeleccionado> pagos) {
    _pagosSeleccionados = pagos;
    _pagosOriginales = List.from(pagos);  // Guardamos los pagos originales al cargar
    notifyListeners();
  }

  // Método para obtener los pagos modificados
  List<Map<String, dynamic>> obtenerCamposModificados() {
    List<Map<String, dynamic>> pagosModificados = [];

    for (int i = 0; i < _pagosSeleccionados.length; i++) {
      PagoSeleccionado pagoOriginal = _pagosOriginales[i]; // Pago original
      PagoSeleccionado pagoActual = _pagosSeleccionados[i]; // Pago modificado

      Map<String, dynamic> camposModificados = {};

      // Compara los campos y agrega los modificados
      if (pagoActual.deposito != pagoOriginal.deposito) {
        camposModificados['deposito'] = pagoActual.deposito;
      }
      if (pagoActual.capitalMasInteres != pagoOriginal.capitalMasInteres) {
        camposModificados['capitalMasInteres'] = pagoActual.capitalMasInteres;
      }
      if (pagoActual.saldoFavor != pagoOriginal.saldoFavor) {
        camposModificados['saldoFavor'] = pagoActual.saldoFavor;
      }
      if (pagoActual.moratorio != pagoOriginal.moratorio) {
        camposModificados['moratorio'] = pagoActual.moratorio;
      }
      if (pagoActual.saldoEnContra != pagoOriginal.saldoEnContra) {
        camposModificados['saldoEnContra'] = pagoActual.saldoEnContra;
      }
      if (pagoActual.abonos != pagoOriginal.abonos) {
        camposModificados['abonos'] = pagoActual.abonos;
      }

      // Si hay cambios, agregamos al resultado
      if (camposModificados.isNotEmpty) {
        camposModificados['semana'] = pagoActual.semana;
        camposModificados['tipoPago'] = pagoActual.tipoPago;
        pagosModificados.add(camposModificados);
      }
    }

    return pagosModificados;
  }

  // Métodos de agregar y eliminar pagos
  void agregarPago(PagoSeleccionado nuevoPago) {
    _pagosSeleccionados.add(nuevoPago);
    notifyListeners();
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

    if (!abono.containsKey('id')) {
      var uuid = Uuid();
      abono['id'] = uuid.v4();
    }

    bool existe = pago.abonos.any((a) => a['id'] == abono['id']);
    if (!existe) {
      pago.abonos.add(abono);
      notifyListeners();
    }
  }

  @override
  String toString() {
    return 'PagosProvider(pagosSeleccionados: $_pagosSeleccionados)';
  }
}
