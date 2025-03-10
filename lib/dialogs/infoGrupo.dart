import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:finora/dialogs/renovarGrupo.dart';
import 'dart:convert';

import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
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

      print(
          'Iniciando petición de historial para grupo: $nombreGrupo'); // Añadir log inicial

      final response = await http.get(
        uri,
        headers: {'tokenauth': token},
      ).timeout(Duration(seconds: 10));

      print('Respuesta recibida (historial): ${response.statusCode}');
      print(
          'Respuesta completa (historial): ${response.body}'); // Imprime respuesta completa

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          historialData = data;
          errorDeConexion = false;
        });
      } else if (response.statusCode == 400) {
        print('Error 400: ${response.body}'); // Imprime detalle del error
        final errorData = json.decode(response.body);
        if (errorData["Error"]["Message"] ==
            "No hay historial del grupo registrado con este nombre") {
          setState(() {
            historialData = [];
            errorDeConexion = false;
          });
        }
      } else if (response.statusCode == 404) {
        print('Error 404: ${response.body}'); // Imprime detalle del error
        final errorData = json.decode(response.body);
        if (errorData["Error"]["Message"] == "jwt expired") {
          if (mounted) {
            setState(() => isLoading = false);
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');
            _timerHistorial?.cancel();

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
      } else if (response.statusCode == 401) {
        print('Error 401: ${response.body}'); // Imprime detalle del error
        if (mounted) {
          setState(() => isLoading = false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('tokenauth');
          _timerHistorial?.cancel();

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
      print(
          'Error general fetchGrupoHistorial: $e'); // Imprime el error completo
      setErrorState(dialogShown, e);
    }
  }

// Mantenemos tu método setErrorState original
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

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Error'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onClose?.call();
                dialogShown = false;
              },
              child: const Text('OK'),
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

  Future<void> obtenerGrupos() async {
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
          Uri.parse('http://$baseUrl/api/v1/grupodetalles'),
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        print(
            'Respuesta recibida (grupodetalles fetchData): ${response.statusCode}');
        print(
            'Respuesta completa (grupodetalles fetchData): ${response.body}'); // Imprime respuesta completa

        if (mounted) {
          if (response.statusCode == 200) {
            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
              listaGrupos.sort((a, b) => b.fCreacion.compareTo(a.fCreacion));
              isLoading = false;
              errorDeConexion = false;
            });
            _timer?.cancel();
          } else if (response.statusCode == 404) {
            print('Error 404: ${response.body}'); // Imprime detalle del error
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
                });
              }
              return;
            } else {
              setErrorState(dialogShown);
            }
          } else if (response.statusCode == 400) {
            print('Error 400: ${response.body}'); // Imprime detalle del error
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] ==
                "No hay detalle de grupos registrados") {
              setState(() {
                listaGrupos = [];
                isLoading = false;
                noGroupsFound = true;
              });
              _timer?.cancel();
            } else {
              setErrorState(dialogShown);
            }
          } else {
            print(
                'Error no manejado: ${response.statusCode}, Respuesta: ${response.body}');
            setErrorState(dialogShown);
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: Color(0xFFF7F8FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 50),
        width: width,
        height: height,
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : grupoData != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda fija y centrada
                      Expanded(
                        flex: 25,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF5162F6),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 70, // Tamaño del avatar
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.groups,
                                  size: 100,
                                  color: Color(
                                      0xFF5162F6), // Color que combine con el fondo
                                ),
                              ),
                              SizedBox(height: 16),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Información del Grupo',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                              SizedBox(
                                  height:
                                      8), // Espacio entre el título y los detalles
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
                                    borderRadius: BorderRadius.circular(20),
                                  ),
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
                              child: Container(
                                constraints: BoxConstraints(
                                    minHeight: 300), // Altura mínima
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle('Integrantes'),
                                      // Dentro del método build, en la sección donde se muestran los detalles de los clientes:
                                      if (grupoData!.clientes.isNotEmpty) ...[
                                        for (var cliente in grupoData!.clientes)
                                          Card(
                                            color: Colors.white,
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
                                                        Text(cliente.nombres,
                                                            style: TextStyle(
                                                                fontSize: 14)),
                                                        Row(
                                                          children: [
                                                            Text('Cargo:',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        12)),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              cliente.cargo!,
                                                              style: TextStyle(
                                                                  fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              children: [
                                                if (cliente.cuenta != null) ...[
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
                                                        ),
                                                        _buildDetailRow(
                                                          'Número de Cuenta:',
                                                          cliente.cuenta!
                                                              .numCuenta,
                                                        ),
                                                        _buildDetailRow(
                                                          'Número de Tarjeta:',
                                                          cliente.cuenta!
                                                              .numTarjeta,
                                                        ),
                                                        _buildDetailRow(
                                                          'CLABE:',
                                                          cliente.cuenta!
                                                              .clbIntBanc,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 8.0),
                                                    child: Text(
                                                      'No hay información de cuenta bancaria.',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey),
                                                    ),
                                                  ),
                                                ]
                                              ],
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Columna de Créditos
                            SizedBox(width: 20),
                            Expanded(
                              flex: 6,
                              child: SingleChildScrollView(
                                child: Container(
                                  constraints: BoxConstraints(
                                      minHeight: 600), // Altura mínima
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionTitle(
                                            'Historial de Créditos'),
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
                                                color: Colors.white,
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
                                                                        .bold),
                                                          ),
                                                          Text(
                                                            historialItem[
                                                                'estado'],
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey[800]),
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
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                              ),
                                                              Text(
                                                                '${historialItem['folio'] ?? 'No asignado'}',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                              )
                                                            ],
                                                          ),
                                                          Text(
                                                            'Fecha: ${_formatDate(historialItem['fCreacion'])}',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey[800]),
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
                                                                color: Colors
                                                                    .grey[800]),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            historialItem[
                                                                    'detalles'] ??
                                                                'Sin descripción',
                                                            style: TextStyle(
                                                                fontSize: 12),
                                                          ),
                                                        ],
                                                      )
                                                    ],
                                                  ),
                                                  children: [
                                                    _buildGrupoYClientes(
                                                        historialItem),
                                                  ],
                                                ),
                                              );
                                            },
                                          )
                                        else
                                          Center(
                                            child: Text(
                                                'No hay versiones disponibles'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  )
                : Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text('Error al cargar datos del grupo'),
                        SizedBox(
                            height: 20), // Espaciado entre el texto y el botón
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading =
                                  true; // Indica que la recarga ha comenzado
                            });
                            fetchGrupoData(); // Llama a la función para recargar los datos
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
                      ])),
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

  Widget _buildGrupoYClientes(Map historialItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tipo de Grupo: ${historialItem['tipoGrupo']}',
              style: TextStyle(fontSize: 12)),

          // Mostrar clientes
          SizedBox(height: 8),
          Text('Integrantes:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ...historialItem['clientes'].asMap().entries.map<Widget>((entry) {
            int index = entry.key + 1; // Agregar índice (numeración)
            var cliente = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 0), // Reducir espacio

                leading: Icon(
                  Icons.account_circle,
                  size: 30,
                  color: Color(0xFF5162F6),
                ),
                title: Text(
                  cliente['nombres'],
                  style: TextStyle(fontSize: 12),
                ),
                subtitle: Text(
                  'Cargo: ${cliente['cargo']} | Teléfono: ${cliente['telefono']}',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {IconData? icon}) {
    if (value?.isNotEmpty ?? false) {
      return Row(
        children: [
          Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          SizedBox(width: 4),
          SelectableText(
            value!,
            style: TextStyle(fontSize: 12),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
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
