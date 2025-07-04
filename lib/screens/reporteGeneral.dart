import 'package:finora/providers/theme_provider.dart'; // Asegúrate de que esta ruta sea correcta
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

  @override
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
          _buildHeaderCell('Saldo Favor', context),
          // Columnas de moratorios con los nombres solicitados
          _buildHeaderCell('Moratorios\nGenerados', context),
          _buildHeaderCell('Moratorios\nPagados', context),
        ],
      ),
    );
  }

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

  // --- WIDGET MODIFICADO ---
  // Se ha cambiado la lógica para determinar el estado del círculo.

  // --- WIDGET MODIFICADO: _buildDataTableBody ---
  // Simplificado para iterar directamente sobre la lista de reportes,
  // ya que el servidor ahora agrupa los datos.
  Widget _buildDataTableBody(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Ya no necesitamos groupBy, porque cada 'ReporteGeneral' es una fila.
    return Column(
      children: listaReportes.asMap().entries.map((entry) {
        final index = entry.key;
        final reporte = entry.value;

        // La lógica de estado ahora se basa en el reporte único
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
              // --- CAMBIO: Usamos el nuevo método que muestra la lista de pagos ---
              _buildBodyCell(_buildPagosColumn(reporte, context),
                  alignment: Alignment.center, context: context),
              // --- CAMBIO: Usamos el nuevo método para mostrar las fechas ---
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

  // --- WIDGET NUEVO: Para mostrar la lista de fechas ---
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

  // --- WIDGET MODIFICADO ---
  // Ahora acepta más parámetros para determinar el color y el mensaje del tooltip.
  Widget _buildIndexCircle(int index, bool pagoNoRealizado, bool esIncompleto,
      bool faltaPagoFicha, bool faltaPagoMoratorios, BuildContext context) {
    Color circleColor = Colors.transparent; // Estado por defecto: completo
    String tooltipMessage = 'Pago completo y al corriente';

    if (pagoNoRealizado) {
      circleColor = Colors.red;
      tooltipMessage = 'Pago no realizado';
    } else if (esIncompleto) {
      circleColor = Colors.orange;

      // Construir un mensaje dinámico para el tooltip
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

  // --- WIDGET MODIFICADO: _buildPagosColumn ---
  // Ahora itera sobre la lista de depósitos dentro del reporte.
  Widget _buildPagosColumn(ReporteGeneral reporte, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    if (reporte.depositos.isEmpty) {
      return Text(
        currencyFormat.format(0.0), // Muestra 0 si no hay depósitos
        style: TextStyle(
          fontSize: cellTextSize,
          color: isDarkMode ? Colors.white70 : Colors.grey[800],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      // Itera sobre la lista de depósitos
      children: reporte.depositos.map((deposito) {
        bool isGarantia = deposito.garantia == "Si";
        // La comparación de "depositoCompleto" se hace contra el total
        bool tieneDepositoDiferente =
            reporte.pagoficha != reporte.depositoCompleto;

        Widget paymentDisplay = Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: isGarantia
              ? BoxDecoration(
                  color: const Color(0xFFE53888),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currencyFormat.format(
                    deposito.monto), // Muestra el monto del depósito individual
                style: TextStyle(
                  fontSize: cellTextSize,
                  color: isGarantia
                      ? Colors.white
                      : (isDarkMode ? Colors.white70 : Colors.grey[800]),
                ),
              ),
              if (tieneDepositoDiferente)
                // El tooltip de info solo se muestra si el TOTAL es diferente
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 12,
                    color: isGarantia
                        ? Colors.white70
                        : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                  ),
                ),
            ],
          ),
        );

        // La lógica del Tooltip se mantiene, pero ahora se aplica a cada pago
        if (tieneDepositoDiferente || isGarantia) {
          String tooltipMessage = '';

          if (isGarantia && tieneDepositoDiferente) {
            tooltipMessage =
                'Pago realizado con garantía\nDepósito completo: ${currencyFormat.format(reporte.depositoCompleto)}';
          } else if (isGarantia) {
            tooltipMessage = 'Pago realizado con garantía';
          } else if (tieneDepositoDiferente) {
            tooltipMessage =
                'Depósito completo: ${currencyFormat.format(reporte.depositoCompleto)}';
          }

          return Tooltip(
            message: tooltipMessage,
            decoration: BoxDecoration(
              color: const Color(0xFFE53888),
              borderRadius: BorderRadius.circular(12),
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.help,
              child: paymentDisplay,
            ),
          );
        }

        return paymentDisplay;
      }).toList(),
    );
  }

  Widget _buildSaldoFavor(ReporteGeneral reporte, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final saldoFavor = reporte.saldofavor;
    final color = isDarkMode ? Colors.white70 : Colors.grey[800];

    return Text(
      currencyFormat.format(saldoFavor),
      style: TextStyle(
        fontSize: cellTextSize,
        color: color,
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

  Widget _buildTotalsWidget() {
    // --- INICIO DE LA MODIFICACIÓN ---

    // Primero, nos aseguramos de que reporteData no sea nulo para evitar errores.
    if (reporteData == null) {
      return const SizedBox.shrink(); // No muestra nada si no hay datos.
    }

    // Usamos los totales que ya vienen directamente del servidor.
    // Tu modelo ReporteGeneralData ya debería convertir estos valores a double.
    final double totalPagosFicha = reporteData!.totalPagoficha;
    final double totalFicha = reporteData!.totalFicha;
    final double totalCapital = reporteData!.totalCapital;
    final double totalInteres = reporteData!.totalInteres;
    final double totalSaldoFavor = reporteData!.totalSaldoFavor;

    // --- VALORES QUE SÍ SEGUIMOS CALCULANDO LOCALMENTE ---
    // Estos totales específicos no vienen en el objeto principal del JSON,
    // por lo que es correcto seguir sumándolos desde la lista de grupos.

    // 1. Total Saldo Contra: La lógica original es correcta, ya que solo suma si es positivo.
    double totalSaldoContra = 0.0;
    for (final reporte in listaReportes) {
      final double saldoContra = reporte.montoficha - reporte.pagoficha;
      if (saldoContra > 0) {
        totalSaldoContra += saldoContra;
      }
    }

    // 2. Totales de Moratorios: Estos se calculan sumando los de cada fila.
    final double totalMoratoriosGenerados =
        listaReportes.fold(0.0, (sum, r) => sum + r.moratoriosAPagar);
    final double totalMoratoriosPagados =
        listaReportes.fold(0.0, (sum, r) => sum + r.sumaMoratorio);

    // --- FIN DE LA MODIFICACIÓN ---

    // El resto del widget que muestra la fila no cambia,
    // simplemente usará los valores que acabamos de definir.
    return Column(
      children: [
        _buildTotalsRow(
          'Totales',
          [
            (value: totalPagosFicha, column: 3),
            (value: totalFicha, column: 5),
            (value: totalSaldoContra, column: 6),
            (value: totalCapital, column: 7),
            (value: totalInteres, column: 8),
            (value: totalSaldoFavor, column: 9),
            (value: totalMoratoriosGenerados, column: 10),
            (value: totalMoratoriosPagados, column: 11),
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

  Widget _buildTotalsRow(
      String label, List<({double value, int column})> values) {
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
