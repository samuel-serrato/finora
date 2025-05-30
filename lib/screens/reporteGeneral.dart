import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20, left: 20, right: 20),
      child: Column(
        children: [
          // Header fuera del container con ClipRRect
          if (reporteData != null) _buildHeader(context),
          const SizedBox(
              height: 10), // Espacio entre el header y el contenedor principal
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.white,
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
                    ? Center(
                        child: Text(
                          'No hay datos para mostrar',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          _buildDataTableHeader(context),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: verticalScrollController,
                              child: _buildDataTableBody(context),
                            ),
                          ),
                          if (reporteData != null)
                            Column(
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

  // Header modificado para incluir las dos columnas de moratorios
  Widget _buildDataTableHeader(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      color: primaryColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          _buildHeaderCell('#', context),
          _buildHeaderCell('Tipo', context),
          _buildHeaderCell('Grupos', context),
          _buildHeaderCell('Pagos', context),
          _buildHeaderCell('Fecha', context),
          _buildHeaderCell('Monto', context),
          _buildHeaderCell('Capital', context),
          _buildHeaderCell('Interés', context),
          _buildHeaderCell('Saldo Favor', context),
          // Columnas de moratorios separadas
          _buildHeaderCell('Moratorios\nGenerados', context),
          _buildHeaderCell('Moratorios\nPagados', context),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

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

  Widget _buildDataTableBody(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final groupedReportes = groupBy(listaReportes, (r) => r.idficha);
    final groups = groupedReportes.entries.toList();

    return Column(
      children: groups.asMap().entries.map((entry) {
        final index = entry.key;
        final group = entry.value;
        final idFicha = group.key;
        final reportesInGroup = group.value;

        final totalPagos =
            reportesInGroup.fold(0.0, (sum, r) => sum + r.pagoficha);
        final bool allPagosFichaZero = totalPagos == 0.0;
        final bool pagoIncompleto =
            totalPagos < reportesInGroup.first.montoficha && totalPagos > 0;

        return Container(
          color: isDarkMode
              ? (index.isEven
                  ? const Color(0xFF2A3040)
                  : const Color(0xFF1E1E1E))
              : (index.isEven
                  ? const Color.fromARGB(255, 216, 228, 245)
                  : Colors.white),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              _buildBodyCell(
                  _buildIndexCircle(
                      index, allPagosFichaZero, pagoIncompleto, context),
                  alignment: Alignment.center,
                  context: context),
              _buildBodyCell(reportesInGroup.first.tipoPago,
                  context: context, alignment: Alignment.center),
              _buildBodyCell(reportesInGroup.first.grupos,
                  context: context, alignment: Alignment.center),
              _buildBodyCell(_buildPagosColumn(reportesInGroup, context),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(
                  reportesInGroup.map((r) => r.fechadeposito).join('\n'),
                  alignment: Alignment.center,
                  context: context),
              _buildBodyCell(
                  currencyFormat.format(reportesInGroup.first.montoficha),
                  alignment: Alignment.center,
                  context: context),
              _buildBodyCell(
                  currencyFormat.format(reportesInGroup.first.capitalsemanal),
                  alignment: Alignment.center,
                  context: context),
              _buildBodyCell(
                  currencyFormat.format(reportesInGroup.first.interessemanal),
                  alignment: Alignment.center,
                  context: context),
              _buildBodyCell(_buildSaldoFavor(reportesInGroup, context),
                  alignment: Alignment.center, context: context),
              // Moratorios Generados
              _buildBodyCell(_buildMoratoriosGenerados(reportesInGroup, context),
                  alignment: Alignment.center, context: context),
              // Moratorios Pagados
              _buildBodyCell(_buildMoratoriosPagados(reportesInGroup, context),
                  alignment: Alignment.center, context: context),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBodyCell(dynamic content,
      {Alignment alignment = Alignment.centerLeft,
      required BuildContext context}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: alignment,
        child: content is String
            ? Text(
                content,
                style: TextStyle(
                  fontSize: cellTextSize,
                  color: isDarkMode ? Colors.white70 : Colors.grey[800],
                ),
              )
            : content,
      ),
    );
  }

  Widget _buildIndexCircle(int index, bool allPagosFichaZero,
      bool pagoIncompleto, BuildContext context) {
    Color circleColor = Colors.transparent;
    String tooltipMessage = '';

    if (allPagosFichaZero) {
      circleColor = Colors.red;
      tooltipMessage = 'Pago no realizado';
    } else if (pagoIncompleto) {
      circleColor = Colors.orange;
      tooltipMessage = 'Pago incompleto';
    }

    // Detecta si está en modo oscuro
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Color del texto basado en el modo actual y el fondo
    final Color textColor = circleColor == Colors.transparent
        ? (isDarkMode ? Colors.white : Colors.black)
        : Colors.white;

    return Tooltip(
      message: tooltipMessage,
      verticalOffset: 20,
      preferBelow: true,
      textStyle: const TextStyle(
        fontSize: 12,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: circleColor != Colors.transparent
            ? circleColor
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
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
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagosColumn(
      List<ReporteGeneral> reportes, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: reportes.map((reporte) {
        // Check if payment is a guarantee
        bool isGarantia = reporte.garantia == "Si";

        // Create the payment display with or without the pink highlight
        Widget paymentDisplay = Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: isGarantia
              ? BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Text(
            currencyFormat.format(reporte.pagoficha),
            style: TextStyle(
              fontSize: cellTextSize,
              // Change text color to white when isGarantia is true
              color: isGarantia
                  ? Colors.white
                  : (isDarkMode ? Colors.white70 : Colors.grey[800]),
            ),
          ),
        );

        // Wrap with Tooltip if it's a guarantee
        return isGarantia
            ? Tooltip(
                message: 'Pago realizado con garantía',
                decoration: BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                preferBelow: true,
                verticalOffset: 15,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: paymentDisplay,
                ),
              )
            : paymentDisplay;
      }).toList(),
    );
  }

  Widget _buildSaldoFavor(List<ReporteGeneral> reportes, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final saldoFavor = reportes.first.saldofavor;
    final color = isDarkMode ? Colors.white70 : Colors.grey[800];

    return Text(
      currencyFormat.format(saldoFavor),
      style: TextStyle(
        fontSize: cellTextSize,
        color: color,
      ),
    );
  }

  // Nueva función para Moratorios Generados
  Widget _buildMoratoriosGenerados(List<ReporteGeneral> reportes, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Aquí debes obtener el valor de moratorios generados desde tu modelo
    // Asumiendo que tienes un campo moratoriosGenerados en tu modelo
    final moratoriosGenerados = reportes.first.moratorios; // O el campo correspondiente
    final color = moratoriosGenerados > 0
        ? (isDarkMode ? Colors.red.shade300 : Colors.red)
        : (isDarkMode ? Colors.white70 : Colors.grey[800]);

    return Container(
      child: Text(
        currencyFormat.format(moratoriosGenerados),
        style: TextStyle(
          fontSize: cellTextSize,
          color: color,
          fontWeight: moratoriosGenerados > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // Nueva función para Moratorios Pagados
  Widget _buildMoratoriosPagados(List<ReporteGeneral> reportes, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Aquí debes obtener el valor de moratorios pagados desde tu modelo
    // Asumiendo que tienes un campo moratoriosPagados en tu modelo
    final moratoriosPagados = 0.0; // Reemplaza con el campo correspondiente de tu modelo
    final color = moratoriosPagados > 0
        ? (isDarkMode ? Colors.green.shade300 : Colors.green)
        : (isDarkMode ? Colors.white70 : Colors.grey[800]);

    return Container(
      child: Text(
        currencyFormat.format(moratoriosPagados),
        style: TextStyle(
          fontSize: cellTextSize,
          color: color,
          fontWeight: moratoriosPagados > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTotalsWidget() {
    return Column(
      children: [
        _buildTotalsRow(
          'Totales',
          [
            (value: reporteData!.totalPagoficha, column: 3),
            (value: reporteData!.totalFicha, column: 5),
            (value: reporteData!.totalCapital, column: 6),
            (value: reporteData!.totalInteres, column: 7),
            (value: reporteData!.totalSaldoFavor, column: 8),
            // Totales para las nuevas columnas de moratorios
            (value: reporteData!.saldoMoratorio, column: 9), // Moratorios Generados
            (value: 0.0, column: 10), // Moratorios Pagados - reemplaza con el campo correcto
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
        mainAxisAlignment:
            MainAxisAlignment.start, // Alinea los elementos a la izquierda
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
                message:
                    'La Diferencia es el monto restante para alcanzar el Total Ideal.\n\n'
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
    // Ahora necesitamos 12 columnas en lugar de 10
    List<Widget> cells = List.generate(11, (_) => Expanded(child: Container()));

    cells[0] = Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
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
        cells[val.column] = Expanded(
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