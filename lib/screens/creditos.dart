import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:money_facil/dialogs/infoCredito.dart';
import 'package:money_facil/dialogs/nCredito.dart';
import 'package:money_facil/ip.dart';
import 'package:money_facil/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para manejar fechas

class SeguimientoScreen extends StatefulWidget {
  final String username;
  final String tipoUsuario;

  const SeguimientoScreen({required this.username, required this.tipoUsuario});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  // Datos estáticos de ejemplo de créditos activos
  List<Credito> listaCreditos = [];

  bool isLoading = false; // Para indicar si los datos están siendo cargados.
  bool errorDeConexion = false; // Para indicar si hubo un error de conexión.
  bool noCreditsFound = false; // Para indicar si no se encontraron créditos.
  Timer?
      _timer; // Para manejar el temporizador que muestra el mensaje de error después de cierto tiempo.

  @override
  void initState() {
    super.initState();
    obtenerCreditos();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancela el temporizador al destruir el widget
    super.dispose();
  }

  Future<void> obtenerCreditos() async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noCreditsFound = false;
    });

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        //Recuperar el token de Shared Preferences
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        final response = await http.get(
          Uri.parse('http://$baseUrl/api/v1/creditos'),
          headers: {
            'tokenauth': token, // Agregar el token al header
            'Content-Type': 'application/json',
          },
        );

        print('Status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (mounted) {
          if (response.statusCode == 200) {
            // Agrega estos prints
            print('✅ GET exitoso');
            print('📦 Token usado: $token');
            print('🌐 Endpoint: http://$baseUrl/api/v1/creditos');
            print('📡 Response headers: ${response.headers}');

            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaCreditos =
                  data.map((item) => Credito.fromJson(item)).toList();
              isLoading = false;
              errorDeConexion = false;
            });
            _timer?.cancel();
          } else if (response.statusCode == 404) {
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] == "jwt expired") {
              if (mounted) {
                setState(() => isLoading = false);
                // Limpiar token y redirigir
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('tokenauth');
                _timer?.cancel(); // Cancela el temporizador antes de navegar

                mostrarDialogoError(
                    'Tu sesión ha expirado. Por favor inicia sesión de nuevo.',
                    onClose: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                });
              }
              return;
            } else {
              setErrorState(dialogShown);
            }
          } else if (response.statusCode == 400) {
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] ==
                "No hay ningun credito registrado") {
              setState(() {
                listaCreditos = [];
                isLoading = false;
                noCreditsFound = true;
              });
              _timer
                  ?.cancel(); // Detener intentos de reconexión si no hay créditos
            } else {
              setErrorState(dialogShown);
            }
          } else {
            setErrorState(dialogShown);
          }
        }
      } catch (e) {
        if (mounted) {
          print('Error: $e'); // Imprime el error capturado
          setErrorState(dialogShown, e);
        }
      }
    }

    fetchData();

    if (!noCreditsFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noCreditsFound) {
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
  }

  void setErrorState(bool dialogShown, [dynamic error]) {
    _timer?.cancel(); // Cancela el temporizador antes de navegar
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
      _timer?.cancel(); // Detener intentos de reconexión en caso de error
    }
  }

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
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

  bool _isDarkMode = false;

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        isDarkMode: _isDarkMode,
        toggleDarkMode: _toggleDarkMode,
        title: 'Créditos Activos',
        nombre: widget.username,
        tipoUsuario: widget.tipoUsuario,
      ),
      backgroundColor: Color(0xFFF7F8FA),
      body: content(context),
    );
  }

  Widget content(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFB2056),
        ),
      );
    } else if (errorDeConexion) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No hay conexión o no se pudo cargar la información. Intenta más tarde.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                obtenerCreditos();
              },
              child: Text('Recargar'),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Color(0xFFFB2056)),
                foregroundColor: MaterialStateProperty.all(Colors.white),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filaBuscarYAgregar(context), // Mostrar siempre este widget
          noCreditsFound || listaCreditos.isEmpty
              ? Expanded(
                  child: Center(
                    child: Text(
                      'No hay créditos para mostrar.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : Expanded(
                  child: filaTabla(context),
                ),
        ],
      );
    }
  }

  Widget filaBuscarYAgregar(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width * 0.35;
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 40,
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8.0)],
            ),
            child: TextField(
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide:
                      BorderSide(color: Color.fromARGB(255, 137, 192, 255)),
                ),
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Color(0xFFFB2056)),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            onPressed: mostrarDialogAgregarCredito,
            child: Text('Agregar Crédito'),
          ),
        ],
      ),
    );
  }

  void mostrarDialogAgregarCredito() {
    showDialog(
      barrierDismissible: false, // Evita que se cierre al tocar fuera
      context: context,
      builder: (context) {
        return nCreditoDialog(
          onCreditoAgregado: () {
            obtenerCreditos(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }

  Widget filaTabla(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0.5,
                  blurRadius: 5,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(child: tabla()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget tabla() {
    const double fontSize = 11;

    // Lista para almacenar los índices de las filas seleccionadas
    List<int> selectedRows = [];

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowColor:
            MaterialStateProperty.resolveWith((states) => Color(0xFFE8EFF9)),
        columnSpacing: 10,
        headingRowHeight: 50,
        dataRowHeight: 60, // Ajusta la altura de las filas según lo necesites
        columns: const [
          DataColumn(label: Text('Tipo', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Frecuencia', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Nombre', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Autorizado', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('Desembolsado', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Interés %', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('Interés Total', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('M. a Recuperar', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Día Pago', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('Pago Semanal', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Núm de Pago', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Duración', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('Estado de Pago', style: TextStyle(fontSize: fontSize))),
        ],
        rows: listaCreditos.map((credito) {
          return DataRow(
            selected: selectedRows.contains(listaCreditos.indexOf(credito)),
            onSelectChanged: (isSelected) {
              setState(() {
                if (isSelected == true) {
                  selectedRows.add(listaCreditos.indexOf(credito));
                  showDialog(
                    context: context,
                    builder: (context) => InfoCredito(folio: credito.folio),
                  );
                }
              });
            },
            cells: [
              DataCell(
                  Text(credito.tipo, style: TextStyle(fontSize: fontSize))),
              DataCell(Text(credito.tipoPlazo,
                  style: TextStyle(fontSize: fontSize))),
              DataCell(
                Container(
                  width: 80,
                  child: Text(
                    credito.nombreGrupo,
                    style: TextStyle(fontSize: fontSize),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
              ),
              DataCell(Center(
                  child: Text('\$${credito.montoTotal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text(
                      '\$${credito.montoDesembolsado.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('${credito.interesGlobal}%',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('\$${credito.interesTotal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('\$${credito.montoMasInteres.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('${credito.diaPago}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('${credito.pagoCuota}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('${credito.numPago}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(
                Container(
                  width: 70,
                  child: Text(
                    credito.fechasIniciofin,
                    style: TextStyle(fontSize: fontSize),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
              ),
              DataCell(
                Center(
                  child: Text(
                    credito.estadoCredito.estado, // Mostrar el estado
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ),
            ],
            color: MaterialStateColor.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.blue.withOpacity(0.1);
              } else if (states.contains(MaterialState.hovered)) {
                return Colors.blue.withOpacity(0.2);
              }
              return Colors.transparent;
            }),
          );
        }).toList(),
      ),
    );
  }
}

class Credito {
  final String idCredito;
  final String nombreGrupo;
  final int plazo;
  final String tipoPlazo;
  final String tipo;
  final double interes;
  final double montoDesembolsado;
  final String folio;
  final String diaPago;
  final double garantia;
  final double pagoCuota;
  final double interesGlobal;
  final double montoTotal;
  final double interesTotal;
  final double montoMasInteres;
  final String numPago;
  final String fechasIniciofin;
  final DateTime fCreacion;
  final EstadoCredito estadoCredito;

  Credito({
    required this.idCredito,
    required this.nombreGrupo,
    required this.plazo,
    required this.tipoPlazo,
    required this.tipo,
    required this.interes,
    required this.montoDesembolsado,
    required this.folio,
    required this.diaPago,
    required this.garantia,
    required this.pagoCuota,
    required this.interesGlobal,
    required this.montoTotal,
    required this.interesTotal,
    required this.montoMasInteres,
    required this.numPago,
    required this.fechasIniciofin,
    required this.estadoCredito,
    required this.fCreacion,
  });

  factory Credito.fromJson(Map<String, dynamic> json) {
    return Credito(
      idCredito: json['idcredito'],
      nombreGrupo: json['nombreGrupo'],
      plazo: json['plazo'] is String ? int.parse(json['plazo']) : json['plazo'],
      tipoPlazo: json['tipoPlazo'],
      tipo: json['tipo'],
      interes: json['interesGlobal'].toDouble(),
      montoDesembolsado: json['montoDesembolsado'].toDouble(),
      folio: json['folio'],
      diaPago: json['diaPago'],
      garantia: double.parse(json['garantia'].replaceAll('%', '')),
      pagoCuota: json['pagoCuota'].toDouble(),
      interesGlobal: json['interesGlobal'].toDouble(),
      montoTotal: json['montoTotal'].toDouble(),
      interesTotal: json['interesTotal'].toDouble(),
      montoMasInteres: json['montoMasInteres'].toDouble(),
      numPago: json['numPago'],
      fechasIniciofin: json['fechasIniciofin'],
      estadoCredito: EstadoCredito.fromJson(json['estado_credito']),
      fCreacion: DateTime.parse(json['fCreacion']),
    );
  }
}

class EstadoCredito {
  final double montoTotal;
  final double moratorios;
  final int semanasDeRetraso;
  final int diferenciaEnDias;
  final String mensaje;
  final String estado;

  EstadoCredito({
    required this.montoTotal,
    required this.moratorios,
    required this.semanasDeRetraso,
    required this.diferenciaEnDias,
    required this.mensaje,
    required this.estado,
  });

  factory EstadoCredito.fromJson(Map<String, dynamic> json) {
    return EstadoCredito(
      montoTotal: (json['montoTotal'] as num).toDouble(), // Convertir a double
      moratorios: (json['moratorios'] as num).toDouble(), // Convertir a double
      semanasDeRetraso: json['semanasDeRetraso'],
      diferenciaEnDias: json['diferenciaEnDias'],
      mensaje: json['mensaje'],
      estado: json[
          'esatado'], // Nota: el JSON tiene un error de tipografía aquí ("esatado" en lugar de "estado").
    );
  }
}
