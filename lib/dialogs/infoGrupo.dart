import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:money_facil/dialogs/renovarGrupo.dart';
import 'dart:convert';

import 'package:money_facil/ip.dart';
import 'package:money_facil/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoGrupo extends StatefulWidget {
  final String idGrupo;
  final String nombreGrupo;

  InfoGrupo({required this.idGrupo, required this.nombreGrupo});

  @override
  _InfoGrupoState createState() => _InfoGrupoState();
}

class _InfoGrupoState extends State<InfoGrupo> {
  Map<String, dynamic>? grupoData;
  bool isLoading = true;
  Timer? _timerData;
  Timer? _timerHistorial;
  bool dialogShown = false;
  late ScrollController _scrollController;
  List<dynamic> historialData = [];
  bool errorDeConexion = false;
  bool noGroupsFound = false;

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

    print('Respuesta recibida (grupo): ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData is List && responseData.isNotEmpty) {
        setState(() {
          grupoData = responseData[0];
          errorDeConexion = false;
        });
      } else {
        throw Exception('Datos del grupo no encontrados');
      }
    } 
    else if (response.statusCode == 401) {
      if (mounted) {
        setState(() => isLoading = false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tokenauth');
        _timerData?.cancel();
        
        if (!dialogShown) {
          dialogShown = true;
          mostrarDialogoError(
            'Tu sesión ha expirado. Por favor inicia sesión de nuevo.',
            onClose: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            }
          );
        }
      }
    }
    else if (response.statusCode == 404) {
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
              'Tu sesión ha expirado. Por favor inicia sesión de nuevo.',
              onClose: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              }
            );
          }
        }
        return;
      } else {
        throw Exception('Endpoint no encontrado');
      }
    }
    else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
    
  } on SocketException {
    setErrorState(dialogShown, SocketException('Error de conexión'));
  } on TimeoutException {
    setErrorState(dialogShown, TimeoutException('Timeout'));
  } catch (e) {
    setErrorState(dialogShown, e);
  }
}


  Future<void> fetchGrupoHistorial(String nombreGrupo) async {
  bool dialogShown = false;
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    final nombreCodificado = Uri.encodeComponent(nombreGrupo.trim());
    final uri = Uri.parse('http://$baseUrl/api/v1/grupodetalles/historial/$nombreCodificado');

    final response = await http.get(
      uri,
      headers: {'tokenauth': token},
    ).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      // ... (tu procesamiento normal de datos) ...
    } 
    else if (response.statusCode == 400) {
      // ... (manejo de "no hay registros" como antes) ...
    }
    else if (response.statusCode == 404) {
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
              'Tu sesión ha expirado. Por favor inicia sesión de nuevo.',
              onClose: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              }
            );
          }
        }
        return;
      } else {
        throw Exception('Endpoint no encontrado');
      }
    }
    else if (response.statusCode == 401) {
      // Manejo alternativo para 401 (no basado en mensaje)
      if (mounted) {
        setState(() => isLoading = false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tokenauth');
        _timerHistorial?.cancel();
        
        if (!dialogShown) {
          dialogShown = true;
          mostrarDialogoError(
            'Tu sesión ha expirado. Por favor inicia sesión de nuevo.',
            onClose: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            }
          );
        }
      }
    }
    else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
    
  } on SocketException {
    setErrorState(dialogShown, SocketException('Error de conexión'));
  } on TimeoutException {
    setErrorState(dialogShown, TimeoutException('Timeout'));
  } catch (e) {
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
  } 
  else if (error is TimeoutException) {
    mostrarDialogoError('El servidor no respondió a tiempo');
  }
  else {
    mostrarDialogoError('Ocurrió un error inesperado: ${error.toString()}');
  }
}

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
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
                            color: Color(0xFFFB2056),
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
                                      0xFFFB2056), // Color que combine con el fondo
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
                              _buildDetailRowIG('ID:', grupoData!['idgrupos']),
                              _buildDetailRowIG(
                                  'Nombre:', grupoData!['nombreGrupo']),
                              _buildDetailRowIG(
                                  'Tipo:', grupoData!['tipoGrupo']),
                              _buildDetailRowIG(
                                  'Detalles:', grupoData!['detalles']),
                              _buildDetailRowIG(
                                  'Estado:', grupoData!['estado']),

                              _buildDetailRowIG('Folio del Crédito:',
                                  grupoData!['folio'] ?? 'No asignado'),
                              SizedBox(height: 30),
                              ElevatedButton(
                                onPressed: () {
                                  print("Renovación de Grupo");
                                  mostrarDialogoEditarCliente(widget.idGrupo);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Color(0xFFFB2056),
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
                                      if (grupoData!['clientes'] is List) ...[
                                        for (var cliente
                                            in grupoData!['clientes'])
                                          Card(
                                            color: Colors.white,
                                            margin: EdgeInsets.symmetric(
                                                vertical: 8),
                                            elevation: 4,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.account_circle,
                                                    size: 40,
                                                    color: Color(0xFFFB2056),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical:
                                                                      4.0),
                                                          child: Text(
                                                              cliente[
                                                                  'nombres'],
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                              )),
                                                        ),
                                                        _buildDetailRow(
                                                            'Cargo:',
                                                            cliente['cargo']),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                                                                '${historialItem['credito'] ?? 'No asignado'}',
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
                                MaterialStateProperty.all(Color(0xFFFB2056)),
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
                  color: Color(0xFFFB2056),
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

  Widget _buildDetailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text('$title $value',
          style: TextStyle(
            fontSize: 12,
          )),
    );
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
