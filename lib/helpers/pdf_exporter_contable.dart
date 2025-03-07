import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:finora/models/reporte_contable.dart';

class PDFExportHelperContable {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF5162F6);
  static const PdfColor warningColor = PdfColor.fromInt(0xFFF59E0B);
  final ReporteContableData reporteData;
  final NumberFormat currencyFormat;

  PDFExportHelperContable(this.reporteData, this.currencyFormat);

  Future<pw.Document> generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10), // Reducido margen general
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 8), // Reducido espacio
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
      margin: const pw.EdgeInsets.only(bottom: 10), // Reducido margen inferior
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(8), // Reducido padding interno
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildGrupoHeader(grupo),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.max, // Asegura que use todo el ancho disponible
              children: [
                _buildClientesTable(grupo),
                pw.SizedBox(width: 10), // Reducido espacio
                _buildFinancialInfoSection(grupo),
                pw.SizedBox(width: 10), // Reducido espacio
                _buildDepositosSection(grupo.pagoficha, grupo.restanteFicha),
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
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor)),
        pw.SizedBox(width: 9),
        pw.Text('(Folio: ${grupo.folio})',
            style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
        pw.Spacer(),
        pw.Text('Semanas: ${grupo.semanas}',
            style: pw.TextStyle(fontSize: 6)),
        pw.SizedBox(width: 15),
        pw.Text('Semana: ${grupo.pagoPeriodo}',
            style: pw.TextStyle(fontSize: 6)),
        pw.SizedBox(width: 15),
        pw.Text('Pago: ${grupo.tipopago}',
            style: pw.TextStyle(fontSize: 6)),
      ],
    );
  }

  pw.Widget _buildClientesTable(ReporteContableGrupo grupo) {
    return pw.Expanded(
      flex: 50, // Ajustado el ratio de ancho para balancear las columnas
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
          // Añadir fila de totales
          _buildTotalesRow(grupo.clientes),
        ],
      ),
    );
  }

  pw.TableRow _buildTotalesRow(List<Cliente> clientes) {
    double totalCapital = 0;
    double totalInteres = 0;
    double totalGeneral = 0;

    for (var cliente in clientes) {
      totalCapital += cliente.periodoCapital;
      totalInteres += cliente.periodoInteres;
      totalGeneral += cliente.capitalMasInteres;
    }

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: const PdfColor(0.95, 0.95, 1.0)),
      children: [
        _buildTotalCell('Totales'),
        _buildTotalCell(currencyFormat.format(totalCapital)),
        _buildTotalCell(currencyFormat.format(totalInteres)),
        _buildTotalCell(currencyFormat.format(totalGeneral)),
      ],
    );
  }

  pw.Widget _buildTotalCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: pw.FontWeight.bold,
        ),
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
          fontSize: 6,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
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
        style: const pw.TextStyle(fontSize: 6),
      ),
    );
  }

  pw.Widget _buildFinancialInfoSection(ReporteContableGrupo grupo) {
    return pw.Expanded(
      flex: 20, // Ajustado el ratio de ancho para balancear las columnas
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Información del Crédito',
              style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 4), // Reducido espacio
          
          // Fila para Garantía y Tasa
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildFinancialRow('Garantía ', grupo.garantia, isText: true),
              _buildFinancialRow('Tasa ', grupo.tazaInteres, isPercentage: true),
            ],
          ),
          pw.SizedBox(height: 2), // Espaciado reducido entre filas

          _buildFinancialRow('Monto Solicitado', grupo.montoSolicitado),
          pw.SizedBox(height: 2), // Espaciado reducido entre filas
          _buildFinancialRow('Monto Desembolsado', grupo.montoDesembolsado),
          pw.SizedBox(height: 2), // Espaciado reducido entre filas
          _buildFinancialRow('Interés Total', grupo.interesCredito),
          pw.SizedBox(height: 2), // Espaciado reducido entre filas
          _buildFinancialRow('Monto a Recuperar', grupo.montoARecuperar),
          
          pw.SizedBox(height: 6), // Espacio para la siguiente sección
          
          // Sección de Resumen Global
          pw.Text('Resumen Global',
              style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 4),
          _buildFinancialRow('Saldo Global', grupo.saldoGlobal),
          pw.SizedBox(height: 2),
          _buildFinancialRow('Restante Global', grupo.restanteGlobal),
          
          pw.SizedBox(height: 6), // Espacio para la siguiente sección
          
          // Sección de información semanal
          pw.Text('Información Semanal',
              style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 4),
          _buildFinancialRow('Capital Semanal', grupo.capitalsemanal),
          pw.SizedBox(height: 2),
          _buildFinancialRow('Interés Semanal', grupo.interessemanal),
          pw.SizedBox(height: 2),
          _buildFinancialRow('Monto Ficha', grupo.montoficha),
        ],
      ),
    );
  }

  pw.Widget _buildDepositosSection(Pagoficha pagoficha, double restanteFicha) {
  return pw.Expanded(
    flex: 30,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Depósitos',
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.Text(
              'Fecha prog: ${_formatDateSafe(pagoficha.fechasPago)}',
              style: const pw.TextStyle(fontSize: 6),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ...pagoficha.depositos.map((deposito) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      // Encabezado con la fecha de depósito
                      pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: pw.BoxDecoration(
    color: PdfColor.fromInt(0xFFdce0fd),
    borderRadius: const pw.BorderRadius.only(
      topLeft: pw.Radius.circular(4),
      topRight: pw.Radius.circular(4),
    ),
  ),
  child: pw.Text(
    'Fecha depósito: ${_formatDateSafe(deposito.fechaDeposito)}',
    style: pw.TextStyle(
      fontSize: 6,
      color: PdfColors.black,
    ),
    textAlign: pw.TextAlign.center, // Centra el texto
  ),
),

                      // Contenido de la tarjeta
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          children: [
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                _buildDepositoDetailPDF(
                                  'Depósito',
                                  deposito.deposito,
                                ),
                                _buildDepositoDetailPDF(
                                  'Saldo a Favor',
                                  deposito.saldofavor,
                                ),
                                _buildDepositoDetailPDF(
                                  'Moratorio',
                                  deposito.pagoMoratorio,
                                ),
                              ],
                            ),
                            if (deposito.garantia == "Si")
                              pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.start,
  children: [
    pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE53888),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Garantía',
        style: pw.TextStyle(
          fontSize: 6,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ),
  ],
),

                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            // Total de depósitos
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFedeffe),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total depósitos:',
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF5465f6),
                    ),
                  ),
                  pw.Text(
                    currencyFormat.format(pagoficha.sumaDeposito),
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF5465f6),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            // Restante ficha
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFfff3e0),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Restante ficha:',
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFFe9661d),
                    ),
                  ),
                  pw.Text(
                    currencyFormat.format(restanteFicha),
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFFe9661d),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// Función auxiliar para construir detalles del depósito en el PDF
pw.Widget _buildDepositoDetailPDF(String label, double value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 6),
      ),
      pw.Text(
        currencyFormat.format(value),
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

  pw.Widget _buildTotalesCard() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: primaryColor),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10), // Reducido padding
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Totales', style: pw.TextStyle(color: PdfColors.white, fontSize: 9)),
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

  pw.Widget _buildFinancialRow(String label, dynamic value, {bool isText = false, bool isPercentage = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 6)),
        isText 
            ? pw.Text(value.toString(), style: const pw.TextStyle(fontSize: 6))
            : pw.Text(
                '${isText ? value.toString() : currencyFormat.format(value)}${isPercentage ? '%' : ''}',
                style: const pw.TextStyle(fontSize: 6)
              ),
      ],
    );
  }

  pw.Widget _buildTotalItem(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6), // Reducido espacio
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6, color: PdfColors.white)),
          pw.Text(currencyFormat.format(value),
              style: pw.TextStyle(
                  fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
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