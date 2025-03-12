import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:finora/helpers/pdf_exporter_contable.dart';
import 'package:finora/helpers/pdf_exporter_general.dart';
import 'package:finora/ip.dart';
import 'package:finora/models/reporte_contable.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/screens/login.dart';
import 'package:finora/screens/reporteContable.dart';
import 'package:finora/screens/reporteGeneral.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finora/models/reporte_general.dart'; // Importación correcta de modelos

class ReportesScreen extends StatefulWidget {
  final String username;
  final String tipoUsuario;

  const ReportesScreen({required this.username, required this.tipoUsuario});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  List<ReporteGeneral> listaReportes = [];
  List<ReporteContableData> listaReportesContable = [];
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

  ReporteGeneralData? reporteData;
  String? errorMessage;
  bool hasError = false;

  final List<String> reportTypes = [
    'Reporte General',
    'Reporte Contable',
  ];

  @override
  void initState() {
    super.initState();
    // Inicializaciones necesarias
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> obtenerReportes() async {
    if (selectedReportType == null || selectedDateRange == null) {
      mostrarDialogoError('Selecciona tipo de reporte y rango de fechas');
      return;
    }

    setState(() {
      isLoading = true;
      hasGenerated = true; // Establece hasGenerated = true desde el principio
      listaReportes = [];
      listaReportesContable = [];
      reporteData = null;
      hasError = false;
      errorDeConexion = false;
      noReportesFound = false;
    });

    //await Future.delayed(Duration(milliseconds: 200));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final fechaInicio =
          DateFormat('yyyy-MM-dd').format(selectedDateRange!.start);
      final fechaFin = DateFormat('yyyy-MM-dd').format(selectedDateRange!.end);

      String tipoReporte =
          selectedReportType == 'Reporte Contable' ? 'contable' : 'general';

      final url = Uri.parse(
        'http://$baseUrl/api/v1/formato/reporte/$tipoReporte/datos?inicio=$fechaInicio&final=$fechaFin',
      );

      final response = await http.get(
        url,
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      print(
          'Respuesta del servidor (${response.statusCode}): ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (selectedReportType == 'Reporte Contable') {
          // Debug: Verificar estructura del JSON
          print('Keys en JSON recibido: ${data.keys}');
          print('¿Existe fechaSemana? ${data.containsKey('fechaSemana')}');
          print('¿Existe listaGrupos? ${data.containsKey('listaGrupos')}');

          // Validar estructura básica
          if (!data.containsKey('listaGrupos')) {
            throw FormatException(
                'Estructura JSON inválida: falta listaGrupos');
          }

          setState(() {
            listaReportesContable = [ReporteContableData.fromJson(data)];
            print(
                'Reporte contable creado: ${listaReportesContable.first}'); // Debug
          });
        } else {
          setState(() {
            reporteData = ReporteGeneralData.fromJson(data);
            listaReportes = reporteData?.listaGrupos ?? [];
          });
        }
      } else if (response.statusCode == 401) {
        await prefs.remove('tokenauth');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      } else if (response.statusCode == 404) {
        setState(() {
          isLoading = false;
          noReportesFound = true;
        });
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on SocketException {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Error de conexión. Verifica tu internet';
      });
    } on TimeoutException {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Tiempo de espera agotado';
      });
    } on FormatException catch (e) {
      print('Error de formato: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Error en formato de datos: ${e.message}';
      });
    } catch (e) {
      print('Error inesperado: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Error inesperado: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          //hasGenerated = true;
        });
      }
    }
  }

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onClose?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Scaffold(
      backgroundColor:
          isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA), // Fondo dinámico
      appBar: CustomAppBar(
        isDarkMode: isDarkMode,
        toggleDarkMode: (value) {
          themeProvider.toggleDarkMode(value); // Cambia el tema
        },
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
                    ? Center(
                        child: CircularProgressIndicator(
                            color: isDarkMode
                                ? Colors.white70
                                : Color(0xFF5162F6)))
                    : hasError
                        ? _buildErrorDisplay()
                        : selectedReportType == 'Reporte Contable'
                            ? _buildContableWithDebug() // Función modificada
                            : ReporteGeneralWidget(
                                listaReportes: listaReportes,
                                reporteData: reporteData,
                                currencyFormat: currencyFormat,
                                verticalScrollController:
                                    _verticalScrollController,
                                horizontalScrollController:
                                    _horizontalScrollController,
                              )
                : _buildInitialMessage(),
          ),
        ],
      ),
    );
  }

  Widget _buildContableWithDebug() {
    // Debug: Verificar datos antes de enviar al widget
    debugPrint('=== DEBUG REPORTE CONTABLE ===');
    debugPrint(
        'Cantidad de reportes contables: ${listaReportesContable.length}');

    if (listaReportesContable.isNotEmpty) {
      final reporte = listaReportesContable.first;
      debugPrint('Fecha semana: ${reporte.fechaSemana}');
      debugPrint('Total capital: ${reporte.totalCapital}');
      debugPrint('Total grupos: ${reporte.listaGrupos.length}');

      if (reporte.listaGrupos.isNotEmpty) {
        final primerGrupo = reporte.listaGrupos.first;
        debugPrint('Primer grupo: ${primerGrupo.grupos}');
        debugPrint(
            'Depósitos en primer grupo: ${primerGrupo.pagoficha.depositos.length}');
        debugPrint('Clientes en primer grupo: ${primerGrupo.clientes.length}');
      }
    } else {
      debugPrint('Lista de reportes contables VACÍA');
    }

    return ReporteContableWidget(
      reporteData: listaReportesContable.first,
      currencyFormat: currencyFormat,
      verticalScrollController: _verticalScrollController,
      horizontalScrollController: _horizontalScrollController,
    );
  }

  Widget _buildErrorDisplay() {
    // Extract meaningful message from error JSON if possible
    String displayMessage = errorMessage ?? 'Error desconocido';

    // Try to parse JSON error message if it's in that format
    if (displayMessage.contains('"Message"')) {
      try {
        final regexp = RegExp(r'"Message"\s*:\s*"([^"]+)"');
        final match = regexp.firstMatch(displayMessage);
        if (match != null && match.groupCount >= 1) {
          displayMessage = match.group(1) ?? displayMessage;
        }
      } catch (e) {
        // If parsing fails, keep the original message
      }
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              displayMessage,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => setState(() {
                hasError = false;
                hasGenerated = false;
              }),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: const Color(0xFF5162F6),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.4)
                        : Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SizedBox(
                height: 40, // Ajusta la altura deseada aquí
                child: DropdownButtonFormField<String>(
                  value: selectedReportType,
                  items: reportTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    selectedReportType = value;
                    hasGenerated = false;
                  }),
                  decoration: InputDecoration(
                    isDense: true, // Hace que el campo sea más compacto
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12), // Reduce espacio interno
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
                  ),
                  hint: Text(
                    'Selecciona tipo de reporte',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  dropdownColor: isDarkMode ? Color(0xFF2A2D3E) : Colors.white,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          InkWell(
            onTap: _selectDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.4)
                        : Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    selectedDateRange != null
                        ? '${DateFormat('dd/MM/yy').format(selectedDateRange!.start)} - '
                            '${DateFormat('dd/MM/yy').format(selectedDateRange!.end)}'
                        : 'Seleccionar fechas',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            width: 180,
            child: ElevatedButton(
              onPressed:
                  (selectedReportType != null && selectedDateRange != null)
                      ? () {
                          print(
                              'Tipo de reporte seleccionado: $selectedReportType'); // Depuración
                          obtenerReportes();
                        }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5162F6),
                disabledBackgroundColor:
                    isDarkMode ? Colors.grey[700] : Colors.grey[300],
                disabledForegroundColor:
                    isDarkMode ? Colors.grey[500] : Colors.grey[600],
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    size: 18,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Generar',
                    style: TextStyle(color: Colors.white),
                  ),
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
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Exportar',
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
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    // Implementación con adaptación de colores para modo oscuro
    DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDarkMode ? Color(0xFF2A2D3E) : Color(0xFFf5fafb),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                // 2. Tema específico del DatePicker
                datePickerTheme: DatePickerThemeData(
                  backgroundColor:
                      isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
                  headerBackgroundColor:
                      isDarkMode ? Color(0xFF5162F6) : Colors.blue,
                  headerForegroundColor: Colors.white,
                  dayForegroundColor: MaterialStateProperty.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                        ? Colors.white
                        : isDarkMode
                            ? Colors.white
                            : null,
                  ),
                  yearForegroundColor: MaterialStateProperty.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                        ? Colors.white
                        : isDarkMode
                            ? Colors.white
                            : null,
                  ),
                  dayBackgroundColor: MaterialStateProperty.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                        ? isDarkMode
                            ? Color(0xFF5162F6)
                            : Colors.blue
                        : null,
                  ),
                  yearBackgroundColor: MaterialStateProperty.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                        ? isDarkMode
                            ? Color(0xFF5162F6)
                            : Colors.blue
                        : null,
                  ),
                  weekdayStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  // Colores para los campos de texto
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor:
                        isDarkMode ? Color(0xFF2A2D3E) : Colors.yellow.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? Color(0xFF5162F6) : Colors.blue,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? Color(0xFF5162F6) : Colors.blue,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? Color(0xFF5162F6) : Colors.blue,
                        width: 2,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
                // 3. Esquema de colores para el control
                colorScheme: ColorScheme(
                  brightness: isDarkMode ? Brightness.dark : Brightness.light,
                  primary: isDarkMode ? Color(0xFF5162F6) : Colors.blue,
                  onPrimary: Colors.white,
                  secondary: isDarkMode ? Color(0xFF5162F6) : Colors.blue,
                  onSecondary: Colors.white,
                  error: isDarkMode ? Colors.redAccent : Colors.red,
                  onError: Colors.white,
                  background: isDarkMode ? Color(0xFF2A2D3E) : Colors.white,
                  onBackground: isDarkMode ? Colors.white : Colors.black,
                  surface: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
                  onSurface: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              child: Builder(builder: (context) {
                return DateRangePickerDialog(
                  initialDateRange: selectedDateRange,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  currentDate: DateTime.now(),
                  helpText: 'Selecciona rango de fechas',
                  cancelText: 'Cancelar',
                  confirmText: 'Confirmar',
                  saveText: 'Guardar',
                  errorInvalidRangeText: 'Rango inválido',
                  fieldStartLabelText: 'Fecha inicio',
                  fieldEndLabelText: 'Fecha fin',
                );
              }),
            ),
          ),
        ),
      ),
    );

    if (picked != null) {
      setState(() => selectedDateRange = picked);
    }
  }

  Widget _buildInitialMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 50, color: Colors.grey[600]),
          const SizedBox(height: 20),
          const Text(
            'Selecciona tipo de reporte y rango de fechas\npara generar el informe',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> exportarReporte() async {
    // Crea una variable para el estado de tema ANTES de que inicie la operación asíncrona
    // Y usa listen: false para evitar reconstrucciones innecesarias
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: isDarkMode ? Color(0xFF2A2D3E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 50),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF5162F6),
                ),
                const SizedBox(height: 20),
                Text(
                  'Exportando reporte...',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Resto del código igual...
      await Future.delayed(Duration(milliseconds: 500));

      if (selectedReportType == 'Reporte Contable') {
        // Exportar reporte contable
        if (listaReportesContable.isEmpty) {
          // Cerrar el diálogo de carga
          Navigator.pop(context);
          mostrarDialogoError('No hay datos contables para exportar');
          return;
        }

        final pdfHelper = PDFExportHelperContable(
            listaReportesContable.first, currencyFormat, selectedReportType);

        final pdfDocument = await pdfHelper.generatePDF();
        final bytes = await pdfDocument.save();

        final output = await FilePicker.platform.saveFile(
          dialogTitle: 'Exportar Reporte Contable',
          fileName:
              'reporte_contable_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
        );

        // Cerrar el diálogo de carga antes de mostrar el selector de archivos
        Navigator.pop(context);

        if (output != null) {
          final file = File(output);
          await file.writeAsBytes(bytes);
          await OpenFile.open(file.path);
        }
      } else {
        // Cerrar el diálogo de carga antes de llamar a exportToPdf
        Navigator.pop(context);

        // Exportar reporte general existente
        await ExportHelperGeneral.exportToPdf(
          context: context,
          reporteData: reporteData,
          listaReportes: listaReportes,
          selectedDateRange: selectedDateRange,
          selectedReportType: selectedReportType,
          currencyFormat: currencyFormat,
        );
      }
    } catch (e) {
      // Cerrar el diálogo de carga en caso de error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      mostrarDialogoError('Error al exportar: ${e.toString()}');
    }
  }
}
