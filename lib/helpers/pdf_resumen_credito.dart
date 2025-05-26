// lib/pdf/pdf_resumen_credito.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:finora/dialogs/infoCredito.dart';
import 'package:finora/ip.dart';
import 'package:finora/models/credito.dart';
import 'package:finora/models/cliente_monto.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PDFResumenCredito {
  static final format = NumberFormat("#,##0.00");
  static final dateFormat = DateFormat('dd/MM/yyyy');
  static final darkGrey = PdfColors.grey800;

  // Agregar los mismos colores de ControlPagos
  static final PdfColor primaryColor = PdfColors.indigo700;
  static final PdfColor accentColor = PdfColors.teal500;
  static final PdfColor lightGrey = PdfColors.grey200;
  static final PdfColor mediumGrey = PdfColors.grey400;
  static final PdfColor darkGreyColor = PdfColors.grey800;

  // Función para cargar assets (por ejemplo, el logo de FINORA)
  static Future<Uint8List> _loadAsset(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  // Función para cargar imágenes desde URL (por ejemplo, el logo de la financiera)
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

  static pw.TextStyle sectionTitleStyle = pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
    color: darkGreyColor, // Usar el mismo color que ControlPagos
  );

  static pw.TextStyle infoColumnValueStyle = pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
  );

  // --- NUEVA FUNCIÓN PARA OBTENER PAGOS (ADAPTADA) ---
  static Future<List<Pago>> _fetchPagosData(String idCredito) async {
    // No usamos 'context' ni 'widget' aquí, ya que es estático.
    // El manejo de errores será lanzando excepciones que 'generar' capturará.
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      if (token.isEmpty) {
        throw Exception('Token de autenticación no encontrado.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/creditos/calendario/$idCredito'),
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Pago> pagos = data.map((pago) => Pago.fromJson(pago)).toList();

        // La lógica de cálculo de saldos ya está en tu _fetchPagos original, la replicamos
        for (var pago in pagos) {
          double totalDeuda =
              (pago.capitalMasInteres) + // Ya no es nullable en tu clase
                  (pago.moratorioDesabilitado == "Si"
                      ? 0.0
                      : (pago.moratorios?.moratorios ?? 0.0));

          bool tieneGarantia =
              pago.abonos.any((abono) => abono['garantia'] == 'Si');

          // --- CORRECCIÓN AQUÍ ---
          double montoPagado = pago.abonos.fold(0.0, (total, itemAbono) {
            // Renombrado 'abono' a 'itemAbono' para claridad
            double valorDeposito = 0.0;
            if (itemAbono['deposito'] != null) {
              if (itemAbono['deposito'] is String) {
                valorDeposito = double.tryParse(itemAbono['deposito']) ?? 0.0;
              } else if (itemAbono['deposito'] is num) {
                valorDeposito = (itemAbono['deposito'] as num).toDouble();
              }
            }
            return total + valorDeposito;
          });
          // --- FIN DE LA CORRECCIÓN ---

          pago.saldoEnContra = totalDeuda - montoPagado;
          if (pago.saldoEnContra! < 0) pago.saldoEnContra = 0.0;

          bool sinActividad = pago.abonos.isEmpty;

          if (sinActividad) {
            pago.saldoEnContra = 0.0;
            pago.saldoFavor = 0.0;
          } else {
            bool estaPagado = montoPagado >= totalDeuda;
            pago.saldoEnContra = estaPagado ? 0.0 : totalDeuda - montoPagado;
            pago.saldoFavor =
                estaPagado && !tieneGarantia ? montoPagado - totalDeuda : 0.0;
            if (pago.saldoFavor! < 0)
              pago.saldoFavor = 0.0; // Asegurar que no sea negativo
          }
        }
        return pagos;
      } else {
        String errorMessage = 'Error al obtener pagos: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] != null) {
            errorMessage = errorData["Error"]["Message"];
            if (errorMessage == "La sesión ha cambiado. Cerrando sesión..." ||
                errorMessage == "jwt expired") {
              // En un contexto estático, no podemos navegar. Lanzamos una excepción específica.
              await prefs.remove('tokenauth'); // Intentar limpiar token
              throw Exception(
                  'Sesión inválida o expirada. Por favor, vuelve a iniciar sesión en la app.');
            }
          } else {
            errorMessage = 'Error ${response.statusCode}: ${response.body}';
          }
        } catch (e) {
          // Error al decodificar el JSON del error, usar el mensaje genérico
          print('Error al procesar la respuesta de error: $e');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Re-lanzar la excepción para que 'generar' la maneje
      print('Error en _fetchPagosData: $e');
      throw Exception('Error al obtener datos de pagos: ${e.toString()}');
    }
  }
  // --- FIN DE LA NUEVA FUNCIÓN ---

  static Future<void> generar(
      BuildContext context, Credito credito, String savePath) async {
    try {
       // Currency Formatter
      final currencyFormat =
          NumberFormat.currency(locale: 'es_MX', symbol: '\$');
      /* // 1. Validar permisos
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw 'Se requieren permisos de almacenamiento';
      } */

      // 2. Validar formato de fechas
      if (!credito.fechasIniciofin.contains(' - ')) {
        throw 'Formato de fecha inválido. Use "yyyy/MM/dd - yyyy/MM/dd"';
      }

      final partes = credito.fechasIniciofin.split(' - ');
      if (partes.length != 2) {
        throw 'Formato debe ser: fecha_inicio - fecha_fin';
      }

      // 3. Parsear fechas y cambiar el formato
      final formatEntrada = DateFormat('yyyy/MM/dd');
      final formatSalida = DateFormat('dd/MM/yyyy');

      final fechaInicio = formatEntrada.parse(partes[0].trim());
      final fechaFin = formatEntrada.parse(partes[1].trim());

      final fechaInicioFormateada = formatSalida.format(fechaInicio);
      final fechaFinFormateada = formatSalida.format(fechaFin);

      // 4. Generar documento PDF
      final pdf = pw.Document();

      // 5. Definir estilos de texto
      final titleStyle = pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: primaryColor,
      );

      final sectionTitleStyle = pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: darkGrey,
      );

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

      // --- OBTENER DATOS DE PAGOS ---
      List<Pago> pagosData = [];
      String? errorPagos;
      try {
        // Asegúrate que tu objeto 'credito' tiene un campo 'idCredito' o similar
        // Si el ID del crédito está en otro campo, ajústalo aquí (ej: credito.id)
        if (credito.idcredito == null || credito.idcredito!.isEmpty) {
          throw Exception(
              "ID de crédito no disponible para obtener calendario de pagos.");
        }
        pagosData = await _fetchPagosData(credito.idcredito!);
      } catch (e) {
        print("Error al obtener datos de pagos para el PDF: $e");
        errorPagos = e
            .toString(); // Guardar el error para mostrarlo en el PDF si es necesario
      }
      // --- FIN OBTENER DATOS DE PAGOS ---

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
          header: (context) => _buildDocumentHeader(
            credito,
            titleStyle,
            finoraLogo,
            financieraLogo,
          ),
          footer: (context) => _buildCompactFooter(),
          build: (context) => [
            pw.SizedBox(height: 15),
            _buildGroupInfo(credito, sectionTitleStyle, currencyFormat),
            pw.SizedBox(height: 15),
            _buildLoanInfo(credito, sectionTitleStyle, fechaInicioFormateada,
                fechaFinFormateada,  currencyFormat),
            pw.SizedBox(height: 15),
            if (credito.clientesMontosInd.isNotEmpty) ...[
              _buildClientesSection(
                  credito.clientesMontosInd
                      .map((e) => e as ClienteMonto)
                      .toList(),
                  credito,  currencyFormat),
              pw.SizedBox(height: 15),
              // --- AÑADIR TABLA DE PAGOS ---
              if (errorPagos != null)
                pw.Padding(
                    padding: pw.EdgeInsets.symmetric(vertical: 10),
                    child: pw.Text(
                        "Error al cargar calendario de pagos: $errorPagos",
                        style: pw.TextStyle(color: PdfColors.red, fontSize: 9)))
              else if (pagosData.isNotEmpty) ...[
                pw.NewPage(),
                pw.SizedBox(height: 20),
                pw.Text("CALENDARIO DE PAGOS", style: sectionTitleStyle),
                pw.SizedBox(height: 10),
                _buildPagosSection(pagosData,  currencyFormat),
                pw.SizedBox(height: 15),
              ] else
                pw.Padding(
                    padding: pw.EdgeInsets.symmetric(vertical: 10),
                    child: pw.Text(
                        "No hay datos del calendario de pagos para mostrar.",
                        style: pw.TextStyle(
                            fontSize: 9, fontStyle: pw.FontStyle.italic))),
              // --- FIN AÑADIR TABLA DE PAGOS ---
            ],
            pw.SizedBox(height: 30),
          ],
        ),
      );

      // 6. Guardar PDF en la ruta seleccionada
      final file = File(savePath);
      await file.writeAsBytes(await pdf.save());
    } on FormatException catch (e) {
      throw 'Error en fecha: ${e.message}';
    } catch (e) {
      throw 'Error al generar PDF: ${e.toString()}';
    }
  }

  static pw.Widget _buildDocumentHeader(
      Credito credito,
      pw.TextStyle titleStyle,
      Uint8List finoraLogo,
      Uint8List? financieraLogo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: mediumGrey, width: 0.5)),
      ),
      child: pw.Column(
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
                )
              else
                pw.Container(),
              pw.Image(
                pw.MemoryImage(finoraLogo),
                width: 120,
                height: 40,
                fit: pw.BoxFit.contain,
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Resumen de crédito',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#5162F6'),
                  )),
              pw.Text(
                'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        '${credito.nombreGrupo} | ${credito.detalles}',
                        style: pw.TextStyle(
                          fontSize: 6,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Container(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    _buildStatusBadge(credito.estado),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Copiado exactamente de ControlPagos
  static pw.Widget _buildGroupInfo(
      Credito credito, pw.TextStyle sectionTitleStyle, final currencyFormat) {
    final format = NumberFormat("#,##0.00");

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('f2f7fa'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('INFORMACIÓN DEL GRUPO', style: sectionTitleStyle),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _buildInfoColumn('NOMBRE DEL GRUPO', credito.nombreGrupo, flex: 2),
            _buildInfoColumn('CICLO', credito.detalles, flex: 2),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildInfoColumn('NOMBRE DE LA PRESIDENTA',
                _getPresidenta(credito.clientesMontosInd),
                flex: 2),
            _buildInfoColumn('NOMBRE DE LA TESORERA',
                _getTesorera(credito.clientesMontosInd),
                flex: 2),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildInfoColumn('NOMBRE DEL ASESOR', credito.asesor, flex: 2),
            _buildInfoColumn(
                'MONTO TOTAL', '${currencyFormat.format(credito.montoTotal)}',
                flex: 2),
          ]),
        ],
      ),
    );
  }

  // Copiado exactamente de ControlPagos
  static String _getPresidenta(List<ClienteMonto> clientes) {
    for (var cliente in clientes) {
      if (cliente.cargo == "Presidente/a") {
        return cliente.nombreCompleto;
      }
    }
    return "No asignada";
  }

  // Copiado exactamente de ControlPagos
  static String _getTesorera(List<ClienteMonto> clientes) {
    for (var cliente in clientes) {
      if (cliente.cargo == "Tesorero/a") {
        return cliente.nombreCompleto;
      }
    }
    return "No asignada";
  }

  // Copiado exactamente de ControlPagos
  static pw.Widget _buildLoanInfo(
      Credito credito,
      pw.TextStyle sectionTitleStyle,
      String fechaInicioFormateada,
      String fechaFinFormateada,
      final currencyFormat
      ) {
    final format = NumberFormat("#,##0.00");

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('f2f7fa'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DETALLES DEL CRÉDITO', style: sectionTitleStyle),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _buildInfoColumn('DÍA DE PAGO', credito.diaPago, flex: 1),
            _buildInfoColumn('PLAZO', '${credito.plazo} SEMANAS', flex: 1),
            _buildInfoColumn('MONTO FICHA', '${currencyFormat.format(credito.pagoCuota)}', flex: 1),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildInfoColumn('MONTO DESEMBOLSADO',
                '${currencyFormat.format(credito.montoDesembolsado)}',
                flex: 1),
            _buildInfoColumn('GARANTÍA', '${credito.garantia}', flex: 1),
            _buildInfoColumn('GARANTÍA MONTO', '${currencyFormat.format(credito.montoGarantia)}',
                flex: 1),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildInfoColumn('TIPO DE CRÉDITO',
                '${credito.tipo}${credito.tipo == "Grupal" ? " - AVAL SOLIDARIO" : ""}',
                flex: 1),
            _buildInfoColumn('TASA DE INTERÉS MENSUAL', '${credito.ti_mensual}',
                flex: 1),
            _buildInfoColumn('INTERÉS TOTAL', '${currencyFormat.format(credito.interesTotal)}',
                flex: 1),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildInfoColumn('FECHA INICIO DE CONTRATO', fechaInicioFormateada,
                flex: 1),
            _buildInfoColumn('FECHA TÉRMINO DE CONTRATO', fechaFinFormateada,
                flex: 1),
            _buildInfoColumn('MONTO A RECUPERAR', '${currencyFormat.format(credito.montoMasInteres)}',
                flex: 1),
          ]),
        ],
      ),
    );
  }

  // Método actualizado con el mismo estilo de ControlPagos (con parámetro flex)
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
              fontSize: 7, // Mismo tamaño que ControlPagos
              color: darkGreyColor, // Mismo color que ControlPagos
            ),
          ),
          pw.SizedBox(height: 2), // Mismo espaciado que ControlPagos
          pw.Text(
            value.toUpperCase(),
            style: valueStyle ??
                pw.TextStyle(
                  fontSize: 8, // Mismo tamaño que ControlPagos
                  fontWeight: pw.FontWeight.bold, // Mismo peso que ControlPagos
                ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatusBadge(String status) {
    PdfColor statusColor;
    switch (status.toLowerCase()) {
      case 'activo':
      case 'vigente':
        statusColor = PdfColors.green;
        break;
      case 'finalizado':
      case 'pagado':
        statusColor = PdfColors.blue800;
        break;
      case 'vencido':
      case 'moroso':
        statusColor = PdfColors.red;
        break;
      case 'pendiente':
        statusColor = PdfColors.orange;
        break;
      default:
        statusColor = PdfColors.grey;
    }

    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: statusColor,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        status.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _tableHeader(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildClientesSection(
      List<ClienteMonto> clientesMontosInd, Credito credito, final currencyFormat) {
    final sumTotalRedondeado = credito.pagoCuota * credito.plazo;

    // Definir colores para la tabla (mismos que _paymentTable)
    final headerColor = PdfColor.fromHex('f2f7fa');
    final rowEvenColor = PdfColors.white;
    final rowOddColor = PdfColors.grey100;
    final totalRowColor = PdfColor.fromHex('f2f7fa');
    final borderColor = PdfColors.blue800;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      /*  decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('f2f7fa'),
        borderRadius: pw.BorderRadius.circular(8),
      ), */
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('MONTOS INDIVIDUALES', style: sectionTitleStyle),
          pw.SizedBox(height: 10),
          pw.Column(
            children: [
              // Encabezado de la tabla
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 50,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'No.',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 220,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'CLIENTE',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 100,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'M. INDIV.',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 100,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'CAPITAL',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 100,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'INTERÉS',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 120,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'TOT. CAPITAL',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 120,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'TOT. INTERÉS',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 120,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'CAP + INT',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 120,
                    child: pw.Container(
                      height: 30,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: headerColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'PAGO TOTAL',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Filas de clientes
              ...clientesMontosInd.asMap().entries.map((entry) {
                int index = entry.key;
                ClienteMonto cliente = entry.value;
                bool isEven = index % 2 == 0;

                return pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 50,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${index + 1}',
                            style: pw.TextStyle(
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 220,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Padding(
                          padding: pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: pw.Align(
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Text(
                              cliente.nombreCompleto,
                              style: pw.TextStyle(fontSize: 6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 100,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${currencyFormat.format(cliente.capitalIndividual)}',
                            style: pw.TextStyle(
                              fontSize: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 100,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${currencyFormat.format(cliente.periodoCapital)}',
                            style: pw.TextStyle(
                              fontSize: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 100,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${currencyFormat.format(cliente.periodoInteres)}',
                            style: pw.TextStyle(
                              fontSize: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 120,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${currencyFormat.format(cliente.totalCapital)}',
                            style: pw.TextStyle(
                              fontSize: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 120,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${currencyFormat.format(cliente.totalIntereses)}',
                            style: pw.TextStyle(
                              fontSize: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 120,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${currencyFormat.format(cliente.capitalMasInteres)}',
                            style: pw.TextStyle(
                              fontSize: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 120,
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.5),
                          color: isEven ? rowEvenColor : rowOddColor,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '${currencyFormat.format(cliente.total)}',
                            style: pw.TextStyle(
                              fontSize: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),

              // Fila de totales
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 50,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '', // Celda en blanco
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 220,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'TOTALES',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 100,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                         '${currencyFormat.format(clientesMontosInd.fold(
                              0.0, (sum, c) => sum + c.capitalIndividual))}',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 100,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '${currencyFormat.format(clientesMontosInd.fold(
                              0.0, (sum, c) => sum + c.periodoCapital))}',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 100,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                         '${currencyFormat.format(clientesMontosInd.fold(
                              0.0, (sum, c) => sum + c.periodoInteres))}',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 120,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                         '${currencyFormat.format(clientesMontosInd.fold(
                              0.0, (sum, c) => sum + c.totalCapital))}',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 120,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                         '${currencyFormat.format(clientesMontosInd.fold(
                              0.0, (sum, c) => sum + c.totalIntereses))}',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 120,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                         '${currencyFormat.format(credito.pagoCuota)}',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 120,
                    child: pw.Container(
                      height: 25,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.5),
                        color: totalRowColor,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                         '${currencyFormat.format(sumTotalRedondeado)}',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
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

  // --- NUEVA FUNCIÓN HELPER PARA FORMATEAR FECHAS ---
  static String _formatPdfDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'N/A';
    }
    try {
      // Intentar parsear formatos comunes que podrías recibir
      if (dateString.contains('-')) {
        // Formato YYYY-MM-DD (común en APIs)
        final parsedDate = DateFormat('yyyy-MM-dd').parse(dateString);
        return dateFormat.format(parsedDate); // dateFormat es dd/MM/yyyy
      } else if (dateString.contains('/')) {
        // Formato YYYY/MM/DD
        final parsedDate = DateFormat('yyyy/MM/dd').parse(dateString);
        return dateFormat.format(parsedDate);
      } else if (dateString.length == 8 && int.tryParse(dateString) != null) {
        // Formato YYYYMMDD
        final parsedDate = DateFormat('yyyyMMdd').parse(dateString);
        return dateFormat.format(parsedDate);
      }
      // Si no es un formato conocido o falla el parseo, devolver original o un placeholder
      return dateString;
    } catch (e) {
      print("Error parseando fecha '$dateString' para PDF: $e");
      return dateString; // Devolver original en caso de error de parseo
    }
  }

  // --- MÉTODO PARA CONSTRUIR LA SECCIÓN DE PAGOS ---
  // --- MÉTODO ACTUALIZADO PARA CONSTRUIR LA SECCIÓN DE PAGOS ---
  // --- MÉTODO ACTUALIZADO PARA CONSTRUIR LA SECCIÓN DE PAGOS CON SALDO EN CONTRA ---
  static pw.Widget _buildPagosSection(List<Pago> pagos, final currencyFormat) {
    final headerColor = PdfColor.fromHex('f2f7fa');
    final rowEvenColor = PdfColors.white;
    final rowOddColor = PdfColors.grey100;
    final borderColor = PdfColors.blueGrey300;
    final headerTextStyle = pw.TextStyle(
        fontSize: 6,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey900);
    final cellTextStyle = pw.TextStyle(fontSize: 6);

    List<pw.TableRow> tableRows = [];

    // Encabezado
    tableRows.add(pw.TableRow(
      decoration: pw.BoxDecoration(color: headerColor),
      children: [
        _paddedCell('SEM.', headerTextStyle, alignment: pw.Alignment.center),
        _paddedCell('F. PROGRAMADA', headerTextStyle,
            alignment: pw.Alignment.center),
        _paddedCell('MONTO FICHA', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('F. REALIZADO', headerTextStyle,
            alignment: pw.Alignment.center),
        _paddedCell('PAGOS', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('S. A FAVOR', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('S. EN CONTRA', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('MORAT. GENERADOS', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('MORAT. PAGADOS', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('TIPO PAGO', headerTextStyle,
            alignment: pw.Alignment.center),
        _paddedCell('ESTADO', headerTextStyle, alignment: pw.Alignment.center),
      ],
    ));

    // Totales acumulados
    double totalCuotas = 0.0;
    double totalAbonos = 0.0;
    double totalSaldoFavor = 0.0;
    double totalSaldoContra = 0.0;
    double totalMoratoriosGenerados = 0.0;
    double totalMoratoriosPagados = 0.0;

    // Filas de datos
    for (int i = 0; i < pagos.length; i++) {
      final pago = pagos[i];
      final bool isEven = i % 2 == 0;
      final bgColor = isEven ? rowEvenColor : rowOddColor;

      String fechaProgramadaFormateada = _formatPdfDate(pago.fechaPago);

      String fechaRealizadoFormateada = "N/A";
      if (pago.abonos.isNotEmpty) {
        List<String> fechasFormateadas = [];
        for (var abono in pago.abonos) {
          if (abono['fechaDeposito'] != null) {
            String fechaFormateada = _formatPdfDate(abono['fechaDeposito'] as String?);
            fechasFormateadas.add(fechaFormateada);
          }
        }
        if (fechasFormateadas.isNotEmpty) {
          fechaRealizadoFormateada = fechasFormateadas.join('\n');
        }
      }

      String tipoPagoDisplay = pago.tipoPago;
      if (tipoPagoDisplay.isEmpty ||
          tipoPagoDisplay.toLowerCase() == "sin asignar") {
        tipoPagoDisplay = "N/A";
      }

      // Procesar abonos
      String pagosDetallados = "N/A";
      double totalAbonosPago = 0.0;
      if (pago.abonos.isNotEmpty) {
        List<String> detalles = [];
        for (var abono in pago.abonos) {
          double montoDeposito = 0.0;
          if (abono['deposito'] != null) {
            if (abono['deposito'] is String) {
              montoDeposito = double.tryParse(abono['deposito']) ?? 0.0;
            } else if (abono['deposito'] is num) {
              montoDeposito = (abono['deposito'] as num).toDouble();
            }
          }
          totalAbonosPago += montoDeposito;
          String montoFormateado = '${currencyFormat.format(montoDeposito)}';
          String esGarantia = (abono['garantia'] == 'Si') ? " (G)" : "";
          detalles.add("$montoFormateado$esGarantia");
        }
        pagosDetallados = detalles.join('\n');
      }

      // Calcular saldo en contra
      // Si el monto pagado es menor que el monto de la ficha, hay saldo en contra
      double saldoContra = 0.0;
      if (pago.semana != 0) {
        double montoDebe = pago.capitalMasInteres;
        if (totalAbonosPago < montoDebe) {
          saldoContra = montoDebe - totalAbonosPago;
        }
      }

      // Procesar moratorios
      double moratoriosGenerados = 0.0;
      double moratoriosPagados = 0.0;
      
      if (pago.pagosMoratorios.isNotEmpty) {
        for (var moratorio in pago.pagosMoratorios) {
          double moratorioAPagar = 0.0;
          double sumaMoratorios = 0.0;
          
          if (moratorio['moratorioAPagar'] != null) {
            if (moratorio['moratorioAPagar'] is String) {
              moratorioAPagar = double.tryParse(moratorio['moratorioAPagar']) ?? 0.0;
            } else if (moratorio['moratorioAPagar'] is num) {
              moratorioAPagar = (moratorio['moratorioAPagar'] as num).toDouble();
            }
          }
          
          if (moratorio['sumaMoratorios'] != null) {
            if (moratorio['sumaMoratorios'] is String) {
              sumaMoratorios = double.tryParse(moratorio['sumaMoratorios']) ?? 0.0;
            } else if (moratorio['sumaMoratorios'] is num) {
              sumaMoratorios = (moratorio['sumaMoratorios'] as num).toDouble();
            }
          }
          
          moratoriosGenerados += moratorioAPagar;
          moratoriosPagados += sumaMoratorios;
        }
      }

      // Acumuladores solo si no es semana 0
      if (pago.semana != 0) {
        totalCuotas += pago.capitalMasInteres;
        totalAbonos += totalAbonosPago;
        totalSaldoFavor += pago.saldoFavor ?? 0.0;
        totalSaldoContra += saldoContra;
        totalMoratoriosGenerados += moratoriosGenerados;
        totalMoratoriosPagados += moratoriosPagados;
      }

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bgColor),
        children: [
          _paddedCell(pago.semana.toString(), cellTextStyle,
              alignment: pw.Alignment.center),
          _paddedCell(fechaProgramadaFormateada, cellTextStyle,
              alignment: pw.Alignment.center),
          _paddedCell(
              pago.semana == 0 ? 'N/A' : '${currencyFormat.format(pago.capitalMasInteres)}',
              cellTextStyle,
              alignment: pw.Alignment.centerRight),
          _paddedCell(fechaRealizadoFormateada, cellTextStyle,
              alignment: pw.Alignment.center),
          _paddedCell(pagosDetallados, cellTextStyle,
              alignment: pw.Alignment.centerRight),
          _paddedCell('${currencyFormat.format(pago.saldoFavor ?? 0.0)}', cellTextStyle,
              alignment: pw.Alignment.centerRight),
          _paddedCell('${currencyFormat.format(saldoContra)}', cellTextStyle,
              alignment: pw.Alignment.centerRight),
          _paddedCell('${currencyFormat.format(moratoriosGenerados)}', cellTextStyle,
              alignment: pw.Alignment.centerRight),
          _paddedCell('${currencyFormat.format(moratoriosPagados)}', cellTextStyle,
              alignment: pw.Alignment.centerRight),
          _paddedCell(tipoPagoDisplay, cellTextStyle,
              alignment: pw.Alignment.center),
          _paddedCell(pago.estado, cellTextStyle,
              alignment: pw.Alignment.center),
        ],
      ));
    }

    // Fila de totales
    tableRows.add(pw.TableRow(
      decoration: pw.BoxDecoration(color: headerColor),
      children: [
        _paddedCell(
          'TOTALES',
          headerTextStyle,
          alignment: pw.Alignment.center,
        ),
        _paddedCell('', headerTextStyle),
        _paddedCell('${currencyFormat.format(totalCuotas)}', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('', headerTextStyle),
        _paddedCell('${currencyFormat.format(totalAbonos)}', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('${currencyFormat.format(totalSaldoFavor)}', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('${currencyFormat.format(totalSaldoContra)}', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('${currencyFormat.format(totalMoratoriosGenerados)}', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('${currencyFormat.format(totalMoratoriosPagados)}', headerTextStyle,
            alignment: pw.Alignment.centerRight),
        _paddedCell('', headerTextStyle),
        _paddedCell('', headerTextStyle),
      ],
    ));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        //pw.Text('CALENDARIO DE PAGOS', style: sectionTitleStyle),
        //pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          children: tableRows,
          columnWidths: {
            0: pw.FlexColumnWidth(0.7), // Sem.
            1: pw.FlexColumnWidth(1.0), // F. Programada
            2: pw.FlexColumnWidth(0.9), // Monto Ficha
            3: pw.FlexColumnWidth(1.0), // F. Realizado
            4: pw.FlexColumnWidth(1.0), // Pagos
            5: pw.FlexColumnWidth(0.8), // S. Favor
            6: pw.FlexColumnWidth(0.8), // S. En Contra
            7: pw.FlexColumnWidth(0.8), // Morat. Generados
            8: pw.FlexColumnWidth(0.8), // Morat. Pagados
            9: pw.FlexColumnWidth(0.8), // Tipo Pago
            10: pw.FlexColumnWidth(0.7), // Estado
          },
        ),
      ],
    );
  }

  // Helper para celdas con padding
  static pw.Widget _paddedCell(String text, pw.TextStyle style,
      {pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(
          horizontal: 4, vertical: 5), // Aumentar padding vertical
      alignment: alignment,
      child: pw.Text(text, style: style, softWrap: true),
    );
  }

  static pw.Widget _buildCompactFooter() {
    // Implementa el footer según tu necesidad
    return pw.Container();
  }
}
