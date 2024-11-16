import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:money_facil/ip.dart';

class InfoGrupo extends StatefulWidget {
  final String idGrupo;

  InfoGrupo({required this.idGrupo});

  @override
  _InfoGrupoState createState() => _InfoGrupoState();
}

class _InfoGrupoState extends State<InfoGrupo> {
  Map<String, dynamic>? grupoData;
  bool isLoading = true;
  Timer? _timer;
  bool dialogShown = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    _scrollController = ScrollController();
    super.initState();
    fetchGrupoData();
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
                              _buildDetailRowIG('Nombre:',
                                  grupoData!['nombreGrupo']),
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
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sección para dividir en dos columnas
                                Row(
                                  children: [
                                    // Columna de Integrantes
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                                constraints: BoxConstraints(minHeight: 300), // Altura mínima opcional

                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Título Integrantes
                                              _buildSectionTitle('Integrantes'),
                                              if (grupoData!['clientes']
                                                  is List) ...[
                                                for (var cliente
                                                    in grupoData!['clientes'])
                                                  Card(
                                                    color: Colors.white,
                                                    margin: EdgeInsets.symmetric(
                                                        vertical: 8),
                                                    elevation: 4,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              16),
                                                      child: Row(
                                                        children: [
                                                          // CircleAvatar para el cliente
                                                          Icon(Icons.account_circle, size: 40, color: Color(0xFFFB2056),),
                                                          SizedBox(width: 16),
                                                          // Información del cliente
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                _buildDetailRow(
                                                                    'Nombre:',
                                                                    cliente[
                                                                        'nombres']),
                                                                _buildDetailRow(
                                                                    'Cargo:',
                                                                    cliente[
                                                                        'cargo']),
                                                               /*  _buildDetailRow(
                                                                    'Monto Individual:',
                                                                    cliente['montoIndividual'] ??
                                                                        'No especificado'), */
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
                                    SizedBox(width: 50),
                                    // Columna de Créditos
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                                constraints: BoxConstraints(minHeight: 300), // Altura mínima opcional

                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Título Créditos del Grupo
                                              _buildSectionTitle(
                                                  'Créditos del Grupo'),
                                              // Créditos Activos
                                              _buildSectionTitle('Activos'),
                                              if (grupoData!['creditos'] is List)
                                                for (var credito
                                                    in grupoData!['creditos'])
                                                  if (credito['estado'] ==
                                                      'Activo')
                                                    Card(
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              vertical: 8),
                                                      elevation: 4,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                                16),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            _buildDetailRow(
                                                                'Crédito:',
                                                                credito[
                                                                    'nombre']),
                                                            _buildDetailRow(
                                                                'Monto Total:',
                                                                credito[
                                                                    'montoTotal']),
                                                            _buildDetailRow(
                                                                'Estado:',
                                                                credito[
                                                                    'estado']),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                        
                                              // Créditos Inactivos
                                              _buildSectionTitle('Inactivos'),
                                              if (grupoData!['creditos'] is List)
                                                for (var credito
                                                    in grupoData!['creditos'])
                                                  if (credito['estado'] ==
                                                      'Inactivo')
                                                    Card(
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              vertical: 8),
                                                      elevation: 4,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                                16),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            _buildDetailRow(
                                                                'Crédito:',
                                                                credito[
                                                                    'nombre']),
                                                            _buildDetailRow(
                                                                'Monto Total:',
                                                                credito[
                                                                    'montoTotal']),
                                                            _buildDetailRow(
                                                                'Estado:',
                                                                credito[
                                                                    'estado']),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
