class EstadoCredito {
  final double montoTotal;
  final double moratorios;
  final int semanasDeRetraso;
  final int diferenciaEnDias;
  final String mensaje;
  final String estado;

  EstadoCredito({
    required this.montoTotal,
    required this.moratorios,
    required this.semanasDeRetraso,
    required this.diferenciaEnDias,
    required this.mensaje,
    required this.estado,
  });

  factory EstadoCredito.fromJson(Map<String, dynamic> json) {
    return EstadoCredito(
      montoTotal: (json['montoTotal'] as num).toDouble(), // Convertir a double
      moratorios: (json['moratorios'] as num).toDouble(), // Convertir a double
      semanasDeRetraso: json['semanasDeRetraso'],
      diferenciaEnDias: json['diferenciaEnDias'],
      mensaje: json['mensaje'],
      estado: json[
          'esatado'], // Nota: el JSON tiene un error de tipografía aquí ("esatado" en lugar de "estado").
    );
  }
}
