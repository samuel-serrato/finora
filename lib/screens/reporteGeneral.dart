import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import '../models/reporte_general.dart';

class ReporteGeneralWidget extends StatelessWidget {
  final List<ReporteGeneral> listaReportes;
  final ReporteGeneralData? reporteData;
  final NumberFormat currencyFormat;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final double headerTextSize;
  final double cellTextSize;

  const ReporteGeneralWidget({
    super.key,
    required this.listaReportes,
    required this.reporteData,
    required this.currencyFormat,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    this.headerTextSize = 12.0,
    this.cellTextSize = 11.0,
  });

    // Color principal definido como constante para fácil referencia
  static const Color primaryColor = Color(0xFF5162F6);

  @override
  Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.only(top: 10, bottom: 20, left: 20, right: 20),
    child: Column(
      children: [
        // Header fuera del container con ClipRRect
        if (reporteData != null) _buildHeader(context),
        const SizedBox(height: 10), // Espacio entre el header y el contenedor principal
        Expanded(
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
                            child: _buildDataTableBody(),
                          ),
                        ),
                        if (reporteData != null) Column(
                          children: [
                            _buildTotalsWidget(),
                            _buildTotalsIdealWidget()
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildHeader(BuildContext context) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Icon(
        Icons.bar_chart_rounded,
        color: primaryColor,
        size: 22,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          /*   Text(
              'Reporte Contable Financiero',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 14,
                  ),
            ), */
            Row(
              children: [
                Text(
                  'Período: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  reporteData!.fechaSemana,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Generado: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  reporteData!.fechaActual,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildDataTableHeader() {
    return Container(
      color: const Color(0xFF5162F6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          _buildHeaderCell('#'),
          _buildHeaderCell('Tipo de Pago'),
          _buildHeaderCell('Grupos'),
          _buildHeaderCell('Folio'),
          _buildHeaderCell('ID Ficha'),
          _buildHeaderCell('Pago Ficha'),
          _buildHeaderCell('Fecha Depósito'),
          _buildHeaderCell('Monto Ficha'),
          _buildHeaderCell('Capital Semanal'),
          _buildHeaderCell('Interés Semanal'),
          _buildHeaderCell('Saldo Favor'),
          _buildHeaderCell('Moratorios'),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: headerTextSize,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDataTableBody() {
  final groupedReportes = groupBy(listaReportes, (r) => r.idficha);
  final groups = groupedReportes.entries.toList();

  return Column(
    children: groups.asMap().entries.map((entry) {
      final index = entry.key;
      final group = entry.value;
      final idFicha = group.key;
      final reportesInGroup = group.value;

      final totalPagos = reportesInGroup.fold(0.0, (sum, r) => sum + r.pagoficha);
      final bool allPagosFichaZero = totalPagos == 0.0;
      final bool pagoIncompleto = totalPagos < reportesInGroup.first.montoficha && totalPagos > 0;

      return Container(
        color: index.isEven ? const Color.fromARGB(255, 216, 228, 245) : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            _buildBodyCell(_buildIndexCircle(index, allPagosFichaZero, pagoIncompleto),
              alignment: Alignment.center), // Alinea el número en el centro
            _buildBodyCell(reportesInGroup.first.tipoPago),
            _buildBodyCell(reportesInGroup.first.grupos),
            _buildBodyCell(reportesInGroup.first.folio),
            _buildBodyCell(idFicha, alignment: Alignment.center),
            _buildBodyCell(_buildPagosColumn(reportesInGroup), alignment: Alignment.center),
            _buildBodyCell(reportesInGroup.map((r) => r.fechadeposito).join('\n'), alignment: Alignment.center),
            _buildBodyCell(currencyFormat.format(reportesInGroup.first.montoficha), 
             alignment: Alignment.center),
            _buildBodyCell(currencyFormat.format(reportesInGroup.first.capitalsemanal), 
              alignment: Alignment.center),
            _buildBodyCell(currencyFormat.format(reportesInGroup.first.interessemanal), 
              alignment: Alignment.center),
            _buildBodyCell(_buildSaldoFavor(reportesInGroup), 
              alignment: Alignment.center),
            _buildBodyCell(_buildMoratorios(reportesInGroup), 
              alignment: Alignment.center),
          ],
        ),
      );
    }).toList(),
  );
}

  Widget _buildBodyCell(dynamic content, {Alignment alignment = Alignment.centerLeft}) {
  return Flexible(
    fit: FlexFit.tight,
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

  Widget _buildIndexCircle(int index, bool allPagosFichaZero, bool pagoIncompleto) {
    Color circleColor = Colors.transparent;
    if (allPagosFichaZero) {
      circleColor = Colors.red;
    } else if (pagoIncompleto) {
      circleColor = Colors.orange;
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        (index + 1).toString(),
        style: TextStyle(
          fontSize: cellTextSize,
          fontWeight: FontWeight.w700,
          color: circleColor == Colors.transparent ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildPagosColumn(List<ReporteGeneral> reportes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: reportes.map((r) {
        bool esGarantia = r.garantia == "Si";
        return esGarantia
            ? Tooltip(
                decoration: BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12
                ),
                message: 'Este pago se realizó con garantía',
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53888),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    currencyFormat.format(r.pagoficha),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: cellTextSize,
                    ),
                  ),
                ),
              )
            : Text(
                currencyFormat.format(r.pagoficha),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: cellTextSize,
                ),
              );
      }).toList(),
    );
  }

  Widget _buildSaldoFavor(List<ReporteGeneral> reportes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: reportes.map((r) => Text(
        currencyFormat.format(r.saldofavor),
        style: TextStyle(
          fontSize: cellTextSize,
          color: Colors.grey[800],
        ),
      )).toList(),
    );
  }

  Widget _buildMoratorios(List<ReporteGeneral> reportes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: reportes.map((r) => Text(
        currencyFormat.format(r.moratorios),
        style: TextStyle(
          fontSize: cellTextSize,
          color: Colors.grey[800],
        ),
      )).toList(),
    );
  }

  Widget _buildTotalsWidget() {
    return Column(
      children: [
        _buildTotalsRow(
          'Totales',
          [
            (value: reporteData!.totalPagoficha, column: 5),
            (value: reporteData!.totalFicha, column: 7),
            (value: reporteData!.totalCapital, column: 8),
            (value: reporteData!.totalInteres, column: 9),
            (value: reporteData!.totalSaldoFavor, column: 10),
            (value: reporteData!.saldoMoratorio, column: 11),
          ],
        ),
       
      ],
    );
  }


 Widget _buildTotalsIdealWidget() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 109, 121, 232),
      borderRadius: BorderRadius.circular(0),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start, // Alinea los elementos a la izquierda
      children: [
        // Total Ideal con ícono de información
        Row(
          children: [
            _buildTotalItem('Total Ideal', reporteData!.totalTotal),
            const SizedBox(width: 8), // Espacio entre el texto y el ícono
            Tooltip(
              message: 'El Total Ideal representa la suma de:\n\n'
                  '• Monto ficha\n'
                  '• Saldo a favor\n'
                  '• Moratorios\n\n'
                  'Es el monto objetivo que se debe alcanzar.',
                decoration: BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(12),
                ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.all(12),
              preferBelow: false, // Evita que el tooltip se oculte debajo
              child: const MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 18, // Tamaño ligeramente mayor para mejor visibilidad
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 100), // Espacio entre los elementos
        // Diferencia con ícono de información
        Row(
          children: [
            _buildTotalItem('Diferencia', reporteData!.restante),
            const SizedBox(width: 8), // Espacio entre el texto y el ícono
            Tooltip(
              message: 'La Diferencia es el monto restante para alcanzar el Total Ideal.\n\n'
                  'Se calcula restando el total de pagos recibidos del Total Ideal.',
                decoration: BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(12),
                ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.all(12),
              preferBelow: false,
              child: const MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


  Widget _buildTotalItem(String label, double value) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: cellTextSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      Text(
        currencyFormat.format(value),
        style: TextStyle(
          fontSize: cellTextSize,
          color: Colors.white,
        ),
      ),
    ],
  );
}


  Widget _buildTotalsRow(
    String label, List<({double value, int column})> values) {
  List<Widget> cells = List.generate(12, (_) => Expanded(child: Container()));

  cells[0] = Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Text(
        label,
        style: TextStyle(
          fontSize: cellTextSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );

  for (final val in values) {
    cells[val.column] = Flexible(
      fit: FlexFit.tight,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        alignment: Alignment.center,
        child: Text(
          currencyFormat.format(val.value),
          style: TextStyle(
            fontSize: cellTextSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  return Container(
    color: const Color(0xFF5162F6),
    child: Row(children: cells),
  );
}
}