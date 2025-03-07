import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:finora/models/reporte_contable.dart';

class PDFExportHelperContable {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF5162F6);
  final ReporteContableData reporteData;
  final NumberFormat currencyFormat;

  PDFExportHelperContable(this.reporteData, this.currencyFormat);

  Future<pw.Document> generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 10),
          pw.ListView.builder(
            itemCount: reporteData.listaGrupos.length,
            itemBuilder: (context, index) {
              final grupo = reporteData.listaGrupos[index];
              return _buildGrupoCard(grupo);
            },
          ),
          _buildTotalesCard(),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Reporte Contable',
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor)),
        pw.Spacer(),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Período: ${reporteData.fechaSemana}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Generado: ${reporteData.fechaActual}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildGrupoCard(ReporteContableGrupo grupo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildGrupoHeader(grupo),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildClientesTable(grupo),
                pw.SizedBox(width: 20),
                _buildFinancialInfoSection(grupo),
                pw.SizedBox(width: 20),
                _buildDepositosSection(grupo.pagoficha),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildGrupoHeader(ReporteContableGrupo grupo) {
    return pw.Row(
      children: [
        pw.Text(grupo.grupos,
            style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor)),
        pw.SizedBox(width: 10),
        pw.Text('(Folio: ${grupo.folio})',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Spacer(),
        pw.Text('Semanas: ${grupo.semanas}',
            style: pw.TextStyle(fontSize: 10)),
        pw.SizedBox(width: 15),
        pw.Text('Semana: ${grupo.pagoPeriodo}',
            style: pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildClientesTable(ReporteContableGrupo grupo) {
    return pw.Container(
      width: 200,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: primaryColor),
            children: [
              _buildHeaderCell('Cliente'),
              _buildHeaderCell('Capital'),
              _buildHeaderCell('Interés'),
              _buildHeaderCell('Total'),
            ],
          ),
          ...grupo.clientes.map((cliente) => pw.TableRow(
                children: [
                  _buildDataCell(cliente.nombreCompleto),
                  _buildDataCell(currencyFormat.format(cliente.periodoCapital)),
                  _buildDataCell(currencyFormat.format(cliente.periodoInteres)),
                  _buildDataCell(currencyFormat.format(cliente.capitalMasInteres)),
                ],
              )),
        ],
      ),
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  pw.Widget _buildDataCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  pw.Widget _buildFinancialInfoSection(ReporteContableGrupo grupo) {
    return pw.Container(
      width: 200,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Información del Crédito',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 8),
          _buildFinancialRow('Monto Solicitado', grupo.montoSolicitado),
          _buildFinancialRow('Monto Desembolsado', grupo.montoDesembolsado),
          _buildFinancialRow('Interés Total', grupo.interesCredito),
          _buildFinancialRow('Monto a Recuperar', grupo.montoARecuperar),
        ],
      ),
    );
  }

  pw.Widget _buildDepositosSection(Pagoficha pagoficha) {
    return pw.Container(
      width: 200,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Depósitos',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 8),
          ...pagoficha.depositos.map((deposito) => pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(_formatDateSafe(deposito.fechaDeposito)),
                      pw.Text(currencyFormat.format(deposito.deposito)),
                    ],
                  ),
                  pw.Divider(),
                ],
              )),
          pw.Text('Total: ${currencyFormat.format(pagoficha.sumaDeposito)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildTotalesCard() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: primaryColor),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Totales', style: pw.TextStyle(color: primaryColor)),
          pw.Row(
            children: [
              _buildTotalItem('Capital', reporteData.totalCapital),
              _buildTotalItem('Interés', reporteData.totalInteres),
              _buildTotalItem('Fichas', reporteData.totalFicha),
              _buildTotalItem('Pagos', reporteData.totalPagoficha),
              _buildTotalItem('Saldo', reporteData.totalSaldoFavor),
              _buildTotalItem('Total', reporteData.totalTotal),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFinancialRow(String label, double value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(currencyFormat.format(value),
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildTotalItem(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(currencyFormat.format(value),
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
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