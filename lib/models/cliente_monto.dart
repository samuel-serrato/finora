class ClienteMonto {
  final String idamortizacion;
  final String nombreCompleto;
  final String cargo;
  final double capitalIndividual;
  final double periodoCapital;
  final double periodoInteres;
  final double totalCapital;
  final double totalIntereses;
  final double periodoInteresPorcentaje;
  final double capitalMasInteres;
  final double total;

  ClienteMonto({
    required this.idamortizacion,
    required this.nombreCompleto,
    required this.cargo,
    required this.capitalIndividual,
    required this.periodoCapital,
    required this.periodoInteres,
    required this.totalCapital,
    required this.totalIntereses,
    required this.periodoInteresPorcentaje,
    required this.capitalMasInteres,
    required this.total,
  });

  factory ClienteMonto.fromJson(Map<String, dynamic> json) {
    return ClienteMonto(
      idamortizacion: json['idamortizacion'],
      nombreCompleto: json['nombreCompleto'],
      cargo: json['cargo'],
      capitalIndividual: json['capitalIndividual'].toDouble(),
      periodoCapital: json['periodoCapital'].toDouble(),
      periodoInteres: json['periodoInteres'].toDouble(),
      totalCapital: json['totalCapital'].toDouble(),
      totalIntereses: json['interesTotal'].toDouble(),
      periodoInteresPorcentaje: json['periodoInteresPorcentaje'].toDouble(),
      capitalMasInteres: json['capitalMasInteres'].toDouble(),
      total: json['total'].toDouble(),
    );
  }
}