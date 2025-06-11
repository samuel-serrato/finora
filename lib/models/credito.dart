// Archivo: models/credito.dart

import 'cliente_monto.dart';
import 'fecha_pago.dart'; // NUEVO: Importa el nuevo modelo

class Credito {
  final String idcredito;
  final String idgrupos;
  final String nombreGrupo;
  final String detalles;
  final String asesor;
  final String diaPago;
  final int plazo;
  final String tipoPlazo;
  final String tipo;
  final double ti_mensual;
  final String ti_semanal;
  final String folio;
  final String garantia;
  final double montoGarantia;
  final double montoDesembolsado;
  final double interesGlobal;
  final double semanalCapital;
  final double semanalInteres;
  final double montoTotal;
  final double interesTotal;
  final double montoMasInteres;
  final double pagoCuota;
  final String numPago;
  final String periodoPagoActual; // NUEVO
  final String estadoPeriodo;     // NUEVO
  final String estado;
  final String fechasIniciofin;
  final List<FechaPago> fechas;   // ACTUALIZADO: ahora es una lista del tipo FechaPago
  final String fCreacion;
  final String estadoInterno;
  final List<ClienteMonto> clientesMontosInd;
  // Nota: he quitado estado_credito de la lista de propiedades, ya que solo se usaba para extraer 'estadoInterno'.

  Credito({
    required this.idcredito,
    required this.idgrupos,
    required this.nombreGrupo,
    required this.detalles,
    required this.asesor,
    required this.diaPago,
    required this.plazo,
    required this.tipoPlazo,
    required this.tipo,
    required this.ti_mensual,
    required this.ti_semanal,
    required this.folio,
    required this.garantia,
    required this.montoGarantia,
    required this.montoDesembolsado,
    required this.interesGlobal,
    required this.semanalCapital,
    required this.semanalInteres,
    required this.montoTotal,
    required this.interesTotal,
    required this.montoMasInteres,
    required this.pagoCuota,
    required this.numPago,
    required this.periodoPagoActual, // NUEVO
    required this.estadoPeriodo,     // NUEVO
    required this.estado,
    required this.fechasIniciofin,
    required this.fechas,            // ACTUALIZADO
    required this.fCreacion,
    required this.estadoInterno,
    required this.clientesMontosInd,
  });

  factory Credito.fromJson(Map<String, dynamic> json) {
    final estadoCreditoJson = json['estado_credito'];

    // Lógica para parsear la lista de fechas
    final List<dynamic> fechasJson = json['fechas'] as List? ?? [];
    final List<FechaPago> fechasList = fechasJson
        .map((fechaJson) => FechaPago.fromJson(fechaJson))
        .toList();

    return Credito(
      idcredito: json['idcredito'] ?? '',
      idgrupos: json['idgrupos'] ?? '',
      nombreGrupo: json['nombreGrupo'] ?? '',
      detalles: json['detalles'] ?? '',
      asesor: json['asesor'] ?? '',
      diaPago: json['diaPago'] ?? '',
      plazo: json['plazo'] is String
          ? int.tryParse(json['plazo']) ?? 0
          : (json['plazo'] ?? 0),
      tipoPlazo: json['tipoPlazo'] ?? '',
      tipo: json['tipo'] ?? '',
      ti_mensual: (json['ti_mensual'] as num?)?.toDouble() ?? 0.0,
      ti_semanal: json['ti_semanal'] ?? '',
      folio: json['folio'] ?? '',
      garantia: json['garantia'] ?? '',
      montoGarantia: (json['montoGarantia'] as num?)?.toDouble() ?? 0.0,
      montoDesembolsado: (json['montoDesembolsado'] as num?)?.toDouble() ?? 0.0,
      interesGlobal: (json['interesGlobal'] as num?)?.toDouble() ?? 0.0,
      semanalCapital: (json['semanalCapital'] as num?)?.toDouble() ?? 0.0,
      semanalInteres: (json['semanalInteres'] as num?)?.toDouble() ?? 0.0,
      montoTotal: (json['montoTotal'] as num?)?.toDouble() ?? 0.0,
      interesTotal: (json['interesTotal'] as num?)?.toDouble() ?? 0.0,
      montoMasInteres: (json['montoMasInteres'] as num?)?.toDouble() ?? 0.0,
      pagoCuota: (json['pagoCuota'] as num?)?.toDouble() ?? 0.0,
      numPago: json['numPago'] ?? '',
      periodoPagoActual: json['periodoPagoActual'] ?? '', // NUEVO
      estadoPeriodo: json['estadoPeriodo'] ?? '',         // NUEVO
      estado: json['estado'] ?? '',
      fechasIniciofin: json['fechasIniciofin'] ?? '',
      fechas: fechasList, // ACTUALIZADO
      fCreacion: json['fCreacion'],
      estadoInterno: estadoCreditoJson?['estado'] ?? '',
      clientesMontosInd: (json['clientesMontosInd'] as List? ?? [])
          .map((e) => ClienteMonto.fromJson(e))
          .toList(),
    );
  }
}