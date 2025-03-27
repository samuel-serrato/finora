import 'dart:async';
import 'dart:io';

import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:finora/dialogs/renovarGrupo.dart';
import 'dart:convert';

import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoGrupo extends StatefulWidget {
  final String idGrupo;
  final String nombreGrupo;

  InfoGrupo({required this.idGrupo, required this.nombreGrupo});

  @override
  _InfoGrupoState createState() => _InfoGrupoState();
}

class _InfoGrupoState extends State<InfoGrupo> {
  Grupo? grupoData; // Cambiar el tipo aquí
  bool isLoading = true;
  Timer? _timerData;
  Timer? _timerHistorial;
  bool dialogShown = false;
  late ScrollController _scrollController;
  List<dynamic> historialData = [];
  bool errorDeConexion = false;
  bool noGroupsFound = false;
  Timer? _timer;
  List<Grupo> listaGrupos = [];

  @override
  void initState() {
    _scrollController = ScrollController();
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        fetchGrupoData(),
        fetchGrupoHistorial(widget.nombreGrupo),
      ]);
    } catch (e) {
      print('Error en fetchAllData: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _timerData?.cancel();
    _timerHistorial?.cancel();
    super.dispose();
    _scrollController.dispose();
  }

  Future<void> fetchGrupoData() async {
    bool dialogShown = false;

    try {
      print('Iniciando petición de datos del grupo ${widget.idGrupo}');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('http://$baseUrl/api/v1/grupodetalles/${widget.idGrupo}'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print(
          'Respuesta recibida (grupodetalles fetchGrupoData): ${response.statusCode}');
      print(
          'Respuesta completa (grupodetalles fetchGrupoData): ${response.body}'); // Imprime respuesta completa

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is List && responseData.isNotEmpty) {
          setState(() {
            grupoData =
                Grupo.fromJson(responseData[0]); // Convertir JSON a modelo
            errorDeConexion = false;
          });
        } else {
          throw Exception('Datos del grupo no encontrados');
        }
      } else if (response.statusCode == 401) {
        print('Error 401: ${response.body}'); // Imprime detalle del error
        if (mounted) {
          setState(() => isLoading = false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('tokenauth');
          _timerData?.cancel();

          if (!dialogShown) {
            dialogShown = true;
            mostrarDialogoError(
                'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                onClose: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            });
          }
        }
      } else if (response.statusCode == 404) {
        print('Error 404: ${response.body}'); // Imprime detalle del error
        final errorData = json.decode(response.body);
        if (errorData["Error"]["Message"] == "jwt expired") {
          if (mounted) {
            setState(() => isLoading = false);
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');
            _timerData?.cancel();

            if (!dialogShown) {
              dialogShown = true;
              mostrarDialogoError(
                  'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                  onClose: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              });
            }
          }
          return;
        } else {
          throw Exception('Endpoint no encontrado: ${response.body}');
        }
      } else {
        throw Exception(
            'Error del servidor: ${response.statusCode}, Respuesta: ${response.body}');
      }
    } on SocketException catch (e) {
      print('Error de conexión: $e'); // Imprime el error completo
      setErrorState(dialogShown, SocketException('Error de conexión'));
    } on TimeoutException catch (e) {
      print('Error de timeout: $e'); // Imprime el error completo
      setErrorState(dialogShown, TimeoutException('Timeout'));
    } catch (e) {
      print('Error general fetchGrupoData: $e'); // Imprime el error completo
      setErrorState(dialogShown, e);
    }
  }

  Future<void> fetchGrupoHistorial(String nombreGrupo) async {
    bool dialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final nombreCodificado = Uri.encodeComponent(nombreGrupo.trim());
      final uri = Uri.parse(
          'http://$baseUrl/api/v1/grupodetalles/historial/$nombreCodificado');

      print('Iniciando petición de historial para grupo: $nombreGrupo');

      final response = await http.get(
        uri,
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('Respuesta recibida (historial): ${response.statusCode}');
      print('Respuesta completa (historial): ${response.body}');

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          setState(() {
            historialData = data;
            errorDeConexion = false;
          });
        } else {
          try {
            final errorData = json.decode(response.body);

            // Check for specific session change message
            if (errorData["Error"] != null &&
                errorData["Error"]["Message"] ==
                    "La sesión ha cambiado. Cerrando sesión...") {
              if (mounted) {
                setState(() => isLoading = false);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('tokenauth');
                _timerHistorial?.cancel();

                // Show dialog and redirect to login
                mostrarDialogoCierreSesion(
                    'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false, // Remove all previous routes
                  );
                });
              }
              return;
            }
            // Handle JWT expired error
            else if (response.statusCode == 404 &&
                errorData["Error"]["Message"] == "jwt expired") {
              if (mounted) {
                setState(() => isLoading = false);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('tokenauth');
                _timerHistorial?.cancel();
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
            }
            // Handle no history found error
            else if (response.statusCode == 400 &&
                errorData["Error"]["Message"] ==
                    "No hay historial del grupo registrado con este nombre") {
              setState(() {
                historialData = [];
                errorDeConexion = false;
              });
            }
            // Other authentication errors
            else if (response.statusCode == 401) {
              if (mounted) {
                setState(() => isLoading = false);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('tokenauth');
                _timerHistorial?.cancel();

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
            }
            // Other errors
            else {
              setErrorState(dialogShown);
            }
          } catch (parseError) {
            // If response body cannot be parsed, handle as generic error
            setErrorState(dialogShown);
          }
        }
      }
    } on SocketException catch (e) {
      print('Error de conexión: $e');
      setErrorState(dialogShown, SocketException('Error de conexión'));
    } on TimeoutException catch (e) {
      print('Error de timeout: $e');
      setErrorState(dialogShown, TimeoutException('Timeout'));
    } catch (e) {
      print('Error general fetchGrupoHistorial: $e');
      setErrorState(dialogShown, e);
    }
  }

  // Método para manejar estados de error
  void setErrorState(bool dialogShown, [dynamic error]) {
    if (!mounted || dialogShown) return;

    setState(() {
      isLoading = false;
      errorDeConexion = true;
    });

    if (error is SocketException) {
      mostrarDialogoError('Error de conexión. Verifica tu red.');
    } else if (error is TimeoutException) {
      mostrarDialogoError('El servidor no respondió a tiempo');
    } else {
      mostrarDialogoError('Ocurrió un error inesperado: ${error.toString()}');
    }
  }

  void mostrarDialogoError(String mensaje,
      {VoidCallback? onClose, bool isDarkMode = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? Colors.grey[900]
              : Colors.white, // Fondo oscuro o claro
          title: Text(
            'Error',
            style: TextStyle(
              color: isDarkMode
                  ? Colors.white
                  : Colors.black, // Texto oscuro o claro
            ),
          ),
          content: Text(
            mensaje,
            style: TextStyle(
              color: isDarkMode
                  ? Colors.white
                  : Colors.black, // Texto oscuro o claro
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onClose?.call();
                dialogShown = false;
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.white
                      : Colors.black, // Texto oscuro o claro
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String isoDate) {
    final parsedDate = DateTime.parse(isoDate);
    return "${parsedDate.day}-${parsedDate.month}-${parsedDate.year}";
  }

  Future<void> obtenerGrupos({int page = 1}) async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noGroupsFound = false;
    });

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        print('Iniciando petición para obtener grupos');
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        final response = await http.get(
          Uri.parse(
              'http://$baseUrl/api/v1/grupodetalles'), // Add pagination parameters
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        print('Respuesta recibida (grupodetalles): ${response.statusCode}');
        print(
            'Respuesta completa (grupodetalles): ${response.body}'); // Imprime respuesta completa

        if (mounted) {
          if (response.statusCode == 200) {
            /*   int totalDatosResp =
                int.tryParse(response.headers['x-total-totaldatos'] ?? '0') ??
                    0;
            int totalPaginasResp =
                int.tryParse(response.headers['x-total-totalpaginas'] ?? '1') ??
                    1; */

            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
              listaGrupos.sort((a, b) => b.fCreacion.compareTo(a.fCreacion));

              isLoading = false;
              errorDeConexion = false;
              /*  totalDatos = totalDatosResp;
              totalPaginas = totalPaginasResp; */
            });
            _timer?.cancel();
          } else {
            // In case of error, reset pagination
            setState(() {
              /*   totalDatos = 0;
              totalPaginas = 1; */
            });

            try {
              final errorData = json.decode(response.body);

              // Check for specific session change message
              if (errorData["Error"] != null &&
                  errorData["Error"]["Message"] ==
                      "La sesión ha cambiado. Cerrando sesión...") {
                if (mounted) {
                  setState(() => isLoading = false);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('tokenauth');
                  _timer?.cancel();

                  // Show dialog and redirect to login
                  mostrarDialogoCierreSesion(
                      'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false, // Remove all previous routes
                    );
                  });
                }
                return;
              }
              // Handle JWT expired error
              else if (response.statusCode == 404 &&
                  errorData["Error"]["Message"] == "jwt expired") {
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
                  });
                }
                return;
              }
              // Handle no groups found error
              else if (response.statusCode == 400 &&
                  errorData["Error"]["Message"] ==
                      "No hay detalle de grupos registrados") {
                setState(() {
                  listaGrupos = [];
                  isLoading = false;
                  noGroupsFound = true;
                });
                _timer?.cancel();
              }
              // Other errors
              else {
                setErrorState(dialogShown);
              }
            } catch (parseError) {
              // If response body cannot be parsed, handle as generic error
              setErrorState(dialogShown);
            }
          }
        }
      } catch (e) {
        print('Error en obtenerGrupos: $e'); // Imprime el error completo
        if (mounted) {
          setErrorState(dialogShown, e);
        }
      }
    }

    fetchData();

    if (!noGroupsFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noGroupsFound) {
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

  void mostrarDialogoCierreSesion(String mensaje,
      {required Function() onClose}) {
    // Detectar si estamos en modo oscuro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          contentPadding: EdgeInsets.only(top: 25, bottom: 10),
          title: Column(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 60,
                color: Colors.red[700],
              ),
              SizedBox(height: 15),
              Text(
                'Sesión Finalizada',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          actionsPadding: EdgeInsets.only(bottom: 20, right: 25, left: 25),
          actions: [
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(double.infinity, 48), // Ancho completo
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onClose();
              },
              child: Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: isDarkMode
          ? Colors.grey[900]
          : Color(0xFFF7F8FA), // Fondo oscuro o claro
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 50),
        width: width,
        height: height,
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: isDarkMode
                      ? Colors.white
                      : Color(0xFF5162F6), // Color del indicador de carga
                ),
              )
            : grupoData != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda fija y centrada
                      Expanded(
                        flex: 25,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF5162F6), // Mantén el color azul
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 70,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.groups,
                                  size: 100,
                                  color: Color(0xFF5162F6),
                                ),
                              ),
                              SizedBox(height: 16),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Información del Grupo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildDetailRowIG('ID:', grupoData!.idgrupos),
                              _buildDetailRowIG(
                                  'Nombre:', grupoData!.nombreGrupo),
                              _buildDetailRowIG('Tipo:', grupoData!.tipoGrupo),
                              _buildDetailRowIG(
                                  'Detalles:', grupoData!.detalles),
                              _buildDetailRowIG('Estado:', grupoData!.estado),
                              _buildDetailRowIG('Folio del Crédito:',
                                  grupoData!.folio ?? 'No asignado'),
                              SizedBox(height: 30),
                              ElevatedButton(
                                onPressed: () {
                                  print("Renovación de Grupo");
                                  mostrarDialogoEditarCliente(widget.idGrupo);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Color(0xFF5162F6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                ),
                                child: Text(
                                  "Renovación de Grupo",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      // Columna derecha deslizable
                      Expanded(
                        flex: 75,
                        child: Row(
                          children: [
                            // Columna de Integrantes
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: _buildSectionTitle(
                                        'Integrantes', isDarkMode),
                                  ),
                                  Expanded(
                                    child: ListView(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      children: [
                                        if (grupoData!.clientes.isNotEmpty) ...[
                                          for (var cliente
                                              in grupoData!.clientes)
                                            Card(
                                              color: isDarkMode
                                                  ? Colors.grey[800]
                                                  : Colors.white,
                                              margin: EdgeInsets.symmetric(
                                                  vertical: 8),
                                              elevation: 4,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: ExpansionTile(
                                                title: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.account_circle,
                                                      size: 40,
                                                      color: Color(0xFF5162F6),
                                                    ),
                                                    SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            cliente.nombres,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black,
                                                            ),
                                                          ),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                'Cargo:',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                cliente.cargo!,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                children: [
                                                  if (cliente.cuenta == null ||
                                                      (cliente
                                                              .cuenta!
                                                              .nombreBanco
                                                              .isEmpty &&
                                                          cliente
                                                              .cuenta!
                                                              .numCuenta
                                                              .isEmpty &&
                                                          cliente
                                                              .cuenta!
                                                              .numTarjeta
                                                              .isEmpty &&
                                                          cliente
                                                              .cuenta!
                                                              .clbIntBanc
                                                              .isEmpty)) ...[
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16.0,
                                                          vertical: 8.0),
                                                      child: Text(
                                                        'No hay información de cuenta bancaria.',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDarkMode
                                                              ? Colors.white
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16.0,
                                                          vertical: 8.0),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          _buildDetailRow(
                                                            'Banco:',
                                                            cliente.cuenta!
                                                                .nombreBanco,
                                                            isDarkMode:
                                                                isDarkMode,
                                                          ),
                                                          _buildDetailRow(
                                                            'Número de Cuenta:',
                                                            cliente.cuenta!
                                                                .numCuenta,
                                                            isDarkMode:
                                                                isDarkMode,
                                                          ),
                                                          _buildDetailRow(
                                                            'Número de Tarjeta:',
                                                            cliente.cuenta!
                                                                .numTarjeta,
                                                            isDarkMode:
                                                                isDarkMode,
                                                          ),
                                                          _buildDetailRow(
                                                            'CLABE:',
                                                            cliente.cuenta!
                                                                .clbIntBanc,
                                                            isDarkMode:
                                                                isDarkMode,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 20),
                            // Columna de Créditos
                            Expanded(
                              flex: 6,
                              child: SingleChildScrollView(
                                child: Container(
                                  constraints: BoxConstraints(minHeight: 600),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionTitle(
                                            'Historial de Créditos',
                                            isDarkMode),
                                        if (historialData != null &&
                                            historialData.isNotEmpty)
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            itemCount: historialData.length,
                                            itemBuilder: (context, index) {
                                              var historialItem =
                                                  historialData[index];
                                              return Card(
                                                color: isDarkMode
                                                    ? Colors.grey[800]
                                                    : Colors
                                                        .white, // Fondo oscuro o claro
                                                margin: EdgeInsets.symmetric(
                                                    vertical: 8),
                                                elevation: 4,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: ExpansionTile(
                                                  title: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            'Grupo: ${historialItem['nombreGrupo']}',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black, // Texto oscuro o claro
                                                            ),
                                                          ),
                                                          Text(
                                                            historialItem[
                                                                'estado'],
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: isDarkMode
                                                                  ? Colors.white
                                                                  : Colors.grey[
                                                                      800], // Texto oscuro o claro
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Divider(
                                                          color: Colors
                                                              .grey), // Línea divisoria
                                                      SizedBox(height: 8),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Text(
                                                                'Crédito: ',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black, // Texto oscuro o claro
                                                                ),
                                                              ),
                                                              Text(
                                                                '${historialItem['folio'] ?? 'No asignado'}',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black, // Texto oscuro o claro
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          Text(
                                                            'Fecha: ${_formatDate(historialItem['fCreacion'])}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: isDarkMode
                                                                  ? Colors.white
                                                                  : Colors.grey[
                                                                      800], // Texto oscuro o claro
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 10),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Detalles: ',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isDarkMode
                                                                  ? Colors.white
                                                                  : Colors.grey[
                                                                      800], // Texto oscuro o claro
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            historialItem[
                                                                    'detalles'] ??
                                                                'Sin descripción',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black, // Texto oscuro o claro
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  children: [
                                                    _buildGrupoYClientes(
                                                        historialItem,
                                                        isDarkMode),
                                                  ],
                                                ),
                                              );
                                            },
                                          )
                                        else
                                          Center(
                                            child: Text(
                                              'No hay versiones disponibles',
                                              style: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors
                                                        .black, // Texto oscuro o claro
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error al cargar datos del grupo',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : Colors.black, // Texto oscuro o claro
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                            });
                            fetchGrupoData();
                          },
                          child: Text('Recargar'),
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Color(0xFF5162F6)),
                            foregroundColor:
                                MaterialStateProperty.all(Colors.white),
                            shape: MaterialStateProperty.all<
                                RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void mostrarDialogoEditarCliente(String idGrupo) async {
    final resultado = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return renovarGrupoDialog(
          idGrupo: idGrupo,
          onGrupoRenovado: () {
            Navigator.of(context).pop(true); // Enviar true al cerrarse
            obtenerGrupos(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );

    if (resultado == true) {
      Navigator.of(context)
          .pop(true); // Propaga el true hacia la pantalla Grupos
    }
  }

  Widget _buildGrupoYClientes(Map historialItem, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo de Grupo: ${historialItem['tipoGrupo']}',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode
                  ? Colors.white
                  : Colors.black, // Texto oscuro o claro
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Integrantes:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white
                  : Colors.black, // Texto oscuro o claro
            ),
          ),
          ...historialItem['clientes'].asMap().entries.map<Widget>((entry) {
            int index = entry.key + 1;
            var cliente = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 0),
                leading: Icon(
                  Icons.account_circle,
                  size: 30,
                  color: Color(0xFF5162F6),
                ),
                title: Text(
                  cliente['nombres'],
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.white
                        : Colors.black, // Texto oscuro o claro
                  ),
                ),
                subtitle: Text(
                  'Cargo: ${cliente['cargo']} | Teléfono: ${cliente['telefono']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.white
                        : Colors.black, // Texto oscuro o claro
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value,
      {bool isDarkMode = false}) {
    if (value?.isNotEmpty ?? false) {
      return Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDarkMode
                  ? Colors.white
                  : Colors.black, // Texto oscuro o claro
            ),
          ),
          SizedBox(width: 4),
          SelectableText(
            value!,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode
                  ? Colors.white
                  : Colors.black, // Texto oscuro o claro
            ),
          ),
        ],
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildDetailRowIG(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text('$title $value',
          style: TextStyle(fontSize: 12, color: Colors.white)),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDarkMode
              ? Colors.white
              : Colors.black87, // Texto oscuro o claro
        ),
      ),
    );
  }
}

class Grupo {
  final String idgrupos;
  final String idusuario;
  final String? folio;
  final String asesor;
  final String estado;
  final String tipoGrupo;
  final String nombreGrupo;
  final String detalles;
  final List<Cliente> clientes;
  final DateTime fCreacion;

  Grupo({
    required this.idgrupos,
    required this.idusuario,
    required this.folio,
    required this.asesor,
    required this.estado,
    required this.tipoGrupo,
    required this.nombreGrupo,
    required this.detalles,
    required this.clientes,
    required this.fCreacion,
  });

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      idgrupos: json['idgrupos'],
      idusuario: json['idusuario'],
      folio: json['folio'],
      asesor: json['asesor'],
      estado: json['estado'] ?? 'N/A',
      tipoGrupo: json['tipoGrupo'],
      nombreGrupo: json['nombreGrupo'],
      detalles: json['detalles'],
      clientes: (json['clientes'] as List)
          .map((cliente) => Cliente.fromJson(cliente))
          .toList(),
      fCreacion: DateTime.parse(json['fCreacion']),
    );
  }
}

class Cliente {
  final String iddetallegrupos;
  final String idclientes;
  final String nombres;
  final String telefono;
  final DateTime fechaNacimiento;
  final String cargo;
  final Cuenta? cuenta;

  Cliente({
    required this.iddetallegrupos,
    required this.idclientes,
    required this.nombres,
    required this.telefono,
    required this.fechaNacimiento,
    required this.cargo,
    this.cuenta,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      iddetallegrupos: json['iddetallegrupos'],
      idclientes: json['idclientes'],
      nombres: json['nombres'],
      telefono: json['telefono'],
      fechaNacimiento: DateTime.parse(json['fechaNacimiento']),
      cargo: json['cargo'],
      cuenta: json['cuenta'] != null ? Cuenta.fromJson(json['cuenta']) : null,
    );
  }
}

class Cuenta {
  final String idcuantabank;
  final String nombreBanco;
  final String numCuenta;
  final String numTarjeta;
  final String clbIntBanc;
  final String idclientes;

  Cuenta({
    required this.idcuantabank,
    required this.nombreBanco,
    required this.numCuenta,
    required this.numTarjeta,
    required this.clbIntBanc,
    required this.idclientes,
  });

  factory Cuenta.fromJson(Map<String, dynamic> json) {
    return Cuenta(
      idcuantabank: json['idcuantabank'],
      nombreBanco: json['nombreBanco'],
      numCuenta: json['numCuenta'],
      numTarjeta: json['numTarjeta'],
      clbIntBanc: json['clbIntBanc'],
      idclientes: json['idclientes'],
    );
  }
}
