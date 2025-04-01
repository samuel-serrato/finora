import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Ajusta estas importaciones según tu proyecto
import 'package:finora/dialogs/infoCredito.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:finora/ip.dart';

class PDFFichaPagoSemanal {
  // Paleta de colores moderna
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF5162F6);
  static const PdfColor accentColor = PdfColor.fromInt(0xFF2ECC71);
  static const PdfColor backgroundGrey = PdfColor.fromInt(0xFFFAFAFA);
  static const PdfColor dividerColor = PdfColor.fromInt(0xFFEEEEEE);
  static const PdfColor textPrimary = PdfColor.fromInt(0xFF2C3E50);
  static const PdfColor textSecondary = PdfColor.fromInt(0xFF7F8C8D);

  // Estilos tipográficos
  static final titleStyle = pw.TextStyle(
    fontSize: 18,
    fontWeight: pw.FontWeight.bold,
    color: primaryColor,
    font: pw.Font.courierBold(),
  );

  static final headerStyle = pw.TextStyle(
    fontSize: 12,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.white,
    font: pw.Font.courierBold(),
  );

  static final labelStyle = pw.TextStyle(
    fontSize: 10,
    color: textSecondary,
    font: pw.Font.courier(),
  );

  static final dataStyle = pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
    color: textPrimary,
    font: pw.Font.courier(),
  );

  static Future<Uint8List> _loadAsset(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  static Future<Uint8List?> _loadNetworkImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(imageUrl));
      return response.statusCode == 200 ? response.bodyBytes : null;
    } catch (e) {
      print('Error loading network image: $e');
      return null;
    }
  }

  static String _formatCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length == 16
        ? cleaned
            .replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)} ')
            .trim()
        : cardNumber;
  }

  static Future<void> generar(
      BuildContext context, Credito credito, String savePath) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) throw 'Se requieren permisos de almacenamiento';

      // Procesamiento de fechas
      if (!credito.fechasIniciofin.contains(' - ')) {
        throw 'Formato de fecha inválido';
      }
      final dateParts = credito.fechasIniciofin.split(' - ');
      if (dateParts.length != 2)
        throw 'Formato debe ser: fecha_inicio - fecha_fin';

      await initializeDateFormatting('es_ES', null);
      final inputFormat = DateFormat('yyyy/MM/dd');
      final outputFormat = DateFormat('dd MMMM yyyy', 'es_ES');

      final fechaInicio = inputFormat.parse(dateParts[0].trim());
      final fechaFin = inputFormat.parse(dateParts[1].trim());
      final fechaInicioFormateada = outputFormat.format(fechaInicio);
      final fechaFinFormateada = outputFormat.format(fechaFin);

      // Carga de recursos
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      final logoColorInfo = userData.imagenes
          .where((img) => img.tipoImagen == 'logoColor')
          .firstOrNull;

      final moneyFacilLogoUrl = logoColorInfo != null
          ? 'http://$baseUrl/imagenes/subidas/${logoColorInfo.rutaImagen}'
          : null;

      final moneyFacilLogoBytes = await _loadNetworkImage(moneyFacilLogoUrl);
      final finoraLogoBytes = await _loadAsset('assets/finora_hzt.png');

      Uint8List? santanderLogoBytes;
      try {
        santanderLogoBytes = await _loadAsset('assets/santander_logo.png');
      } catch (e) {
        print('Logo Santander no disponible: $e');
      }

      final currencyFormat =
          NumberFormat.currency(locale: 'es_MX', symbol: '\$');

      // Construcción del PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter.copyWith(
            marginTop: 32,
            marginBottom: 32,
            marginLeft: 24,
            marginRight: 24,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(moneyFacilLogoBytes, finoraLogoBytes),
                pw.Divider(color: dividerColor, height: 24),
                _buildTitleSection(credito),
                pw.SizedBox(height: 20),
                _buildDateSection(fechaInicioFormateada, fechaFinFormateada),
                pw.SizedBox(height: 24),
                _buildInfoTable(credito, currencyFormat, santanderLogoBytes),
                pw.SizedBox(height: 24),
                _buildFooter(),
              ],
            );
          },
        ),
      );

      final file = File(savePath);
      await file.writeAsBytes(await pdf.save());
    } catch (e) {
      print("Error generando PDF: $e");
      throw 'Error al generar PDF: ${e.toString()}';
    }
  }

  static pw.Widget _buildHeader(
      Uint8List? moneyFacilLogo, Uint8List finoraLogo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (moneyFacilLogo != null)
          pw.Image(pw.MemoryImage(moneyFacilLogo), height: 32),
        pw.Image(pw.MemoryImage(finoraLogo), height: 32),
      ],
    );
  }

  static pw.Widget _buildTitleSection(Credito credito) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Ficha de Pago ${credito.tipoPlazo}',
          style: titleStyle,
        ),
        pw.Text(
          DateFormat('dd/MM/yyyy').format(DateTime.now()),
          style: labelStyle.copyWith(color: textSecondary),
        ),
      ],
    );
  }

  static pw.Widget _buildDateSection(String startDate, String endDate) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: backgroundGrey,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        children: [
          pw.Text(
            'FECHAS DE CONTRATO',
            style: headerStyle.copyWith(
              fontSize: 14,
              color: primaryColor,
              //backgroundColor: PdfColors.transparent,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildDateCard('Inicio', startDate),
              _buildVerticalDivider(),
              _buildDateCard('Término', endDate),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoTable(
    Credito credito,
    NumberFormat currencyFormat,
    Uint8List? santanderLogo,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: dividerColor),
      ),
      child: pw.Table(
        columnWidths: const {
          0: pw.FixedColumnWidth(120),
          1: pw.FlexColumnWidth(),
        },
        border: null,
        children: [
          _buildModernTableRow('NOMBRE DEL GRUPO', credito.nombreGrupo),
          _buildTableDivider(),
          _buildModernTableRow(
            'MONTO DE PAGO ${credito.tipoPlazo.toUpperCase()}',
            currencyFormat.format(credito.pagoCuota ?? 0.0),
          ),
          _buildTableDivider(),
          _buildModernTableRow('NOMBRE DEL TITULAR', 'nomtit' ?? 'N/A'),
          _buildTableDivider(),
          _buildModernTableRow(
            'NÚMERO DE TARJETA',
            _formatCardNumber('numerotarjeta' ?? ''),
          ),
          _buildTableDivider(),
          _buildModernTableRowWithLogo(
            'INSTITUCIÓN BANCARIA',
            'Santander',
            santanderLogo != null ? pw.MemoryImage(santanderLogo) : null,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        'Para cualquier duda contacte a su asesor financiero',
        style: labelStyle.copyWith(
          fontSize: 9,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  static pw.TableRow _buildModernTableRow(String label, String value) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: backgroundGrey),
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: pw.Text(label, style: labelStyle),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: pw.Text(value, style: dataStyle),
        ),
      ],
    );
  }

  static pw.TableRow _buildModernTableRowWithLogo(
    String label,
    String value,
    pw.ImageProvider? logo,
  ) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: pw.Text(label, style: labelStyle),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: logo != null
              ? pw.Row(
                  children: [
                    pw.Text(value, style: dataStyle),
                    pw.SizedBox(width: 8),
                    pw.Image(logo, height: 16),
                  ],
                )
              : pw.Text(value, style: dataStyle),
        ),
      ],
    );
  }

  static pw.TableRow _buildTableDivider() {
    return pw.TableRow(
      children: [
        pw.Container(
          height: 1,
          color: dividerColor,
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
        ),
        pw.Container(
          height: 1,
          color: dividerColor,
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
        ),
      ],
    );
  }

  static pw.Widget _buildDateCard(String title, String date) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: labelStyle.copyWith(
            fontWeight: pw.FontWeight.bold,
            color: textSecondary,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(6),
            boxShadow: [
              pw.BoxShadow(
                color: PdfColors.grey200,
                blurRadius: 4,
                //offset: const pw.Offset(0, 2),
              ),
            ],
          ),
          child: pw.Text(
            date,
            style: dataStyle.copyWith(
              fontSize: 12,
              color: primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildVerticalDivider() {
    return pw.Container(
      width: 1,
      height: 50,
      margin: const pw.EdgeInsets.symmetric(horizontal: 16),
      color: dividerColor,
    );
  }
}
