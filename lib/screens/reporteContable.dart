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
        padding: const EdgeInsets.only(top: 10, bottom: 20, left: 20, right: 20),
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
                        const SizedBox(height: 12),
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
    return Card(
      elevation: 1,
      color: Colors.white,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Totales text now as part of the row
              Container(
                padding: const EdgeInsets.only(right: 16),
                child: const Text(
                  'Totales',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                   ),
                ),
              ),
              // Vertical divider between title and items
              Container(
                height: 24,
                width: 1,
                color: Colors.white30,
                margin: const EdgeInsets.only(right: 16),
              ),
              // All summary items in a single row
              _buildSummaryItem('Capital Total', reporteData.totalCapital,
                  isWhiteText: true),
              const SizedBox(width: 24),
              _buildSummaryItem('Interés Total', reporteData.totalInteres,
                  isWhiteText: true),
              const SizedBox(width: 24),
              _buildSummaryItem('Pago Fichas', reporteData.totalPagoficha,
                  isWhiteText: true),
              const SizedBox(width: 24),
              _buildSummaryItem('Saldo Favor', reporteData.totalSaldoFavor,
                  isWhiteText: true),
              const SizedBox(width: 24),
              _buildSummaryItem('Moratorio', reporteData.saldoMoratorio,
                  isWhiteText: true),
              const SizedBox(width: 24),
              _buildSummaryItem(
                'Total General',
                reporteData.totalTotal,
                isWhiteText: true,
              ),
              const SizedBox(width: 24),
              _buildSummaryItem('Total Fichas', reporteData.totalFicha,
                  isWhiteText: true),
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
        return _buildGrupoCard(grupo);
      },
    );
  }

  Widget _buildGrupoCard(ReporteContableGrupo grupo) {
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
                              _buildInfoText('Semanas: ${grupo.semanas}'),
                              _buildInfoText('Tasa: ${grupo.tazaInteres}%'),
                              _buildInfoText('Semana: ${grupo.pagoPeriodo}'),
                              _buildInfoText('Pago: ${grupo.tipopago}'),
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
                // COLUMNA 1: Tabla de clientes (lado izquierdo)
                Expanded(
                  flex: 3,
                  child: _buildClientesSection(grupo),
                ),

                // COLUMNA 2: Información financiera (ahora en medio)
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
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
                            'Información Financiera',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // CAMBIO: De Column a Row para los elementos financieros
                      Row(
                        children: [
                          // Capital Semanal
                          Expanded(
                            child: _buildFinancialInfo(
                                'Capital Semanal', grupo.capitalsemanal),
                          ),
                          const SizedBox(width: 8),

                          // Interés Semanal
                          Expanded(
                            child: _buildFinancialInfo(
                                'Interés Semanal', grupo.interessemanal),
                          ),
                          const SizedBox(width: 8),
                          // Monto Ficha
                          Expanded(
                            child: _buildFinancialInfo(
                                'Monto Ficha', grupo.montoficha),
                          ),
                        ],
                      ),

                      // Espacio para alinear mejor con las otras columnas
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // COLUMNA 3: Información de depósitos (lado derecho)
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildDepositosSection(grupo.pagoficha),
                ),
              ],
            ),
          ],
        ),
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
            const SizedBox(width: 6),
           
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: horizontalScrollController,
            child: DataTable(
              headingRowHeight: 36,
              dataRowHeight: 32,
              horizontalMargin: 12,
              columnSpacing: 16,
              headingRowColor: MaterialStateProperty.all(Colors.white),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontSize: 11,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
              ),
              columns: const [
                DataColumn(
                  label: Text('Nombre Cliente'),
                ),
                DataColumn(
                  label: Text('Capital'),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('Interés'),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('Capital + Interés'),
                  numeric: true,
                ),
              ],
              rows: [
                ...grupo.clientes.map(
                  (cliente) => DataRow(
                    cells: [
                      DataCell(Text(cliente.nombreCompleto)),
                      DataCell(
                          Text(currencyFormat.format(cliente.periodoCapital))),
                      DataCell(
                          Text(currencyFormat.format(cliente.periodoInteres))),
                      DataCell(Text(
                          currencyFormat.format(cliente.capitalMasInteres))),
                    ],
                  ),
                ),
                // Fila de totales
                DataRow(
                  color: MaterialStateProperty.all(
                      const Color.fromRGBO(81, 98, 246, 0.1)),
                  cells: [
                    const DataCell(
                      Text(
                        'Totales',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        currencyFormat.format(totalCapital),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        currencyFormat.format(totalInteres),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        currencyFormat.format(totalGeneral),
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
        ),
      ],
    );
  }

  // SECCIÓN: DEPÓSITOS
  Widget _buildDepositosSection(Pagoficha pagoficha) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Fecha: ${_formatDateSafe(pagoficha.fechaDeposito)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pagoficha.depositos.length,
            itemBuilder: (context, index) {
              final deposito = pagoficha.depositos[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
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
                    // Solo mostrar la etiqueta de garantía cuando sea "Si"
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
              );
            },
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