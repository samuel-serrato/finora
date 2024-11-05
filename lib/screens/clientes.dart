import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:money_facil/dialogs/infoCliente.dart';
import 'package:money_facil/dialogs/nCliente.dart';
import 'dart:async';

import 'package:money_facil/ip.dart';

class ClientesScreen extends StatefulWidget {
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> listaClientes = [];
  bool isLoading = true;
  bool showErrorDialog = false;
  Timer? _timer; // Usar un Timer que se pueda cancelar

  @override
  void initState() {
    super.initState();
    obtenerClientes();
  }

  // Define el tamaño de texto aquí
  final double textHeaderTableSize = 12.0;
  final double textTableSize = 12.0; // Tamaño de texto más pequeño

  @override
  void dispose() {
    print('dispose() called: Cancelling timer if it exists');
    _timer?.cancel(); // Cancelar el timer si existe
    super.dispose();
  }

  Future<void> obtenerClientes() async {
    print('obtenerClientes() called');
    setState(() {
      isLoading = true;
    });

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        print('Fetching data...');
        final response =
            await http.get(Uri.parse('http://$baseUrl/api/v1/clientes'));
        if (mounted) {
          print('Response received: ${response.statusCode}');
          if (response.statusCode == 200) {
            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaClientes =
                  data.map((item) => Cliente.fromJson(item)).toList();
              isLoading = false;
              print('Data successfully loaded: ${listaClientes.length} items');
            });
            _timer?.cancel();
            print('Timer cancelled after successful data load');
          } else {
            setState(() {
              isLoading = false;
              print('Error loading data: ${response.statusCode}');
            });
            if (!dialogShown) {
              dialogShown = true;
              mostrarDialogoError(
                  'Error en la carga de datos. Código de error: ${response.statusCode}');
            }
          }
        }
      } catch (e) {
        if (mounted) {
          print('Exception caught: $e');
          setState(() {
            isLoading = false;
          });
          if (!dialogShown) {
            dialogShown = true;
            if (e is SocketException) {
              mostrarDialogoError(
                  'Error de conexión. No se puede acceder al servidor. Verifica tu red.');
            } else {
              mostrarDialogoError('Ocurrió un error inesperado: $e');
            }
          }
        }
      }
    }

    // Ejecuta la función de búsqueda de datos
    fetchData();

    // Configurar un temporizador para mostrar el diálogo si no hay respuesta
    _timer = Timer(Duration(seconds: 10), () {
      if (mounted && !dialogShown) {
        print('10 seconds elapsed: Showing timeout dialog');
        setState(() {
          isLoading = false;
        });
        dialogShown = true;
        mostrarDialogoError(
            'No se pudo conectar al servidor. Por favor, revise su conexión de red.');
      } else {
        print('Timer cancelled or dialog already shown before 10 seconds');
      }
    });
  }

// Función para mostrar el diálogo de error
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

  String formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  bool _isDarkMode = false; // Estado del modo oscuro

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      appBar: CustomAppBar(
        isDarkMode: _isDarkMode,
        toggleDarkMode: _toggleDarkMode,
        title: 'Clientes', // Título específico para esta pantalla
      ),
      body: isLoading // Si isLoading es true, muestra el indicador
          ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFB2056),
              ),
            )
          : (listaClientes
                  .isEmpty // Verifica si la lista de clientes está vacía
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No hay conexión o no se pudo cargar la información. Intenta más tarde.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                          height: 20), // Espaciado entre el texto y el botón
                      ElevatedButton(
                        onPressed: () {
                          obtenerClientes(); // Llama a la función para recargar los datos
                        },
                        child: Text('Recargar'),
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Color(0xFFFB2056)),
                          foregroundColor:
                              MaterialStateProperty.all(Colors.white),
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : content(context)), // Si hay clientes, muestra el contenido
    );
  }

  Widget content(BuildContext context) {
    return Column(
      children: [
        filaSearch(context),
        filaTabla(context),
      ],
    );
  }

  Widget filaSearch(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width * 0.35;
    return Container(
      padding: EdgeInsets.only(top: 10, bottom: 0, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(
            height: 40,
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: Colors.white, // Fondo blanco del TextField
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8.0,
                  offset: Offset(
                      1, 1), // Cambia estos valores para ajustar la dirección
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide:
                      BorderSide(color: Color.fromARGB(255, 137, 192, 255)),
                ),
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget filaTabla(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 0.5,
                blurRadius: 5,
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Últimos Clientes',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Color(0xFFFB2056)),
                        foregroundColor:
                            MaterialStateProperty.all(Colors.white),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      onPressed: () {
                        mostrarDialogoAgregarCliente();
                      },
                      child: Text('Agregar Clientes'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: listaClientes.isEmpty
                    ? Center(
                        child: Text(
                          'No hay clientes para mostrar.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                showCheckboxColumn: false,
                                headingRowColor:
                                    MaterialStateProperty.resolveWith(
                                        (states) => Color(0xFFDFE7F5)),
                                dataRowHeight: 50,
                                columnSpacing: 30,
                                headingTextStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Tipo Cliente',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Nombre',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'F. Nac',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Sexo',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Teléfono',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Email',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'E. Civil',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'F. Creación',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Acciones',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize),
                                    ),
                                  ),
                                ],
                                rows: listaClientes.map((cliente) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                          cliente.tipoclientes ?? 'N/A',
                                          style: TextStyle(
                                              fontSize: textTableSize))),
                                      DataCell(
                                        Text(
                                          '${cliente.nombres ?? 'N/A'} ${cliente.apellidoP ?? 'N/A'} ${cliente.apellidoM ?? 'N/A'}',
                                          style: TextStyle(
                                              fontSize: textTableSize),
                                        ),
                                      ),
                                      DataCell(Text(
                                          formatDate(cliente.fechaNac) ?? 'N/A',
                                          style: TextStyle(
                                              fontSize: textTableSize))),
                                      DataCell(Text(cliente.sexo ?? 'N/A',
                                          style: TextStyle(
                                              fontSize: textTableSize))),
                                      DataCell(Text(cliente.telefono ?? 'N /A',
                                          style: TextStyle(
                                              fontSize: textTableSize))),
                                      DataCell(Text(cliente.email ?? 'N/A',
                                          style: TextStyle(
                                              fontSize: textTableSize))),
                                      DataCell(Text(cliente.eCilvi ?? 'N/A',
                                          style: TextStyle(
                                              fontSize: textTableSize))),
                                      DataCell(Text(
                                          formatDate(cliente.fCreacion) ??
                                              'N/A',
                                          style: TextStyle(
                                              fontSize: textTableSize))),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit_outlined,
                                                  color: Colors.grey),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      nClienteDialog(
                                                    idCliente: cliente
                                                        .idclientes, // Solo pasas el id del cliente
                                                  ),
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline,
                                                  color: Colors.grey),
                                              onPressed: () {
                                                // Lógica para eliminar el cliente
                                                //seliminarCliente(cliente.idclientes!);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelectChanged: (isSelected) {
                                      if (isSelected!) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => InfoCliente(
                                              idCliente: cliente.idclientes!),
                                        );
                                      }
                                    },
                                    color: MaterialStateColor.resolveWith(
                                        (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.blue.withOpacity(0.1);
                                      } else if (states
                                          .contains(MaterialState.hovered)) {
                                        return Colors.blue.withOpacity(0.2);
                                      }
                                      return Colors.transparent;
                                    }),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void mostrarDialogoAgregarCliente() {
    showDialog(
      barrierDismissible: false, // No se puede cerrar tocando fuera
      context: context,
      builder: (context) {
        return nClienteDialog(
          onClienteAgregado: () {
            obtenerClientes(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }
}

class Cliente {
  final String idclientes;
  final String tipoclientes;
  final String? nombres; // Cambiar a String?
  final String? apellidoP; // Cambiar a String?
  final String? apellidoM; // Cambiar a String?
  final String fechaNac;
  final String sexo;
  final String? telefono; // Cambiar a String?
  final String? email; // Cambiar a String?
  final String eCilvi;
  final String fCreacion;

  Cliente({
    required this.idclientes,
    required this.tipoclientes,
    this.nombres,
    this.apellidoP,
    this.apellidoM,
    required this.fechaNac,
    required this.sexo,
    this.telefono,
    this.email,
    required this.eCilvi,
    required this.fCreacion,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      idclientes: json['idclientes'],
      tipoclientes: json['tipo_cliente'],
      nombres: json['nombres'] ?? 'N/A', // Proveer 'N/A' si es null
      apellidoP: json['apellidoP'] ?? 'N/A', // Proveer 'N/A' si es null
      apellidoM: json['apellidoM'] ?? 'N/A', // Proveer 'N/A' si es null
      fechaNac: json['fechaNac'],
      sexo: json['sexo'],
      telefono: json['telefono'] ?? 'N/A', // Proveer 'N/A' si es null
      email: json['email'] ?? 'N/A', // Proveer 'N/A' si es null
      eCilvi: json['eCivil'],
      fCreacion: json['fCreacion'],
    );
  }
}
