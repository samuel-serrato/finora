import 'package:finora/dialogs/infoCredito.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

class PDFControlPagos {
  // Modern color palette
  static final PdfColor primaryColor = PdfColors.indigo700;
  static final PdfColor accentColor = PdfColors.teal500;
  static final PdfColor lightGrey = PdfColors.grey200;
  static final PdfColor mediumGrey = PdfColors.grey400;
  static final PdfColor darkGrey = PdfColors.grey800;

  static Future<void> generar(Credito credito) async {
    try {
      // 1. Validar permisos
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw 'Se requieren permisos de almacenamiento';
      }

      // 2. Validar formato de fechas
      if (!credito.fechasIniciofin.contains(' - ')) {
        throw 'Formato de fecha inválido. Use "yyyy/MM/dd - yyyy/MM/dd"';
      }

      final partes = credito.fechasIniciofin.split(' - ');
      if (partes.length != 2) {
        throw 'Formato debe ser: fecha_inicio - fecha_fin';
      }

      // 3. Parsear fechas
      final format = DateFormat('yyyy/MM/dd');
      final fechaInicio = format.parse(partes[0].trim());
      final fechaFin = format.parse(partes[1].trim());

      // 4. Generar documento PDF
      final pdf = pw.Document();
      final fechas = _generarFechas(fechaInicio, credito.plazo);

      // 5. Definir estilos de texto
      final titleStyle = pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: primaryColor,
      );

      final sectionTitleStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: darkGrey,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(25),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
          header: (context) => _buildDocumentHeader(credito, titleStyle),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            pw.SizedBox(height: 15),
            _buildGroupInfo(credito, sectionTitleStyle),
            pw.SizedBox(height: 15),
            _buildLoanInfo(credito, sectionTitleStyle),
            pw.SizedBox(height: 25),
            ..._buildPaymentTables(fechas, credito),
            pw.SizedBox(height: 30),
            _buildSignatures(),
          ],
        ),
      );

      // 6. Guardar y compartir PDF
      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'ControlPagos_${credito.folio}.pdf',
      );
    } on FormatException catch (e) {
      throw 'Error en fecha: ${e.message}';
    } catch (e) {
      throw 'Error al generar PDF: ${e.toString()}';
    }
  }

  static List<DateTime> _generarFechas(DateTime startDate, int weeks) {
    return List.generate(weeks, (i) => startDate.add(Duration(days: 7 * i)));
  }

  static pw.Widget _buildDocumentHeader(
      Credito credito, pw.TextStyle titleStyle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: mediumGrey, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CONTROL DE PAGO SEMANAL', style: titleStyle),
              pw.SizedBox(height: 5),
              pw.Text('Folio: ${credito.folio}',
                  style: pw.TextStyle(fontSize: 10, color: darkGrey)),
            ],
          ),
          pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: pw.BorderRadius.circular(30),
            ),
            child: pw.Center(
              child: pw.Text(
                'FINORA',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildGroupInfo(
      Credito credito, pw.TextStyle sectionTitleStyle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: lightGrey.shade(0.3),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Información del Grupo', style: sectionTitleStyle),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _buildInfoColumn('Grupo', credito.nombreGrupo, flex: 2),
              _buildInfoColumn('Ciclo', '01', flex: 1),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildInfoColumn('Presidenta', 'Miriam Yamilet Campos López',
                  flex: 2),
              _buildInfoColumn('Tesorera', 'Adriana Molina Escobar', flex: 2),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildInfoColumn('Asesor', 'Ma. Carmen Fernández León', flex: 2),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLoanInfo(
      Credito credito, pw.TextStyle sectionTitleStyle) {
    final format = NumberFormat("#,##0.00");
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: primaryColor.shade(0.05),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Detalles del Crédito', style: sectionTitleStyle),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _buildInfoColumn('Día de pago', credito.diaPago, flex: 1),
              _buildInfoColumn('Plazo', '${credito.plazo} semanas', flex: 1),
              _buildInfoColumn('Tasa interés', '${credito.ti_semanal}% semanal',
                  flex: 1),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildInfoColumn('Monto desembolsado',
                  '\$${format.format(credito.montoDesembolsado)}',
                  valueStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                    color: accentColor,
                  ),
                  flex: 2),
              _buildInfoColumn('Pago semanal',
                  '\$${format.format(credito.semanalCapital + credito.semanalInteres)}',
                  valueStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                    color: accentColor,
                  ),
                  flex: 1),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoColumn(String label, String value,
      {int flex = 1, pw.TextStyle? valueStyle}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: darkGrey,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: valueStyle ??
                pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildPaymentTables(
      List<DateTime> dates, Credito credito) {
    final blocks = _splitDates(dates, 4);
    final widgets = <pw.Widget>[];

    widgets.add(pw.Text(
      'Registro de Pagos Semanales',
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: darkGrey,
      ),
    ));

    widgets.add(pw.SizedBox(height: 10));

    for (var i = 0; i < blocks.length; i++) {
      widgets.add(_paymentTable(blocks[i], credito));
      if (i < blocks.length - 1) {
        widgets.add(pw.SizedBox(height: 15));
      }
    }

    return widgets;
  }

  static pw.Widget _paymentTable(List<DateTime> dates, Credito credito) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: mediumGrey),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Fechas de pago: ${DateFormat('dd/MM').format(dates.first)} - ${DateFormat('dd/MM').format(dates.last)}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: mediumGrey.shade(0.5), width: 0.5),
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(3),
              for (var i = 0; i < dates.length; i++)
                i + 2: const pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: lightGrey),
                children: [
                  _buildCell('No.', isHeader: true),
                  _buildCell('Integrante',
                      isHeader: true, alignment: pw.Alignment.centerLeft),
                  ...dates.map((d) => _buildCell(
                        DateFormat('dd/MM').format(d),
                        isHeader: true,
                      )),
                ],
              ),
              for (var member in credito.clientesMontosInd)
                pw.TableRow(
                  verticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: [
                    _buildCell(
                        '${credito.clientesMontosInd.indexOf(member) + 1}'),
                    _buildCell(member.nombreCompleto,
                        alignment: pw.Alignment.centerLeft),
                    ...List.generate(
                        dates.length, (_) => _buildEmptyPaymentCell()),
                  ],
                ),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: accentColor.shade(0.1)),
                children: [
                  _buildCell('', isHeader: true),
                  _buildCell('TOTAL SEMANAL',
                      isHeader: true, alignment: pw.Alignment.centerRight),
                  ...List.generate(
                    dates.length,
                    (_) => _buildCell(
                      '\$${NumberFormat("#,##0.00").format(credito.semanalCapital + credito.semanalInteres)}',
                      isHeader: true,
                      textColor: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<List<DateTime>> _splitDates(List<DateTime> dates, int chunkSize) {
    return List.generate(
      (dates.length / chunkSize).ceil(),
      (i) => dates.sublist(
        i * chunkSize,
        i * chunkSize + chunkSize > dates.length
            ? dates.length
            : i * chunkSize + chunkSize,
      ),
    );
  }

  static pw.Widget _buildCell(
    String text, {
    bool isHeader = false,
    pw.Alignment alignment = pw.Alignment.center,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: alignment,
        child: pw.Text(
          text,
          style: isHeader
              ? pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: textColor ?? darkGrey,
                )
              : pw.TextStyle(
                  fontSize: 9,
                  color: textColor ?? darkGrey,
                ),
        ),
      ),
    );
  }

  static pw.Widget _buildEmptyPaymentCell() {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Container(
        height: 18,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: mediumGrey.shade(0.3), width: 0.5),
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildSignatures() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: mediumGrey.shade(0.5), width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'FIRMAS DE CONFORMIDAD',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 25),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _signatureLine('PRESIDENTA'),
              _signatureLine('TESORERA'),
              _signatureLine('ASESOR'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureLine(String role) {
    return pw.Column(
      children: [
        pw.Container(
          width: 120,
          height: 1,
          color: darkGrey,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          role,
          style: pw.TextStyle(
            fontSize: 10,
            color: darkGrey,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: pw.TextStyle(
          fontSize: 9,
          color: mediumGrey,
        ),
      ),
    );
  }
}
