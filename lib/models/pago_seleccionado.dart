class PagoSeleccionado {
  final int semana;
  final String tipoPago;
  final double deposito;
  final DateTime? fechaPago; // Nueva propiedad para la fecha de pago
  List<Map<String, dynamic>> abonos; // Lista mutable

  // Constructor actualizado para incluir fechaPago
  PagoSeleccionado({
    required this.semana,
    required this.tipoPago,
    required this.deposito,
    this.fechaPago, // Requerimos esta propiedad
    List<Map<String, dynamic>>? abonos, // Parámetro opcional
  }) : abonos = abonos ?? []; // Inicialización por defecto

  // Método toJson actualizado para incluir la fechaPago
  Map<String, dynamic> toJson() {
    return {
      'semana': semana,
      'tipoPago': tipoPago,
      'deposito': deposito,
      'fechaPago': fechaPago, // Convertir la fecha a string ISO
      'abonos': abonos, // Agregar los abonos al JSON
    };
  }
}
