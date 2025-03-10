import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:finora/dialogs/infoCredito.dart';
import 'package:finora/dialogs/nCredito.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
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
  Timer? _debounceTimer; // Para el debounce de la búsqueda
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    obtenerCreditos();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancela el temporizador al destruir el widget
    _debounceTimer?.cancel();
    _searchController.dispose();
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
              listaCreditos.sort((a, b) =>
                  b.fCreacion.compareTo(a.fCreacion)); // <-- Agrega esta línea

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
                    'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
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

  // Función para buscar créditos según el texto ingresado
  Future<void> searchCreditos(String query) async {
    if (query.trim().isEmpty) {
      obtenerCreditos();
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noCreditsFound = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // Agregar timeout a la petición
      final response = await http.get(
        Uri.parse('http://$baseUrl/api/v1/creditos/$query'),
        headers: {'tokenauth': token},
      ).timeout(Duration(seconds: 10)); // Limitar tiempo de espera

      // Delay para mostrar el loading (500ms)
      await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;

      print('Status code (search): ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          listaCreditos = data.map((item) => Credito.fromJson(item)).toList();
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Manejar token expirado
        _handleTokenExpiration();
      } else {
        setState(() {
          isLoading = false;
          errorDeConexion = true; // Activar estado de error
        });
      }
    } on SocketException catch (e) {
      // Capturar error de conexión
      print('SocketException: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
      }
    } on TimeoutException catch (_) {
      // Capturar timeout
      print('Timeout');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
      }
    } catch (e) {
      print('Error general: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
      }
    }
  }

  void _handleTokenExpiration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tokenauth');

    if (mounted) {
      mostrarDialogoError(
          'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
          onClose: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
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
      body: Column(
        children: [
          // Solo muestra la fila de búsqueda si NO hay error de conexión
          if (!errorDeConexion) filaBuscarYAgregar(context),
          Expanded(child: _buildTableContainer()),
        ],
      ),
    );
  }

  // Se encapsula el contenedor de la tabla para que sea lo único que se actualice al buscar
  // Este widget se encarga de mostrar el contenedor de la tabla o, en su defecto,
// un CircularProgressIndicator mientras se realiza la petición.
  Widget _buildTableContainer() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFF5162F6),
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
                if (_searchController.text.trim().isEmpty) {
                  obtenerCreditos();
                } else {
                  searchCreditos(_searchController.text);
                }
              },
              child: Text('Recargar'),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Color(0xFF5162F6)),
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
      return noCreditsFound || listaCreditos.isEmpty
          ? Center(
              child: Text(
                'No hay créditos para mostrar.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : filaTabla(context);
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
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide:
                      BorderSide(color: Color.fromARGB(255, 137, 192, 255)),
                ),
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          // Si se borra el texto, se vuelve a cargar la lista completa
                          obtenerCreditos();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // Debounce: esperar 500ms después de dejar de escribir
                if (_debounceTimer?.isActive ?? false) {
                  _debounceTimer!.cancel();
                }
                _debounceTimer = Timer(Duration(milliseconds: 500), () {
                  searchCreditos(value);
                });
              },
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              padding: MaterialStateProperty.all(
                  EdgeInsets.symmetric(vertical: 15, horizontal: 20)),
              backgroundColor: MaterialStateProperty.all(Color(0xFF5162F6)),
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 0.5,
                blurRadius: 5,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.0),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(child: tabla(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final double textHeaderTableSize = 12.0;
  final double textTableSize = 11.0;
  Widget tabla(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowColor: MaterialStateProperty.resolveWith(
            (states) => const Color(0xFF5162F6)),
        columnSpacing: 10,
        headingRowHeight: 50,
        dataRowHeight: 60,
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: textHeaderTableSize,
        ),
        columns: [
          DataColumn(
              label: Text('Tipo',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Frecuencia',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Nombre',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Autorizado',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Desembolsado',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Interés',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('M. a Recuperar',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Día Pago',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Pago Periodo',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Núm de Pago',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Duración',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Estado de Pago',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Estado',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
            label: Text(
              'Acciones',
              style: TextStyle(fontSize: textHeaderTableSize),
            ),
          ),
        ],
        rows: listaCreditos.map((credito) {
          return DataRow(
            onSelectChanged: (isSelected) {
              if (isSelected == true) {
                showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (context) => InfoCredito(folio: credito.folio),
                );
              }
            },
            cells: [
              DataCell(Text(credito.tipo,
                  style: TextStyle(fontSize: textTableSize))),
              DataCell(Text(credito.tipoPlazo,
                  style: TextStyle(fontSize: textTableSize))),
              DataCell(Container(
                width: 80,
                child: Text(
                  credito.nombreGrupo,
                  style: TextStyle(fontSize: textTableSize),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: true,
                ),
              )),
              DataCell(Center(
                  child: Text('\$${credito.montoTotal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text(
                      '\$${credito.montoDesembolsado.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text('${credito.ti_mensual}%',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text('\$${credito.montoMasInteres.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text('${credito.diaPago}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text('${credito.pagoCuota}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text('${credito.numPago}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Container(
                width: 70,
                child: Text(
                  credito.fechasIniciofin,
                  style: TextStyle(fontSize: textTableSize),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: true,
                ),
              )),
              DataCell(Center(
                  child: Text(credito.estadoCredito.estado,
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text(credito.estado,
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirmar eliminación'),
                            content: const Text(
                                '¿Estás seguro de eliminar este crédito?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _eliminarCredito(credito.idCredito);
                                },
                                child: const Text('Eliminar',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
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

  Future<void> _eliminarCredito(String idCredito) async {
    // Mostrar SnackBar de carga
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 20),
            Text('Eliminando crédito...'),
          ],
        ),
        duration: const Duration(
            minutes: 1), // Duración larga para mantenerlo visible
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.delete(
        Uri.parse('http://$baseUrl/api/v1/creditos/$idCredito'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        // Actualizar lista
        obtenerCreditos();
        // Mostrar SnackBar de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Crédito eliminado exitosamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (response.statusCode == 401) {
        _handleTokenExpiration();
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error al eliminar: ${errorData['Error']['Message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. Verifica tu red.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void mostrarDialogoExito(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Éxito'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
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
  final double ti_mensual;
  final double interesTotal;
  final double montoMasInteres;
  final String numPago;
  final String fechasIniciofin;
  final DateTime fCreacion;
  final String estado;
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
    required this.ti_mensual,
    required this.interesTotal,
    required this.montoMasInteres,
    required this.numPago,
    required this.fechasIniciofin,
    required this.estadoCredito,
    required this.estado,
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
      ti_mensual: json['ti_mensual'].toDouble(),
      montoTotal: json['montoTotal'].toDouble(),
      interesTotal: json['interesTotal'].toDouble(),
      montoMasInteres: json['montoMasInteres'].toDouble(),
      numPago: json['numPago'],
      fechasIniciofin: json['fechasIniciofin'],
      estado: json['estado'],
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
