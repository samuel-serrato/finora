import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:finora/models/reporte_general.dart';
import 'package:flutter/services.dart' show rootBundle;

class ExportHelper {
  
  static void mostrarDialogoError(BuildContext context, String mensaje) {
    // Mostrar un SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );}
  static Future<void> exportToPdf({
    required BuildContext context,
    required ReporteGeneralData? reporteData,
    required List<ReporteGeneral> listaReportes,
    required DateTimeRange? selectedDateRange,
    required String? selectedReportType,
    required NumberFormat currencyFormat,
  }) async {
    if (reporteData == null || selectedDateRange == null) {
      mostrarDialogoError(context, 'No hay datos para exportar');
      return;
    }

    try {
      final doc = pw.Document();

      void buildPdfPages() {
        final headers = [
          '#',
          'Tipo Pago',
          'Grupos',
          'Folio',
          'Pago Ficha',
          'Fecha Depósito',
          'Monto Ficha',
          'Capital',
          'Interés',
          'Saldo',
          'Moratorios'
        ];

        final groupedReportes = groupBy(listaReportes, (r) => r.idficha);
        final groups = groupedReportes.entries.toList();

        doc.addPage(
          pw.MultiPage(
            margin: const pw.EdgeInsets.all(20),
            header: (context) => _buildPdfHeader(
              selectedReportType: selectedReportType,
              selectedDateRange: selectedDateRange,
            ),
            footer: (context) => _buildPdfFooter(context),
            build: (context) => [
              _buildPdfTable(headers, groups, currencyFormat),
              _buildPdfTotals(reporteData, currencyFormat),
            ],
          ),
        );
      }

      buildPdfPages();

      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar Reporte',
        fileName:
            'reporte_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );

      if (output != null) {
        final file = File(output);
        await file.writeAsBytes(await doc.save());
        await OpenFile.open(file.path);
      }
    } catch (e) {
      mostrarDialogoError(context, 'Error al exportar: ${e.toString()}');
    }
  }

  static pw.Widget _buildPdfTable(
  List<String> headers, List<MapEntry<String, List<ReporteGeneral>>> data, NumberFormat currencyFormat) {
  int currentNumber = 1; // Inicializa el contador

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColor.fromHex('#3D3D3D')),
    columnWidths: {
      0: const pw.FlexColumnWidth(0.5),
      1: const pw.FlexColumnWidth(1.2),
      2: const pw.FlexColumnWidth(2.5),
      3: const pw.FlexColumnWidth(1.5),
      4: const pw.FlexColumnWidth(1.5),
      5: const pw.FlexColumnWidth(1.5),
      6: const pw.FlexColumnWidth(1.5),
      7: const pw.FlexColumnWidth(1.5),
      8: const pw.FlexColumnWidth(1.5),
      9: const pw.FlexColumnWidth(1.5),
      10: const pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#5162F6')),
        children: headers.map((header) => _buildPdfHeaderCell(header)).toList(),
      ),
      ...data.map((group) {
        final groupData = group.value;
        final totalPagos = groupData.fold(0.0, (sum, r) => sum + r.pagoficha);
        final pagoIncompleto = totalPagos < groupData.first.montoficha && totalPagos > 0;

        final row = pw.TableRow(
          decoration: _rowDecoration(groupData, pagoIncompleto),
          children: [
            _buildPdfCell(currentNumber.toString(), isNumeric: true), // Usa el contador actual
            _buildPdfCell(groupData.first.tipoPago),
            _buildPdfCell(groupData.first.grupos),
            _buildPdfCell(groupData.first.folio),
            _buildPagosColumn(groupData, currencyFormat),
            _buildPdfCell(groupData.map((r) => r.fechadeposito).join('\n')),
            _buildPdfCell(currencyFormat.format(groupData.first.montoficha), isNumeric: true),
            _buildPdfCell(currencyFormat.format(groupData.first.capitalsemanal), isNumeric: true),
            _buildPdfCell(currencyFormat.format(groupData.first.interessemanal), isNumeric: true),
            _buildPdfCell(groupData.map((r) => currencyFormat.format(r.saldofavor)).join('\n'), isNumeric: true),
            _buildPdfCell(groupData.map((r) => currencyFormat.format(r.moratorios)).join('\n'), isNumeric: true),
          ],
        );

        currentNumber++; // Incrementa el contador después de construir la fila
        return row;
      }).toList(),
    ],
  );
}

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfHeader({
    required String? selectedReportType,
    required DateTimeRange? selectedDateRange,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(
              pw.MemoryImage(
                  File('assets/logo_mf_n_hzt.png').readAsBytesSync()),
              width: 100,
              height: 100,
            ),
            pw.Image(
              pw.MemoryImage(File('assets/finora_hzt.png').readAsBytesSync()),
              width: 120,
              height: 120,
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          selectedReportType ?? '',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#5162F6'),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Periodo: ${DateFormat('dd/MM/yyyy').format(selectedDateRange!.start)} - '
              '${DateFormat('dd/MM/yyyy').format(selectedDateRange.end)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 6,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfCell(String text, {bool isNumeric = false}) {
    return pw.Container(
      alignment: isNumeric ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 6,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfTotals(
      ReporteGeneralData reporteData, NumberFormat currencyFormat) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#3D3D3D')),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.7),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.3),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(1.5),
        6: const pw.FlexColumnWidth(1.5),
        7: const pw.FlexColumnWidth(1.5),
        8: const pw.FlexColumnWidth(1.5),
        9: const pw.FlexColumnWidth(1.5),
        10: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#5162F6')),
          children: [
            _buildTotalCell('Totales', alignLeft: true),
            _buildTotalCell(''),
            _buildTotalCell(''),
            _buildTotalCell(''),
            _buildTotalCell(currencyFormat.format(reporteData.totalPagoficha)),
            _buildTotalCell(''),
            _buildTotalCell(currencyFormat.format(reporteData.totalFicha)),
            _buildTotalCell(currencyFormat.format(reporteData.totalCapital)),
            _buildTotalCell(currencyFormat.format(reporteData.totalInteres)),
            _buildTotalCell(currencyFormat.format(reporteData.totalSaldoFavor)),
            _buildTotalCell(currencyFormat.format(reporteData.saldoMoratorio)),
          ],
        ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#5162F6')),
          children: [
            _buildTotalCell('Total Final', alignLeft: true),
            _buildTotalCell(''),
            _buildTotalCell(''),
            _buildTotalCell(''),
            _buildTotalCell(''),
            _buildTotalCell(''),
            _buildTotalCell(currencyFormat.format(reporteData.totalTotal)),
            _buildTotalCell(''),
            _buildTotalCell(''),
            _buildTotalCell(''),
            _buildTotalCell(''),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTotalCell(String text, {bool alignLeft = false}) {
    return pw.Container(
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 6,
        ),
      ),
    );
  }

  static pw.BoxDecoration _rowDecoration(
      List<ReporteGeneral> groupData, bool pagoIncompleto) {
    if (groupData.any((r) => r.pagoficha == 0)) {
      return pw.BoxDecoration(color: PdfColor.fromHex('#ffcccc'));
    }
    if (pagoIncompleto) {
      return pw.BoxDecoration(color: PdfColor.fromHex('#ffe2b0'));
    }
    return pw.BoxDecoration(
      color: groupData.indexOf(groupData.first).isEven
          ? PdfColor.fromHex('#F8F9FE')
          : PdfColors.white,
    );
  }

  static pw.Widget _buildPagosColumn(
      List<ReporteGeneral> groupData, NumberFormat currencyFormat) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: groupData.map((r) => _pagoWidget(r, currencyFormat)).toList(),
      ),
    );
  }

  static pw.Widget _pagoWidget(ReporteGeneral r, NumberFormat currencyFormat) {
    if (r.garantia == "Si") {
      return pw.Container(
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#E53888'),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: pw.Text(
          currencyFormat.format(r.pagoficha),
          style: const pw.TextStyle(
            color: PdfColors.white,
            fontSize: 6,
          ),
        ),
      );
    }
    return pw.Text(
      currencyFormat.format(r.pagoficha),
      style: const pw.TextStyle(
        color: PdfColors.black,
        fontSize: 6,
      ),
    );
  }
  
}
