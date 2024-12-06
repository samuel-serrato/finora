import 'package:flutter/material.dart';

class InfoCredito extends StatefulWidget {
  final int id;

  InfoCredito({required this.id});

  @override
  _InfoCreditoState createState() => _InfoCreditoState();
}

class _InfoCreditoState extends State<InfoCredito> {
  late Credito credito;
  late List<Pago> pagos;

  @override
  void initState() {
    super.initState();
    credito = _buscarCreditoPorId(widget.id);
    pagos = _generarPagos(credito);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(16),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: _buildPagosTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFB2056),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Información del Crédito",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _infoItem("Nombre", credito.nombreCredito),
                    _infoItem(
                        "Monto Autorizado", "\$${credito.montoAutorizado}"),
                    _infoItem("Pago Semanal", "\$${credito.pagoSemanal}"),
                    _infoItem(
                        "Fecha de Inicio", _formatDate(credito.fechaInicio)),
                    _infoItem("Fecha de Fin", _formatDate(credito.fechaFin)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Icon(
                Icons.credit_card,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagosTable() {
    // Calcular totales
    double totalMonto = pagos.fold(0, (sum, pago) => sum + pago.monto);
    double totalParcial =
        pagos.fold(0, (sum, pago) => sum + (pago.montoRecibido ?? 0));
    double totalSaldoFavor = pagos.fold(
        0,
        (sum, pago) =>
            sum +
            ((pago.montoRecibido != null && pago.montoRecibido! > pago.monto)
                ? pago.montoRecibido! - pago.monto
                : 0));
    double totalSaldoContra = pagos.fold(
        0,
        (sum, pago) =>
            sum +
            ((pago.montoRecibido != null && pago.montoRecibido! < pago.monto)
                ? pago.monto - pago.montoRecibido!
                : 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Detalles de los Pagos",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFB2056)),
        ),
        SizedBox(height: 10),
        // Encabezado fijo
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Color(0xFFFB2056),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Row(
              children: [
                _buildTableCell("Semana",
                    isHeader: true, textColor: Colors.white),
                _buildTableCell("Fecha",
                    isHeader: true, textColor: Colors.white),
                _buildTableCell("Monto",
                    isHeader: true, textColor: Colors.white),
                _buildTableCell("Completo",
                    isHeader: true, textColor: Colors.white),
                _buildTableCell("Monto Parcial",
                    isHeader: true, textColor: Colors.white),
                _buildTableCell("Saldo a Favor",
                    isHeader: true, textColor: Colors.white),
                _buildTableCell("Saldo en Contra",
                    isHeader: true, textColor: Colors.white),
              ],
            ),
          ),
        ),
        // Contenedor de la tabla con desplazamiento
        Container(
          height: 300, // Ajusta el tamaño según sea necesario
          child: SingleChildScrollView(
            child: Column(
              children: pagos.asMap().entries.map((entry) {
                int index = entry.key + 1;
                Pago pago = entry.value;
                double saldoFavor = 0.0;
                double saldoContra = 0.0;

                if (pago.montoRecibido != null) {
                  if (pago.montoRecibido! > pago.monto) {
                    saldoFavor = pago.montoRecibido! - pago.monto;
                  } else if (pago.montoRecibido! < pago.monto) {
                    saldoContra = pago.monto - pago.montoRecibido!;
                  }
                }

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        _buildTableCell("$index"),
                        _buildTableCell(_formatDate(pago.fecha)),
                        _buildTableCell("\$${pago.monto.toStringAsFixed(2)}"),
                        _buildTableCell(Checkbox(
                          value: pago.completado,
                          activeColor: Color(0xFFFB2056),
                          onChanged: (value) {
                            setState(() {
                              pago.completado = value!;
                              if (pago.completado) {
                                pago.parcial = false;
                                pago.montoRecibido = pago.monto;
                              } else {
                                pago.montoRecibido = null;
                              }
                            });
                          },
                        )),
                        _buildTableCell(_buildMontoParcial(pago)),
                        _buildTableCell(saldoFavor > 0
                            ? "\$${saldoFavor.toStringAsFixed(2)}"
                            : "-"),
                        _buildTableCell(saldoContra > 0
                            ? "\$${saldoContra.toStringAsFixed(2)}"
                            : "-"),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Fila de totales
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Color(0xFFFB2056),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Row(
              children: [
                _buildTableCell("Totales",
                    isHeader: false, textColor: Colors.white),
                _buildTableCell("", textColor: Colors.white),
                _buildTableCell("\$${totalMonto.toStringAsFixed(2)}",
                    textColor: Colors.white),
                _buildTableCell("", textColor: Colors.white),
                _buildTableCell("\$${totalParcial.toStringAsFixed(2)}",
                    textColor: Colors.white),
                _buildTableCell("\$${totalSaldoFavor.toStringAsFixed(2)}",
                    textColor: Colors.white),
                _buildTableCell("\$${totalSaldoContra.toStringAsFixed(2)}",
                    textColor: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(dynamic content,
      {bool isHeader = false, Color textColor = Colors.black}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: content
                is Widget // Si el contenido es un Widget, lo renderizamos directamente.
            ? content
            : Text(content.toString(),
                style: TextStyle(
                    color:
                        textColor)), // Si no es un Widget, lo mostramos como texto
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, color: Colors.white)),
      ],
    );
  }

  Widget _buildMontoParcial(Pago pago) {
    return Row(
      children: [
        Checkbox(
          value: pago.parcial,
          activeColor: Color(0xFFFB2056),
          onChanged: (value) {
            setState(() {
              pago.parcial = value!;
              if (pago.parcial) {
                pago.completado = false;
                pago.montoRecibido = null;
              }
            });
          },
        ),
        if (pago.parcial)
          Expanded(
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Monto',
                isDense: true, // Hace que el diseño sea más compacto
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                constraints: BoxConstraints(
                  minHeight: 30, // Altura mínima
                  maxHeight: 30, // Altura máxima
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFCCCCCC)),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  pago.montoRecibido = double.tryParse(value) ?? 0.0;
                });
              },
            ),
          )
        else
          Text(pago.completado ? "\$${pago.monto}" : ""),
      ],
    );
  }

  String _formatDate(DateTime date) => "${date.toLocal()}".split(' ')[0];

  Credito _buscarCreditoPorId(int id) {
    return Credito(
      idCredito: 1,
      nombreCredito: 'Cielito Azul',
      montoAutorizado: 50000,
      garantia: 10,
      interes: 9.28,
      tipoCredito: 'Individual',
      estadoCredito: 'Activo',
      montoDesembolsado: 40000,
      semanaDePago: '2 de 14',
      diaDePago: 'Lunes',
      fechaPago: DateTime(2024, 11, 10),
      pagoSemanal: 2500.0,
      fechaInicio: DateTime(2024, 10, 1),
      fechaFin: DateTime(2025, 1, 1),
    );
  }

  List<Pago> _generarPagos(Credito credito) {
    final List<Pago> pagos = [];
    DateTime fechaActual = credito.fechaInicio;
    final semanas =
        ((credito.fechaFin.difference(credito.fechaInicio).inDays) / 7).ceil();
    for (int i = 0; i < semanas; i++) {
      pagos.add(Pago(fecha: fechaActual, monto: credito.pagoSemanal));
      fechaActual = fechaActual.add(Duration(days: 7));
    }
    return pagos;
  }
}

class Credito {
  final int idCredito;
  final String nombreCredito;
  final double montoAutorizado;
  final double garantia;
  final double interes;
  final String tipoCredito;
  final String estadoCredito;
  final double montoDesembolsado;
  final String semanaDePago;
  final String diaDePago;
  final DateTime fechaPago;
  final double pagoSemanal;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  Credito({
    required this.idCredito,
    required this.nombreCredito,
    required this.montoAutorizado,
    required this.garantia,
    required this.interes,
    required this.tipoCredito,
    required this.estadoCredito,
    required this.montoDesembolsado,
    required this.semanaDePago,
    required this.diaDePago,
    required this.fechaPago,
    required this.pagoSemanal,
    required this.fechaInicio,
    required this.fechaFin,
  });
}

class Pago {
  final DateTime fecha;
  final double monto;
  bool completado = false;
  bool parcial = false;
  double? montoRecibido;

  Pago({required this.fecha, required this.monto});
}
