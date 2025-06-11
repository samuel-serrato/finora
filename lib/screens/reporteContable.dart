import 'package:finora/models/reporte_contable.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReporteContableWidget extends StatelessWidget {
  final ReporteContableData reporteData;
  final NumberFormat currencyFormat;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;

  const ReporteContableWidget({
    required this.reporteData,
    required this.currencyFormat,
    required this.verticalScrollController,
    required this.horizontalScrollController,
  });

  // Color principal definido como constante para fácil referencia
  static const Color primaryColor = Color(0xFF5162F6);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        padding:
            const EdgeInsets.only(top: 10, bottom: 20, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header fuera del container principal
            _buildHeader(context),
            const SizedBox(height: 10),
            // Container principal con bordes redondeados y sombra
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        // Contenido principal
                        Expanded(
                          child: _buildGruposList(context),
                        ),
                        const SizedBox(height: 0),
                        // La tarjeta de totales ahora va al final
                        _buildTotalesCard(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SECCIÓN: CABECERA CON TÍTULO Y FECHAS
  Widget _buildHeader(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

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
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  Text(
                    reporteData.fechaSemana,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: isDarkMode ? Colors.grey[300] : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generado: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  Text(
                    reporteData.fechaActual,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: isDarkMode ? Colors.grey[300] : Colors.black,
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

  // SECCIÓN: TARJETA DE TOTALES
  Widget _buildTotalesCard(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 1,
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Texto "Totales" a la izquierda
              const Text(
                'Totales',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              // Elementos de resumen a la derecha
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Vertical divider entre el texto "Totales" y los elementos de resumen
                    Container(
                      height: 24,
                      width: 1,
                      color: isDarkMode ? Colors.grey[700] : Colors.white30,
                      margin: const EdgeInsets.only(right: 16),
                    ),
                    // Todos los elementos de resumen en una fila
                    _buildSummaryItem(
                        context, 'Capital Total', reporteData.totalCapital),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                        context, 'Interés Total', reporteData.totalInteres),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                        context, 'Monto Fichas', reporteData.totalFicha),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                        context, 'Pago Fichas', reporteData.totalPagoficha),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                        context, 'Saldo Favor', reporteData.totalSaldoFavor),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                        context, 'Moratorios', reporteData.saldoMoratorio),

                    const SizedBox(width: 100),
                    _buildSummaryItem(
                      context,
                      'Total Ideal',
                      reporteData.totalTotal,
                      isPrimary: true,
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'El Total Ideal representa el total de:\n\n'
                          '• Monto ficha\n\n'
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
                      preferBelow: false,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          Icons.info_outline,
                          color: isDarkMode ? Colors.grey[400] : Colors.black38,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                      context,
                      'Diferencia',
                      reporteData.restante,
                      isPrimary: true,
                    ),
                    const SizedBox(width: 10),
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
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          Icons.info_outline,
                          color: isDarkMode ? Colors.grey[400] : Colors.black38,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                      context,
                      'Total Bruto',
                      reporteData.sumaTotalCapMoraFav,
                      isPrimary: true,
                    ),
                    const SizedBox(width: 10),
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
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.all(12),
                      preferBelow: false,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          Icons.info_outline,
                          color: isDarkMode ? Colors.grey[400] : Colors.black38,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modified _buildSummaryItem to include dark mode support
  Widget _buildSummaryItem(BuildContext context, String label, double value,
      {bool isPrimary = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: isPrimary
                ? primaryColor
                : (isDarkMode ? Colors.grey[600] : Colors.grey[300]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              currencyFormat.format(value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isPrimary
                    ? primaryColor
                    : (isDarkMode ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // SECCIÓN: LISTA DE GRUPOS
  Widget _buildGruposList(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    if (reporteData.listaGrupos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No hay datos para mostrar',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: verticalScrollController,
      itemCount: reporteData.listaGrupos.length,
      itemBuilder: (context, index) {
        final grupo = reporteData.listaGrupos[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildGrupoCard(context, grupo),
        );
      },
    );
  }

  Widget _buildGrupoCard(BuildContext context, ReporteContableGrupo grupo) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isActivo = grupo.estado.toLowerCase() == 'activo';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del grupo
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  grupo.grupos,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(Folio: ${grupo.folio})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            children: [
                              _buildInfoText(
                                  context, 'Pago: ${grupo.tipopago}'),
                              _buildInfoText(context, 'Plazo: ${grupo.plazo}'),
                              _buildInfoText(context,
                                  'Periodo Pago: ${grupo.pagoPeriodo}'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ],
            ),

            Divider(
              height: 16,
              thickness: 0.5,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),

            // Nueva disposición: Row con 3 columnas
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COLUMNA 1: Tabla de clientes (lado izquierdo) - EXPANSIBLE
                Expanded(
                  child: _buildClientesSection(grupo, context),
                ),

                // Separador (mínimo)
                const SizedBox(width: 20),

                // COLUMNA 2: Información financiera - ANCHO FIJO
                SizedBox(
                  width: 300, // Ancho fijo reducido
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título de sección financiera
                      Row(
                        children: [
                          const Icon(Icons.attach_money,
                              size: 14, color: primaryColor),
                          const SizedBox(width: 6),
                          const Text(
                            'Información del Crédito',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Información de garantía y montos
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildFinancialInfoText(
                                      context, 'Garantía', grupo.garantia),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _buildFinancialInfoCompact(
                                      context, 'Tasa', grupo.tazaInteres,
                                      isPercentage: true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildFinancialInfoCompact(
                                      context,
                                      'Monto Solicitado',
                                      grupo.montoSolicitado),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _buildFinancialInfoCompact(
                                      context,
                                      'Monto Desembolsado',
                                      grupo.montoDesembolsado),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildFinancialInfoCompact(context,
                                      'Interés Total', grupo.interesCredito),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _buildFinancialInfoCompact(
                                      context,
                                      'Monto a Recuperar',
                                      grupo.montoARecuperar),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Elementos financieros por período
                      Row(
                        children: [
                          // Capital (Semanal/Quincenal según tipopago)
                          Expanded(
                            child: _buildFinancialInfo(
                                context,
                                '${grupo.tipopago == "SEMANAL" ? "Capital Semanal" : "Capital Quincenal"}',
                                grupo.capitalsemanal),
                          ),
                          const SizedBox(width: 4),
                          // Interés (Semanal/Quincenal según tipopago)
                          Expanded(
                            child: _buildFinancialInfo(
                                context,
                                '${grupo.tipopago == "SEMANAL" ? "Interés Semanal" : "Interés Quincenal"}',
                                grupo.interessemanal),
                          ),
                          const SizedBox(width: 4),
                          // Monto Ficha (no cambia)
                          Expanded(
                            child: _buildFinancialInfo(
                                context, 'Monto Ficha', grupo.montoficha),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

// Con esta nueva sección:
                      Row(
                        children: [
                          // Moratorios Generados
                          Expanded(
                            child: _buildFinancialInfo(
                              context,
                              'Moratorios Generados',
                              grupo.moratorios.moratoriosAPagar ??
                                  0.0, // Asegúrate de tener este campo en tu modelo
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Moratorios Pagados
                          Expanded(
                            child: _buildFinancialInfo(
                              context,
                              'Moratorios Pagados',
                              grupo.pagoficha.sumaMoratorio ??
                                  0.0, // Asegúrate de tener este campo en tu modelo
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Separador (mínimo)
                const SizedBox(width: 20),

                // COLUMNA 3: Información de depósitos - ANCHO FIJO
                SizedBox(
                  width: 300, // Ancho fijo reducido
                  child: _buildDepositosSection(
                      context, grupo.pagoficha, grupo.restanteFicha, grupo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Método para mostrar información financiera de manera compacta
  Widget _buildFinancialInfoCompact(
      BuildContext context, String label, double value,
      {bool isPercentage = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              '${currencyFormat.format(value)}${isPercentage ? '%' : ''}', // Agrega % si es necesario
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: isDarkMode ? Colors.grey[300] : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

// Método nuevo para valores de texto (String)
  Widget _buildFinancialInfoText(
      BuildContext context, String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: isDarkMode ? Colors.grey[300] : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

// Método para mostrar etiquetas tipo "pill"
  Widget _buildInfoPill(
      BuildContext context, String label, String value, Color color) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Ajustar el color para modo oscuro si es necesario
    final pillColor =
        isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1);
    final borderColor =
        isDarkMode ? color.withOpacity(0.4) : color.withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText(BuildContext context, String text) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: isDarkMode ? Colors.grey[300] : Colors.grey[900],
        fontWeight: FontWeight.w500,
      ),
    );
  }

// Versión para usar en Row (horizontal)
  Widget _buildFinancialInfo(BuildContext context, String label, double value) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color:
                  primaryColor, // Keeping this color the same for both themes
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // SECCIÓN: CLIENTES
  Widget _buildClientesSection(ReporteContableGrupo grupo, context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    // Calcular totales
    double totalCapital = 0;
    double totalInteres = 0;
    double totalGeneral = 0;

    for (var cliente in grupo.clientes) {
      totalCapital += cliente.periodoCapital;
      totalInteres += cliente.periodoInteres;
      totalGeneral += cliente.capitalMasInteres;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, size: 14, color: primaryColor),
            const SizedBox(width: 6),
            Text(
              'Clientes (${grupo.clientes.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          // Aquí está el cambio principal, en vez de usar DataTable que tiene espaciado
          // predeterminado, usaremos una tabla personalizada
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(4), // Nombre del cliente - ancho mayor
              1: FlexColumnWidth(1.5), // Capital
              2: FlexColumnWidth(1.5), // Interés
              3: FlexColumnWidth(1.5), // Capital + Interés
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey[300]!),
            ),
            children: [
              // Encabezado
              TableRow(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.white70,
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Nombre Cliente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      'Capital',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      'Interés',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      'Capital + Interés',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              // Filas de datos
              ...grupo.clientes.map((cliente) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text(
                          cliente.nombreCompleto,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(
                          currencyFormat.format(cliente.periodoCapital),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(
                          currencyFormat.format(cliente.periodoInteres),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(
                          currencyFormat.format(cliente.capitalMasInteres),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  )),
              // Fila de totales
              TableRow(
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(81, 98, 246, 0.1),
                ),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Totales',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      currencyFormat.format(totalCapital),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      currencyFormat.format(totalInteres),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      currencyFormat.format(totalGeneral),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
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

  // SECCIÓN: DEPÓSITOS
  // SECCIÓN: DEPÓSITOS
  Widget _buildDepositosSection(BuildContext context, Pagoficha pagoficha,
      double restanteFicha, ReporteContableGrupo grupo) {
    // Get theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

      // --- NUEVA LÍNEA ---
  // Calculamos la condición UNA SOLA VEZ para todo el grupo de depósitos.
  // Comparamos el total de depósitos con el total esperado.
  final bool mostrarIconoInfoParaEsteGrupo = pagoficha.sumaDeposito != pagoficha.depositoCompleto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, size: 14, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  'Depósitos',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            Text(
              'Fecha programada: ${_formatDateSafe(pagoficha.fechasPago)}',
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 6),

        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pagoficha.depositos.length,
            itemBuilder: (context, index) {
              final deposito = pagoficha.depositos[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color:
                          isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    // Encabezado con la fecha de depósito
                    Container(
                      width: double.infinity, // Ocupa todo el ancho
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF5162F6).withOpacity(0.2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Fecha depósito: ${_formatDateSafe(deposito.fechaDeposito)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode ? Colors.grey[200] : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // Contenido de la tarjeta
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Asumiendo que 'reporte' y 'deposito' están disponibles en este contexto

                              _buildDepositoDetail(
                              context,
                              'Depósito',
                              deposito.deposito,
                              Icons.arrow_downward,
                              depositoCompleto: pagoficha.depositoCompleto,
                              // --- LÍNEA MODIFICADA ---
                              // Pasamos el resultado del cálculo que hicimos arriba.
                              mostrarIconoInfo: mostrarIconoInfoParaEsteGrupo,
                            ),
                              _buildDepositoDetail(
                                context,
                                'Saldo a Favor',
                                deposito.saldofavor,
                                Icons.account_balance_wallet,
                              ),
                              _buildDepositoDetail(
                                context,
                                'Moratorio',
                                deposito.pagoMoratorio,
                                Icons.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Mostrar la etiqueta de garantía si es "Si"
                          if (deposito.garantia == "Si")
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFFE53888),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Garantía',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Mostrar suma total de depósitos
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total depósitos:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
              Text(
                currencyFormat.format(pagoficha.sumaDeposito),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),

        // Añadir el restanteFicha
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.orange[900]!.withOpacity(0.2)
                : Colors.orange[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: isDarkMode ? Colors.orange[800]! : Colors.orange[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Restante ficha:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[900],
                ),
              ),
              Text(
                currencyFormat.format(restanteFicha),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[900],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen Global',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildFinancialInfoCompact(
                      context,
                      'Saldo Global',
                      grupo.saldoGlobal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildFinancialInfoCompact(
                      context,
                      'Restante Global',
                      grupo.restanteGlobal,
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

  Widget _buildDepositoDetail(
    BuildContext context,
    String label,
    double value,
    IconData icon, {
    double? depositoCompleto,
    // --- NUEVO PARÁMETRO ---
  // Por defecto es false para no romper otras llamadas.
  bool mostrarIconoInfo = false,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;


  // --- LÓGICA MODIFICADA ---
  // Ya no calculamos la condición aquí. Simplemente usamos el valor que nos pasan.
  final bool mostrarInfoAdicional = mostrarIconoInfo;
  
    // El widget base que se va a construir.
    Widget detailWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila para el label y el ícono principal (sin cambios)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 10,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        // 2. CAMBIO PRINCIPAL: Envolvemos el monto y el nuevo ícono en un Row.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // El texto con el monto del depósito
            Text(
              currencyFormat.format(value),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: isDarkMode ? Colors.grey[200] : Colors.black87,
              ),
            ),
            // 3. Ícono de información condicional.
            //    Se muestra solo si la condición es verdadera.
            if (mostrarInfoAdicional)
              Padding(
                padding: const EdgeInsets.only(left: 4.0), // Un poco de espacio
                child: Icon(
                  Icons.info_outline, // El ícono que pediste
                  size: 12, // Tamaño sutil
                  // Colores consistentes con tu primer ejemplo
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
          ],
        ),
      ],
    );

    // 4. La lógica del Tooltip sigue siendo la misma.
    //    Si hay info adicional, envolvemos todo el widget en el Tooltip.
    if (mostrarInfoAdicional) {
      return Tooltip(
        message:
            'Depósito completo: ${currencyFormat.format(depositoCompleto!)}',
        decoration: BoxDecoration(
          color: const Color(0xFFE53888),
          borderRadius: BorderRadius.circular(12),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.help,
          child: detailWidget,
        ),
      );
    }

    // Si no, se devuelve el widget sin Tooltip ni ícono de info.
    return detailWidget;
  }

  String _formatDateSafe(String dateString) {
    try {
      if (dateString.isEmpty) return 'N/A';
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}
