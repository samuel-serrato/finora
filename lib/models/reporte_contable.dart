class ReporteContable {
  final int numero;
  final String tipoPago;
  final int semanas;
  final double tazaInteres;
  final String folio;
  final int pagoPeriodo;
  final String grupos;
  final String estado;
  final PagoFicha pagoficha;
  final double montoficha;
  final double capitalsemanal;
  final double interessemanal;
  final List<Cliente> clientes;

  ReporteContable({
    required this.numero,
    required this.tipoPago,
    required this.semanas,
    required this.tazaInteres,
    required this.folio,
    required this.pagoPeriodo,
    required this.grupos,
    required this.estado,
    required this.pagoficha,
    required this.montoficha,
    required this.capitalsemanal,
    required this.interessemanal,
    required this.clientes,
  });

  factory ReporteContable.fromJson(Map<String, dynamic> json) {
   // ✅ Corrección: 
double parseValor(dynamic value) {
  if (value is String) {
    String cleanedValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanedValue) ?? 0.0;
  } else if (value is num) { // Maneja int o double
    return value.toDouble();
  }
  return 0.0;
}


    return ReporteContable(
      numero: json['num'] ?? 0,
      tipoPago: json['tipopago'] ?? 'N/A',
      semanas: json['semanas'] ?? 0,
      tazaInteres: json['taza_interes'] ?? 0.0,
      folio: json['folio'] ?? 'N/A',
      pagoPeriodo: json['pagoPeriodo'] ?? 0,
      grupos: json['grupos'] ?? 'N/A',
      estado: json['estado'] ?? 'N/A',
      pagoficha: PagoFicha.fromJson(json['pagoficha']),
      montoficha: parseValor(json['montoficha']),
      capitalsemanal: parseValor(json['capitalsemanal']),
      interessemanal: parseValor(json['interessemanal']),
      clientes: (json['clientes'] as List)
          .map((cliente) => Cliente.fromJson(cliente))
          .toList(),
    );
  }
}

class Cliente {
  final String nombreCompleto;
  final double montoIndividual;
  final double periodoCapital;
  final double periodoInteres;
  final double totalCapital;
  final double interesTotal;
  final double capitalMasInteres;
  final double totalFicha;

  Cliente({
    required this.nombreCompleto,
    required this.montoIndividual,
    required this.periodoCapital,
    required this.periodoInteres,
    required this.totalCapital,
    required this.interesTotal,
    required this.capitalMasInteres,
    required this.totalFicha,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    double parseValor(dynamic value) {
  if (value is String) {
    String cleanedValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanedValue) ?? 0.0;
  } else if (value is num) { // Maneja int o double
    return value.toDouble();
  }
  return 0.0;
}

    return Cliente(
      nombreCompleto: json['nombreCompleto'] ?? 'N/A',
      montoIndividual: parseValor(json['montoIndividual']),
      periodoCapital: parseValor(json['periodoCapital']),
      periodoInteres: parseValor(json['periodoInteres']),
      totalCapital: parseValor(json['totalCapital']),
      interesTotal: parseValor(json['interesTotal']),
      capitalMasInteres: parseValor(json['capitalMasInteres']),
      totalFicha: parseValor(json['totalFicha']),
    );
  }
}

class PagoFicha {
  final String idpagosdetalles;
  final String idgrupos;
  final String fechaDeposito;
  final List<Deposito> depositos;

  PagoFicha({
    required this.idpagosdetalles,
    required this.idgrupos,
    required this.fechaDeposito,
    required this.depositos,
  });

  factory PagoFicha.fromJson(Map<String, dynamic> json) {
    return PagoFicha(
      idpagosdetalles: json['idpagosdetalles'] ?? '',
      idgrupos: json['idgrupos'] ?? '',
      fechaDeposito: json['fechaDeposito'] ?? 'Pendiente',
      depositos: (json['depositos'] as List)
          .map((deposito) => Deposito.fromJson(deposito))
          .toList(),
    );
  }
}

class Deposito {
  final double deposito;
  final double saldofavor;
  final double pagoMoratorio;
  final String garantia;

  Deposito({
    required this.deposito,
    required this.saldofavor,
    required this.pagoMoratorio,
    required this.garantia,
  });

 factory Deposito.fromJson(Map<String, dynamic> json) {
  return Deposito(
    // ✅ Corrección: Convierte directamente desde num
    deposito: (json['deposito'] as num).toDouble(),
    saldofavor: (json['saldofavor'] as num).toDouble(),
    pagoMoratorio: (json['pagoMoratorio'] as num).toDouble(),
    garantia: json['garantia'] ?? 'No',
  );
}
}