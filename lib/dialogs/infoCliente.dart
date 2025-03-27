import 'dart:async';
import 'dart:io';

import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
              });
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

  void mostrarDialogoError(String mensaje,
      {VoidCallback? onClose, bool isDarkMode = false}) {
    if (mounted) {
      showDialog(
        barrierDismissible: false,
        context: context,
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
                  if (onClose != null) onClose();
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
                              _buildDetailRowIG('',
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
                              _buildDetailRowIG('Email:',
                                  _getValidatedValue(clienteData!['email'])),
                              _buildDetailRowIG(
                                  'Estado:', clienteData!['estado'] ?? 'N/A'),
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
                                              'Cuentas de Banco', isDarkMode),
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 4.0, vertical: 4.0),
                                            height: 180,
                                            width: double.infinity,
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? Colors.grey[800]
                                                  : Colors
                                                      .white, // Fondo oscuro o claro
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isDarkMode
                                                      ? Colors.black
                                                      : Colors
                                                          .black26, // Sombra oscura o clara
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
                                                        _getValidatedValue(
                                                            cuenta[
                                                                'nombreBanco']),
                                                        isDarkMode),
                                                    _buildDetailRow(
                                                        'Núm. de Cuenta:',
                                                        _getValidatedValue(
                                                            cuenta[
                                                                'numCuenta']),
                                                        isDarkMode),
                                                    _buildDetailRow(
                                                        'CLABE Interbancaria:',
                                                        _getValidatedValue(
                                                            cuenta[
                                                                'clbIntBanc']),
                                                        isDarkMode),
                                                    _buildDetailRow(
                                                        'Núm. de Tarjeta:',
                                                        _getValidatedValue(
                                                            cuenta[
                                                                'numTarjeta']),
                                                        isDarkMode),
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
                                              'Datos Adicionales', isDarkMode),
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 4.0, vertical: 4.0),
                                            height: 180,
                                            width: double.infinity,
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? Colors.grey[800]
                                                  : Colors
                                                      .white, // Fondo oscuro o claro
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isDarkMode
                                                      ? Colors.black
                                                      : Colors
                                                          .black26, // Sombra oscura o clara
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
                                                    _buildDetailRow(
                                                        'CURP:',
                                                        adicional['curp'],
                                                        isDarkMode),
                                                    _buildDetailRow(
                                                        'RFC:',
                                                        adicional['rfc'],
                                                        isDarkMode),
                                                    _buildDetailRow(
                                                        'Fecha de Creación:',
                                                        adicional['fCreacion'],
                                                        isDarkMode),
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
                                              'Inf. del Cónyuge', isDarkMode),
                                          Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 4.0, vertical: 4.0),
                                            height: 180,
                                            width: double.infinity,
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? Colors.grey[800]
                                                  : Colors
                                                      .white, // Fondo oscuro o claro
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isDarkMode
                                                      ? Colors.black
                                                      : Colors
                                                          .black26, // Sombra oscura o clara
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
                                                  _getConyugeValue(
                                                      'nombreConyuge'), // Función para obtener el valor
                                                  isDarkMode,
                                                ),
                                                _buildDetailRow(
                                                  'Teléfono:',
                                                  _getConyugeValue(
                                                      'telefonoConyuge'), // Función para obtener el valor
                                                  isDarkMode,
                                                ),
                                                _buildDetailRow(
                                                  'Ocupacion:',
                                                  _getConyugeValue(
                                                      'ocupacionConyuge'), // Función para obtener el valor
                                                  isDarkMode,
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
                                // Sección de Domicilio
                                _buildSectionTitle('Domicilio', isDarkMode),
                                if (clienteData!['domicilios'] is List)
                                  Container(
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 4.0, vertical: 4.0),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.grey[800]
                                          : Colors
                                              .white, // Fondo oscuro o claro
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDarkMode
                                              ? Colors.black
                                              : Colors
                                                  .black26, // Sombra oscura o clara
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
                                          _buildAddresses(
                                              domicilio, isDarkMode),
                                          SizedBox(height: 16),
                                        ],
                                      ],
                                    ),
                                  ),
                                SizedBox(height: 16),
                                _buildSectionTitle(
                                    'Ingresos y Egresos', isDarkMode),
                                if (clienteData!['ingresos_egresos'] is List)
                                  _buildIncomeInfo(
                                      clienteData!['ingresos_egresos'],
                                      isDarkMode),
                                SizedBox(height: 16),
                                _buildSectionTitle('Referencias', isDarkMode),
                                if (clienteData!['referencias'] is List)
                                  _buildReferences(
                                      clienteData!['referencias'], isDarkMode),
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
                        Text(
                          'Error al cargar datos del cliente',
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
                            fetchClienteData();
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

  String _getConyugeValue(String key) {
    if (clienteData == null || !clienteData!.containsKey(key)) {
      return 'No asignado';
    }
    final value = clienteData![key];
    if (value == null ||
        value == "null" ||
        (value is String && value.isEmpty)) {
      return 'No asignado';
    }
    return value.toString(); // Asegura que el valor sea una cadena
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color:
              isDarkMode ? Colors.white : Colors.black, // Texto oscuro o claro
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String? value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        '$title $value',
        style: TextStyle(
          fontSize: 12,
          color:
              isDarkMode ? Colors.white : Colors.black, // Texto oscuro o claro
        ),
      ),
    );
  }

  Widget _buildDetailRowIG(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        '$title $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white, // Mantén el texto blanco en la columna izquierda
        ),
      ),
    );
  }

  Widget _buildIncomeInfo(List<dynamic> ingresos, bool isDarkMode) {
    final List<dynamic> ingresosValidos = ingresos.where((ingreso) {
      return ingreso != null &&
          (ingreso['tipo_info'] != null ||
              ingreso['años_actividad'] != null ||
              ingreso['descripcion'] != null ||
              ingreso['monto_semanal'] != null ||
              ingreso['fCreacion'] != null);
    }).toList();

    if (ingresosValidos.isEmpty) {
      return Center(
        child: Text(
          'No hay ingresos disponibles',
          style: TextStyle(
            fontSize: 16,
            color:
                isDarkMode ? Colors.white : Colors.grey, // Texto oscuro o claro
          ),
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
              double montoSemanal;
              if (ingreso['monto_semanal'] is String) {
                montoSemanal = double.tryParse(ingreso['monto_semanal']) ?? 0.0;
              } else {
                montoSemanal = ingreso['monto_semanal'] ?? 0.0;
              }

              String montoFormateado =
                  montoSemanal.toString().replaceAll(RegExp(r'\.0*$'), '');

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey[800]
                      : Colors.white, // Fondo oscuro o claro
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black
                          : Colors.black26, // Sombra oscura o clara
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow(
                        'Tipo de Info:', ingreso['tipo_info'], isDarkMode),
                    _buildDetailRow('Años de Actividad:',
                        ingreso['años_actividad'], isDarkMode),
                    _buildDetailRow(
                        'Descripción:', ingreso['descripcion'], isDarkMode),
                    _buildDetailRow(
                        'Monto Semanal:', montoFormateado, isDarkMode),
                    _buildDetailRow(
                        'Fecha Creación:', ingreso['fCreacion'], isDarkMode),
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
            icon:
                Icon(Icons.arrow_back_ios, color: Color(0xFF5162F6), size: 20),
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController
                    .jumpTo(_scrollController.position.pixels - 100);
              }
            },
          ),
        ),
        Positioned(
          right: 0,
          top: 50,
          child: IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                color: Color(0xFF5162F6), size: 20),
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController
                    .jumpTo(_scrollController.position.pixels + 100);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReferences(List<dynamic> referencias, bool isDarkMode) {
    final ScrollController _scrollController = ScrollController();

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

    if (referenciasValidas.isEmpty) {
      return Center(
        child: Text(
          'No hay referencias disponibles',
          style: TextStyle(
            fontSize: 16,
            color:
                isDarkMode ? Colors.white : Colors.grey, // Texto oscuro o claro
          ),
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
                  color: isDarkMode
                      ? Colors.grey[800]
                      : Colors.white, // Fondo oscuro o claro
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black
                          : Colors.black26, // Sombra oscura o clara
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
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
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black, // Texto oscuro o claro
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailRow('Parentesco:',
                              referencia['parentescoRefProp'], isDarkMode),
                        ),
                        Expanded(
                          child: _buildDetailRow(
                              'Teléfono:', referencia['telefono'], isDarkMode),
                        ),
                        Expanded(
                          child: _buildDetailRow('Tiempo de Conocer:',
                              referencia['tiempoCo'], isDarkMode),
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
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black, // Texto oscuro o claro
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (referencia['domicilio_ref'] is List &&
                        referencia['domicilio_ref'].isNotEmpty)
                      for (var domicilio in referencia['domicilio_ref']) ...[
                        _buildAddresses(domicilio, isDarkMode),
                        SizedBox(height: 16),
                      ]
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'No hay domicilio para esta referencia',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white
                                : Colors.grey, // Texto oscuro o claro
                          ),
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
            icon:
                Icon(Icons.arrow_back_ios, color: Color(0xFF5162F6), size: 20),
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController
                    .jumpTo(_scrollController.position.pixels - 600);
              }
            },
          ),
        ),
        Positioned(
          right: 0,
          top: 80,
          child: IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                color: Color(0xFF5162F6), size: 20),
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController
                    .jumpTo(_scrollController.position.pixels + 600);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddresses(Map<String, dynamic> domicilio, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(height: 8),
            Expanded(
              child: _buildDetailRow(
                  'Tipo Domicilio:', domicilio['tipo_domicilio'], isDarkMode),
            ),
            Expanded(
              child: _buildDetailRow(
                  'Propietario:', domicilio['nombre_propietario'], isDarkMode),
            ),
            Expanded(
              child: _buildDetailRow(
                  'Parentesco:', domicilio['parentesco'], isDarkMode),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
                child:
                    _buildDetailRow('Calle:', domicilio['calle'], isDarkMode)),
            Expanded(
                child: _buildDetailRow(
                    'Número Ext:', domicilio['nExt'], isDarkMode)),
            Expanded(
                child: _buildDetailRow(
                    'Número Int:', domicilio['nInt'], isDarkMode)),
          ],
        ),
        Row(
          children: [
            Expanded(
                child: _buildDetailRow(
                    'Colonia:', domicilio['colonia'], isDarkMode)),
            Expanded(
                child: _buildDetailRow(
                    'Estado:', domicilio['estado'], isDarkMode)),
            Expanded(
                child: _buildDetailRow(
                    'Municipio:', domicilio['municipio'], isDarkMode)),
          ],
        ),
        Row(
          children: [
            Expanded(
                child: _buildDetailRow(
                    'Código Postal:', domicilio['cp'], isDarkMode)),
            Expanded(
                child: _buildDetailRow(
                    'Entre Calles:', domicilio['entreCalle'], isDarkMode)),
            Expanded(
                child: _buildDetailRow('Tiempo Viviendo:',
                    domicilio['tiempoViviendo'], isDarkMode)),
          ],
        ),
      ],
    );
  }

  // Helper method to handle null and empty values
  String _getValidatedValue(dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return 'No asignado';
    }
    return value.toString();
  }
}
