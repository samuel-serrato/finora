// lib/widgets/creditos_mora_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:finora/providers/theme_provider.dart';

class CreditosEnMoraWidget extends StatelessWidget {
  const CreditosEnMoraWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    // --- Datos de ejemplo ---
    final List<Map<String, dynamic>> creditosEnMora = [
      {'cliente': 'Ana García', 'dias_atraso': 15, 'monto': 1250.75},
      {'cliente': 'Luis Martínez', 'dias_atraso': 8, 'monto': 800.00},
      {'cliente': 'Sofía Hernández', 'dias_atraso': 32, 'monto': 2500.50},
      {'cliente': 'Carlos Rodríguez', 'dias_atraso': 5, 'monto': 550.20},
    ];

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias, // Importante para que el gradiente no se salga
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          // --- 1. Encabezado estilizado ---
          _buildHeader(isDarkMode),

          // --- 2. Contenido en un Expanded para evitar overflows ---
          Expanded(
            child: Container(
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              child: creditosEnMora.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: creditosEnMora.length,
                      itemBuilder: (context, index) {
                        return _buildMoraListItem(creditosEnMora[index], isDarkMode);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget para el encabezado (estilo del calendario) ---
  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      /* decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDarkMode ? Colors.red[800]! : Colors.red[500]!,
            isDarkMode ? Colors.orange[900]! : Colors.orange[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ), */
              color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: isDarkMode ? Colors.white : Colors.black, size: 18),
          SizedBox(width: 10),
          Text(
            'Créditos en Mora',
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

  // --- Widget para cada elemento de la lista (estilo del calendario) ---
  Widget _buildMoraListItem(Map<String, dynamic> credito, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        border: Border(
          left: BorderSide(
            width: 4,
            color: Colors.red[400]!,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin_circle_outlined, color: Colors.red[400], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credito['cliente'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${credito['dias_atraso']} días de atraso',
                  style: TextStyle(
                    color: Colors.red[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.currency(symbol: '\$').format(credito['monto']),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
  
  // --- Widget para cuando la lista está vacía ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            'Sin créditos en mora',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}