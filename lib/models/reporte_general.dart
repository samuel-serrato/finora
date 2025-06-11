// reporte_general.dart

import 'package:intl/intl.dart';

// --- CLASE NUEVA: Para representar cada depósito individual ---
class Deposito {
  final double monto;
  final String fecha;
  final String garantia;

  Deposito({
    required this.monto,
    required this.fecha,
    required this.garantia,
  });

  factory Deposito.fromJson(Map<String, dynamic> json) {
    return Deposito(
      // El campo 'deposito' en el JSON es un número
      monto: (json['deposito'] as num?)?.toDouble() ?? 0.0, 
      fecha: json['fechaDeposito']?.toString() ?? 'Sin fecha',
      garantia: json['garantia']?.toString() ?? 'No',
    );
  }
}

// --- CLASE MODIFICADA: ReporteGeneral ---
// Ahora contiene una lista de depósitos
class ReporteGeneral {
  final int numero;
  final String tipoPago;
  final String folio;
  final String idficha;
  final String grupos;
  final double pagoficha; // Mantenemos esto para el total de la fila
  final double montoficha;
  final double capitalsemanal;
  final double interessemanal;
  final double saldofavor;
  final double moratorios;
  final double moratoriosAPagar;
  final double sumaMoratorio;
  final double depositoCompleto;
  
  // --- CAMBIO PRINCIPAL: Guardamos la lista completa de depósitos ---
  final List<Deposito> depositos;

  ReporteGeneral({
    required this.numero,
    required this.tipoPago,
    required this.folio,
    required this.idficha,
    required this.grupos,
    required this.pagoficha,
    required this.montoficha,
    required this.capitalsemanal,
    required this.interessemanal,
    required this.saldofavor,
    required this.moratorios,
    required this.moratoriosAPagar,
    required this.sumaMoratorio,
    required this.depositoCompleto,
    required this.depositos, // Se añade al constructor
  });

  factory ReporteGeneral.fromJson(Map<String, dynamic> json) {
    double parseValor(String value) =>
        double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    final moratoriosData = json['Moratorios'] as Map<String, dynamic>?;
    final pagofichaData = json['pagoficha'] as Map<String, dynamic>?;
    
    // --- CAMBIO: Parseamos la lista de depósitos ---
    List<Deposito> listaDepositos = [];
    if (pagofichaData != null && pagofichaData['depositos'] is List) {
      listaDepositos = (pagofichaData['depositos'] as List)
          .map((depositoJson) => Deposito.fromJson(depositoJson))
          .toList();
    }

    return ReporteGeneral(
      numero: json['num'] ?? 0,
      tipoPago: json['tipopago'] ?? 'N/A',
      folio: json['folio'] ?? 'N/A',
      idficha: json['idficha'] ?? 'N/A',
      grupos: json['grupos'] ?? 'N/A',
      montoficha: parseValor(json['montoficha'] ?? '0.0'),
      capitalsemanal: parseValor(json['capitalsemanal'] ?? '0.0'),
      interessemanal: parseValor(json['interessemanal'] ?? '0.0'),
      saldofavor: parseValor(json['saldofavor'] ?? '0.0'),
      moratorios: parseValor(json['moratoriosPagados'] ?? '0.0'),
      
      // Total de pagos, viene de 'sumaDeposito'
      pagoficha: (pagofichaData?['sumaDeposito'] as num?)?.toDouble() ?? 0.0,

      moratoriosAPagar: (moratoriosData?['moratoriosAPagar'] as num?)?.toDouble() ?? 0.0,
      sumaMoratorio: (pagofichaData?['sumaMoratorio'] as num?)?.toDouble() ?? 0.0,
      
      // Depósito completo (puede venir de dos sitios)
      depositoCompleto: parseValor(json['depositoCompleto'] ?? '0.0') != 0.0
          ? parseValor(json['depositoCompleto'] ?? '0.0')
          : (pagofichaData?['depositoCompleto'] as num?)?.toDouble() ?? 0.0,
          
      // --- Asignamos la lista de depósitos que parseamos ---
      depositos: listaDepositos,
    );
  }
}


// --- La clase ReporteGeneralData no necesita cambios ---
// ... (El resto de la clase ReporteGeneralData y la función _formatearFechaSemana se quedan igual)
class ReporteGeneralData {
  final String fechaSemana;
  final String fechaActual;
  final double totalCapital;
  final double totalInteres;
  final double totalPagoficha;
  final double totalSaldoFavor;
  final double saldoMoratorio;
  final double totalTotal;
  final double restante;
  final double totalFicha;
  final double sumaTotalCapMoraFav;
  final List<ReporteGeneral> listaGrupos;

  ReporteGeneralData({
    required this.fechaSemana,
    required this.fechaActual,
    required this.totalCapital,
    required this.totalInteres,
    required this.totalPagoficha,
    required this.totalSaldoFavor,
    required this.saldoMoratorio,
    required this.totalTotal,
    required this.restante,
    required this.totalFicha,
    required this.sumaTotalCapMoraFav,
    required this.listaGrupos,
  });

  factory ReporteGeneralData.fromJson(Map<String, dynamic> json) {
    double parseValor(String value) =>
        double.parse(value.replaceAll(RegExp(r'[^0-9.]'), ''));

    // --- CORRECCIÓN IMPORTANTE ---
    // El servidor ya agrupa los datos, por lo que 'listaGrupos' contiene objetos
    // ReporteGeneral únicos para cada ficha. No necesitamos procesar una lista plana.
    var rawListaGrupos = json['listaGrupos'] as List? ?? [];
    List<ReporteGeneral> reportesProcesados = [];
    if (rawListaGrupos.isNotEmpty && rawListaGrupos.first['pagoficha'] is Map) {
      // Si el JSON es como el ejemplo (anidado), mapeamos directamente
      reportesProcesados = rawListaGrupos
          .map((item) => ReporteGeneral.fromJson(item))
          .toList();
    } else {
      // (Opcional) Aquí podrías poner una lógica de fallback si el servidor
      // a veces envía un formato antiguo. Por ahora, asumimos el nuevo.
      print("Formato de listaGrupos no reconocido o vacío.");
    }

    return ReporteGeneralData(
      fechaSemana: _formatearFechaSemana(json['fechaSemana']?? 'N/A'),
      fechaActual: json['fechaActual'] ?? 'N/A',
      totalCapital: parseValor(json['totalCapital']),
      totalInteres: parseValor(json['totalInteres']),
      totalPagoficha: parseValor(json['totalPagoficha']),
      totalSaldoFavor: parseValor(json['totalSaldoFavor']),
      saldoMoratorio: parseValor(json['saldoMoratorio']),
      totalTotal: parseValor(json['totalTotal']),
      restante: parseValor(json['restante']),
      totalFicha: parseValor(json['totalFicha']),
      sumaTotalCapMoraFav: parseValor(json['sumaTotalCapMoraFav']),
      listaGrupos: reportesProcesados,
    );
  }
}

 String _formatearFechaSemana(String fechaOriginal) {
    try {
      final partes = fechaOriginal.split(' - ');
      final fechaInicio = partes[0].split(' ')[0];
      final fechaFin = partes[1].split(' ')[0];
      
      final formateador = DateFormat('d \'de\' MMMM \'de\' yyyy', 'es');
      
      final inicio = formateador.format(DateTime.parse(fechaInicio));
      final fin = formateador.format(DateTime.parse(fechaFin));
      
      return '$inicio - $fin';
    } catch (e) {
      return fechaOriginal; // En caso de error, devolver original
    }
  }