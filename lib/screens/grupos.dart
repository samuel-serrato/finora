import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:money_facil/dialogs/nCliente.dart';
import 'package:money_facil/dialogs/nGrupo.dart';
import 'package:money_facil/ip.dart';

class GruposScreen extends StatefulWidget {
  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  List<Grupo> listaGrupos = [];
  bool isLoading = true;
  bool showErrorDialog = false;

  @override
  void initState() {
    super.initState();
    obtenerGrupos();
    // Datos de ejemplo para la tabla de grupos
    listaGrupos = [
      Grupo(
          idTipoGrupo: 1,
          nombre: 'Grupo Alpha',
          detalles: 'Detalles del grupo Alpha',
          fechaCreacion: '2023-10-20'),
      Grupo(
          idTipoGrupo: 2,
          nombre: 'Grupo Beta',
          detalles: 'Detalles del grupo Beta',
          fechaCreacion: '2023-09-15'),
      // Puedes agregar más grupos de ejemplo si es necesario
    ];
    isLoading = false;
  }

  // Define el tamaño de texto aquí
  final double textHeaderTableSize = 12.0;
  final double textTableSize = 10.0;

  Future<void> obtenerGrupos() async {
    try {
      final response =
          await http.get(Uri.parse('http://$baseUrl/api/v1/grupos'));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        if (mounted) {
          // Verificar si el widget está montado antes de llamar a setState()
          setState(() {
            listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          // Verificar si el widget está montado antes de llamar a setState()
          setState(() {
            showErrorDialog = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // Verificar si el widget está montado antes de llamar a setState()
        setState(() {
          showErrorDialog = true;
        });
      }
      print('Error: $e');
    }
  }

  String formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  bool _isDarkMode = false;

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
        title: 'Grupos',
      ),
      body: content(context),
    );
  }

  Widget content(BuildContext context) {
    return Column(
      children: [
        filaSearch(context),
        filaBotonAgregar(context),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8.0,
                  offset: Offset(1, 1),
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

  Widget filaBotonAgregar(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Últimos Clientes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Color(0xFFFB2056)),
            foregroundColor: MaterialStateProperty.all(Colors.white),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          onPressed: () {
            mostrarDialogoAgregarCliente();
          },
          child: Text('Agregar Grupo'),
        ),
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
                color: Colors.black.withOpacity(0.1), // Color de la sombra
                spreadRadius: 0.5, // Expansión de la sombra
                blurRadius: 5, // Difuminado de la sombra
                offset: Offset(2, 2), // Posición de la sombra
              ),
            ],
          ),
          child: Column(
            children: [
              
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
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
                              'ID Grupo',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Nombre',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Detalles',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                            DataColumn(
                                label: Text(
                              'Fecha Creación',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            )),
                          ],
                          rows: listaGrupos.map((grupo) {
                            return DataRow(
                              cells: [
                                DataCell(Text(grupo.idTipoGrupo.toString(),
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(grupo.nombre,
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(grupo.detalles,
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(formatDate(grupo.fechaCreacion),
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
      barrierDismissible: false, // Evita que se cierre al tocar fuera
      context: context,
      builder: (context) {
        return nGrupoDialog(
          onGrupoAgregado: () {
            obtenerGrupos(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }
}

class Grupo {
  final int idTipoGrupo;
  final String nombre;
  final String detalles;
  final String fechaCreacion;

  Grupo({
    required this.idTipoGrupo,
    required this.nombre,
    required this.detalles,
    required this.fechaCreacion,
  });

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      idTipoGrupo: json['idTipoGrupo'],
      nombre: json['nombre'],
      detalles: json['detalles'],
      fechaCreacion: json['fechaCreacion'],
    );
  }
}
