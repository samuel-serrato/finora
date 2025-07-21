// lib/widgets/rendimiento_semanal_widget.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:finora/providers/theme_provider.dart';

class RendimientoSemanalWidget extends StatefulWidget {
  const RendimientoSemanalWidget({Key? key}) : super(key: key);

  @override
  State<RendimientoSemanalWidget> createState() =>
      _RendimientoSemanalWidgetState();
}

class _RendimientoSemanalWidgetState extends State<RendimientoSemanalWidget> {
  final List<Map<String, dynamic>> datosSemanales = [
    {'semana': 1, 'meta': 1500.0, 'recaudado': 1450.0},
    {'semana': 2, 'meta': 1600.0, 'recaudado': 1750.0},
    {'semana': 3, 'meta': 1550.0, 'recaudado': 1300.0},
    {'semana': 4, 'meta': 1800.0, 'recaudado': 1100.0},
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _buildHeader(isDarkMode),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(
                  top: 24, right: 16, left: 8, bottom: 12),
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              child: BarChart(
                _mainBarData(isDarkMode),
                swapAnimationDuration: const Duration(milliseconds: 250),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      /* decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDarkMode ? Colors.green[800]! : Colors.green[500]!,
            isDarkMode ? Colors.teal[800]! : Colors.teal[400]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ), */
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: Row(
        children: [
          Icon(Icons.insights_rounded,
              color: isDarkMode ? Colors.white : Colors.black, size: 18),
          SizedBox(width: 10),
          Text(
            'Rendimiento Semanal',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  BarChartData _mainBarData(bool isDarkMode) {
    return BarChartData(
      barGroups: _createBarGroups(isDarkMode),
      barTouchData: _getBarTouchData(isDarkMode),
      titlesData: FlTitlesData(
        show: true,
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: _getBottomTitles,
            reservedSize: 38,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: _getLeftTitles,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    );
  }

  List<BarChartGroupData> _createBarGroups(bool isDarkMode) {
    return List.generate(datosSemanales.length, (i) {
      final data = datosSemanales[i];
      final meta = data['meta'];
      final recaudado = data['recaudado'];
      final barColor =
          recaudado >= meta ? Colors.teal[400]! : Colors.orange[400]!;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: meta,
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: recaudado,
            color: barColor,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  // =======================================================================
  // FUNCIÓN CRÍTICA CORREGIDA
  // =======================================================================
  BarTouchData _getBarTouchData(bool isDarkMode) {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (group) => isDarkMode
            ? Colors.black.withOpacity(0.8)
            : const Color(0xFF434242),
        tooltipMargin: 8,
        // La firma correcta con todos los tipos explícitos para evitar errores.
        getTooltipItem: (
          BarChartGroupData group,
          int groupIndex,
          BarChartRodData rod,
          int rodIndex,
        ) {
          final data = datosSemanales[group.x.toInt()];
          final currencyFormat =
              NumberFormat.currency(locale: 'es_MX', symbol: '\$');
          final String title = 'Semana ${data['semana']}';

          // El texto que se mostrará dependerá de la barra tocada (meta o recaudado)
          String touchedRodText;
          if (rodIndex == 0) {
            // Barra de la meta
            touchedRodText = 'Meta: ${currencyFormat.format(rod.toY)}';
          } else {
            // Barra de lo recaudado
            touchedRodText = 'Recaudado: ${currencyFormat.format(rod.toY)}';
          }

          return BarTooltipItem(
            '$title\n',
            const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            children: <TextSpan>[
              TextSpan(
                text: touchedRodText,
                style: TextStyle(
                  color: rod.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  // =======================================================================

  Widget _getBottomTitles(double value, TitleMeta meta) {
    final style = TextStyle(
        color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14);
    return SideTitleWidget(
      meta: meta,
      space: 16,
      child: Text('S${value.toInt() + 1}', style: style),
    );
  }

  Widget _getLeftTitles(double value, TitleMeta meta) {
    final style = TextStyle(
        color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12);
    String text;
    if (value == 0) {
      text = '0';
    } else {
      text = '${(value / 1000).toStringAsFixed(0)}k';
    }
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(text, style: style),
    );
  }
}
