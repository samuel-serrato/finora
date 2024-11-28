import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:money_facil/dialogs/renovarGrupo.dart';
import 'dart:convert';

import 'package:money_facil/ip.dart';

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
  Timer? _timer;
  bool dialogShown = false;
  late ScrollController _scrollController;
  List<dynamic> historialData = [];

  @override
  void initState() {
    _scrollController = ScrollController();
    super.initState();
    fetchGrupoData();
    fetchGrupoHistorial(widget.nombreGrupo); // Obtener el historial del grupo
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
    _scrollController.dispose();
  }

  Future<void> fetchGrupoData() async {
    // Cancelamos cualquier temporizador anterior antes de crear uno nuevo
    _timer?.cancel();

    // Inicializamos el estado de carga
    setState(() {
      isLoading = true; // Indicamos que está cargando
    });

    // Iniciamos un nuevo temporizador de 10 segundos
    _timer = Timer(Duration(seconds: 10), () {
      if (mounted && isLoading) {
        // Solo si sigue cargando después de 10 segundos
        setState(() {
          isLoading = false; // Detenemos el indicador de carga
        });
        mostrarDialogoError(
            'No se pudo conectar al servidor. Por favor, revise su conexión de red.');
      }
    });

    try {
      final response = await http.get(
          Uri.parse('http://$baseUrl/api/v1/grupodetalles/${widget.idGrupo}'));

      // Cancelamos el temporizador si la solicitud fue exitosa
      _timer?.cancel();

      if (response.statusCode == 200) {
        setState(() {
          grupoData = json.decode(response.body)[0];
          isLoading = false; // Fin de la carga
        });
      } else {
        // Si la respuesta tiene un código de error, también dejamos de cargar
        setState(() {
          isLoading = false; // Fin de la carga
        });
        if (!dialogShown) {
          dialogShown = true;
          mostrarDialogoError(
              'Error en la carga de datos. Código de error: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Si hay un error en la solicitud
      if (mounted) {
        setState(() {
          isLoading = false; // Fin de la carga
        });
        if (!dialogShown) {
          dialogShown = true;
          mostrarDialogoError('Error de conexión o inesperado: $e');
        }
      }
    }
  }

  Future<void> fetchGrupoHistorial(String nombreGrupo) async {
  _timer?.cancel();

  setState(() {
    isLoading = true; // Indicamos que está cargando
  });

  _timer = Timer(Duration(seconds: 10), () {
    if (mounted && isLoading) {
      setState(() {
        isLoading = false;
      });
      mostrarDialogoError(
          'No se pudo conectar al servidor. Por favor, revise su conexión de red.');
    }
  });

  try {
    final response = await http.get(Uri.parse(
        'http://$baseUrl/api/v1/grupodetalles/historial/$nombreGrupo'));

    _timer?.cancel();

    if (response.statusCode == 200) {
      setState(() {
        historialData = json.decode(response.body); // Guarda el historial
        // Ordenar los datos por fecha
        historialData.sort((a, b) {
          DateTime dateA = DateTime.parse(a['fCreacion']);
          DateTime dateB = DateTime.parse(b['fCreacion']);
          return dateB.compareTo(dateA); // Orden descendente, cambia a dateA.compareTo(dateB) para ascendente
        });
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      if (!dialogShown) {
        dialogShown = true;
        mostrarDialogoError(
            'Error en la carga de datos. Código de error: ${response.statusCode}');
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
      if (!dialogShown) {
        dialogShown = true;
        mostrarDialogoError('Error de conexión o inesperado: $e');
      }
    }
  }
}


  void mostrarDialogoError(String mensaje) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error de conexión'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
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

                              _buildDetailRowIG('Crédito:', 'No asignado'),
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
    Navigator.of(context).pop(true); // Propaga el true hacia la pantalla Grupos
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
