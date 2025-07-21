// lib/widgets/gestion_visitas_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finora/providers/theme_provider.dart';

class GestionVisitasWidget extends StatelessWidget {
  const GestionVisitasWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    // --- Datos de ejemplo ---
    final List<Map<String, dynamic>> visitasHoy = [
      {
        'nombre': 'Grupo "Las Emprendedoras"',
        'hora': '10:30 AM',
        'tipo': 'Grupal'
      },
      {'nombre': 'Jorge Ramirez', 'hora': '12:00 PM', 'tipo': 'Individual'},
      {
        'nombre': 'Grupo "Avanzando Juntos"',
        'hora': '02:45 PM',
        'tipo': 'Grupal'
      },
      {
        'nombre': 'Maria Fernanda López',
        'hora': '04:00 PM',
        'tipo': 'Individual'
      },
    ];

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          // --- 1. Encabezado estilizado ---
          _buildHeader(isDarkMode),

          // --- 2. Contenido en un Expanded ---
          Expanded(
            child: Container(
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              child: visitasHoy.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: visitasHoy.length,
                      itemBuilder: (context, index) {
                        return _buildVisitaListItem(
                            visitasHoy[index], isDarkMode);
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
            isDarkMode ? Colors.blue[800]! : Colors.blue[500]!,
            isDarkMode ? Colors.teal[800]! : Colors.teal[400]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ), */
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: Row(
        children: [
          Icon(Icons.route_rounded,
              color: isDarkMode ? Colors.white : Colors.black, size: 18),
          SizedBox(width: 10),
          Text(
            'Gestión de Visitas (Hoy)',
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
  Widget _buildVisitaListItem(Map<String, dynamic> visita, bool isDarkMode) {
    final bool isGrupal = visita['tipo'] == 'Grupal';
    final Color color =
        isGrupal ? const Color(0xFF5162F6) : const Color(0xFF4ECDC4);
    final IconData icon = isGrupal ? Icons.group : Icons.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        border: Border(
          left: BorderSide(
            width: 4,
            color: color,
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
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visita['nombre'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  visita['tipo'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            visita['hora'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color:
                  isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87,
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
          Icon(Icons.calendar_today_rounded, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            'Sin visitas para hoy',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
