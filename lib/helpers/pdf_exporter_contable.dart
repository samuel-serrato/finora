import 'dart:io';
import 'package:finora/ip.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:finora/models/reporte_contable.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PDFExportHelperContable {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF5162F6);
  static const PdfColor warningColor = PdfColor.fromInt(0xFFF59E0B);
  final ReporteContableData reporteData;
  final NumberFormat currencyFormat;
  final String? selectedReportType;
  final BuildContext context; // Nuevo parámetro

  PDFExportHelperContable(
      this.reporteData, this.currencyFormat, this.selectedReportType,     this.context, // Contexto añadido
);

  // Función para cargar assets
  Future<Uint8List> _loadAsset(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  // Nuevo método para cargar desde URL
  Future<Uint8List?> _loadNetworkImage(String? imageUrl) async {
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

  Future<pw.Document> generatePDF() async {
    final pdf = pw.Document();

     // Obtener datos del provider
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    
    // Buscar el logo a color
    final logoColor = userData.imagenes
        .where((img) => img.tipoImagen == 'logoColor')
        .firstOrNull;
    
    // Construir URL completa
    final logoUrl = logoColor != null 
        ? 'http://$baseUrl/imagenes/subidas/${logoColor.rutaImagen}'
        : null;

    // Cargar logos
    final financieraLogo = await _loadNetworkImage(logoUrl);
    final finoraLogo = await _loadAsset('assets/finora_hzt.png');


    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20), // Reducido margen general
        build: (context) => [
          _buildHeader(
            selectedReportType: selectedReportType,
            financieraLogo: financieraLogo,
            finoraLogo: finoraLogo,
          ),
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

  pw.Widget _buildHeader({
    required String? selectedReportType,
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
                width: 120, // Tamaño ajustado
                height: 40,
                fit: pw.BoxFit.contain,
              )
            else
              pw.Container(), // Espacio vacío si no hay logo

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
              mainAxisSize: pw
                  .MainAxisSize.max, // Asegura que use todo el ancho disponible
              children: [
                _buildClientesTable(grupo),
                pw.SizedBox(width: 10), // Reducido espacio
                _buildFinancialInfoSection(grupo),
                pw.SizedBox(width: 10), // Reducido espacio
                _buildDepositosSection(
                    grupo.pagoficha, grupo.restanteFicha, grupo),
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
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor)),
        pw.SizedBox(width: 9),
        pw.Text('(Folio: ${grupo.folio})',
            style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
        pw.Spacer(),
        pw.Text('Pago: ${grupo.tipopago}', style: pw.TextStyle(fontSize: 6)),
        pw.SizedBox(width: 15),
        pw.Text('Plazo: ${grupo.plazo}', style: pw.TextStyle(fontSize: 6)),
        pw.SizedBox(width: 15),
        pw.Text('Periodo Pago: ${grupo.pagoPeriodo}',
            style: pw.TextStyle(fontSize: 6)),
      ],
    );
  }

  pw.Widget _buildClientesTable(ReporteContableGrupo grupo) {
    return pw.Expanded(
      flex: 50,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Añadir el encabezado de la sección
          pw.Text('Clientes',
              style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 4), // Espacio entre el título y la tabla

          // La tabla existente
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.white),
                children: [
                  _buildHeaderCell('Nombre Cliente'),
                  _buildHeaderCell('Capital'),
                  _buildHeaderCell('Interés'),
                  _buildHeaderCell('Capital + Interés'),
                ],
              ),
              ...grupo.clientes.map((cliente) => pw.TableRow(
                    children: [
                      _buildDataCell(cliente.nombreCompleto),
                      _buildDataCell(
                          currencyFormat.format(cliente.periodoCapital)),
                      _buildDataCell(
                          currencyFormat.format(cliente.periodoInteres)),
                      _buildDataCell(
                          currencyFormat.format(cliente.capitalMasInteres)),
                    ],
                  )),
              // Añadir fila de totales
              _buildTotalesRow(grupo.clientes),
            ],
          ),
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
        style: const pw.TextStyle(fontSize: 6),
      ),
    );
  }

  pw.Widget _buildFinancialInfoSection(ReporteContableGrupo grupo) {
    return pw.Expanded(
      flex: 20,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Información del Crédito',
              style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 6),

          // Container para los 6 elementos de información del crédito
          pw.Container(
            padding: pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              children: [
                // Primera fila con 2 columnas (Garantía y Tasa)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFinancialColumn('Garantía', grupo.garantia,
                        isText: true),
                    _buildFinancialColumn('Tasa', grupo.tazaInteres,
                        isPercentage: true),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Segunda fila con 2 columnas (Monto Solicitado y Monto Desembolsado)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFinancialColumn(
                        'Monto Solicitado', grupo.montoSolicitado),
                    _buildFinancialColumn(
                        'Monto Desembolsado', grupo.montoDesembolsado),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Tercera fila con 2 columnas (Interés Total y Monto a Recuperar)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFinancialColumn(
                        'Interés Total', grupo.interesCredito),
                    _buildFinancialColumn(
                        'Monto a Recuperar', grupo.montoARecuperar),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 4),

          // Container para la información semanal con 3 columnas
          pw.Container(
            padding: pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildFinancialColumn(
                    '${grupo.tipopago == "SEMANAL" ? "Capital Semanal" : "Capital Quincenal"}',
                    grupo.capitalsemanal),
                _buildFinancialColumn(
                    '${grupo.tipopago == "SEMANAL" ? "Interés Semanal" : "Interés Quincenal"}',
                    grupo.interessemanal),
                _buildFinancialColumn('Monto Ficha', grupo.montoficha),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Método auxiliar para crear columnas con texto arriba y valor abajo
  pw.Widget _buildFinancialColumn(String label, dynamic value,
      {bool isText = false, bool isPercentage = false}) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(
              isText
                  ? value.toString()
                  : isPercentage
                      ? '${value.toString()}%'
                      : currencyFormat.format(value),
              style: pw.TextStyle(fontSize: 6)),
        ],
      ),
    );
  }

  pw.Widget _buildDepositosSection(
      Pagoficha pagoficha, double restanteFicha, ReporteContableGrupo grupo) {
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
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: pw.BoxDecoration(
                                        color: PdfColor.fromInt(0xFFE53888),
                                        borderRadius:
                                            pw.BorderRadius.circular(4),
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
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
              pw.SizedBox(height: 6), // Espacio para la siguiente sección

              // Sección de Resumen Global

              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Resumen Global',
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Saldo Global',
                              style: pw.TextStyle(
                                fontSize: 6,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              currencyFormat.format(grupo
                                  .saldoGlobal), // Convertido a string con formato
                              style: pw.TextStyle(
                                fontSize: 6,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Restante Global',
                              style: pw.TextStyle(
                                fontSize: 6,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              currencyFormat.format(grupo
                                  .restanteGlobal), // Convertido a string con formato
                              style: pw.TextStyle(
                                fontSize: 6,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              )
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
        //color: primaryColor,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      padding: const pw.EdgeInsets.symmetric(
          vertical: 8, horizontal: 10), // Reducido padding
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Totales',
              style: pw.TextStyle(
                  color: primaryColor,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold)),
          pw.Row(
            children: [
              _buildTotalItem('Capital Total', reporteData.totalCapital),
              _buildTotalItem('Interés Total', reporteData.totalInteres),
              _buildTotalItem('Monto Fichas', reporteData.totalFicha),
              _buildTotalItem('Pago Fichas', reporteData.totalPagoficha),
              _buildTotalItem('Saldo Favor', reporteData.totalSaldoFavor),
              _buildTotalItem('Moratorios', reporteData.saldoMoratorio),
              pw.SizedBox(width: 70),
              _buildTotalItem('Total Ideal', reporteData.totalTotal),
              _buildTotalItem('Diferencia', reporteData.restante),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFinancialRow(String label, dynamic value,
      {bool isText = false, bool isPercentage = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 6)),
        isText
            ? pw.Text(value.toString(), style: const pw.TextStyle(fontSize: 6))
            : pw.Text(
                '${isText ? value.toString() : currencyFormat.format(value)}${isPercentage ? '%' : ''}',
                style: const pw.TextStyle(fontSize: 6)),
      ],
    );
  }

  pw.Widget _buildTotalItem(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6), // Reducido espacio
      child: pw.Column(
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.black)),
          pw.Text(currencyFormat.format(value),
              style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black)),
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
