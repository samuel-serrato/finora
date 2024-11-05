import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:money_facil/ip.dart';

class InfoCliente extends StatefulWidget {
  final String idCliente;

  InfoCliente({required this.idCliente});

  @override
  _InfoClienteState createState() => _InfoClienteState();
}

class _InfoClienteState extends State<InfoCliente> {
  Map<String, dynamic>? clienteData;
  bool isLoading = true;
  Timer? _timer; // Agrega el temporizador como variable de instancia
  bool dialogShown = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    _scrollController = ScrollController();
    super.initState();
    fetchClienteData();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancela el temporizador en dispose
    super.dispose();
    _scrollController.dispose(); // Asegúrate de llamar a dispose aquí
  }

  Future<void> fetchClienteData() async {
    // Configura el temporizador para mostrar un diálogo después de 10 segundos si no hay respuesta
    _timer = Timer(Duration(seconds: 10), () {
      if (mounted && !dialogShown) {
        setState(() {
          isLoading = false;
        });
        dialogShown = true;
        mostrarDialogoError(
            'No se pudo conectar al servidor. Por favor, revise su conexión de red.');
      }
    });

    try {
      final response = await http.get(
          Uri.parse('http://$baseUrl/api/v1/clientes/${widget.idCliente}'));

      if (response.statusCode == 200) {
        setState(() {
          clienteData = json.decode(response.body)[0];
          isLoading = false;
        });
        _timer
            ?.cancel(); // Cancela el temporizador al completar la carga exitosa
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
                              color: Color(0xFFFB2056),
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
                                            margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
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
                                                    _buildDetailRow('Banco:',
                                                        cuenta['nombreBanco']),
                                                    _buildDetailRow(
                                                        'Núm. de Cuenta:',
                                                        cuenta['numCuenta']),
                                                    _buildDetailRow(
                                                        'Núm. de Tarjeta:',
                                                        cuenta['numTarjeta']),
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
                                            margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
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
                                            margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
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
                                                    clienteData![
                                                        'nombreConyuge']),
                                                _buildDetailRow(
                                                    'Teléfono:',
                                                    clienteData![
                                                        'telefonoConyuge']),
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
                                    margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
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
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: ClampingScrollPhysics(), // Física adecuada para escritorio
          child: Row(
            children: ingresos.map<Widget>((ingreso) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.white, // Color de fondo
                  borderRadius: BorderRadius.circular(8), // Bordes redondeados
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 2), // Dirección de la sombra
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(
                    8.0), // Padding directamente en el Container
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min, // Permitir que se ajuste al contenido
                  children: [
                    _buildDetailRow('Tipo de Info:', ingreso['tipo_info']),
                    _buildDetailRow(
                        'Años de Actividad:', ingreso['años_actividad']),
                    _buildDetailRow('Descripción:', ingreso['descripcion']),
                    _buildDetailRow('Monto Semanal:', ingreso['monto_semanal']),
                    _buildDetailRow('Fecha Creación:', ingreso['fCreacion']),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        // Fila de iconos para deslizar
        Positioned(
          left: 0,
          top: 50, // Ajusta la posición vertical según sea necesario
          child: IconButton(
            icon:
                Icon(Icons.arrow_back_ios, color: Color(0xFFFB2056), size: 20),
            onPressed: () {
              // Desplazar a la izquierda
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.pixels -
                      100, // Desplazar 100 píxeles a la izquierda
                );
              }
            },
          ),
        ),
        Positioned(
          right: 0,
          top: 50, // Ajusta la posición vertical según sea necesario
          child: IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                color: Color(0xFFFB2056), size: 20),
            onPressed: () {
              // Desplazar a la derecha
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.pixels +
                      100, // Desplazar 100 píxeles a la derecha
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

    return Stack(
      children: [
        // Quitamos el Listener que detecta eventos de desplazamiento
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics:
              NeverScrollableScrollPhysics(), // Desactiva el scroll con mouse/trackpad
          child: Row(
            children: referencias.map<Widget>((referencia) {
              return Container(
                width:
                    650, // Establece un ancho fijo o deseado para cada referencia
                margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.white, // Color de fondo
                  borderRadius: BorderRadius.circular(8), // Bordes redondeados
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 2), // Dirección de la sombra
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16), // Padding directamente en el Container
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min, // Permitir que se ajuste al contenido
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
                            referencia['parentesco'],
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
                            referencia['timepoCo'],
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
                    if (referencia['domicilio_ref'] is List)
                      for (var domicilio in referencia['domicilio_ref']) ...[
                        _buildAddresses(domicilio),
                        SizedBox(height: 16), // Espacio entre domicilios
                      ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        // Fila de iconos para deslizar
        Positioned(
          left: 0,
          top: 80, // Ajusta la posición vertical según sea necesario
          child: IconButton(
            icon:
                Icon(Icons.arrow_back_ios, color: Color(0xFFFB2056), size: 20),
            onPressed: () {
              // Desplazar a la izquierda
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.pixels -
                      600, // Desplazar 100 píxeles a la izquierda
                );
              }
            },
          ),
        ),
        Positioned(
          right: 0,
          top: 80, // Ajusta la posición vertical según sea necesario
          child: IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                color: Color(0xFFFB2056), size: 20),
            onPressed: () {
              // Desplazar a la derecha
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.pixels +
                      600, // Desplazar 100 píxeles a la derecha
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
            Expanded(child: _buildDetailRow('Número Ext:', domicilio['next'])),
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
                    _buildDetailRow('Entre Calles:', domicilio['entrecalle'])),
            Expanded(
                child: _buildDetailRow(
                    'Tiempo Viviendo:', domicilio['tiempoViviendo'])),
          ],
        ),
      ],
    );
  }
}
