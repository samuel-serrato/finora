import 'package:finora/models/reporte_contable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    return Scaffold(
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
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Contenido principal
                        Expanded(
                          child: _buildGruposList(),
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
                    reporteData.fechaSemana,
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
                    reporteData.fechaActual,
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

  // SECCIÓN: TARJETA DE TOTALES (renombrado de _buildSummaryCard)
  Widget _buildTotalesCard(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Ocupa todo el ancho disponible
      child: Card(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment
                .spaceBetween, // Separa el texto "Totales" y los elementos de resumen
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
                      color: Colors.white30,
                      margin: const EdgeInsets.only(right: 16),
                    ),
                    // Todos los elementos de resumen en una fila
                    _buildSummaryItem('Capital Total', reporteData.totalCapital,
                        isWhiteText: true),
                    const SizedBox(width: 24),
                    _buildSummaryItem('Interés Total', reporteData.totalInteres,
                        isWhiteText: true),
                    const SizedBox(width: 24),
                    _buildSummaryItem('Monto Fichas', reporteData.totalFicha,
                        isWhiteText: true),
                    const SizedBox(width: 24),
                    _buildSummaryItem('Pago Fichas', reporteData.totalPagoficha,
                        isWhiteText: true),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                        'Saldo Favor', reporteData.totalSaldoFavor,
                        isWhiteText: true),
                    const SizedBox(width: 24),
                    _buildSummaryItem('Moratorios', reporteData.saldoMoratorio,
                        isWhiteText: true),

                    const SizedBox(width: 100),
                    _buildSummaryItem(
                      'Total Ideal',
                      reporteData.totalTotal,
                      isWhiteText: true,
                    ),
                    const SizedBox(width: 10),
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
                      preferBelow:
                          false, // Evita que el tooltip se oculte debajo
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.black38,
                          size:
                              18, // Tamaño ligeramente mayor para mejor visibilidad
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _buildSummaryItem(
                      'Diferencia',
                      reporteData.restante,
                      isWhiteText: true,
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
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.black38,
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

  // The _buildSummaryItem method remains the same
  Widget _buildSummaryItem(String label, double value,
      {bool isPrimary = false, bool isWhiteText = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: isPrimary ? primaryColor : Colors.grey[300],
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
                color: Colors.grey[600],
              ),
            ),
            Text(
              currencyFormat.format(value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isPrimary ? primaryColor : Colors.grey[800],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // SECCIÓN: LISTA DE GRUPOS
  Widget _buildGruposList() {
    return ListView.builder(
      controller: verticalScrollController,
      itemCount: reporteData.listaGrupos.length,
      itemBuilder: (context, index) {
        final grupo = reporteData.listaGrupos[index];
        return Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            child: _buildGrupoCard(context, grupo));
      },
    );
  }

  Widget _buildGrupoCard(context, ReporteContableGrupo grupo) {
    final isActivo = grupo.estado.toLowerCase() == 'activo';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: Colors.grey[400]!,
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
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            children: [
                              //_buildInfoText('Tasa: ${grupo.tazaInteres}%'),
                              _buildInfoText('Pago: ${grupo.tipopago}'),
                              _buildInfoText('Plazo: ${grupo.plazo}'),
                              _buildInfoText(
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

            const Divider(height: 16, thickness: 0.5),

            // Nueva disposición: Row con 3 columnas
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COLUMNA 1: Tabla de clientes (lado izquierdo) - EXPANSIBLE
                Expanded(
                  child: _buildClientesSection(grupo),
                ),

                // Separador (mínimo)
                const SizedBox(width: 20),

                // COLUMNA 2: Información financiera - ANCHO FIJO
                // Actualización de la COLUMNA 2: Información financiera
                Container(
                  width: 300, // Ancho fijo reducido
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título de sección financiera
                      Row(
                        children: [
                          Icon(Icons.attach_money,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildFinancialInfoText(
                                      'Garantía', grupo.garantia),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _buildFinancialInfoCompact(
                                      'Tasa', grupo.tazaInteres,
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
                                      'Monto Solicitado',
                                      grupo.montoSolicitado),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _buildFinancialInfoCompact(
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
                                  child: _buildFinancialInfoCompact(
                                      'Interés Total', grupo.interesCredito),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _buildFinancialInfoCompact(
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
                                '${grupo.tipopago == "SEMANAL" ? "Capital Semanal" : "Capital Quincenal"}',
                                grupo.capitalsemanal),
                          ),
                          const SizedBox(width: 4),
                          // Interés (Semanal/Quincenal según tipopago)
                          Expanded(
                            child: _buildFinancialInfo(
                                '${grupo.tipopago == "SEMANAL" ? "Interés Semanal" : "Interés Quincenal"}',
                                grupo.interessemanal),
                          ),
                          const SizedBox(width: 4),
                          // Monto Ficha (no cambia)
                          Expanded(
                            child: _buildFinancialInfo(
                                'Monto Ficha', grupo.montoficha),
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
                Container(
                  width: 300, // Ancho fijo reducido
                  child: _buildDepositosSection(
                      grupo.pagoficha, grupo.restanteFicha, grupo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Método para mostrar información financiera de manera compacta
  Widget _buildFinancialInfoCompact(String label, double value,
      {bool isPercentage = false}) {
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
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${currencyFormat.format(value)}${isPercentage ? '%' : ''}', // Agrega % si es necesario
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

// Método nuevo para valores de texto (String)
  Widget _buildFinancialInfoText(String label, String value) {
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
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

// Método para mostrar etiquetas tipo "pill"
  Widget _buildInfoPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey[900],
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Versión para usar en Row (horizontal)
  Widget _buildFinancialInfo(String label, double value) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: primaryColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // SECCIÓN: CLIENTES
  Widget _buildClientesSection(ReporteContableGrupo grupo) {
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
                  color: Colors.white,
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(
                          currencyFormat.format(cliente.periodoCapital),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(
                          currencyFormat.format(cliente.periodoInteres),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(
                          currencyFormat.format(cliente.capitalMasInteres),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
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
  Widget _buildDepositosSection(
      Pagoficha pagoficha, double restanteFicha, ReporteContableGrupo grupo) {
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
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 6),

        Container(
          constraints: const BoxConstraints(
              maxHeight: 220), // Reducido para acomodar el nuevo elemento
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pagoficha.depositos.length,
            itemBuilder: (context, index) {
              final deposito = pagoficha.depositos[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    // Encabezado con la fecha de depósito
                    Container(
                      width: double.infinity, // Ocupa todo el ancho
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF5162F6)
                            .withOpacity(0.2), // Fondo azul claro
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ), // Bordes redondeados solo arriba
                      ),
                      child: Align(
                        alignment:
                            Alignment.center, // Alinea la fecha a la derecha
                        child: Text(
                          'Fecha depósito: ${_formatDateSafe(deposito.fechaDeposito)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black, // Texto azul oscuro
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
                              _buildDepositoDetail(
                                'Depósito',
                                deposito.deposito,
                                Icons.arrow_downward,
                              ),
                              _buildDepositoDetail(
                                'Saldo a Favor',
                                deposito.saldofavor,
                                Icons.account_balance_wallet,
                              ),
                              _buildDepositoDetail(
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
        // Mostrar suma total de depósitos - Ya existe pero mejoraremos su visualización
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
                  color: const Color.fromARGB(255, 39, 48, 135),
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
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Restante ficha:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange[900],
                ),
              ),
              Text(
                currencyFormat.format(restanteFicha),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[200]!),
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
                      'Saldo Global',
                      grupo.saldoGlobal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildFinancialInfoCompact(
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

  Widget _buildDepositoDetail(String label, double value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: Colors.grey[600]),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Text(
          currencyFormat.format(value),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
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
