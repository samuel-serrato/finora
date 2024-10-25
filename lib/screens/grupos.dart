import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/screens/nGrupo.dart';
import '../widgets/CardUserWidget.dart';
import 'dart:async';
import 'dart:io';

class GruposScreen extends StatefulWidget {
  final String username; // Agregar esta línea
  const GruposScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  int selectedIndex = -1;
  //String selectedGroupType = 'Todos';

  late Timer timer;

  List<GroupType> listaTipoGrupos = [];
  List<Grupo> listaGrupos = [];
  List<Grupo> filteredGrupos = []; // Lista filtrada que se muestra en la tabla
  bool isTodosSelected = false; // Nuevo estado para el botón "Todos"

  List<bool> isSelected = [];

  bool isLoading = true;
  bool showErrorDialog = false;
  String username = '';
  String nombre = '';
  String formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
  String formattedDateTime = DateFormat('h:mm:ss a').format(DateTime.now());

  @override
  void initState() {
    super.initState();

    print('Tipo de Grupos: $listaTipoGrupos');
    print('Grupos: $listaGrupos');

    // Actualizar la fecha y la hora cada segundo
    timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      setState(() {
        formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
        formattedDateTime = DateFormat('h:mm:ss a').format(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    // Cancelar el temporizador en el método dispose()
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEFF5FD),
      body: content(),
    );
  }


  Widget content() {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      child: Column(
        children: [
          Expanded(
            flex: 15,
            child: Container(
              //color: Colors.red,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: CardUserWidget(
                      username: widget.username,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Container(
              //color: Colors.purple, // Cambia el color a tu preferencia
              child: textoyBoton(),
            ),
          ),
          Expanded(
            flex: 75,
            child: Container(
              //margin: EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.only(top: 20, left: 20),
                    //color: Colors.orange, // Cambia el color a tu preferencia
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 30),
                          child: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AddGroupDialog();
                                },
                              );
                            },
                            style: ButtonStyle(
                              surfaceTintColor:
                                  MaterialStateProperty.all<Color>(
                                Color(0xFFFB2056),
                              ),
                              shape: MaterialStateProperty.all<OutlinedBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              backgroundColor: MaterialStateProperty.all<Color>(
                                Color(0xFFFB2056),
                              ),
                              overlayColor: MaterialStateProperty.all(
                                Color.fromARGB(255, 190, 15, 59),
                              ), // Color al pasar el mouse
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 60, vertical: 10),
                              child: Text(
                                'Nuevo Grupo',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  tabla(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to build table
  Widget tabla() {
    double fontsizecell = 12;

    // Datos estáticos de ejemplo
    List<Grupo> gruposEjemplo = [
      Grupo(
          idTipoGrupo: 1,
          nombre: 'Grupo A',
          detalles: 'Detalles del Grupo A',
          fechaCreacion: '2023-06-01T12:00:00'),
      Grupo(
          idTipoGrupo: 2,
          nombre: 'Grupo B',
          detalles: 'Detalles del Grupo B',
          fechaCreacion: '2023-06-02T14:30:00'),
      Grupo(
          idTipoGrupo: 3,
          nombre: 'Grupo C',
          detalles: 'Detalles del Grupo C',
          fechaCreacion: '2023-06-03T09:15:00'),
    ];

    // Definir nombres para los tipos de grupo
    Map<int, String> nombresTiposGrupo = {
      1: 'Grupo X',
      2: 'Grupo Y',
      3: 'Grupo Z',
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 10,
                headingRowColor: MaterialStateProperty.resolveWith((states) =>
                    Color(0xFFE8EFF9)), // Color de fondo para el encabezado
                columns: const [
                  DataColumn(
                    label: Text(
                      'Tipo de Grupo',
                    ), // Color del texto
                  ),
                  DataColumn(
                    label: Text(
                      'Nombre',
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Detalles',
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Fecha de Creación',
                    ),
                  ),
                ],
                rows: gruposEjemplo.map((lg) {
                  final fechaCreacion = DateTime.parse(lg.fechaCreacion);
                  final nombreTipoGrupo =
                      nombresTiposGrupo[lg.idTipoGrupo] ?? 'Desconocido';

                  return DataRow(
                    cells: [
                      DataCell(Text(
                        nombreTipoGrupo,
                        style: TextStyle(fontSize: fontsizecell),
                      )),
                      DataCell(Text(
                        lg.nombre,
                        style: TextStyle(fontSize: fontsizecell),
                      )),
                      DataCell(Text(
                        lg.detalles,
                        style: TextStyle(fontSize: fontsizecell),
                      )),
                      DataCell(Text(
                        lg.fechaCreacion,
                        style: TextStyle(fontSize: fontsizecell),
                      )),
                    ],
                    onSelectChanged: (isSelected) {
                      // Acción al seleccionar la fila
                    },
                    color: MaterialStateColor.resolveWith(
                      (states) {
                        if (states.contains(MaterialState.selected)) {
                          return Colors.blue.withOpacity(
                              0.1); // Color azul bajito cuando está seleccionada la fila
                        } else if (states.contains(MaterialState.hovered)) {
                          return Colors.blue.withOpacity(
                              0.2); // Color azul bajito cuando el mouse está encima
                        }
                        return Colors
                            .transparent; // Color transparente cuando no se cumple ninguna condición
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget textoyBoton() {
    double maxWidth = MediaQuery.of(context).size.width * 0.35;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          //color: Colors.orange,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grupos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4.0),
            ],
          ),
        ),
        Container(
          //height: 50,
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: TextField(
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 20.0), // Ajusta el relleno interno
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide:
                      BorderSide(color: Color.fromARGB(255, 137, 192, 255))),
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              hintText: 'Buscar...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.0),
                borderSide: BorderSide.none, // Borde transparente
              ),
            ),
          ),
        ),
      ],
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
}

class GroupType {
  final int id;
  final String nombre;
  final String descripcion;
  final bool activo;

  GroupType(this.id, this.nombre, this.descripcion, this.activo);
}
