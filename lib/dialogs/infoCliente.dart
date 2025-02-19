import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoCliente extends StatefulWidget {
  final String idCliente;

  InfoCliente({required this.idCliente});

  @override
  _InfoClienteState createState() => _InfoClienteState();
}

class _InfoClienteState extends State<InfoCliente> {
  Map<String, dynamic>? clienteData;
  bool isLoading = true;
  Timer? _timer;
  bool dialogShown = false;
  bool errorDeConexion = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    _scrollController = ScrollController();
    super.initState();
    fetchClienteData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
    _scrollController.dispose();
  }

  Future<void> fetchClienteData() async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
    });

    bool localDialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('http://$baseUrl/api/v1/clientes/${widget.idCliente}'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
            setState(() {
              clienteData = data[0];
              isLoading = false;
            });
          } else {
            setErrorState(localDialogShown);
          }
          _timer?.cancel();
        } else if (response.statusCode == 404) {
          final errorData = json.decode(response.body);
          if (errorData["Error"]["Message"] == "jwt expired") {
            if (mounted) {
              setState(() => isLoading = false);
              await prefs.remove('tokenauth');
              _timer?.cancel();
              mostrarDialogoError(
                'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                onClose: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                }
              );
            }
            return;
          } else {
            setErrorState(localDialogShown);
          }
        } else {
          setErrorState(localDialogShown);
        }
      }
    } catch (e) {
      if (mounted) {
        setErrorState(localDialogShown, e);
      }
    }

    // Configurar el timer solo si no se ha obtenido respuesta
    _timer = Timer(Duration(seconds: 10), () {
      if (mounted && !localDialogShown && isLoading) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
        localDialogShown = true;
        mostrarDialogoError(
          'No se pudo conectar al servidor. Verifica tu red.',
        );
      }
    });
  }

  void setErrorState(bool dialogShown, [dynamic error]) {
    if (mounted) {
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
      }
      _timer?.cancel();
    }
  }

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    if (mounted) {
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
            : clienteData != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda fija y centrada
                      Expanded(
                        flex: 25,
                        child: Container(
                          decoration: BoxDecoration(
                              color: Color(0xFF5162F6),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20))),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_circle,
                                size: 150,
                                color: Colors.white,
                              ),
                              SizedBox(height: 16),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Información General',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                              /*   _buildDetailRow(
                                  'ID:', clienteData!['idclientes']), */
                              _buildDetailRowIG('Nombre:',
                                  '${clienteData!['nombres']} ${clienteData!['apellidoP']} ${clienteData!['apellidoM']}'),
                              _buildDetailRowIG(
                                  'Fecha de Nac:', clienteData!['fechaNac']),
                              _buildDetailRowIG('Tipo Cliente:',
                                  clienteData!['tipo_cliente']),
                              _buildDetailRowIG('Sexo:', clienteData!['sexo']),
                              _buildDetailRowIG(
                                  'Ocupación:', clienteData!['ocupacion']),
                              _buildDetailRowIG(
                                  'Teléfono:', clienteData!['telefono']),
                              _buildDetailRowIG(
                                  'Estado Civil:', clienteData!['eCivil']),
                              _buildDetailRowIG('Dependientes Económicos:',
                                  clienteData!['dependientes_economicos']),
                              _buildDetailRowIG(
                                  'Email:', clienteData!['email']),
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
                                // Fila para Cuentas de Banco y Domicilios
                                Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .spaceEvenly, // Distribuye los elementos con espacio uniforme
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Columna para Cuentas de Banco
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionTitle(
                                              'Cuentas de Banco'),
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 4.0, vertical: 4.0),
                                            height:
                                                150, // Ajusta la altura al tamaño deseado
                                            width: double.infinity,
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (clienteData!['cuentabanco']
                                                    is List)
                                                  for (var cuenta
                                                      in clienteData![
                                                          'cuentabanco']) ...[
                                                    _buildDetailRow(
                                                        'Banco:',
                                                        cuenta['nombreBanco'] ??
                                                            'No asignado'),
                                                    _buildDetailRow(
                                                        'Núm. de Cuenta:',
                                                        cuenta['numCuenta'] ??
                                                            'No asignado'),
                                                    _buildDetailRow(
                                                        'Núm. de Tarjeta:',
                                                        cuenta['numTarjeta'] ??
                                                            'No asignado'),
                                                    SizedBox(height: 16),
                                                  ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(width: 10),

                                    // Columna para Datos Adicionales
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionTitle(
                                              'Datos Adicionales'),
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 4.0, vertical: 4.0),
                                            height:
                                                150, // Ajusta la altura al tamaño deseado
                                            width: double.infinity,
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (clienteData!['adicionales']
                                                    is List)
                                                  for (var adicional
                                                      in clienteData![
                                                          'adicionales']) ...[
                                                    _buildDetailRow('CURP:',
                                                        adicional['curp']),
                                                    _buildDetailRow('RFC:',
                                                        adicional['rfc']),
                                                    _buildDetailRow(
                                                        'Fecha de Creación:',
                                                        adicional['fCreacion']),
                                                    SizedBox(height: 16),
                                                  ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionTitle(
                                              'Inf. del Cónyuge'),
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 4.0, vertical: 4.0),
                                            height:
                                                150, // Ajusta la altura al tamaño deseados
                                            width: double.infinity,
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildDetailRow(
                                                  'Nombre:',
                                                  clienteData != null &&
                                                          clienteData!
                                                              .containsKey(
                                                                  'nombreConyuge')
                                                      ? (clienteData!['nombreConyuge'] ==
                                                                  null ||
                                                              clienteData![
                                                                      'nombreConyuge'] ==
                                                                  "null"
                                                          ? 'No asignado'
                                                          : clienteData![
                                                              'nombreConyuge'])
                                                      : 'No asignado',
                                                ),
                                                _buildDetailRow(
                                                  'Teléfono:',
                                                  clienteData != null &&
                                                          clienteData!.containsKey(
                                                              'telefonoConyuge')
                                                      ? (clienteData!['telefonoConyuge'] ==
                                                                  null ||
                                                              clienteData![
                                                                      'telefonoConyuge'] ==
                                                                  "null"
                                                          ? 'No asignado'
                                                          : clienteData![
                                                              'telefonoConyuge'])
                                                      : 'No asignado',
                                                ),
                                                _buildDetailRow(
                                                  'Ocupacion:',
                                                  clienteData != null &&
                                                          clienteData!.containsKey(
                                                              'ocupacionConyuge')
                                                      ? (clienteData!['ocupacionConyuge'] ==
                                                                  null ||
                                                              clienteData![
                                                                      'ocupacionConyuge'] ==
                                                                  "null"
                                                          ? 'No asignado'
                                                          : clienteData![
                                                              'ocupacionConyuge'])
                                                      : 'No asignado',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 16),

                                // Sección de Domicilio ocupando ambas columnas
                                _buildSectionTitle('Domicilio'),
                                if (clienteData!['domicilios'] is List)
                                  Container(
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 4.0, vertical: 4.0),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (var domicilio
                                            in clienteData!['domicilios']) ...[
                                          _buildAddresses(domicilio),
                                          SizedBox(height: 16),
                                        ],
                                      ],
                                    ),
                                  ),
                                SizedBox(height: 16),

                                _buildSectionTitle('Ingresos y Egresos'),
                                if (clienteData!['ingresos_egresos'] is List)
                                  _buildIncomeInfo(
                                      clienteData!['ingresos_egresos']),
                                SizedBox(height: 16),
                                _buildSectionTitle('Referencias'),
                                if (clienteData!['referencias'] is List)
                                  _buildReferences(clienteData!['referencias']),
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
                        Text('Error al cargar datos del cliente'),
                        SizedBox(
                            height: 20), // Espaciado entre el texto y el botón
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading =
                                  true; // Indica que la recarga ha comenzado
                            });
                            fetchClienteData(); // Llama a la función para recargar los datos
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildIncomeInfo(List<dynamic> ingresos) {
    // Filtrar la lista para eliminar elementos nulos o vacíos
    final List<dynamic> ingresosValidos = ingresos.where((ingreso) {
      return ingreso != null &&
          (ingreso['tipo_info'] != null ||
              ingreso['años_actividad'] != null ||
              ingreso['descripcion'] != null ||
              ingreso['monto_semanal'] != null ||
              ingreso['fCreacion'] != null);
    }).toList();

    // Mostrar un mensaje si no hay ingresos válidos
    if (ingresosValidos.isEmpty) {
      return Center(
        child: Text(
          'No hay ingresos disponibles',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: ClampingScrollPhysics(),
          child: Row(
            children: ingresosValidos.map<Widget>((ingreso) {
              // Convertir el monto semanal a double si es una cadena
              double montoSemanal;
              if (ingreso['monto_semanal'] is String) {
                montoSemanal = double.tryParse(ingreso['monto_semanal']) ?? 0.0;
              } else {
                montoSemanal = ingreso['monto_semanal'] ?? 0.0;
              }

              // Formatear el monto semanal para eliminar ceros innecesarios
              String montoFormateado = montoSemanal.toString().replaceAll(RegExp(r'\.0*$'), '');

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('Tipo de Info:', ingreso['tipo_info']),
                    _buildDetailRow('Años de Actividad:', ingreso['años_actividad']),
                    _buildDetailRow('Descripción:', ingreso['descripcion']),
                    _buildDetailRow('Monto Semanal:', montoFormateado),
                    _buildDetailRow('Fecha Creación:', ingreso['fCreacion']),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          left: 0,
          top: 50,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Color(0xFF5162F6), size: 20),
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.pixels - 100,
                );
              }
            },
          ),
        ),
        Positioned(
          right: 0,
          top: 50,
          child: IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: Color(0xFF5162F6), size: 20),
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.pixels + 100,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReferences(List<dynamic> referencias) {
  final ScrollController _scrollController = ScrollController();

  // Filtrar la lista para eliminar elementos nulos o vacíos
  final List<dynamic> referenciasValidas = referencias.where((referencia) {
    return referencia != null &&
        (referencia['nombres'] != null ||
            referencia['apellidoP'] != null ||
            referencia['apellidoM'] != null ||
            referencia['parentescoRefProp'] != null ||
            referencia['telefono'] != null ||
            referencia['timepoCo'] != null ||
            (referencia['domicilio_ref'] is List &&
                referencia['domicilio_ref'].isNotEmpty));
  }).toList();

  // Mostrar un mensaje si no hay referencias válidas
  if (referenciasValidas.isEmpty) {
    return Center(
      child: Text(
        'No hay referencias disponibles',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  return Stack(
    children: [
      SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: NeverScrollableScrollPhysics(),
        child: Row(
          children: referenciasValidas.map<Widget>((referencia) {
            return Container(
              width: 650,
              margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${referencia['nombres']} ${referencia['apellidoP']} ${referencia['apellidoM']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          'Parentesco:',
                          referencia['parentescoRefProp'],
                        ),
                      ),
                      Expanded(
                        child: _buildDetailRow(
                          'Teléfono:',
                          referencia['telefono'],
                        ),
                      ),
                      Expanded(
                        child: _buildDetailRow(
                          'Tiempo de Conocer:',
                          referencia['tiempoCo'],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Domicilio',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (referencia['domicilio_ref'] is List &&
                      referencia['domicilio_ref'].isNotEmpty)
                    for (var domicilio in referencia['domicilio_ref']) ...[
                      _buildAddresses(domicilio),
                      SizedBox(height: 16),
                    ]
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'No hay domicilio para esta referencia',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      Positioned(
        left: 0,
        top: 80,
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Color(0xFF5162F6), size: 20),
          onPressed: () {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.pixels - 600,
              );
            }
          },
        ),
      ),
      Positioned(
        right: 0,
        top: 80,
        child: IconButton(
          icon: Icon(Icons.arrow_forward_ios, color: Color(0xFF5162F6), size: 20),
          onPressed: () {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.pixels + 600,
              );
            }
          },
        ),
      ),
    ],
  );
}


  Widget _buildAddresses(Map<String, dynamic> domicilio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila para los detalles básicos del domicilio
        Row(
          children: [
            SizedBox(height: 8), // Espacio debajo del título
            Expanded(
                child: _buildDetailRow(
                    'Tipo Domicilio:', domicilio['tipo_domicilio'])),
            Expanded(
                child: _buildDetailRow(
                    'Propietario:', domicilio['nombre_propietario'])),
            Expanded(
                child: _buildDetailRow('Parentesco:', domicilio['parentesco'])),
          ],
        ),
        // Fila para la dirección
        Row(
          children: [
            Expanded(child: _buildDetailRow('Calle:', domicilio['calle'])),
            Expanded(child: _buildDetailRow('Número Ext:', domicilio['nExt'])),
            Expanded(child: _buildDetailRow('Número Int:', domicilio['nInt'])),
          ],
        ),
        // Fila para la ubicación
        Row(
          children: [
            Expanded(child: _buildDetailRow('Colonia:', domicilio['colonia'])),
            Expanded(child: _buildDetailRow('Estado:', domicilio['estado'])),
            Expanded(
                child: _buildDetailRow('Municipio:', domicilio['municipio'])),
          ],
        ),
        // Fila para el código postal y tiempo de residencia
        Row(
          children: [
            Expanded(child: _buildDetailRow('Código Postal:', domicilio['cp'])),
            Expanded(
                child:
                    _buildDetailRow('Entre Calles:', domicilio['entreCalle'])),
            Expanded(
                child: _buildDetailRow(
                    'Tiempo Viviendo:', domicilio['tiempoViviendo'])),
          ],
        ),
      ],
    );
  }
}
