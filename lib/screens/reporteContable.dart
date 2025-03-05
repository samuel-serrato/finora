import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reporte_contable.dart';

class ReporteContableWidget extends StatelessWidget {
  final List<ReporteContable> listaReportes;
  final NumberFormat currencyFormat;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final double headerTextSize;
  final double cellTextSize;

  const ReporteContableWidget({
    super.key,
    required this.listaReportes,
    required this.currencyFormat,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    this.headerTextSize = 12.0,
    this.cellTextSize = 11.0,
  });

 @override
Widget build(BuildContext context) {
  print('Datos recibidos en ReporteContableWidget: ${listaReportes.length} elementos');
  print('Contenido de listaReportes: $listaReportes');
  return Container(
    padding: const EdgeInsets.all(20),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: listaReportes.isEmpty
    ? const Center(child: Text('No hay datos para mostrar'))
    : Column(
        children: [
          _buildDataTableHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: verticalScrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: horizontalScrollController,
                child: _buildDataTableBody(),
              ),
            ),
          ),
        ],
      ),
      ),
    ),
  );
}

  Widget _buildDataTableHeader() {
    return Container(
      color: const Color(0xFF5162F6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          _buildHeaderCell('#'),
          _buildHeaderCell('Tipo Pago'),
          _buildHeaderCell('Semanas'),
          _buildHeaderCell('Tasa Interés'),
          _buildHeaderCell('Folio'),
          _buildHeaderCell('Pago Periodo'),
          _buildHeaderCell('Grupos'),
          _buildHeaderCell('Estado'),
          _buildHeaderCell('Monto Ficha'),
          _buildHeaderCell('Capital Semanal'),
          _buildHeaderCell('Interés Semanal'),
          _buildHeaderCell('Clientes'),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
  return Flexible(
    fit: FlexFit.loose,
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: headerTextSize,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

  Widget _buildDataTableBody() {
  print('Construyendo tabla con ${listaReportes.length} elementos');

  return Column(
    children: listaReportes.map((reporte) {
      print('Procesando reporte: ${reporte.folio}');

      return Container(
        color: listaReportes.indexOf(reporte).isEven
            ? const Color.fromARGB(255, 216, 228, 245)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell((listaReportes.indexOf(reporte) + 1).toString()),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(reporte.tipoPago),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(reporte.semanas.toString()),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell('${reporte.tazaInteres}%'),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(reporte.folio),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(reporte.pagoPeriodo.toString()),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(reporte.grupos),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(reporte.estado),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(currencyFormat.format(reporte.montoficha), 
                alignment: Alignment.centerRight),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(currencyFormat.format(reporte.capitalsemanal), 
                alignment: Alignment.centerRight),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(currencyFormat.format(reporte.interessemanal), 
                alignment: Alignment.centerRight),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: _buildBodyCell(_buildClientesColumn(reporte.clientes)),
            ),
          ],
        ),
      );
    }).toList(),
  );
}

  Widget _buildBodyCell(dynamic content, {Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: alignment,
        child: content is String 
            ? Text(
                content,
                style: TextStyle(
                  fontSize: cellTextSize,
                  color: Colors.grey[800],
                ),
              )
            : content,
      ),
    );
  }

  Widget _buildClientesColumn(List<Cliente> clientes) {
  print('Clientes en el reporte: ${clientes.length}');
  print('Detalle de clientes: $clientes');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: clientes.map((cliente) {
      return Text(
        '${cliente.nombreCompleto}: ${currencyFormat.format(cliente.montoIndividual)}',
        style: TextStyle(
          fontSize: cellTextSize,
          color: Colors.grey[800],
        ),
      );
    }).toList(),
  );
}
}