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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(16),
      child: Container(
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
        gradient: LinearGradient(
          colors: [Color(0xFFFB2056), Color(0xFFFF616D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Información del Crédito",
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 10),
          _buildDetailRow("Nombre:", credito.nombreCredito, Colors.white),
          _buildDetailRow("Monto Autorizado:", "\$${credito.montoAutorizado}", Colors.white),
          _buildDetailRow("Pago Semanal:", "\$${credito.pagoSemanal}", Colors.white),
          _buildDetailRow("Fecha de Inicio:", "${credito.fechaInicio.toLocal()}".split(' ')[0],
              Colors.white),
          _buildDetailRow("Fecha de Fin:", "${credito.fechaFin.toLocal()}".split(' ')[0],
              Colors.white),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
          Text(value, style: TextStyle(fontSize: 14, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildPagosTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Detalles de los Pagos",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFB2056)),
        ),
        SizedBox(height: 10),
        Table(
          columnWidths: {
            0: FractionColumnWidth(0.3),
            1: FractionColumnWidth(0.2),
            2: FractionColumnWidth(0.2),
            3: FractionColumnWidth(0.3),
          },
          border: TableBorder.all(color: Color(0xFFEEEEEE), width: 1),
          children: [
            _buildTableHeader(),
            ...pagos.map((pago) => _buildPagoRow(pago)).toList(),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: BoxDecoration(color: Color(0xFFF7F7F7)),
      children: [
        _buildTableCell(Text("Fecha", style: TextStyle(fontWeight: FontWeight.bold))),
        _buildTableCell(Text("Monto", style: TextStyle(fontWeight: FontWeight.bold))),
        _buildTableCell(Text("Completo", style: TextStyle(fontWeight: FontWeight.bold))),
        _buildTableCell(Text("Monto Parcial", style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }

  TableRow _buildPagoRow(Pago pago) {
    return TableRow(
      children: [
        _buildTableCell(Text("${pago.fecha.toLocal()}".split(' ')[0])),
        _buildTableCell(Text("\$${pago.monto}")),
        _buildTableCell(
          Checkbox(
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
          ),
        ),
        _buildTableCell(
          Row(
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
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(Widget content) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: content,
    );
  }

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
    final int semanas = ((credito.fechaFin.difference(credito.fechaInicio).inDays) / 7).ceil();
    DateTime fechaActual = credito.fechaInicio;

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
