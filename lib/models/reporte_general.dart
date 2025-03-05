class ReporteGeneralData {
  final String fechaSemana;
  final String fechaActual;
  final double totalCapital;
  final double totalInteres;
  final double totalPagoficha;
  final double totalSaldoFavor;
  final double saldoMoratorio;
  final double totalTotal;
  final double totalFicha;
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
    required this.totalFicha,
    required this.listaGrupos,
  });

  factory ReporteGeneralData.fromJson(Map<String, dynamic> json) {
    double parseValor(String value) =>
        double.parse(value.replaceAll(RegExp(r'[^0-9.]'), ''));

    return ReporteGeneralData(
      fechaSemana: json['fechaSemana'] ?? 'N/A',
      fechaActual: json['fechaActual'] ?? 'N/A',
      totalCapital: parseValor(json['totalCapital']),
      totalInteres: parseValor(json['totalInteres']),
      totalPagoficha: parseValor(json['totalPagoficha']),
      totalSaldoFavor: parseValor(json['totalSaldoFavor']),
      saldoMoratorio: parseValor(json['saldoMoratorio']),
      totalTotal: parseValor(json['totalTotal']),
      totalFicha: parseValor(json['totalFicha']),
      listaGrupos: (json['listaGrupos'] as List)
          .map((item) => ReporteGeneral.fromJson(item))
          .toList(),
    );
  }
}

class ReporteGeneral {
  final int numero;
  final String tipoPago;
  final String folio;
  final String idficha;
  final String grupos;
  final double pagoficha;
  final String fechadeposito;
  final double montoficha;
  final double capitalsemanal;
  final double interessemanal;
  final double saldofavor;
  final double moratorios;
  final String garantia;

  ReporteGeneral(
      {required this.numero,
      required this.tipoPago,
      required this.folio,
      required this.idficha,
      required this.grupos,
      required this.pagoficha,
      required this.fechadeposito,
      required this.montoficha,
      required this.capitalsemanal,
      required this.interessemanal,
      required this.saldofavor,
      required this.moratorios,
      required this.garantia});

  factory ReporteGeneral.fromJson(Map<String, dynamic> json) {
    double parseValor(String value) =>
        double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    return ReporteGeneral(
        numero: json['num'] ?? 0,
        tipoPago: json['tipopago'] ?? 'N/A',
        folio: json['folio'] ?? 'N/A',
        idficha: json['idficha'] ?? 'N/A',
        grupos: json['grupos'] ?? 'N/A',
        pagoficha: parseValor(json['pagoficha']),
        fechadeposito: json['fechadeposito'] ?? 'Pendiente',
        montoficha: parseValor(json['montoficha']),
        capitalsemanal: parseValor(json['capitalsemanal']),
        interessemanal: parseValor(json['interessemanal']),
        saldofavor: parseValor(json['saldofavor']),
        moratorios: parseValor(json['moratorios']),
        garantia: json['garantia'] ?? 'N/A');
  }
}