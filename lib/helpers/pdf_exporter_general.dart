// export_helper_general.dart

import 'dart:io';
import 'package:collection/collection.dart';
import 'package:finora/ip.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:finora/models/reporte_general.dart';
import 'package:flutter/services.dart' show ByteData, Uint8List, rootBundle;
import 'package:provider/provider.dart';

class ExportHelperGeneral {
  // ... (métodos sin cambios como mostrarDialogoError, _loadNetworkImage, _loadAsset)
  static void mostrarDialogoError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<Uint8List?> _loadNetworkImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error cargando imagen desde URL: $e');
    }
    return null;
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
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      final logoColor = userData.imagenes
          .where((img) => img.tipoImagen == 'logoColor')
          .firstOrNull;
      final logoUrl = logoColor != null
          ? '$baseUrl/imagenes/subidas/${logoColor.rutaImagen}'
          : null;
      final financieraLogo = await _loadNetworkImage(logoUrl);
      final finoraLogo = await _loadAsset('assets/finora_hzt.png');

      void buildPdfPages() {
        final headers = [
          '#',
          'Tipo',
          'Grupos',
          'Pagos',
          'Fecha',
          'M. Ficha',
          'S. Contra',
          'Capital',
          'Interés',
          'S. Favor', // Nombre de la columna se mantiene
          'Mor. Gen.',
          'Mor. Pag.',
        ];

        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            header: (context) => _buildPdfHeader(
              selectedReportType: selectedReportType,
              selectedDateRange: selectedDateRange,
              reporteData: reporteData,
              financieraLogo: financieraLogo,
              finoraLogo: finoraLogo,
            ),
            footer: (context) => _buildPdfFooter(context),
            build: (context) => [
              _buildPdfTable(headers, listaReportes, currencyFormat),
              pw.SizedBox(height: 10),
              // --- CAMBIO: El método de totales ahora recibe la lista de reportes para cálculos locales
              _buildPdfTotals(reporteData, currencyFormat, listaReportes),
              pw.SizedBox(height: 10),
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

  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  static pw.Widget _buildPdfTable(
    List<String> headers,
    List<ReporteGeneral> listaReportes,
    NumberFormat currencyFormat,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        color: PdfColors.white,
      ),
      child: pw.Table(
        border: pw.TableBorder.symmetric(
            inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        columnWidths: {
          0: const pw.FlexColumnWidth(0.35),
          1: const pw.FlexColumnWidth(0.55),
          2: const pw.FlexColumnWidth(1.3),
          3: const pw.FlexColumnWidth(0.9), // Pagos
          4: const pw.FlexColumnWidth(0.7), // Fecha
          5: const pw.FlexColumnWidth(0.8), // M. Ficha
          6: const pw.FlexColumnWidth(0.8), // S. Contra
          7: const pw.FlexColumnWidth(0.7), // Capital
          8: const pw.FlexColumnWidth(0.7), // Interés
          9: const pw.FlexColumnWidth(0.9), // S. Favor (un poco más ancho)
          10: const pw.FlexColumnWidth(0.8),
          11: const pw.FlexColumnWidth(0.8),
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
          ...listaReportes.asMap().entries.map((entry) {
            final index = entry.key;
            final reporte = entry.value;

            final totalPagos = reporte.pagoficha;
            final montoFicha = reporte.montoficha;
            final moratoriosGenerados = reporte.moratoriosAPagar;
            final moratoriosPagados = reporte.sumaMoratorio;
            final moratoriosPendientes =
                moratoriosGenerados - moratoriosPagados;

            final bool pagoNoRealizado = totalPagos == 0.0;
            final bool fichaCubierta = totalPagos >= montoFicha;
            final bool moratoriosCubiertos = moratoriosPendientes <= 0;
            final bool esCompleto = fichaCubierta && moratoriosCubiertos;
            final bool esIncompleto = !pagoNoRealizado && !esCompleto;

            final double saldoContra = montoFicha - totalPagos;
            final double saldoContraDisplay =
                saldoContra > 0 ? saldoContra : 0.0;

            final isLastRow = index == listaReportes.length - 1;
            final rowDecoration = _rowDecoration(pagoNoRealizado, esIncompleto,
                isLastRow: isLastRow);

            return pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.middle,
              decoration: rowDecoration,
              children: [
                _buildPdfCell((index + 1).toString(), isNumeric: true),
                _buildPdfCell(reporte.tipoPago),
                _buildPdfCell(_truncateText(reporte.grupos, 30)),
                _buildPagosColumnPdf(reporte, currencyFormat), // Modificado
                _buildFechasColumnPdf(reporte),
                _buildPdfCell(currencyFormat.format(reporte.montoficha),
                    isNumeric: true),
                _buildPdfCellSaldoContra(
                    currencyFormat.format(saldoContraDisplay), saldoContra > 0),
                _buildPdfCell(currencyFormat.format(reporte.capitalsemanal),
                    isNumeric: true),
                _buildPdfCell(currencyFormat.format(reporte.interessemanal),
                    isNumeric: true),
                // --- CAMBIO CLAVE: Usar el nuevo widget para la columna Saldo Favor
                _buildSaldoFavorColumnPdf(reporte, currencyFormat),
                _buildPdfCellMoratorios(
                    currencyFormat.format(moratoriosGenerados),
                    moratoriosGenerados > 0,
                    isGenerated: true),
                _buildPdfCellMoratorios(
                    currencyFormat.format(moratoriosPagados),
                    moratoriosPagados > 0,
                    isGenerated: false),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // --- MÉTODO MODIFICADO ---
  // Ahora muestra pagos con saldo a favor con fondo verde.
  static pw.Widget _buildPagosColumnPdf(
      ReporteGeneral reporte, NumberFormat currencyFormat) {
    if (reporte.depositos.isEmpty) {
      return _buildPdfCell(currencyFormat.format(0.0), isNumeric: true);
    }

    final List<pw.Widget> paymentWidgets = [];
    for (final deposito in reporte.depositos) {
      // Pago en efectivo o garantía
      if (deposito.monto > 0) {
        final bool isGarantia = deposito.garantia == "Si";
        paymentWidgets.add(
          pw.Container(
            decoration: isGarantia
                ? pw.BoxDecoration(
                    color: PdfColor.fromHex('#E53888'),
                    borderRadius: pw.BorderRadius.circular(4))
                : null,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
            margin: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(
              currencyFormat.format(deposito.monto),
              style: pw.TextStyle(
                  color: isGarantia ? PdfColors.white : PdfColors.black,
                  fontSize: 6),
            ),
          ),
        );
      }
      // Pago con saldo a favor
      if (deposito.favorUtilizado > 0) {
        paymentWidgets.add(
          pw.Container(
            decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#28a745'), // Verde
                borderRadius: pw.BorderRadius.circular(4)),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
            margin: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(
              currencyFormat.format(deposito.favorUtilizado),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 6),
            ),
          ),
        );
      }
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: paymentWidgets,
      ),
    );
  }

  // --- NUEVO MÉTODO ---
  // Este método replica la lógica de la UI para la columna de "Saldo a Favor".
  static pw.Widget _buildSaldoFavorColumnPdf(
      ReporteGeneral reporte, NumberFormat currencyFormat) {
    final deposito =
        reporte.depositos.isNotEmpty ? reporte.depositos.first : null;

    pw.TextStyle mainStyle =
        const pw.TextStyle(fontSize: 6, color: PdfColors.black);
    pw.TextStyle subStyle =
        const pw.TextStyle(fontSize: 5, color: PdfColors.grey);

    // Caso 1: No hay depósito o no se generó saldo a favor en este pago.
    if (deposito == null || deposito.saldofavor == 0) {
      // Aún mostramos el `reporte.saldofavor` que podría ser un saldo a favor generado en este mismo pago.
      return _buildPdfCell(currencyFormat.format(reporte.saldofavor),
          isNumeric: true);
    }

    // Caso 2: El saldo a favor fue utilizado completamente para otro pago.
    if (deposito.utilizadoPago == 'Si') {
      return pw.Container(
        padding: const pw.EdgeInsets.all(3),
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(currencyFormat.format(deposito.saldofavor),
                  style: mainStyle.copyWith(color: PdfColors.grey)),
              pw.Text("(Utilizado)", style: subStyle),
            ]),
      );
    }

    // Caso 3: Se utilizó una parte del saldo a favor.
    if (deposito.saldoUtilizado > 0) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(3),
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(currencyFormat.format(deposito.saldoDisponible),
                  style: mainStyle),
              pw.Text("(de ${currencyFormat.format(deposito.saldofavor)})",
                  style: subStyle),
            ]),
      );
    }

    // Caso 4 (Default): Se generó un saldo a favor y no se ha tocado.
    return _buildPdfCell(currencyFormat.format(reporte.saldofavor),
        isNumeric: true);
  }

  static pw.Widget _buildFechasColumnPdf(ReporteGeneral reporte) {
    if (reporte.depositos.isEmpty) {
      return _buildPdfCell('Pendiente');
    }
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: reporte.depositos.map((deposito) {
          return pw.Text(deposito.fecha,
              style: const pw.TextStyle(fontSize: 6));
        }).toList(),
      ),
    );
  }

  // --- MÉTODO MODIFICADO ---
  // Ahora muestra los totales de Saldo a Favor como en la UI (Disponible e Histórico).
  static pw.Widget _buildPdfTotals(
    ReporteGeneralData reporteData,
    NumberFormat currencyFormat,
    List<ReporteGeneral> listaReportes,
  ) {
    // Valores del servidor
    final double totalPagosFicha = reporteData.totalPagoficha;
    final double totalFicha = reporteData.totalFicha;
    final double totalCapital = reporteData.totalCapital;
    final double totalInteres = reporteData.totalInteres;
    // --- CAMBIO CLAVE: Obtener ambos valores de saldo a favor ---
    final double totalSaldoDisponible = reporteData.totalSaldoDisponible;
    final double totalSaldoFavorHistorico = reporteData.totalSaldoFavor;

    // Valores calculados localmente
    double totalSaldoContra = listaReportes.fold(0.0, (sum, r) {
      final saldo = r.montoficha - r.pagoficha;
      return sum + (saldo > 0 ? saldo : 0);
    });
    final double totalMoratoriosGenerados =
        listaReportes.fold(0.0, (sum, r) => sum + r.moratoriosAPagar);
    final double totalMoratoriosPagados =
        listaReportes.fold(0.0, (sum, r) => sum + r.sumaMoratorio);

    // --- Flex values para alinear las columnas de totales con la tabla ---
    const flexValues = {
      0: 35,
      1: 55,
      2: 130,
      3: 90,
      4: 70,
      5: 80,
      6: 80,
      7: 70,
      8: 70,
      9: 90,
      10: 80,
      11: 80,
    };
    final int totalFlex = flexValues.values.reduce((a, b) => a + b);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#5162F6'),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
              flex: (flexValues[0]! + flexValues[1]! + flexValues[2]!),
              child: _buildTotalCell('Totales', alignLeft: true)),
          pw.Expanded(
              flex: flexValues[3]!,
              child: _buildTotalCell(currencyFormat.format(totalPagosFicha))),
          pw.Expanded(flex: flexValues[4]!, child: _buildTotalCell('')),
          pw.Expanded(
              flex: flexValues[5]!,
              child: _buildTotalCell(currencyFormat.format(totalFicha))),
          pw.Expanded(
              flex: flexValues[6]!,
              child: _buildTotalCell(currencyFormat.format(totalSaldoContra))),
          pw.Expanded(
              flex: flexValues[7]!,
              child: _buildTotalCell(currencyFormat.format(totalCapital))),
          pw.Expanded(
              flex: flexValues[8]!,
              child: _buildTotalCell(currencyFormat.format(totalInteres))),
          // --- CAMBIO CLAVE: Celda de total para Saldo a Favor ---
          pw.Expanded(
            flex: flexValues[9]!,
            child: pw.Container(
              alignment: pw.Alignment.centerRight,
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(currencyFormat.format(totalSaldoDisponible),
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 6.5)),
                  pw.Text(
                      "(Hist: ${currencyFormat.format(totalSaldoFavorHistorico)})",
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 5.5)),
                ],
              ),
            ),
          ),
          pw.Expanded(
              flex: flexValues[10]!,
              child: _buildTotalCell(
                  currencyFormat.format(totalMoratoriosGenerados))),
          pw.Expanded(
              flex: flexValues[11]!,
              child: _buildTotalCell(
                  currencyFormat.format(totalMoratoriosPagados))),
        ],
      ),
    );
  }

  // --- El resto de los métodos se mantienen igual ---

  static pw.Widget _buildTotalsIdealPdfWidget(
      ReporteGeneralData reporteData, NumberFormat currencyFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#6D79E8'),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          _buildTotalPdfItem(
              'Total Ideal', reporteData.totalTotal, currencyFormat),
          pw.SizedBox(width: 40),
          _buildTotalPdfItem(
              'Diferencia', reporteData.restante, currencyFormat),
          pw.SizedBox(width: 40),
          _buildTotalPdfItem(
              'Total Bruto', reporteData.sumaTotalCapMoraFav, currencyFormat),
        ],
      ),
    );
  }

  static pw.BoxDecoration _rowDecoration(
      bool pagoNoRealizado, bool esIncompleto,
      {bool isLastRow = false}) {
    PdfColor backgroundColor;
    if (pagoNoRealizado) {
      backgroundColor = PdfColor.fromHex('#ffcccc');
    } else if (esIncompleto) {
      backgroundColor = PdfColor.fromHex('#ffe2b0');
    } else {
      backgroundColor = PdfColors.white;
    }
    return pw.BoxDecoration(
      color: backgroundColor,
      borderRadius: isLastRow
          ? const pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(10),
              bottomRight: pw.Radius.circular(10))
          : null,
    );
  }

  static pw.Widget _buildPdfCellSaldoContra(String text, bool isPositive) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 6,
              color: isPositive ? PdfColors.red : PdfColors.black,
              fontWeight:
                  isPositive ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _buildPdfCellMoratorios(String text, bool isPositive,
      {required bool isGenerated}) {
    final PdfColor positiveColor =
        isGenerated ? PdfColors.red : PdfColors.green;
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 6,
              color: isPositive ? positiveColor : PdfColors.black,
              fontWeight:
                  isPositive ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
    );
  }

  static pw.Widget _buildPdfHeader({
    required String? selectedReportType,
    required DateTimeRange? selectedDateRange,
    required ReporteGeneralData reporteData,
    required Uint8List? financieraLogo,
    required Uint8List finoraLogo,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (financieraLogo != null)
              pw.Image(
                pw.MemoryImage(financieraLogo),
                width: 120,
                height: 40,
                fit: pw.BoxFit.contain,
              ),
            pw.Image(
              pw.MemoryImage(finoraLogo),
              width: 120,
              height: 40,
              fit: pw.BoxFit.contain,
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
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 6.5)),
    );
  }

  static pw.Widget _buildPdfCell(String text, {bool isNumeric = false}) {
    return pw.Container(
      alignment: isNumeric ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.black)),
    );
  }

  static pw.Widget _buildTotalCell(String text, {bool alignLeft = false}) {
    return pw.Container(
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      child: pw.Text(text,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 6.5)),
    );
  }

  static pw.Widget _buildTotalPdfItem(
      String label, double value, NumberFormat currencyFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white)),
        pw.SizedBox(height: 2),
        pw.Text(currencyFormat.format(value),
            style: pw.TextStyle(
              fontSize: 6,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            )),
      ],
    );
  }
}
