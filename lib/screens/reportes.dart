import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class ReportesScreen extends StatefulWidget {
  final String username;
  final String tipoUsuario;

  const ReportesScreen({required this.username, required this.tipoUsuario});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  List<Reporte> listaReportes = [];
  bool isLoading = false;
  bool errorDeConexion = false;
  bool noReportesFound = false;
  bool hasGenerated = false;
  String? selectedReportType;
  DateTimeRange? selectedDateRange;
  final NumberFormat currencyFormat = NumberFormat('\$#,##0.00', 'en_US');

  Timer? _timer;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  ReporteData? reporteData; // <--- Variable faltante
  String? errorMessage;
  bool hasError = false;

  final List<String> reportTypes = [
    'Reporte General',
    'Reporte Contable',
    //'Reporte de Moratorios'
  ];

  @override
  void initState() {
    super.initState();
    /* selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    ); */
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> obtenerReportes() async {
    if (selectedReportType == null || selectedDateRange == null) return;

    setState(() {
      isLoading = true;
      listaReportes = []; // <-- Limpia antes de nueva solicitud
      reporteData = null;
      hasError = false;
      errorDeConexion = false;
      noReportesFound = false;
    });

    bool dialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final fechaInicio =
          DateFormat('yyyy-MM-dd').format(selectedDateRange!.start);
      final fechaFin = DateFormat('yyyy-MM-dd').format(selectedDateRange!.end);

      String tipoReporte;
      switch (selectedReportType) {
        case 'Reporte Contable':
          tipoReporte = 'contable';
          break;
        case 'Reporte de Moratorios':
          tipoReporte = 'moratorios';
          break;
        default:
          tipoReporte = 'general';
      }

      final url = Uri.parse(
        'http://$baseUrl/api/v1/formato/reporte/$tipoReporte/datos?inicio=$fechaInicio&final=$fechaFin',
      );

      print(url);

      final response = await http.get(
        url,
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          reporteData = ReporteData.fromJson(data);
          listaReportes =
              reporteData?.listaGrupos ?? []; // <- Esta línea faltaba
          isLoading = false;
          hasGenerated = true;
        });
      } else if (response.statusCode == 401) {
        // Manejo de token expirado
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tokenauth');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      } else if (response.statusCode == 404) {
        setState(() {
          reporteData = null;
          isLoading = false;
          noReportesFound = true;
        });
      } else {
        setState(() {
          // <-- Reemplazar mostrarDialogoError
          isLoading = false;
          hasError = true;
          errorMessage = 'Error ${response.statusCode}: ${response.body}';
        });
      }
    } on SocketException {
      setState(() {
        // <-- Reemplazar mostrarDialogoError
        isLoading = false;
        hasError = true;
        errorMessage = 'Error de conexión. Verifica tu internet';
      });
    } on TimeoutException {
      setState(() {
        // <-- Reemplazar mostrarDialogoError
        isLoading = false;
        hasError = true;
        errorMessage = 'Tiempo de espera agotado';
      });
    } catch (e) {
      setState(() {
        // <-- Reemplazar mostrarDialogoError
        isLoading = false;
        hasError = true;
        errorMessage = 'Error inesperado: ${e.toString()}';
      });
    }
  }

  /* Future<void> exportarReporte() async {
    if (selectedReportType == null || selectedDateRange == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final fechaInicio =
          DateFormat('yyyy-MM-dd').format(selectedDateRange!.start);
      final fechaFin = DateFormat('yyyy-MM-dd').format(selectedDateRange!.end);

      String tipoReporte;
      if (selectedReportType == 'Reporte General') {
        tipoReporte = 'general';
      } else if (selectedReportType == 'Reporte de Pagos') {
        tipoReporte = 'pagos';
      } else {
        tipoReporte = 'moratorios';
      }

      // URL sin /datos
      final url = Uri.parse(
          'http://$baseUrl/api/v1/formato/reporte/$tipoReporte?inicio=$fechaInicio&final=$fechaFin');

      final response = await http.get(
        url,
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Guardar el archivo
        final bytes = response.bodyBytes;
        final fileName =
            'Reporte_${DateFormat('yyyyMMdd').format(DateTime.now())}.docx';

        final result = await FilePicker.platform.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['docx'],
        );

        if (result != null) {
          final file = File(result);
          await file.writeAsBytes(bytes);

          // Abrir el archivo
          OpenFile.open(result);
        }
      } else {
        mostrarDialogoError(
            'Error al exportar el reporte: ${response.statusCode}');
      }
    } catch (e) {
      mostrarDialogoError('Error al exportar: $e');
    }
  } */

 Future<void> exportarReporte() async {
  if (reporteData == null || selectedDateRange == null) {
    mostrarDialogoError('No hay datos para exportar');
    return;
  }

  try {
    final doc = pw.Document();

    // Función para construir el contenido paginado
    void buildPdfPages() {
      final headers = [
        '#', 'Tipo Pago', 'Grupos', 'Folio', 'Pago Ficha',
        'Fecha Depósito', 'Monto Ficha', 'Capital', 'Interés',
        'Saldo', 'Moratorios'
      ];

      // Configuración de la tabla
      const rowHeight = 20.0;
      final pageFormat = PdfPageFormat.a4.copyWith(
        marginTop: 1.5 * PdfPageFormat.cm,
        marginBottom: 1.5 * PdfPageFormat.cm,
        marginLeft: 1.0 * PdfPageFormat.cm,
        marginRight: 1.0 * PdfPageFormat.cm,
      );

      // Calcular filas por página
      final availableHeight = pageFormat.availableHeight - 100; // Espacio para header y footer
      final rowsPerPage = (availableHeight / rowHeight).floor();

      // Dividir los datos en chunks
      final dataChunks = [];
      for (var i = 0; i < listaReportes.length; i += rowsPerPage) {
        dataChunks.add(listaReportes.sublist(
          i, 
          i + rowsPerPage > listaReportes.length ? listaReportes.length : i + rowsPerPage
        ));
      }

      // Construir páginas
      for (var chunk in dataChunks) {
        doc.addPage(
          pw.MultiPage(
            pageTheme: pw.PageTheme(
              pageFormat: pageFormat,
              margin: const pw.EdgeInsets.all(20),
            ),
            header: (context) => _buildPdfHeader(),
            footer: (context) => _buildPdfFooter(context),
            build: (context) => [
              _buildPdfTable(headers, chunk),
              if (chunk == dataChunks.last) _buildPdfTotals(),
            ],
          ),
        );
      }
    }

    buildPdfPages();

    // Guardar el archivo
    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar Reporte',
      fileName: 'reporte_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );

    if (output != null) {
      final file = File(output);
      await file.writeAsBytes(await doc.save());
      await OpenFile.open(file.path);
    }
  } catch (e) {
    mostrarDialogoError('Error al exportar: ${e.toString()}');
  }
}

pw.Widget _buildPdfTable(List<String> headers, List<Reporte> data) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColor.fromHex('#DDDDDD')),
    columnWidths: {
      0: const pw.FlexColumnWidth(0.5), // Reducir el ancho de la columna "#"
      for (var i = 1; i < headers.length; i++) 
        i: const pw.FlexColumnWidth(1), // Mantener el ancho de las otras columnas igual
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#5162F6')),
        children: headers.map((header) => _buildPdfHeaderCell(header)).toList(),
      ),
      ...data.map((reporte) {
        final hasPagoFichaZero = reporte.pagoficha == 0;

        return pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          decoration: pw.BoxDecoration(
            color: hasPagoFichaZero
                ? PdfColor.fromHex('#FFDDDD') 
                : (data.indexOf(reporte).isEven
                    ? PdfColor.fromHex('#F8F9FE')
                    : PdfColors.white),
          ),
          children: [
            _buildPdfCell(reporte.numero.toString(), isNumeric: true),
            _buildPdfCell(reporte.tipoPago),
            _buildPdfCell(reporte.grupos),
            _buildPdfCell(reporte.folio),
            _buildPdfCell(currencyFormat.format(reporte.pagoficha), isNumeric: true),
            _buildPdfCell(reporte.fechadeposito),
            _buildPdfCell(currencyFormat.format(reporte.montoficha), isNumeric: true),
            _buildPdfCell(currencyFormat.format(reporte.capitalsemanal), isNumeric: true),
            _buildPdfCell(currencyFormat.format(reporte.interessemanal), isNumeric: true),
            _buildPdfCell(currencyFormat.format(reporte.saldofavor), isNumeric: true),
            _buildPdfCell(currencyFormat.format(reporte.moratorios), isNumeric: true),
          ],
        );
      }).toList(),
    ],
  );
}


pw.Widget _buildPdfFooter(pw.Context context) {
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

pw.Widget _buildPdfHeader() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Fila para las imágenes
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Image(pw.MemoryImage(File('assets/logo_mf_n_hzt.png').readAsBytesSync()), width: 100, height: 100),
          pw.Image(pw.MemoryImage(File('assets/finora_hzt.png').readAsBytesSync()), width: 120, height: 120),
        ],
      ),
      pw.SizedBox(height: 10), // Espacio entre la fila de imágenes y el texto
      pw.Text(
        '${selectedReportType ?? ''}',
        style: pw.TextStyle(
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#5162F6'),
        ),
      ),
      pw.Text(
        'Periodo: ${DateFormat('dd/MM/yyyy').format(selectedDateRange!.start)} - '
        '${DateFormat('dd/MM/yyyy').format(selectedDateRange!.end)}',
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.Text(
        'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 10),
      ),
    ],
  );
}




pw.Widget _buildPdfHeaderCell(String text) {
  return pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 7,
      ),
    ),
  );
}

pw.Widget _buildPdfCell(String text, {bool isNumeric = false}) {
  return pw.Container(
    alignment: isNumeric ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: const pw.TextStyle(
        fontSize: 7,
        color: PdfColors.black,
      ),
    ),
  );
}

pw.Widget _buildPdfTotals() {
  return pw.Table(
    columnWidths: {
      for (var i = 0; i < 11; i++) i: const pw.FlexColumnWidth(1),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#5162F6')),
        children: [
          _buildTotalCell('Totales'),
          _buildTotalCell(''),
          _buildTotalCell(''),
          _buildTotalCell(''),
          _buildTotalCell(currencyFormat.format(reporteData!.totalPagoficha)),
          _buildTotalCell(''),
          _buildTotalCell(currencyFormat.format(reporteData!.totalFicha)),
          _buildTotalCell(currencyFormat.format(reporteData!.totalCapital)),
          _buildTotalCell(currencyFormat.format(reporteData!.totalInteres)),
          _buildTotalCell(currencyFormat.format(reporteData!.totalSaldoFavor)),
          _buildTotalCell(currencyFormat.format(reporteData!.saldoMoratorio)),
        ],
      ),
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#5162F6')),
        children: [
          _buildTotalCell('Total Final'),
          _buildTotalCell(''),
          _buildTotalCell(''),
          _buildTotalCell(''),
          _buildTotalCell(''),
          _buildTotalCell(''),
          _buildTotalCell(currencyFormat.format(reporteData!.totalTotal)),
          _buildTotalCell(''),
          _buildTotalCell(''),
          _buildTotalCell(''),
          _buildTotalCell(''),
        ],
      ),
    ],
  );
}

pw.Widget _buildTotalCell(String text) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style:  pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 6,
      ),
    ),
  );
}

  void setErrorState(bool dialogShown, [dynamic error]) {
    setState(() {
      isLoading = false;
      errorDeConexion = true;
    });
    if (!dialogShown) {
      dialogShown = true;
      if (error is SocketException) {
        mostrarDialogoError('Error de conexión. Verifica tu red.');
      } else {
        mostrarDialogoError('Ocurrió un error inesperado.');
      }
      _timer?.cancel();
    }
  }

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onClose != null) onClose();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }


  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF7F8FA),
    appBar: CustomAppBar(
      isDarkMode: false,
      toggleDarkMode: (value) {},
      title: 'Reportes Financieros',
      nombre: widget.username,
      tipoUsuario: widget.tipoUsuario,
    ),
    body: Column(
      children: [
        _buildFilterRow(),
        Expanded(
          child: hasGenerated
              ? isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hasError
                      ? _buildErrorDisplay()
                      : _buildDataTableContent() // Aquí se arma la tabla completa
              : _buildInitialMessage(),
        ),
      ],
    ),
  );
}

  Widget _buildErrorDisplay() {
    // Parsear el mensaje de error
    String? errorMessage = "No se encontraron reportes";
    final errorCode = "400";

    return Center(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: Colors.grey,
              size: 40,
            ),
            SizedBox(height: 15),
            Text(
              'Error $errorCode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Reiniciar el estado a los valores iniciales
                setState(() {
                  hasError = false;
                  errorMessage = null;
                  selectedReportType = null;
                  selectedDateRange = null;
                  hasGenerated = false;
                  listaReportes.clear();
                  reporteData = null;
                });
              },
              icon: Icon(
                Icons.refresh,
                size: 18,
                color: Colors.white,
              ),
              label: Text('Intentar nuevamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5162F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: selectedReportType,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                hint: const Text('Selecciona tipo de reporte',
                    style: TextStyle(fontSize: 14)),
                items: reportTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedReportType = value;
                    hasGenerated = false; // <-- Reinicia estado
                    listaReportes.clear(); // <-- Limpia datos antiguos
                    reporteData = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              onTap: _selectDateRange,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 10),
                  Text(
                      selectedDateRange != null
                          ? '${DateFormat('dd/MM/yy').format(selectedDateRange!.start)} - '
                              '${DateFormat('dd/MM/yy').format(selectedDateRange!.end)}'
                          : 'Seleccionar fechas',
                      style: TextStyle(fontSize: 12)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            width: 150,
            child: ElevatedButton(
              onPressed: (selectedReportType != null &&
                      selectedDateRange != null) // Cambio aquí
                  ? () {
                      if (selectedReportType == null ||
                          selectedDateRange == null) {
                        mostrarDialogoError('Selecciona todos los parámetros');
                        return;
                      }
                      setState(() {
                        hasGenerated = true;
                        listaReportes.clear(); // <-- Limpia al generar nuevo
                      });
                      obtenerReportes();
                    }
                  : null, // Deshabilita si falta algún parámetro
              style: ElevatedButton.styleFrom(
                backgroundColor: (selectedReportType != null &&
                        selectedDateRange != null) // Opcional: estilo diferente
                    ? const Color(0xFF5162F6)
                    : Colors.grey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Generar',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 15),
          Visibility(
            visible: hasGenerated,
            child: Container(
              width: 180,
              child: ElevatedButton(
                onPressed: () async {
                  if (selectedReportType == null || selectedDateRange == null) {
                    mostrarDialogoError('Primero genera un reporte');
                    return;
                  }
                  await exportarReporte();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5162F6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Exportar Reporte',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Color(0xFFf5fafb),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(20),
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Theme(
              data: Theme.of(context).copyWith(
                // 1. Color del contenedor principal del diálogo
                dialogTheme: DialogTheme(
                  backgroundColor: Colors.red, // Fondo externo
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                // 2. Tema específico del DatePicker
                datePickerTheme: DatePickerThemeData(
                  backgroundColor: Colors.green, // Fondo interno del calendario
                  headerBackgroundColor: Colors.blue, // Color del encabezado
                ),

                // 3. Esquema de colores crítico
                colorScheme: ColorScheme.light(
                  primary:
                      Colors.blue, // Color principal de botones y selección
                  onPrimary: Colors.white,
                  surface: Colors.yellow, // Color base del calendario
                  onSurface: Colors.black, // Color del texto
                ),
              ),
              child: DateRangePickerDialog(
                initialDateRange: selectedDateRange,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                helpText: 'Selecciona rango de fechas',
                cancelText: 'Cancelar',
                confirmText: 'Confirmar',
                saveText: 'Guardar',
                errorInvalidRangeText: 'Rango inválido',
                fieldStartLabelText: 'Fecha inicio',
                fieldEndLabelText: 'Fecha fin',
              ),
            ),
          ),
        ),
      ),
    );

    if (picked != null) {
      setState(() => selectedDateRange = picked);
    }
  }


  /// Construye el contenedor de la tabla con header fijo, cuerpo desplazable y totales fijos.
/// Construye el contenedor de la tabla con header fijo, cuerpo desplazable y totales fijos.
Widget _buildDataTableContent() {
  return Container(
    padding: const EdgeInsets.all(20),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      // ClipRRect evita que el contenido se salga del contenedor con bordes redondeados
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: listaReportes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const CircularProgressIndicator()
                    else if (noReportesFound)
                      _buildErrorDisplay()
                    else
                      const Text('Selecciona parámetros y genera el reporte'),
                  ],
                ),
              )
            : Column(
                children: [
                  // Encabezado fijo
                  _buildDataTableHeader(),
                  // Cuerpo desplazable (filas de datos)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      child: _buildDataTableBody(),
                    ),
                  ),
                  // Totales fijos
                  if (reporteData != null) _buildTotalsWidget(),
                ],
              ),
      ),
    ),
  );
}

  // Variables para los tamaños de fuente
  final double headerTextSize = 12.0; // Tamaño de fuente para los encabezados
  final double cellTextSize = 11.0; // Tamaño de fuente para las celdas

  /// Encabezado de la tabla (con estilo similar al DataTable original).
Widget _buildDataTableHeader() {
  return Container(
    color: const Color(0xFF5162F6),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    child: Row(
      children: [
        _buildHeaderCell('#'),
        _buildHeaderCell('Tipo de Pago'),
        _buildHeaderCell('Grupos'),
        _buildHeaderCell('Folio'),
        _buildHeaderCell('ID Ficha'),
        _buildHeaderCell('Pago Ficha'),
        _buildHeaderCell('Fecha Depósito'),
        _buildHeaderCell('Monto Ficha'),
        _buildHeaderCell('Capital Semanal'),
        _buildHeaderCell('Interés Semanal'),
        _buildHeaderCell('Saldo Favor'),
        _buildHeaderCell('Moratorios'),
      ],
    ),
  );
}

/// Celda individual para el encabezado.
Widget _buildHeaderCell(String text) {
  return Expanded(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: headerTextSize,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

/// Cuerpo de la tabla: se generan las filas de datos a partir de `listaReportes`.
Widget _buildDataTableBody() {
  return Column(
    children: listaReportes.asMap().entries.map((entry) {
      final reporte = entry.value;
      final index = entry.key;
      return Container(
        color: index.isEven ? const Color.fromARGB(255, 193, 213, 243) : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            _buildBodyCell(reporte.numero.toString(), alignment: Alignment.center),
            _buildBodyCell(reporte.tipoPago),
            _buildBodyCell(reporte.grupos),
            _buildBodyCell(reporte.folio),
            _buildBodyCell(reporte.idficha),
            _buildBodyCell(
              currencyFormat.format(reporte.pagoficha),
              alignment: Alignment.centerRight,
            ),
            _buildBodyCell(reporte.fechadeposito),
            _buildBodyCell(
              currencyFormat.format(reporte.montoficha),
              alignment: Alignment.centerRight,
            ),
            _buildBodyCell(
              currencyFormat.format(reporte.capitalsemanal),
              alignment: Alignment.centerRight,
            ),
            _buildBodyCell(
              currencyFormat.format(reporte.interessemanal),
              alignment: Alignment.centerRight,
            ),
            _buildBodyCell(
              currencyFormat.format(reporte.saldofavor),
              alignment: Alignment.centerRight,
            ),
            _buildBodyCell(
              currencyFormat.format(reporte.moratorios),
              alignment: Alignment.centerRight,
            ),
          ],
        ),
      );
    }).toList(),
  );
}

/// Celda individual para el cuerpo de la tabla.
Widget _buildBodyCell(String text, {Alignment alignment = Alignment.centerLeft}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: alignment,
      child: Text(
        text,
        style: TextStyle(
          fontSize: cellTextSize,
          color: Colors.grey[800],
        ),
      ),
    ),
  );
}

/// Totales fijos: muestra dos filas de totales utilizando los datos de `reporteData`.
Widget _buildTotalsWidget() {
  return Column(
    children: [
      _buildTotalsRow(
        'Totales',
        [
          (value: reporteData!.totalPagoficha, column: 4),
          (value: reporteData!.totalFicha, column: 6),
          (value: reporteData!.totalCapital, column: 7),
          (value: reporteData!.totalInteres, column: 8),
          (value: reporteData!.totalSaldoFavor, column: 9),
          (value: reporteData!.saldoMoratorio, column: 10),
        ],
      ),
      _buildTotalsRow(
        'Total Final',
        [
          (value: reporteData!.totalTotal, column: 6),
        ],
      ),
    ],
  );
}

/// Construye una fila de totales recibiendo el label y una lista de valores en celdas específicas.
Widget _buildTotalsRow(String label, List<({double value, int column})> values) {
  // Se generan 11 celdas (Expanded) vacías para cubrir las 11 columnas.
  List<Widget> cells = List.generate(11, (_) => Expanded(child: Container()));
  
  // La primera celda muestra el label.
  cells[0] = Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: cellTextSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );
  
  // Se asignan los valores a las columnas indicadas.
  for (final val in values) {
    cells[val.column] = Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        alignment: Alignment.centerRight,
        child: Text(
          currencyFormat.format(val.value),
          style: TextStyle(
            fontSize: cellTextSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
  
  return Container(
    color: const Color(0xFF5162F6),
    child: Row(children: cells),
  );
}

  Widget _buildInitialMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 50,
            color: Colors.grey[600],
          ),
          SizedBox(height: 8),
          Text(
            'Selecciona el tipo de reporte y rango de fechas,\nluego presiona Generar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

}

class ReporteData {
  final String fechaSemana;
  final String fechaActual;
  final double totalCapital;
  final double totalInteres;
  final double totalPagoficha;
  final double totalSaldoFavor;
  final double saldoMoratorio;
  final double totalTotal;
  final double totalFicha;
  final List<Reporte> listaGrupos;

  ReporteData({
    required this.fechaSemana,
    required this.fechaActual,
    required this.totalCapital,
    required this.totalInteres,
    required this.totalPagoficha,
    required this.totalSaldoFavor,
    required this.saldoMoratorio,
    required this.totalTotal,
    required this.totalFicha,
    required this.listaGrupos,
  });

  factory ReporteData.fromJson(Map<String, dynamic> json) {
    double parseValor(String value) =>
        double.parse(value.replaceAll(RegExp(r'[^0-9.]'), ''));

    return ReporteData(
      fechaSemana: json['fechaSemana'] ?? 'N/A',
      fechaActual: json['fechaActual'] ?? 'N/A',
      totalCapital: parseValor(json['totalCapital']),
      totalInteres: parseValor(json['totalInteres']),
      totalPagoficha: parseValor(json['totalPagoficha']),
      totalSaldoFavor: parseValor(json['totalSaldoFavor']),
      saldoMoratorio: parseValor(json['saldoMoratorio']),
      totalTotal: parseValor(json['totalTotal']),
      totalFicha: parseValor(json['totalFicha']),
      listaGrupos: (json['listaGrupos'] as List)
          .map((item) => Reporte.fromJson(item))
          .toList(),
    );
  }
}

class Reporte {
  final int numero;
  final String tipoPago;
  final String folio;
  final String idficha;
  final String grupos;
  final double pagoficha;
  final String fechadeposito;
  final double montoficha;
  final double capitalsemanal;
  final double interessemanal;
  final double saldofavor;
  final double moratorios;

  Reporte({
    required this.numero,
    required this.tipoPago,
    required this.folio,
    required this.idficha,
    required this.grupos,
    required this.pagoficha,
    required this.fechadeposito,
    required this.montoficha,
    required this.capitalsemanal,
    required this.interessemanal,
    required this.saldofavor,
    required this.moratorios,
  });

  factory Reporte.fromJson(Map<String, dynamic> json) {
    double parseValor(String value) =>
        double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    return Reporte(
      numero: json['num'] ?? 0,
      tipoPago: json['tipopago'] ?? 'N/A',
      folio: json['folio'] ?? 'N/A',
      idficha: json['idficha'] ?? 'N/A',
      grupos: json['grupos'] ?? 'N/A',
      pagoficha: parseValor(json['pagoficha']),
      fechadeposito: json['fechadeposito'] ?? 'Pendiente',
      montoficha: parseValor(json['montoficha']),
      capitalsemanal: parseValor(json['capitalsemanal']),
      interessemanal: parseValor(json['interessemanal']),
      saldofavor: parseValor(json['saldofavor']),
      moratorios: parseValor(json['moratorios']),
    );
  }
}
