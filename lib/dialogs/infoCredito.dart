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
                    _infoItem("Monto Autorizado", "\$${credito.montoAutorizado}"),
                    _infoItem("Pago Semanal", "\$${credito.pagoSemanal}"),
                    _infoItem("Fecha de Inicio", _formatDate(credito.fechaInicio)),
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
          0: FlexColumnWidth(0.8),  // No. Semana
          1: FlexColumnWidth(2),  // Fecha
          2: FlexColumnWidth(1),  // Monto
          3: FlexColumnWidth(1),  // Completo
          4: FlexColumnWidth(2),  // Monto Parcial
          5: FlexColumnWidth(1),  // Saldo a Favor
          6: FlexColumnWidth(1),  // Saldo en Contra
        },
        border: TableBorder.all(color: Color(0xFFEEEEEE), width: 1),
        children: [
          _tableRow([
            "Semana",
            "Fecha",
            "Monto",
            "Completo",
            "Monto Parcial",
            "Saldo a Favor",
            "Saldo en Contra"
          ], isHeader: true),
          ...pagos.asMap().entries.map((entry) {
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

            return _tableRow([
              "$index",
              _formatDate(pago.fecha),
              "\$${pago.monto}",
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
              _buildMontoParcial(pago),
              saldoFavor > 0 ? "\$${saldoFavor.toStringAsFixed(2)}" : "-",
              saldoContra > 0 ? "\$${saldoContra.toStringAsFixed(2)}" : "-",
            ]);
          }).toList(),
        ],
      ),
    ],
  );
}



  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, color: Colors.white)),
      ],
    );
  }

  TableRow _tableRow(List<dynamic> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.map((cell) {
        if (cell is String) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              cell,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: cell,
        );
      }).toList(),
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
    final semanas = ((credito.fechaFin.difference(credito.fechaInicio).inDays) / 7).ceil();
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
