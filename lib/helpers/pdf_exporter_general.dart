import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:finora/models/reporte_general.dart';
import 'package:flutter/services.dart' show ByteData, Uint8List, rootBundle;

class ExportHelperGeneral {
  static void mostrarDialogoError(BuildContext context, String mensaje) {
    // Mostrar un SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<Uint8List> _loadAsset(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

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

      // Precargar imágenes fuera de la construcción del PDF
      final logoMf = await _loadAsset('assets/logo_mf_n_hzt.png');
      final finoraLogo = await _loadAsset('assets/finora_hzt.png');

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
              reporteData: reporteData!,
              logoMf: logoMf,
              finoraLogo: finoraLogo,
            ),
            footer: (context) => _buildPdfFooter(context),
            build: (context) => [
              _buildPdfTable(headers, groups, currencyFormat),
              pw.SizedBox(height: 10),
              _buildPdfTotals(reporteData, currencyFormat),
              _buildTotalsIdealPdfWidget(reporteData, currencyFormat),
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
      List<String> headers,
      List<MapEntry<String, List<ReporteGeneral>>> data,
      NumberFormat currencyFormat) {
    int currentNumber = 1; // Inicializa el contador

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        color: PdfColors.white,
      ),
      child: pw.Table(
        // Aquí agregamos el borde horizontal gris suave
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(
            color: PdfColors.grey500, // Gris claro para los bordes horizontales
            width: 0.5,
          ),
        ),
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
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#5162F6'),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(10),
                topRight: pw.Radius.circular(10),
              ),
            ),
            children:
                headers.map((header) => _buildPdfHeaderCell(header)).toList(),
          ),
          ...data.map((group) {
            final groupData = group.value;
            final totalPagos =
                groupData.fold(0.0, (sum, r) => sum + r.pagoficha);
            final pagoIncompleto =
                totalPagos < groupData.first.montoficha && totalPagos > 0;

            final isLastRow = data.indexOf(group) == data.length - 1;
            final rowDecoration = _rowDecoration(groupData, pagoIncompleto,
                isLastRow: isLastRow, isFirstRow: data.indexOf(group) == 0);

            final row = pw.TableRow(
              decoration: rowDecoration,
              children: [
                _buildPdfCell(currentNumber.toString(), isNumeric: true),
                _buildPdfCell(groupData.first.tipoPago),
                _buildPdfCell(groupData.first.grupos),
                _buildPdfCell(groupData.first.folio),
                _buildPagosColumn(groupData, currencyFormat),
                _buildPdfCell(groupData.map((r) => r.fechadeposito).join('\n')),
                _buildPdfCell(currencyFormat.format(groupData.first.montoficha),
                    isNumeric: true),
                _buildPdfCell(
                    currencyFormat.format(groupData.first.capitalsemanal),
                    isNumeric: true),
                _buildPdfCell(
                    currencyFormat.format(groupData.first.interessemanal),
                    isNumeric: true),
                _buildPdfCell(
                    groupData
                        .map((r) => currencyFormat.format(r.saldofavor))
                        .join('\n'),
                    isNumeric: true),
                _buildPdfCell(
                    groupData
                        .map((r) => currencyFormat.format(r.moratorios))
                        .join('\n'),
                    isNumeric: true),
              ],
            );

            currentNumber++;
            return row;
          }).toList(),
        ],
      ),
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
    required ReporteGeneralData reporteData,
    required Uint8List logoMf,
    required Uint8List finoraLogo,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(
              pw.MemoryImage(logoMf),
              width: 100,
              height: 100,
            ),
            pw.Image(
              pw.MemoryImage(finoraLogo),
              width: 120,
              height: 120,
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          selectedReportType ?? '',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#5162F6'),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Período: ${reporteData.fechaSemana}',
                style: const pw.TextStyle(fontSize: 8)),
            pw.Text(
              'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
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
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        color: PdfColors.white,
      ),
      child: pw.Table(
        border: null,
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
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#5162F6'),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(10),
                topRight: pw.Radius.circular(10),
              ),
            ),
            children: [
              _buildTotalCell('Totales', alignLeft: true),
              _buildTotalCell(''),
              _buildTotalCell(''),
              _buildTotalCell(''),
              _buildTotalCell(
                  currencyFormat.format(reporteData.totalPagoficha)),
              _buildTotalCell(''),
              _buildTotalCell(currencyFormat.format(reporteData.totalFicha)),
              _buildTotalCell(currencyFormat.format(reporteData.totalCapital)),
              _buildTotalCell(currencyFormat.format(reporteData.totalInteres)),
              _buildTotalCell(
                  currencyFormat.format(reporteData.totalSaldoFavor)),
              _buildTotalCell(
                  currencyFormat.format(reporteData.saldoMoratorio)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalCell(String text, {bool alignLeft = false}) {
    return pw.Container(
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
      padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
      List<ReporteGeneral> groupData, bool pagoIncompleto,
      {bool isLastRow = false, bool isFirstRow = false}) {
    // Base color for the row
    PdfColor backgroundColor;

    if (groupData.any((r) => r.pagoficha == 0)) {
      backgroundColor = PdfColor.fromHex('#ffcccc');
    } else if (pagoIncompleto) {
      backgroundColor = PdfColor.fromHex('#ffe2b0');
    } else {
      backgroundColor = groupData.indexOf(groupData.first).isEven
          ? PdfColor.fromHex('#F8F9FE')
          : PdfColors.white;
    }

    // Add border radius only for first and last rows
    pw.BorderRadius? borderRadius;

    if (isLastRow) {
      borderRadius = const pw.BorderRadius.only(
        bottomLeft: pw.Radius.circular(10),
        bottomRight: pw.Radius.circular(10),
      );
    }

    return pw.BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius,
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

  static pw.Widget _buildTotalsIdealPdfWidget(
      ReporteGeneralData reporteData, currencyFormat) {
    return pw.Container(
        padding: pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF6D79E8), // Color similar al de Flutter
          borderRadius: pw.BorderRadius.only(
            bottomLeft:
                pw.Radius.circular(15), // Borde redondeado inferior izquierdo
            bottomRight:
                pw.Radius.circular(15), // Borde redondeado inferior derecho
          ),
        ),
        child: pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment.start, // Alinea los elementos a la izquierda
          children: [
            // Total Ideal con ícono de información
            pw.Row(
              children: [
                _buildTotalPdfItem(
                    'Total Ideal', reporteData.totalTotal, currencyFormat),
                pw.SizedBox(width: 8), // Espacio entre el texto y el ícono
              ],
            ),
            pw.SizedBox(width: 70), // Espacio entre los elementos
            // Diferencia con ícono de información
            pw.Row(
              children: [
                _buildTotalPdfItem(
                    'Diferencia', reporteData.restante, currencyFormat),
                pw.SizedBox(width: 8), // Espacio entre el texto y el ícono
              ],
            ),
          ],
        ));
  }

  static pw.Widget _buildTotalPdfItem(
      String label, double value, NumberFormat currencyFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 6,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
        pw.SizedBox(height: 4), // Espacio entre el texto y el monto
        pw.Text(
          currencyFormat.format(value), // Usar el formato de moneda aquí
          style: pw.TextStyle(
            fontSize: 6,
            color: PdfColors.white,
          ),
        ),
      ],
    );
  }
}
