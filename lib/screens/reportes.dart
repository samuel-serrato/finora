import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final NumberFormat currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  Timer? _timer;

  final List<String> reportTypes = [
    'Reporte General',
    'Reporte de Pagos',
    'Reporte de Moratorios'
  ];

  @override
  void initState() {
    super.initState();
    selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  Future<void> obtenerReportes() async {
    if (selectedReportType == null || selectedDateRange == null) return;

    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noReportesFound = false;
    });

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        final response = await http.post(
          Uri.parse('http://$baseUrl/api/v1/reportes'),
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'tipo_reporte': selectedReportType,
            'fecha_inicio': selectedDateRange?.start.toIso8601String(),
            'fecha_fin': selectedDateRange?.end.toIso8601String(),
          }),
        );

        if (mounted) {
          if (response.statusCode == 200) {
            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaReportes =
                  data.map((item) => Reporte.fromJson(item)).toList();
              isLoading = false;
              errorDeConexion = false;
            });
            _timer?.cancel();
          } else if (response.statusCode == 401) {
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] == "jwt expired") {
              if (mounted) {
                setState(() => isLoading = false);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('tokenauth');
                _timer?.cancel();
                mostrarDialogoError(
                  'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                  onClose: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                );
              }
              return;
            } else {
              setErrorState(dialogShown);
            }
          } else if (response.statusCode == 404) {
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] ==
                "No hay reportes disponibles") {
              setState(() {
                listaReportes = [];
                isLoading = false;
                noReportesFound = true;
              });
              _timer?.cancel();
            } else {
              setErrorState(dialogShown);
            }
          } else if (response.statusCode == 400) {
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] == "Parámetros inválidos") {
              mostrarDialogoError('Los filtros seleccionados son inválidos');
              setState(() => isLoading = false);
            } else {
              setErrorState(dialogShown);
            }
          } else {
            setErrorState(dialogShown);
          }
        }
      } catch (e) {
        if (mounted) {
          setErrorState(dialogShown, e);
        }
      }
    }

    fetchData();

    _timer = Timer(Duration(seconds: 10), () {
      if (mounted && !dialogShown && !noReportesFound) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
        dialogShown = true;
        mostrarDialogoError(
            'No se pudo conectar al servidor. Verifica tu red.');
      }
    });
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

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedReportType,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              hint: const Text('Selecciona tipo de reporte'),
              items: reportTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedReportType = value);
              },
            ),
          ),
          const SizedBox(width: 15),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              onTap: _selectDateRange,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      selectedDateRange != null
                          ? '${DateFormat('dd/MM/yy').format(selectedDateRange!.start)} - '
                              '${DateFormat('dd/MM/yy').format(selectedDateRange!.end)}'
                          : 'Seleccionar fechas',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          ElevatedButton(
            onPressed: selectedReportType != null
                ? () {
                    if (selectedReportType == null) {
                      mostrarDialogoError('Selecciona un tipo de reporte');
                      return;
                    }
                    setState(() {
                      hasGenerated = true;
                    });
                    obtenerReportes();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5162F6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Generar',
              style: TextStyle(color: Colors.white),
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
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          height: MediaQuery.of(context).size.height * 0.8,
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
    );

    if (picked != null) {
      setState(() => selectedDateRange = picked);
    }
  }

  Widget _buildDataTable() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: listaReportes.isEmpty
            ? Center(
                child: Text(
                  'No se encontraron reportes',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              )
            : Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(const Color(0xFFDFE7F5)),
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('TIPO DE PAGO')),
                      DataColumn(label: Text('GRUPOS')),
                      DataColumn(label: Text('FOLLO')),
                      DataColumn(label: Text('PAGO FICHA')),
                      DataColumn(label: Text('FECHA DEPÓSITO')),
                      DataColumn(label: Text('MONTO FICHA')),
                      DataColumn(label: Text('CAPITAL SEMANAL')),
                      DataColumn(label: Text('INTERÉS SEMANAL')),
                      DataColumn(label: Text('SALDO FAVOR')),
                      DataColumn(label: Text('MORATORIO')),
                    ],
                    rows: listaReportes.map((reporte) {
                      return DataRow(cells: [
                        DataCell(Text(reporte.numero.toString())),
                        DataCell(Text(reporte.tipoPago)),
                        DataCell(Text(reporte.grupos)),
                        DataCell(Text(reporte.follo)),
                        DataCell(
                            Text(currencyFormat.format(reporte.pagoFicha))),
                        DataCell(Text(reporte.fechaDeposito)),
                        DataCell(
                            Text(currencyFormat.format(reporte.montoFicha))),
                        DataCell(Text(
                            currencyFormat.format(reporte.capitalSemanal))),
                        DataCell(Text(
                            currencyFormat.format(reporte.interesSemanal))),
                        DataCell(
                            Text(currencyFormat.format(reporte.saldoFavor))),
                        DataCell(
                            Text(currencyFormat.format(reporte.moratorio))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInitialMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined, size: 50, color: Colors.grey,),
          SizedBox(height: 8),
          Text(
            'Selecciona el tipo de reporte y rango de fechas,\nluego presiona Generar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
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
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF5162F6),
                        ),
                      )
                    : errorDeConexion
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Error al cargar los reportes'),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: obtenerReportes,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5162F6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                  ),
                                  child: const Text('Reintentar',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : _buildDataTable()
                : _buildInitialMessage(),
          ),
        ],
      ),
    );
  }
}

class Reporte {
  final int numero;
  final String tipoPago;
  final String grupos;
  final String follo;
  final double pagoFicha;
  final String fechaDeposito;
  final double montoFicha;
  final double capitalSemanal;
  final double interesSemanal;
  final double saldoFavor;
  final double moratorio;

  Reporte({
    required this.numero,
    required this.tipoPago,
    required this.grupos,
    required this.follo,
    required this.pagoFicha,
    required this.fechaDeposito,
    required this.montoFicha,
    required this.capitalSemanal,
    required this.interesSemanal,
    required this.saldoFavor,
    required this.moratorio,
  });

  factory Reporte.fromJson(Map<String, dynamic> json) {
    return Reporte(
      numero: json['numero'],
      tipoPago: json['tipo_pago'],
      grupos: json['grupos'],
      follo: json['follo'],
      pagoFicha: json['pago_ficha'].toDouble(),
      fechaDeposito: DateFormat('yyyy-MM-dd')
          .format(DateTime.parse(json['fecha_deposito'])),
      montoFicha: json['monto_ficha'].toDouble(),
      capitalSemanal: json['capital_semanal'].toDouble(),
      interesSemanal: json['interes_semanal'].toDouble(),
      saldoFavor: json['saldo_favor'].toDouble(),
      moratorio: json['moratorio'].toDouble(),
    );
  }
}
