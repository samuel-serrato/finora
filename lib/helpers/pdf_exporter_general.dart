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
import 'package:shared_preferences/shared_preferences.dart';

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

  // Reemplaza _loadLogoFile con este nuevo método para cargar desde URL
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

      // Obtener datos del provider
      final userData = Provider.of<UserDataProvider>(context, listen: false);

      // Buscar el logo a color
      final logoColor = userData.imagenes
          .where((img) => img.tipoImagen == 'logoColor')
          .firstOrNull;

      // Construir URL completa
      final logoUrl = logoColor != null
          ? '$baseUrl/imagenes/subidas/${logoColor.rutaImagen}'
          : null;

      // Cargar logos
      final financieraLogo = await _loadNetworkImage(logoUrl);
      final finoraLogo = await _loadAsset('assets/finora_hzt.png');

      void buildPdfPages() {
        final headers = [
          '#',
          'Tipo Pago',
          'Grupos',
          //'Folio',
          'Pago Ficha',
          'Fecha Depósito',
          'Monto Ficha',
          'Saldo Contra',
          'Capital',
          'Interés',
          'Saldo Favor',
          //'Moratorios'
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
              financieraLogo: financieraLogo,
              finoraLogo: finoraLogo,
            ),
            footer: (context) => _buildPdfFooter(context),
            build: (context) => [
              _buildPdfTable(headers, groups, currencyFormat),
              pw.SizedBox(height: 10),
              _buildPdfTotals(reporteData, currencyFormat, groups),
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

  // Actualiza el método _buildPdfTable para incluir la columna "Saldo Contra"
// Optimización de los anchos de columnas
static pw.Widget _buildPdfTable(
    List<String> headers,
    List<MapEntry<String, List<ReporteGeneral>>> data,
    NumberFormat currencyFormat) {
  int currentNumber = 1;

  return pw.Container(
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(10),
      color: PdfColors.white,
    ),
    child: pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: PdfColors.grey500,
          width: 0.5,
        ),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),  // # - mantener pequeño
        1: const pw.FlexColumnWidth(1.0),  // Tipo Pago - reducir un poco
        2: const pw.FlexColumnWidth(2.8),  // Grupos - aumentar ligeramente
        3: const pw.FlexColumnWidth(1.3),  // Pago Ficha - reducir un poco
        4: const pw.FlexColumnWidth(1.0),  // Fecha Depósito - REDUCIR significativamente
        5: const pw.FlexColumnWidth(1.3),  // Monto Ficha - reducir un poco
        6: const pw.FlexColumnWidth(1.3),  // Saldo Contra - reducir un poco
        7: const pw.FlexColumnWidth(1.2),  // Capital - reducir un poco
        8: const pw.FlexColumnWidth(1.2),  // Interés - reducir un poco
        9: const pw.FlexColumnWidth(1.4),  // Saldo Favor - mantener para números largos
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#5162F6'),
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(10),
              topRight: pw.Radius.circular(10),
            ),
          ),
          children: headers.map((header) => _buildPdfHeaderCell(header)).toList(),
        ),
        // Data rows
        ...data.map((group) {
          final groupData = group.value;
          final totalPagos = groupData.fold(0.0, (sum, r) => sum + r.pagoficha);
          final pagoIncompleto = totalPagos < groupData.first.montoficha && totalPagos > 0;
          
          // Calcular saldo en contra
          final double montoFicha = groupData.first.montoficha;
          final double saldoContra = montoFicha - totalPagos;
          final double saldoContraDisplay = saldoContra > 0 ? saldoContra : 0.0;

          final isLastRow = data.indexOf(group) == data.length - 1;
          final rowDecoration = _rowDecoration(groupData, pagoIncompleto,
              isLastRow: isLastRow, isFirstRow: data.indexOf(group) == 0);

          final row = pw.TableRow(
            decoration: rowDecoration,
            children: [
              _buildPdfCell(currentNumber.toString(), isNumeric: true),
              _buildPdfCell(groupData.first.tipoPago),
              _buildPdfCell(groupData.first.grupos),
              _buildPagosColumn(groupData, currencyFormat),
              _buildPdfCell(groupData.map((r) => r.fechadeposito).join('\n')),
              _buildPdfCell(currencyFormat.format(groupData.first.montoficha), isNumeric: true),
              _buildPdfCellSaldoContra(currencyFormat.format(saldoContraDisplay), saldoContra > 0),
              _buildPdfCell(currencyFormat.format(groupData.first.capitalsemanal), isNumeric: true),
              _buildPdfCell(currencyFormat.format(groupData.first.interessemanal), isNumeric: true),
              _buildPdfCell(
                  groupData.map((r) => currencyFormat.format(r.saldofavor)).join('\n'),
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

// Nuevo método para mostrar el saldo en contra con color rojo si es mayor a 0
static pw.Widget _buildPdfCellSaldoContra(String text, bool isPositive) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 6,
        color: isPositive ? PdfColor.fromHex('#d32f2f') : PdfColors.black, // Rojo si es positivo
        fontWeight: isPositive ? pw.FontWeight.normal : pw.FontWeight.normal,
      ),
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
                width: 120, // Ajustar tamaño según necesidad
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

  // Actualiza el método _buildPdfTotals para incluir el total de saldo en contra
// Corrección 3: Arreglar el método _buildPdfTotals
// Corrección para que "Totales" ocupe dos columnas
// También actualizar los anchos en la tabla de totales para que coincidan
static pw.Widget _buildPdfTotals(
    ReporteGeneralData reporteData, 
    NumberFormat currencyFormat,
    List<MapEntry<String, List<ReporteGeneral>>> groups) {
  
  // Calcular el total de saldos en contra
  double totalSaldoContra = 0.0;
  
  for (final group in groups) {
    final reportesInGroup = group.value;
    final double montoFicha = reportesInGroup.first.montoficha;
    final double totalPagos = reportesInGroup.fold(0.0, (sum, reporte) => sum + reporte.pagoficha);
    final double saldoContra = montoFicha - totalPagos;
    
    // Solo sumar si el saldo en contra es positivo
    if (saldoContra > 0) {
      totalSaldoContra += saldoContra;
    }
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(10),
      color: PdfColors.white,
    ),
    child: pw.Table(
      border: null,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),  // Totales (# + Tipo Pago: 0.5 + 1.0)
        1: const pw.FlexColumnWidth(2.8),  // Grupos
        2: const pw.FlexColumnWidth(1.3),  // Pago Ficha
        3: const pw.FlexColumnWidth(1.0),  // Fecha Depósito (vacío)
        4: const pw.FlexColumnWidth(1.3),  // Monto Ficha
        5: const pw.FlexColumnWidth(1.3),  // Saldo Contra
        6: const pw.FlexColumnWidth(1.2),  // Capital
        7: const pw.FlexColumnWidth(1.2),  // Interés
        8: const pw.FlexColumnWidth(1.4),  // Saldo Favor
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
            _buildTotalCell('Totales', alignLeft: true), // Ocupa espacio de # + Tipo Pago
            _buildTotalCell(''), // Grupos
            _buildTotalCell(currencyFormat.format(reporteData.totalPagoficha)), // Pago Ficha
            _buildTotalCell(''), // Fecha Depósito
            _buildTotalCell(currencyFormat.format(reporteData.totalFicha)), // Monto Ficha
            _buildTotalCell(currencyFormat.format(totalSaldoContra)), // Saldo Contra
            _buildTotalCell(currencyFormat.format(reporteData.totalCapital)), // Capital
            _buildTotalCell(currencyFormat.format(reporteData.totalInteres)), // Interés
            _buildTotalCell(currencyFormat.format(reporteData.totalSaldoFavor)), // Saldo Favor
          ],
        ),
      ],
    ),
  );
}

  static pw.Widget _buildTotalCell(String text, {bool alignLeft = false}) {
    return pw.Container(
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
      padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 5),
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
