import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CalendarioPagos extends StatefulWidget {
  final bool isDarkMode;

  const CalendarioPagos({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  State<CalendarioPagos> createState() => _CalendarioPagosState();
}

class _CalendarioPagosState extends State<CalendarioPagos> {
  DateTime selectedDate = DateTime.now();
  CalendarView currentView = CalendarView.monthly;
  DateTime currentMonth = DateTime.now();

  // Datos estáticos de ejemplo
  final Map<DateTime, List<PagoGrupo>> pagosEjemplo = {
    DateTime(2025, 7, 19): [
      PagoGrupo(
          nombreGrupo: "Grupo Las Flores", monto: 1500.00, tipo: "Grupal"),
      PagoGrupo(
          nombreGrupo: "María González", monto: 800.00, tipo: "Individual"),
    ],
    DateTime(2025, 7, 20): [
      PagoGrupo(nombreGrupo: "Grupo Los Pinos", monto: 2200.00, tipo: "Grupal"),
    ],
    DateTime(2025, 7, 21): [
      PagoGrupo(nombreGrupo: "Carlos Ruiz", monto: 650.00, tipo: "Individual"),
      PagoGrupo(nombreGrupo: "Grupo San José", monto: 1800.00, tipo: "Grupal"),
      PagoGrupo(nombreGrupo: "Ana Torres", monto: 900.00, tipo: "Individual"),
    ],
    DateTime(2025, 7, 22): [
      PagoGrupo(nombreGrupo: "Grupo Unidos", monto: 3200.00, tipo: "Grupal"),
    ],
    DateTime(2025, 7, 25): [
      PagoGrupo(nombreGrupo: "Luis Morales", monto: 750.00, tipo: "Individual"),
    ],
    DateTime(2025, 7, 28): [
      PagoGrupo(nombreGrupo: "Grupo Esperanza", monto: 1950.00, tipo: "Grupal"),
      PagoGrupo(
          nombreGrupo: "Patricia Vega", monto: 850.00, tipo: "Individual"),
    ],
  };

  @override
  Widget build(BuildContext context) {
    // FIX 1: Envolver el Card en un widget Flexible o Expanded si es necesario,
    // pero como el padre ya es un Expanded en HomeScreen, está bien.
    // La clave es la estructura interna del Card.
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(
          horizontal: 0), // Eliminado del Container padre
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
              color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildViewSelector(),
            // FIX 2: Envolver el contenido del Agenda en un Expanded.
            // Esto hace que ocupe todo el espacio vertical restante dentro de la Card.
            Expanded(
              child: _buildCalendarContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 5),
      /* decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        gradient: LinearGradient(
          colors: [
            widget.isDarkMode ? Colors.blueGrey[700]! : const Color(0xFF5162F6),
            widget.isDarkMode ? Colors.blueGrey[800]! : const Color(0xFF6A88F7),
          ],
        ),
      ), */
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousPeriod,
            icon: Icon(Icons.chevron_left,  color: isDarkMode ? Colors.white : Colors.black, size: 28),
          ),
          Column(
            children: [
              Text(
                'Agenda de Pagos',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _getHeaderTitle(),
                style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _nextPeriod,
            icon:
           Icon(Icons.chevron_right,  color: isDarkMode ? Colors.white : Colors.black, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      padding: const EdgeInsets.all(15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildViewButton('Día', CalendarView.daily, Icons.today),
          _buildViewButton('Semana', CalendarView.weekly, Icons.view_week),
          _buildViewButton('Mes', CalendarView.monthly, Icons.calendar_month),
        ],
      ),
    );
  }

  Widget _buildViewButton(String title, CalendarView view, IconData icon) {
    final isSelected = currentView == view;
    return GestureDetector(
      onTap: () => setState(() => currentView = view),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: isSelected
              ? const Color(0xFF5162F6)
              : (widget.isDarkMode ? Colors.grey[700] : Colors.grey[200]),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : (widget.isDarkMode ? Colors.white70 : Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (widget.isDarkMode ? Colors.white70 : Colors.grey[600]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarContent() {
    switch (currentView) {
      case CalendarView.daily:
        return _buildDailyView();
      case CalendarView.weekly:
        return _buildWeeklyView();
      case CalendarView.monthly:
        return _buildMonthlyView();
    }
  }

  Widget _buildDailyView() {
    final pagosDelDia = pagosEjemplo[DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day)] ??
        [];

    return Container(
      // FIX 3: Eliminar la altura fija 'height: 400'.
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(selectedDate),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: pagosDelDia.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay pagos programados',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: pagosDelDia.length,
                    itemBuilder: (context, index) {
                      return _buildPagoCard(pagosDelDia[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyView() {
    final startOfWeek =
        selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

    return Container(
      // FIX 4: Eliminar la altura fija 'height: 400'.
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Text(
            'Semana del ${DateFormat('d MMM', 'es_ES').format(startOfWeek)} - ${DateFormat('d MMM', 'es_ES').format(startOfWeek.add(Duration(days: 6)))}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: 7,
              itemBuilder: (context, index) {
                final day = startOfWeek.add(Duration(days: index));
                final pagosDelDia =
                    pagosEjemplo[DateTime(day.year, day.month, day.day)] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color:
                        widget.isDarkMode ? Colors.grey[700] : Colors.grey[50],
                    border: Border.all(
                      color: _isSameDay(day, selectedDate)
                          ? const Color(0xFF5162F6)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('EEEE d', 'es_ES').format(day),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          if (pagosDelDia.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF5162F6),
                              ),
                              child: Text(
                                '${pagosDelDia.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (pagosDelDia.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${pagosDelDia.length} pago${pagosDelDia.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyView() {
    return Container(
      // FIX 5: Eliminar la altura fija 'height: 400'.
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // No es necesario el Text del mes/año aquí, ya está en el header
          // Días de la semana
          Row(
            children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          // Agenda mensual
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: _getDaysInMonth(currentMonth) +
                  _getFirstDayOfMonth(currentMonth) -
                  1,
              itemBuilder: (context, index) {
                final firstDay = _getFirstDayOfMonth(currentMonth);
                if (index < firstDay - 1) {
                  return Container(); // Días vacíos
                }

                final day = index - firstDay + 2;
                final date =
                    DateTime(currentMonth.year, currentMonth.month, day);
                final pagos = pagosEjemplo[date] ?? [];
                final isSelected = _isSameDay(date, selectedDate);
                final isToday = _isSameDay(date, DateTime.now());

                return GestureDetector(
                  onTap: () => setState(() => selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? const Color(0xFF5162F6)
                          : isToday
                              ? const Color(0xFF5162F6).withOpacity(0.2)
                              : null,
                      border: pagos.isNotEmpty
                          ? Border.all(
                              color: const Color(0xFF6BC950), width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (widget.isDarkMode
                                    ? Colors.white
                                    : Colors.black87),
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (pagos.isNotEmpty)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF6BC950),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Resumen del día seleccionado
          _buildSelectedDaySummary(),
        ],
      ),
    );
  }

  // ... (El resto del código permanece igual)

  Widget _buildSelectedDaySummary() {
    final pagos = pagosEjemplo[DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day)] ??
        [];

    if (pagos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[100],
        ),
        child: Text(
          'No hay pagos para ${DateFormat('d MMM', 'es_ES').format(selectedDate)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    }

    final totalMonto = pagos.fold<double>(0, (sum, pago) => sum + pago.monto);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[100],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${DateFormat('d MMM', 'es_ES').format(selectedDate)} - ${pagos.length} pago${pagos.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            'Total: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(totalMonto)}',
            style: TextStyle(
              color: const Color(0xFF6BC950),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagoCard(PagoGrupo pago) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: widget.isDarkMode ? Colors.grey[700] : Colors.white,
        border: Border(
          left: BorderSide(
            width: 4,
            color: pago.tipo == 'Grupal'
                ? const Color(0xFF5162F6)
                : const Color(0xFF4ECDC4),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            pago.tipo == 'Grupal' ? Icons.group : Icons.person,
            color: pago.tipo == 'Grupal'
                ? const Color(0xFF5162F6)
                : const Color(0xFF4ECDC4),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pago.nombreGrupo,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  pago.tipo,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.currency(symbol: '\$', decimalDigits: 2)
                .format(pago.monto),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: const Color(0xFF6BC950),
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    switch (currentView) {
      case CalendarView.daily:
        return DateFormat('MMMM yyyy', 'es_ES').format(selectedDate);
      case CalendarView.weekly:
        final startOfWeek =
            selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
        return DateFormat('MMMM yyyy', 'es_ES').format(startOfWeek);
      case CalendarView.monthly:
        return DateFormat('yyyy').format(currentMonth);
    }
  }

  void _previousPeriod() {
    setState(() {
      switch (currentView) {
        case CalendarView.daily:
          selectedDate = selectedDate.subtract(const Duration(days: 1));
          break;
        case CalendarView.weekly:
          selectedDate = selectedDate.subtract(const Duration(days: 7));
          break;
        case CalendarView.monthly:
          currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
          selectedDate =
              DateTime(currentMonth.year, currentMonth.month, selectedDate.day);
          break;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (currentView) {
        case CalendarView.daily:
          selectedDate = selectedDate.add(const Duration(days: 1));
          break;
        case CalendarView.weekly:
          selectedDate = selectedDate.add(const Duration(days: 7));
          break;
        case CalendarView.monthly:
          currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
          selectedDate =
              DateTime(currentMonth.year, currentMonth.month, selectedDate.day);
          break;
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }
}

enum CalendarView { daily, weekly, monthly }

class PagoGrupo {
  final String nombreGrupo;
  final double monto;
  final String tipo;

  PagoGrupo({
    required this.nombreGrupo,
    required this.monto,
    required this.tipo,
  });
}
