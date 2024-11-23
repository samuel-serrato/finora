import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:money_facil/dialogs/editGrupo.dart';
import 'package:money_facil/dialogs/infoGrupo.dart';
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
  Timer? _timer;
  bool errorDeConexion = false;
  bool noGroupsFound = false;

  @override
  void initState() {
    super.initState();
    obtenerGrupos();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final double textHeaderTableSize = 12.0;
  final double textTableSize = 12.0;

  Future<void> obtenerGrupos() async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noGroupsFound = false;
    });

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        final response =
            await http.get(Uri.parse('http://$baseUrl/api/v1/grupodetalles'));

        print('Status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (mounted) {
          if (response.statusCode == 200) {
            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
              isLoading = false;
              errorDeConexion = false;
            });
            _timer?.cancel();
          } else if (response.statusCode == 400) {
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] == "No hay grupos registrados") {
              setState(() {
                listaGrupos = [];
                isLoading = false;
                noGroupsFound = true;
              });
              _timer
                  ?.cancel(); // Detener intentos de reconexión si no hay grupos
            } else {
              setErrorState(dialogShown);
            }
          } else {
            setErrorState(dialogShown);
          }
        }
      } catch (e) {
        if (mounted) {
          setErrorState(dialogShown, e);
        }
      }
    }

    fetchData();

    if (!noGroupsFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noGroupsFound) {
          setState(() {
            isLoading = false;
            errorDeConexion = true;
          });
          dialogShown = true;
          mostrarDialogoError(
              'No se pudo conectar al servidor. Verifica tu red.');
        }
      });
    }
  }

  void setErrorState(bool dialogShown, [dynamic error]) {
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
      _timer?.cancel(); // Detener intentos de reconexión en caso de error
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
      backgroundColor: Color(0xFFF7F8FA),
      appBar: CustomAppBar(
        isDarkMode: _isDarkMode,
        toggleDarkMode: _toggleDarkMode,
        title: 'Clientes', // Título específico para esta pantalla
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFB2056),
              ),
            )
          : (errorDeConexion
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No hay conexión o no se pudo cargar la información. Intenta más tarde.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          obtenerGrupos();
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
/*                     Padding(
                      padding:
                          const EdgeInsets.only(top: 10, left: 20, right: 20),
                      child: Text('Aquí podrás ver los clientes'),
                    ), */
                    filaBuscarYAgregar(context),
                    listaGrupos.isEmpty
                        ? Expanded(
                            child: Center(
                              child: Text(
                                'No hay grupos para mostrar.',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          )
                        : filaTabla(
                            context), // Muestra la tabla solo si hay clientes
                  ],
                )),
    );
  }

  Widget filaBuscarYAgregar(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width * 0.35;
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 40,
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8.0)],
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
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Color(0xFFFB2056)),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            onPressed: mostrarDialogAgregarGrupo,
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
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0.5,
                  blurRadius: 5)
            ],
          ),
          child: listaGrupos.isEmpty
              ? Center(
                  child: Text(
                    'No hay grupos para mostrar.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : LayoutBuilder(builder: (context, constraints) {
                  // Filtrar los grupos con estado 'Activo'
                  var gruposActivos = listaGrupos
                      .where((grupo) => grupo.estado == 'Activo')
                      .toList();
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth, // Ocupa todo el ancho
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
                              label: Text('ID Grupo',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                              label: Text('Tipo Grupo',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                              label: Text('Nombre',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                              label: Text('Detalles',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                              label: Text('Asesor',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                              label: Text('Fecha Creación',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                            label: Text(
                              'Acciones',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            ),
                          ),
                        ],
                        rows: gruposActivos.map((grupo) {
                          return DataRow(
                            cells: [
                              DataCell(Text(grupo.idgrupos.toString(),
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(Text(grupo.tipoGrupo.toString(),
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(Text(grupo.nombreGrupo,
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(Text(grupo.detalles,
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(Text(grupo.asesor,
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(Text(formatDate(grupo.fCreacion),
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined,
                                          color: Colors.grey),
                                      onPressed: () {
                                        mostrarDialogoEditarCliente(grupo
                                            .idgrupos!); // Llama la función para editar el cliente
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.grey),
                                      onPressed: () {
                                        // Lógica para eliminar el cliente
                                        null;
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
                                  builder: (context) => InfoGrupo(
                                    idGrupo: grupo.idgrupos.toString(),
                                    nombreGrupo: grupo.nombreGrupo,
                                  ),
                                );
                              }
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
                }),
        ),
      ),
    );
  }

  void mostrarDialogAgregarGrupo() {
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

  void mostrarDialogoEditarCliente(String idGrupo) {
    showDialog(
      barrierDismissible: false, // No se puede cerrar tocando fuera
      context: context,
      builder: (context) {
        return editGrupoDialog(
          idGrupo: idGrupo, // Pasamos el idGrupo al diálogo
          onGrupoEditado: () {
            obtenerGrupos();
          },
        );
      },
    );
  }
}

class Grupo {
  final String idgrupos;
  final String tipoGrupo;
  final String nombreGrupo;
  final String detalles;
  final String asesor;
  final String fCreacion;
  final String estado; // Agregamos el campo 'estado'

  Grupo({
    required this.idgrupos,
    required this.tipoGrupo,
    required this.nombreGrupo,
    required this.detalles,
    required this.asesor,
    required this.fCreacion,
    required this.estado, // Inicializamos el campo 'estado' en el constructor
  });

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      idgrupos: json['idgrupos'],
      tipoGrupo: json['tipoGrupo'],
      nombreGrupo: json['nombreGrupo'],
      detalles: json['detalles'],
      asesor: json['asesor'],
      fCreacion: json['fCreacion'],
      estado:
          json['estado'], // Asignamos el valor del campo 'estado' desde el JSON
    );
  }
}
