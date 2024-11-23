import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
                              flex: 1,
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
                                                          child: Text(cliente['nombres'],
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
                              flex: 1,
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
                                      _buildSectionTitle('Créditos del Grupo'),
                                      _buildSectionTitle('Activos'),
                                      if (grupoData!['creditos'] is List)
                                        for (var credito
                                            in grupoData!['creditos'])
                                          if (credito['estado'] == 'Activo')
                                            Card(
                                              margin: EdgeInsets.symmetric(
                                                  vertical: 8),
                                              elevation: 4,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _buildDetailRow('Crédito:',
                                                        credito['nombre']),
                                                    _buildDetailRow(
                                                        'Monto Total:',
                                                        credito['montoTotal']),
                                                    _buildDetailRow('Estado:',
                                                        credito['estado']),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      _buildSectionTitle('Inactivos'),
                                      if (grupoData!['creditos'] is List)
                                        for (var credito
                                            in grupoData!['creditos'])
                                          if (credito['estado'] == 'Inactivo')
                                            Card(
                                              margin: EdgeInsets.symmetric(
                                                  vertical: 8),
                                              elevation: 4,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _buildDetailRow('Crédito:',
                                                        credito['nombre']),
                                                    _buildDetailRow(
                                                        'Monto Total:',
                                                        credito['montoTotal']),
                                                    _buildDetailRow('Estado:',
                                                        credito['estado']),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          print("Renovación de Grupo");
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFFFB2056),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 32, vertical: 16),
                                        ),
                                        child: Text(
                                          "Renovación de Grupo",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Columna de Versiones (Scrollable)
                            Expanded(
                              flex: 1,
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
                                            'Versiones del Grupo'),
                                        isLoading
                                            ? Center(
                                                child:
                                                    CircularProgressIndicator())
                                            : ListView.builder(
                                                shrinkWrap: true,
                                                itemCount:
                                                    historialData?.length ?? 0,
                                                itemBuilder: (context, index) {
                                                  var historialItem =
                                                      historialData[index];
                                                  return Card(
                                                    color: Colors.white,
                                                    margin: EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal:
                                                            0), // Espaciado opcional
                                                    elevation:
                                                        4, // Sombras para destacar el Card
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12), // Bordes redondeados
                                                    ),
                                                    child: ExpansionTile(
                                                      title: Text(
                                                        'Grupo: ${historialItem['nombreGrupo']}',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                      subtitle: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                              style: TextStyle(
                                                                  fontSize: 12),
                                                              'Estado: ${historialItem['estado']}'),
                                                          Text(
                                                            'Fecha: ${_formatDate(historialItem['fCreacion'])}',
                                                            style: TextStyle(
                                                                fontSize: 12),
                                                          ),
                                                        ],
                                                      ),
                                                      children: [
                                                        _buildGrupoYClientes(
                                                            historialItem),
                                                      ],
                                                    ),
                                                  );
                                                },
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

  Widget _buildGrupoYClientes(Map historialItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tipo de Grupo: ${historialItem['tipoGrupo']}',
              style: TextStyle(fontSize: 12)),
          Text('Detalles: ${historialItem['detalles']}',
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
