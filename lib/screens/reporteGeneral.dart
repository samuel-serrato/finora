// reporte_general_widget.dart

import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/reporte_general.dart';

class ReporteGeneralWidget extends StatelessWidget {
  // ... (Propiedades de la clase sin cambios)
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

  // ... (Widget build y _buildHeader sin cambios)
  @override
  Widget build(BuildContext context) {
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
          // El título de la columna se mantiene, ya que representa el concepto general
          _buildHeaderCell('Saldo Favor', context),
          _buildHeaderCell('Moratorios\nGenerados', context),
          _buildHeaderCell('Moratorios\nPagados', context),
        ],
      ),
    );
  }

  // ... (El resto de los widgets de construcción de celdas y cuerpo de la tabla se mantienen iguales)
  // ... (Es decir, _buildHeaderCell, _buildDataTableBody, _buildFechasColumn, etc. hasta _buildSaldoFavor)
  Widget _buildHeaderCell(String text, BuildContext context) {
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

  Widget _buildPagosColumn(ReporteGeneral reporte, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white70 : Colors.grey[800];

    if (reporte.depositos.isEmpty) {
      return Text(
        currencyFormat.format(0.0),
        style: TextStyle(
          fontSize: cellTextSize,
          color: textColor,
        ),
      );
    }

    final List<Widget> paymentWidgets = reporte.depositos.expand((deposito) {
      final List<Widget> widgetsParaEsteDeposito = [];
      final bool isGarantia = deposito.garantia == "Si";

      // --- CORRECCIÓN CLAVE ---
      // Movemos la lógica de comparación DENTRO del bloque que procesa el depósito en efectivo.

      // Procesamos el depósito en efectivo (deposito.monto)
      if (deposito.monto > 0) {
        // --- LÓGICA CORREGIDA ---
        // Comparamos el MONTO EN EFECTIVO (deposito.monto) con el DEPOSITO COMPLETO (reporte.depositoCompleto).
        // Esta es la comparación correcta.
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
          // Añadimos el mensaje de depósito completo solo si realmente es diferente
          if (montoDifiereDeCompleto) {
            tooltip = '$tooltip\n$depositoCompletoMsg';
          }
        } else if (montoDifiereDeCompleto) {
          // Si no es garantía, el único motivo para el tooltip es que el monto sea diferente
          tooltip = depositoCompletoMsg;
        }

        widgetsParaEsteDeposito.add(
          _buildPaymentItem(
            context: context,
            amount: deposito.monto,
            backgroundColor: bgColor,
            tooltipMessage: tooltip,
            tooltipColor: bgColor ?? const Color(0xFFE53888),
            // El ícono solo se muestra si el monto en efectivo difiere y no es garantía
            showInfoIcon: montoDifiereDeCompleto && !isGarantia,
          ),
        );
      }

      // Procesamos el pago con saldo a favor (sin cambios aquí)
      if (deposito.favorUtilizado > 0) {
        widgetsParaEsteDeposito.add(
          _buildPaymentItem(
            context: context,
            amount: deposito.favorUtilizado,
            backgroundColor: Colors.green.shade600,
            tooltipMessage: 'Pago con saldo a favor',
            tooltipColor: Colors.green.shade600,
          ),
        );
      }
      return widgetsParaEsteDeposito;
    }).toList();

    if (paymentWidgets.isEmpty) {
      return Text(
        currencyFormat.format(0.0),
        style: TextStyle(
          fontSize: cellTextSize,
          color: textColor,
        ),
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

  // --- MÉTODO REVERTIDO A TU VERSIÓN ORIGINAL ---
  // Este widget ahora vuelve a mostrar la lógica detallada para cada fila individual.
  Widget _buildSaldoFavor(ReporteGeneral reporte, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final deposito =
        reporte.depositos.isNotEmpty ? reporte.depositos.first : null;

    if (deposito == null || deposito.saldofavor == 0) {
      return Text(
        currencyFormat.format(reporte.saldofavor),
        style: TextStyle(
          fontSize: cellTextSize,
          color: isDarkMode ? Colors.white70 : Colors.grey[800],
        ),
      );
    }

    if (deposito.utilizadoPago == 'Si') {
      return Tooltip(
        message:
            'Saldo de ${currencyFormat.format(deposito.saldofavor)} utilizado completamente',
        child: Text(
          currencyFormat.format(deposito.saldofavor),
          style: TextStyle(
            fontSize: cellTextSize,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
            decoration: TextDecoration.lineThrough,
            decorationThickness: 1.0,
          ),
        ),
      );
    }

    if (deposito.saldoUtilizado > 0) {
      return Tooltip(
        message:
            'Se utilizaron ${currencyFormat.format(deposito.saldoUtilizado)} de saldo a favor',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              currencyFormat.format(deposito.saldoDisponible),
              style: TextStyle(
                fontSize: cellTextSize,
                color: isDarkMode ? Colors.white70 : Colors.grey[800],
              ),
            ),
            Text(
              '(de ${currencyFormat.format(deposito.saldofavor)})',
              style: TextStyle(
                fontSize: cellTextSize - 2,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      currencyFormat.format(reporte.saldofavor),
      style: TextStyle(
        fontSize: cellTextSize,
        color: isDarkMode ? Colors.white70 : Colors.grey[800],
      ),
    );
  }

  Widget _buildMoratoriosGenerados(
      ReporteGeneral reporte, BuildContext context) {
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

  // --- WIDGET DE TOTALES MODIFICADO ---
  // Aquí es donde aplicamos la nueva lógica.
  Widget _buildTotalsWidget() {
    if (reporteData == null) {
      return const SizedBox.shrink();
    }

    // Obtenemos los valores de los totales
    final double totalPagosFicha = reporteData!.totalPagoficha;
    final double totalFicha = reporteData!.totalFicha;
    final double totalCapital = reporteData!.totalCapital;
    final double totalInteres = reporteData!.totalInteres;
    final double totalSaldoDisponible = reporteData!.totalSaldoDisponible;
    final double totalSaldoFavorHistorico = reporteData!.totalSaldoFavor;

    // Calculamos los que no vienen en el reporte principal
    double totalSaldoContra = 0.0;
    for (final reporte in listaReportes) {
      final double saldoContra = reporte.montoficha - reporte.pagoficha;
      if (saldoContra > 0) {
        totalSaldoContra += saldoContra;
      }
    }
    final double totalMoratoriosGenerados =
        listaReportes.fold(0.0, (sum, r) => sum + r.moratoriosAPagar);
    final double totalMoratoriosPagados =
        listaReportes.fold(0.0, (sum, r) => sum + r.sumaMoratorio);

    // Un pequeño widget auxiliar para no repetir el estilo del texto del total
    Widget totalText(double value) {
      return Text(
        currencyFormat.format(value),
        style: TextStyle(
          fontSize: cellTextSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    return Column(
      children: [
        _buildTotalsRow(
          'Totales',
          [
            // Las demás columnas usan el widget de texto simple
            (content: totalText(totalPagosFicha), column: 3),
            (content: totalText(totalFicha), column: 5),
            (content: totalText(totalSaldoContra), column: 6),
            (content: totalText(totalCapital), column: 7),
            (content: totalText(totalInteres), column: 8),
            (content: totalText(totalMoratoriosGenerados), column: 10),
            (content: totalText(totalMoratoriosPagados), column: 11),

            // --- CAMBIO CLAVE: La columna 9 ahora tiene un widget complejo ---
            (
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Muestra el total de saldo DISPONIBLE
                  totalText(totalSaldoDisponible),
                  const SizedBox(width: 4),
                  // Muestra un icono con el tooltip del total HISTÓRICO
                  Tooltip(
                    message:
                        'Total generado históricamente: ${currencyFormat.format(totalSaldoFavorHistorico)}',
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.help,
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
              column: 9
            ),
          ],
        ),
      ],
    );
  }

  // --- MÉTODO _buildTotalsRow MODIFICADO para aceptar Widgets ---
  // Ahora es más flexible y puede renderizar cualquier widget, no solo texto.
  Widget _buildTotalsRow(
      String label, List<({Widget content, int column})> items) {
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

    // Itera sobre los items y coloca el WIDGET de contenido en la columna correcta
    for (final item in items) {
      cells[item.column] = Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          alignment: Alignment.center,
          child: item.content, // <-- Usa directamente el widget proporcionado
        ),
      );
    }

    return Container(
      color: const Color(0xFF5162F6),
      child: Row(children: cells),
    );
  }

  // --- _buildTotalsIdealWidget y _buildTotalItem SIN CAMBIOS ---
  // ... (Pega aquí el resto de tu código que no ha sido modificado)
  Widget _buildTotalsIdealWidget() {
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
