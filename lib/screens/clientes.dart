import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:money_facil/dialogs/nCliente.dart';

class ClientesScreen extends StatefulWidget {
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> listaClientes = [];
  bool isLoading = true;
  bool showErrorDialog = false;

  @override
  void initState() {
    super.initState();
    obtenerClientes();
  }

  // Define el tamaño de texto aquí
  final double textHeaderTableSize = 12.0;
  final double textTableSize = 10.0; // Tamaño de texto más pequeño

  Future<void> obtenerClientes() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.0.108:3000/api/v1/clientes'));

      print('Response status: ${response.statusCode}');
      print(
          'Response body: ${response.body}'); // Agregar esta línea para verificar la respuesta

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          listaClientes = data.map((item) => Cliente.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          showErrorDialog = true;
        });
      }
    } catch (e) {
      setState(() {
        showErrorDialog = true;
      });
      print('Error: $e'); // Mostrar el error en caso de excepción
    }
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
      backgroundColor: Color(0xFFf7f8fa),
      appBar: CustomAppBar(
        isDarkMode: _isDarkMode,
        toggleDarkMode: _toggleDarkMode,
        title: 'Clientes', // Título específico para esta pantalla
      ),
      body: content(context),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection:
                          Axis.vertical, // Permitir desplazamiento vertical
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints
                              .maxWidth, // Asegurar que la tabla ocupe todo el ancho
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingRowColor: MaterialStateProperty.resolveWith(
                              (states) => Color(0xFFDFE7F5)),
                          dataRowHeight: 50,
                          columnSpacing: 30,
                          headingTextStyle: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.black),
                          columns: [
                            DataColumn(
                                label: Text(
                              'ID',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Tipo Cliente',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Nombres',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Apellido P',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Apellido M',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'F. Nac',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Sexo',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Teléfono',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Email',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'E. Civil',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'F. Creación',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                          ],
                          rows: listaClientes.map((cliente) {
                            return DataRow(
                              cells: [
                                DataCell(Text(cliente.idclientes ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(cliente.tipoclientes ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(cliente.nombres ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(cliente.apellidoP ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(cliente.apellidoM ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(
                                    formatDate(cliente.fechaNac) ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(cliente.sexo ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(cliente.telefono ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(cliente.email ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(cliente.eCilvi ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(
                                    formatDate(cliente.fCreacion) ?? 'N/A',
                                    style: TextStyle(fontSize: textTableSize))),
                              ],
                              onSelectChanged: (isSelected) {
                                setState(() {
                                  // Lógica para manejar la selección de fila
                                });
                              },
                              color: MaterialStateColor.resolveWith((states) {
                                if (states.contains(MaterialState.selected)) {
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
