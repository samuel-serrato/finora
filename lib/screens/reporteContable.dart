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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildHeader(context),
          _buildTotalsSection(context),
          const SizedBox(height: 20),
          Expanded(
            child: _buildGroupList(), // Cambiamos a lista de grupos
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    return ListView.builder(
      controller: verticalScrollController,
      itemCount: reporteData.listaGrupos.length,
      itemBuilder: (context, index) {
        final grupo = reporteData.listaGrupos[index];
        return _buildGroupCard(grupo);
      },
    );
  }

  Widget _buildGroupCard(ReporteContableGrupo grupo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupHeader(grupo),
            const SizedBox(height: 10),
            _buildClientsList(grupo.clientes),
            const SizedBox(height: 10),
            _buildDepositInfo(grupo.pagoficha),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(ReporteContableGrupo grupo) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grupo.grupos,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                Text(
                  'Folio: ${grupo.folio} | Grupo #${grupo.num}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildEstadoChip(grupo.estado),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 15,
        runSpacing: 8,
        children: [
          _buildGroupDetailItem('Tipo Pago:', grupo.tipopago),
          _buildGroupDetailItem('Semanas:', '${grupo.semanas}'),
          _buildGroupDetailItem('Tasa Interés:', '${grupo.tazaInteres}%'),
          _buildGroupDetailItem('Pago Periodo:', '${grupo.pagoPeriodo}'),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 15,
        runSpacing: 8,
        children: [
          _buildGroupDetailItem('Monto Ficha:', currencyFormat.format(grupo.montoficha)),
          _buildGroupDetailItem('Capital Semanal:', currencyFormat.format(grupo.capitalsemanal)),
          _buildGroupDetailItem('Interés Semanal:', currencyFormat.format(grupo.interessemanal)),
        ],
      ),
    ],
  );
}

Widget _buildGroupDetailItem(String label, String value) {
  return RichText(
    text: TextSpan(
      style: TextStyle(
        color: Colors.grey[700],
        fontSize: 13,
      ),
      children: [
        TextSpan(
          text: label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        TextSpan(text: ' $value'),
      ],
    ),
  );
}

  Widget _buildClientsList(List<Cliente> clientes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clientes (${clientes.length})',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ...clientes.map((cliente) => _buildClientCard(cliente)).toList(),
      ],
    );
  }

  Widget _buildClientCard(Cliente cliente) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cliente.nombreCompleto,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            _buildClientDetails(cliente),
          ],
        ),
      ),
    );
  }

 Widget _buildClientDetails(Cliente cliente) {
  return Wrap(
    spacing: 15,
    runSpacing: 10,
    children: [
      _buildDetailItem('Monto Individual', cliente.montoIndividual),
      _buildDetailItem('Capital/Periodo', cliente.periodoCapital),
      _buildDetailItem('Interés/Periodo', cliente.periodoInteres),
      _buildDetailItem('Capital + Interés', cliente.capitalMasInteres),
      _buildDetailItem('Total Capital', cliente.totalCapital),
      _buildDetailItem('Total Interés', cliente.interesTotal),
      _buildDetailItem('Total Ficha', cliente.totalFicha),
    ],
  );
}

String _formatDateSafe(String dateString) {
  try {
    if (dateString.isEmpty) return 'Fecha no disponible';
    final date = DateTime.parse(dateString);
    return DateFormat('dd/MM/yyyy').format(date);
  } catch (e) {
    print('Error formateando fecha: $dateString. Error: $e');
    return 'Fecha inválida';
  }
}

  Widget _buildDepositInfo(Pagoficha pagoficha) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(),
      const SizedBox(height: 8),
      Text(
        'Información de Depósitos',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Fecha de depósito: ${_formatDateSafe(pagoficha.fechaDeposito)}',
        style: TextStyle(color: Colors.grey[600]),
      ),
      const SizedBox(height: 8),
      ...pagoficha.depositos.map((deposito) => _buildDepositItem(deposito)),
    ],
  );
}

Widget _buildDepositItem(Deposito deposito) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailItem('Depósito', deposito.deposito),
                _buildDetailItem('Saldo', deposito.saldofavor),
                _buildDetailItem('Moratorio', deposito.pagoMoratorio),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Chip(
                  label: Text(deposito.garantia),
                  backgroundColor: deposito.garantia == "Si" 
                      ? Colors.green[50] 
                      : Colors.red[50],
                  labelStyle: TextStyle(
                    color: deposito.garantia == "Si"
                        ? Colors.green[800]
                        : Colors.red[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDetailItem(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          Text(
            currencyFormat.format(value),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoChip(String estado) {
    final isActivo = estado.toLowerCase() == 'activo';
    return Chip(
      label: Text(estado),
      labelStyle: TextStyle(
        color: isActivo ? Colors.green[800] : Colors.red[800],
      ),
      backgroundColor: isActivo ? Colors.green[50] : Colors.red[50],
      side: BorderSide.none,
    );
  }

   Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reporte Contable Financiero',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildInfoItem('Período:', reporteData.fechaSemana),
            const SizedBox(width: 20),
            _buildInfoItem('Generado:', reporteData.fechaActual),
          ],
        ),
      ],
    );
  }


  Widget _buildInfoItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 5),
        Text(value.isNotEmpty ? value : '--/--/----'),
      ],
    );
  }

  Widget _buildTotalsSection(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Wrap(
          spacing: 30,
          runSpacing: 15,
          children: [
            _buildTotalItem('Capital Total:', reporteData.totalCapital),
            _buildTotalItem('Interés Total:', reporteData.totalInteres),
            _buildTotalItem('Pago Fichas:', reporteData.totalPagoficha),
            _buildTotalItem('Saldo a Favor:', reporteData.totalSaldoFavor),
            _buildTotalItem('Moratorio:', reporteData.saldoMoratorio),
            _buildTotalItem('Total General:', reporteData.totalTotal),
            _buildTotalItem('Total Fichas:', reporteData.totalFicha),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalItem(String label, double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          currencyFormat.format(value),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

}
