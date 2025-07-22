// reporte_general_widget.dart

import 'package:finora/providers/theme_provider.dart'; // Asegúrate de que la ruta sea correcta
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/reporte_general.dart'; // Asegúrate de que la ruta sea correcta

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

  static const Color primaryColor = Color(0xFF5162F6);

  // --- NINGÚN CAMBIO EN build, _buildHeader, _buildDataTableHeader ---
  // (Estos widgets se mantienen igual)
  @override
  Widget build(BuildContext context) {
    // ... (Tu código aquí, sin cambios)
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20, left: 20, right: 20),
      child: Column(
        children: [
          if (reporteData != null) _buildHeader(context),
          const SizedBox(height: 10),
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
    // ... (Tu código aquí, sin cambios)
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

  Widget _buildDataTableHeader(BuildContext context) {
    // ... (Tu código aquí, sin cambios)
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
          _buildHeaderCell('Monto Ficha', context),
          _buildHeaderCell('Saldo Contra', context),
          _buildHeaderCell('Capital', context),
          _buildHeaderCell('Interés', context),
          _buildHeaderCell('Saldo Favor', context),
          _buildHeaderCell('Moratorios\nGenerados', context),
          _buildHeaderCell('Moratorios\nPagados', context),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, BuildContext context) {
    // ... (Tu código aquí, sin cambios)
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

  // --- NINGÚN CAMBIO en _buildDataTableBody, _buildFechasColumn, etc. hasta llegar a _buildPagosColumn ---
  Widget _buildDataTableBody(BuildContext context) {
    // ... (Tu código aquí, sin cambios)
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      children: listaReportes.asMap().entries.map((entry) {
        final index = entry.key;
        final reporte = entry.value;

        final totalPagos = reporte.pagoficha;
        final montoFicha = reporte.montoficha;
        final moratoriosGenerados = reporte.moratoriosAPagar;
        final moratoriosPagados = reporte.sumaMoratorio;
        final moratoriosPendientes = moratoriosGenerados - moratoriosPagados;

        final bool pagoNoRealizado = totalPagos == 0.0;
        final bool fichaCubierta = totalPagos >= montoFicha;
        final bool moratoriosCubiertos = moratoriosPendientes <= 0;
        final bool esCompleto = fichaCubierta && moratoriosCubiertos;
        final bool esIncompleto = !pagoNoRealizado && !esCompleto;

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
                  _buildIndexCircle(index, pagoNoRealizado, esIncompleto,
                      !fichaCubierta, !moratoriosCubiertos, context),
                  alignment: Alignment.center,
                  context: context),
              _buildBodyCell(reporte.tipoPago,
                  context: context, alignment: Alignment.center),
              _buildBodyCell(reporte.grupos,
                  context: context, alignment: Alignment.center),
              _buildBodyCell(_buildPagosColumn(reporte, context),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(_buildFechasColumn(reporte, context),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(currencyFormat.format(reporte.montoficha),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(_buildSaldoContra(reporte, context),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(currencyFormat.format(reporte.capitalsemanal),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(currencyFormat.format(reporte.interessemanal),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(_buildSaldoFavor(reporte, context),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(_buildMoratoriosGenerados(reporte, context),
                  alignment: Alignment.center, context: context),
              _buildBodyCell(_buildMoratoriosPagados(reporte, context),
                  alignment: Alignment.center, context: context),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFechasColumn(ReporteGeneral reporte, BuildContext context) {
    // ... (Tu código aquí, sin cambios)
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    if (reporte.depositos.isEmpty) {
      return Text(
        'Pendiente',
        style: TextStyle(
          fontSize: cellTextSize,
          color: isDarkMode ? Colors.white70 : Colors.grey[800],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: reporte.depositos.map((deposito) {
        return Text(
          deposito.fecha,
          style: TextStyle(
            fontSize: cellTextSize,
            color: isDarkMode ? Colors.white70 : Colors.grey[800],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaldoContra(ReporteGeneral reporte, BuildContext context) {
    // ... (Tu código aquí, sin cambios)
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final double montoFicha = reporte.montoficha;
    final double totalPagos = reporte.pagoficha;
    final double saldoContra = montoFicha - totalPagos;
    final String displayValue = saldoContra > 0
        ? currencyFormat.format(saldoContra)
        : currencyFormat.format(0.0);

    return Text(
      displayValue,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: cellTextSize,
        color: saldoContra > 0
            ? (isDarkMode ? Colors.red[300] : Colors.red[700])
            : (isDarkMode ? Colors.white70 : Colors.grey[800]),
        fontWeight: saldoContra > 0 ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildBodyCell(dynamic content,
      {Alignment alignment = Alignment.centerLeft,
      required BuildContext context}) {
    // ... (Tu código aquí, sin cambios)
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

  Widget _buildIndexCircle(int index, bool pagoNoRealizado, bool esIncompleto,
      bool faltaPagoFicha, bool faltaPagoMoratorios, BuildContext context) {
    // ... (Tu código aquí, sin cambios)
    Color circleColor = Colors.transparent;
    String tooltipMessage = 'Pago completo y al corriente';

    if (pagoNoRealizado) {
      circleColor = Colors.red;
      tooltipMessage = 'Pago no realizado';
    } else if (esIncompleto) {
      circleColor = Colors.orange;
      List<String> razones = [];
      if (faltaPagoFicha) {
        razones.add('monto de la ficha no cubierto');
      }
      if (faltaPagoMoratorios) {
        razones.add('aún debe moratorios');
      }
      tooltipMessage = 'Pago incompleto: ${razones.join(' y ')}.';
    }

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = circleColor == Colors.transparent
        ? (isDarkMode ? Colors.white : Colors.black)
        : Colors.white;

    return Tooltip(
      message: tooltipMessage,
      decoration: BoxDecoration(
        color: circleColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
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

  // --- CAMBIO 1: LÓGICA DE _buildPagosColumn ACTUALIZADA ---
  Widget _buildPagosColumn(ReporteGeneral reporte, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white70 : Colors.grey[800];

    // Si no hay depósitos Y no se usó saldo a favor, se muestra cero.
    if (reporte.depositos.isEmpty && reporte.favorUtilizado == 0) {
      return Text(
        currencyFormat.format(0.0),
        style: TextStyle(fontSize: cellTextSize, color: textColor),
      );
    }

    List<Widget> paymentWidgets = [];

    // Primero, procesamos todos los depósitos en efectivo (vengan o no de garantía)
    for (var deposito in reporte.depositos) {
      if (deposito.monto > 0) {
        final bool isGarantia = deposito.garantia == "Si";
        const double epsilon = 0.01;
        final bool montoDifiereDeCompleto = reporte.depositoCompleto > 0 &&
            (deposito.monto - reporte.depositoCompleto).abs() > epsilon;

        final String depositoCompletoMsg =
            'Depósito completo: ${currencyFormat.format(reporte.depositoCompleto)}';

        String? tooltip;
        Color? bgColor;

        if (isGarantia) {
          bgColor = const Color(0xFFE53888);
          tooltip = 'Pago realizado con garantía';
          if (montoDifiereDeCompleto) {
            tooltip = '$tooltip\n$depositoCompletoMsg';
          }
        } else if (montoDifiereDeCompleto) {
          tooltip = depositoCompletoMsg;
        }

        paymentWidgets.add(
          _buildPaymentItem(
            context: context,
            amount: deposito.monto,
            backgroundColor: bgColor,
            tooltipMessage: tooltip,
            tooltipColor: bgColor ?? const Color(0xFFE53888),
            showInfoIcon: montoDifiereDeCompleto && !isGarantia,
          ),
        );
      }
    }

    // Segundo, y de forma separada, añadimos el pago con saldo a favor si existió.
    if (reporte.favorUtilizado > 0) {
      paymentWidgets.add(
        _buildPaymentItem(
          context: context,
          amount: reporte.favorUtilizado,
          backgroundColor: Colors.green.shade600,
          tooltipMessage: 'Pago con saldo a favor',
          tooltipColor: Colors.green.shade600,
        ),
      );
    }

    if (paymentWidgets.isEmpty) {
      return Text(
        currencyFormat.format(0.0),
        style: TextStyle(fontSize: cellTextSize, color: textColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: paymentWidgets,
    );
  }

  Widget _buildPaymentItem({
    required BuildContext context,
    required double amount,
    Color? backgroundColor,
    String? tooltipMessage,
    Color? tooltipColor,
    bool showInfoIcon = false,
  }) {
    // ... (Tu código aquí, sin cambios)
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = (backgroundColor != null)
        ? Colors.white
        : (isDarkMode ? Colors.white70 : Colors.grey[800]);

    Widget paymentDisplay = Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: backgroundColor != null
          ? BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: cellTextSize,
              color: textColor,
            ),
          ),
          if (showInfoIcon)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.info_outline,
                size: 10,
                color: textColor,
              ),
            ),
        ],
      ),
    );

    if (tooltipMessage != null && tooltipMessage.isNotEmpty) {
      return Tooltip(
        message: tooltipMessage,
        decoration: BoxDecoration(
          color: tooltipColor ?? backgroundColor ?? Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.help,
          child: paymentDisplay,
        ),
      );
    }
    return paymentDisplay;
  }

  // --- CAMBIO 2: LÓGICA DE _buildSaldoFavor TOTALMENTE REESCRITA ---
  Widget _buildSaldoFavor(ReporteGeneral reporte, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Si no se generó saldo a favor en esta ficha, simplemente se muestra 0.00
    if (reporte.saldofavor == 0) {
      return Text(
        currencyFormat.format(0.0),
        style: TextStyle(
          fontSize: cellTextSize,
          color: isDarkMode ? Colors.white70 : Colors.grey[800],
        ),
      );
    }

    // Caso 1: Se generó saldo a favor y se utilizó por completo en este mismo pago.
    if (reporte.utilizadoPago == 'Si') {
      return Tooltip(
        message:
            'Saldo de ${currencyFormat.format(reporte.saldofavor)} generado y utilizado completamente en este pago.',
        child: Text(
          currencyFormat.format(reporte.saldofavor),
          style: TextStyle(
            fontSize: cellTextSize,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
            decoration: TextDecoration.lineThrough, // Tachado
            decorationThickness: 1.0,
          ),
        ),
      );
    }

    // Caso 2: Se generó saldo a favor y se utilizó una parte.
    if (reporte.saldoUtilizado > 0) {
      return Tooltip(
        message:
            'De un saldo total de ${currencyFormat.format(reporte.saldofavor)}, se utilizaron ${currencyFormat.format(reporte.saldoUtilizado)}.',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Muestra el saldo que quedó disponible
            Text(
              currencyFormat.format(reporte.saldoDisponible),
              style: TextStyle(
                fontSize: cellTextSize,
                color: isDarkMode ? Colors.white70 : Colors.grey[800],
              ),
            ),
            // Muestra de cuánto era el saldo original
            Text(
              '(de ${currencyFormat.format(reporte.saldofavor)})',
              style: TextStyle(
                fontSize: cellTextSize - 2,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Caso 3 (Default): Se generó saldo a favor y no se usó nada.
    return Text(
      currencyFormat.format(reporte.saldofavor),
      style: TextStyle(
        fontSize: cellTextSize,
        color: isDarkMode ? Colors.white70 : Colors.grey[800],
      ),
    );
  }

  // --- NINGÚN CAMBIO en _buildMoratoriosGenerados y _buildMoratoriosPagados ---
  Widget _buildMoratoriosGenerados(
      ReporteGeneral reporte, BuildContext context) {
    // ... (Tu código aquí, sin cambios)
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final moratoriosGenerados = reporte.moratoriosAPagar;

    final color = moratoriosGenerados > 0
        ? (isDarkMode ? Colors.red.shade300 : Colors.red)
        : (isDarkMode ? Colors.white70 : Colors.grey[800]);

    return Text(
      currencyFormat.format(moratoriosGenerados),
      style: TextStyle(
        fontSize: cellTextSize,
        color: color,
        fontWeight:
            moratoriosGenerados > 0 ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildMoratoriosPagados(ReporteGeneral reporte, BuildContext context) {
    // ... (Tu código aquí, sin cambios)
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final moratoriosPagados = reporte.sumaMoratorio;

    final color = moratoriosPagados > 0
        ? (isDarkMode ? Colors.green.shade300 : Colors.green.shade700)
        : (isDarkMode ? Colors.white70 : Colors.grey[800]);

    return Text(
      currencyFormat.format(moratoriosPagados),
      style: TextStyle(
        fontSize: cellTextSize,
        color: color,
        fontWeight: moratoriosPagados > 0 ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  // --- CAMBIO 3: LÓGICA DE _buildTotalsWidget REFINADA (basada en tu buena propuesta) ---
  Widget _buildTotalsWidget() {
    if (reporteData == null) {
      return const SizedBox.shrink();
    }

    // Los totales principales vienen del reporte general
    final double totalPagosFicha = reporteData!.totalPagoficha;
    final double totalFicha = reporteData!.totalFicha;
    final double totalCapital = reporteData!.totalCapital;
    final double totalInteres = reporteData!.totalInteres;
    final double totalSaldoDisponible = reporteData!.totalSaldoDisponible;
    final double totalSaldoFavorHistorico = reporteData!.totalSaldoFavor;

    // Calculamos manualmente los que no vienen agregados
    double totalSaldoContra = listaReportes.fold(0.0, (sum, r) {
      final saldo = r.montoficha - r.pagoficha;
      return sum + (saldo > 0 ? saldo : 0);
    });
    final double totalMoratoriosGenerados =
        listaReportes.fold(0.0, (sum, r) => sum + r.moratoriosAPagar);
    final double totalMoratoriosPagados =
        listaReportes.fold(0.0, (sum, r) => sum + r.sumaMoratorio);

    Widget totalText(double value) {
      return Text(
        currencyFormat.format(value),
        style:  TextStyle(
          fontSize: cellTextSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    return _buildTotalsRow(
      'Totales',
      [
        (content: totalText(totalPagosFicha), column: 3),
        (content: totalText(totalFicha), column: 5),
        (content: totalText(totalSaldoContra), column: 6),
        (content: totalText(totalCapital), column: 7),
        (content: totalText(totalInteres), column: 8),
        (
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              totalText(totalSaldoDisponible),
              const SizedBox(width: 4),
              Tooltip(
                message:
                    'Total de saldo a favor generado históricamente: ${currencyFormat.format(totalSaldoFavorHistorico)}',
                child: const MouseRegion(
                  cursor: SystemMouseCursors.help,
                  child:
                      Icon(Icons.info_outline, size: 14, color: Colors.white),
                ),
              )
            ],
          ),
          column: 9
        ),
        (content: totalText(totalMoratoriosGenerados), column: 10),
        (content: totalText(totalMoratoriosPagados), column: 11),
      ],
    );
  }

  Widget _buildTotalsRow(
      String label, List<({Widget content, int column})> items) {
    // ... (Tu código aquí, sin cambios)
    List<Widget> cells = List.generate(12, (_) => Expanded(child: Container()));

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

    for (final item in items) {
      cells[item.column] = Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          alignment: Alignment.center,
          child: item.content,
        ),
      );
    }

    return Container(
      color: const Color(0xFF5162F6),
      child: Row(children: cells),
    );
  }

  // --- NINGÚN CAMBIO en _buildTotalsIdealWidget y _buildTotalItem ---
  Widget _buildTotalsIdealWidget() {
    // ... (Tu código aquí, sin cambios)
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 109, 121, 232),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTotalItem('Total Ideal', reporteData!.totalTotal),
              const SizedBox(width: 8),
              Tooltip(
                message: 'El Total Ideal representa el total de:\n\n'
                    '• Monto ficha\n\n'
                    'Es el monto objetivo que se debe alcanzar.',
                decoration: BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child:
                      Icon(Icons.info_outline, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(width: 50),
          Row(
            children: [
              _buildTotalItem('Diferencia', reporteData!.restante),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    'La Diferencia es el monto restante para alcanzar el Total Ideal.\n\n'
                    'Se calcula restando el total de pagos recibidos del Total Ideal.',
                decoration: BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child:
                      Icon(Icons.info_outline, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(width: 50),
          Row(
            children: [
              _buildTotalItem('Total Bruto', reporteData!.sumaTotalCapMoraFav),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    'El Total Bruto representa la suma completa de todos los conceptos:\n\n'
                    '• Total Pagos\n'
                    '• Moratorios\n'
                    '• Saldos a favor\n\n'
                    'Es el total acumulado antes de aplicar cualquier ajuste o validación.',
                decoration: BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child:
                      Icon(Icons.info_outline, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, double value) {
    // ... (Tu código aquí, sin cambios)
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
}
