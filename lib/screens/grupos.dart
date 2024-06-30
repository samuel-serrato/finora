import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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

  //LISTAS
 /*  List<Usuario> listausuarios = [];
  List<Persona> listapersonas = [];
  List<GrupoPersona> listaGrupoPersona = []; */
  List<GroupType> listaTipoGrupos = [];
  List<Grupo> listaGrupos = [];
  List<Grupo> filteredGrupos = []; // Lista filtrada que se muestra en la tabla
  bool isTodosSelected = false; // Nuevo estado para el botón "Todos"

  List<bool> isSelected = [];
  //bool _isSelected =   false; // Agregamos esta variable para controlar la selección

  //int _selectedIndex = -1; // Índice de la fila seleccionada

  //bool _isDraggableSheetOpen = false;

  bool isLoading = true;
  bool showErrorDialog = false;
  String username = '';
  String nombre = '';
  String formattedDate =
      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
  String formattedDateTime = DateFormat('h:mm:ss a').format(DateTime.now());

  @override
  void initState() {
    super.initState();

    print('Tipo de Grupos: $listaTipoGrupos');
    print('Grupos: $listaGrupos');

    // Actualizar la fecha y la hora cada segundo
    timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      setState(() {
        formattedDate =
            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
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

  // Función para actualizar la lista de grupos filtrados según el estado del botón "Todos" y botones de tipo de grupo seleccionados
  void _actualizarGruposFiltrados() {
    setState(() {
      if (isTodosSelected) {
        // Si se selecciona el botón "Todos", mostrar todos los grupos sin filtrar
        filteredGrupos = listaGrupos;
      } else {
        // Filtrar los grupos basados en el ID_TIPO_GRUPO seleccionado
        filteredGrupos = listaGrupos
            .where((grupo) => isSelected[grupo.idTipoGrupo - 1])
            .toList();
      }
    });
  }

  Widget floatingActionButton() {
    return Positioned(
      bottom: 16.0,
      right: 16.0,
      child: FloatingActionButton(
        onPressed: () {
          //_mostrarFormulariogrupos(context);
        },
        child: const Icon(Icons.add),
      ),
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
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Llamar al método para borrar el tipo de grupo seleccionado en el botón 'X'
                        buildDynamicToggleButtons(),
                        Padding(
                          padding: const EdgeInsets.only(right: 30),
                          child: ElevatedButton(
                                            onPressed: () {
                                              //_mostrarFormulariogrupos(context);
                                            },
                                            style: ButtonStyle(
                                              surfaceTintColor:
                          MaterialStateProperty.all<Color>(Color(0xFFFB2056),),
                                              shape: MaterialStateProperty.all<OutlinedBorder>(
                                                RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          
                                                ),
                                              ),
                                              backgroundColor:
                          MaterialStateProperty.all<Color>(Color(0xFFFB2056),),
                          overlayColor: MaterialStateProperty.all(
                                          Color.fromARGB(255, 190, 15, 59),
                                        ), // Color al pasar el mouse
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 60, vertical: 10),
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

  // Método para imprimir el índice seleccionado en consola
  void _printSelectedIndex(int index) {
    print("Índice seleccionado: $index");
  }

  // Método para cambiar el estado de los botones
  void _onToggle(int index) {
    _actualizarGruposFiltrados(); // Llamamos a la función para aplicar el filtro después de actualizar el estado

    setState(() {
      if (index == -1) {
        // Si se selecciona el botón "Todos", mostramos todos los grupos sin filtrar
        isTodosSelected = true;
        isSelected = List<bool>.filled(listaTipoGrupos.length, false);
        filteredGrupos = listaGrupos; // Mostrar todos los grupos sin filtrar
      } else {
        isTodosSelected = false;
        for (int buttonIndex = 0;
            buttonIndex < isSelected.length;
            buttonIndex++) {
          isSelected[buttonIndex] = buttonIndex == index;
        }
        // Filtramos los grupos basados en el ID_TIPO_GRUPO seleccionado
        filteredGrupos = listaGrupos
            .where((grupo) => isSelected[grupo.idTipoGrupo - 1])
            .toList();
      }
    });
    print('Grupos Filtrados: $filteredGrupos');
    _actualizarGruposFiltrados(); // Llamamos a la función para aplicar el filtro después de actualizar el estado
  }

  // Function to build dynamic ToggleButtons
  Widget buildDynamicToggleButtons() {
    return Expanded(
      child: Flex(
        direction: Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: ElevatedButton(
              onPressed: () =>
                  _onToggle(-1), // Usamos -1 para representar el botón "Todos"
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isTodosSelected ? Color(0xFF001D82) : Colors.white,
                foregroundColor:
                    isTodosSelected ? Colors.white : Color(0xFF001D82),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  side: BorderSide(
                    color: Color(0xFF001D82),
                    width: 1.0,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: Text(
                  'Todos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ToggleButtons(
                isSelected: isSelected,
                onPressed: (index) {
                  _onToggle(index);
                  _printSelectedIndex(index); // Imprimir el índice seleccionado
                },
                selectedColor: Colors.white,
                fillColor: Color(0xFF001D82),
                color: Color(0xFF001D82),
                borderRadius: BorderRadius.circular(20.0),
                constraints: BoxConstraints(minHeight: 36.0, minWidth: 80.0),
                children: List<Widget>.generate(
                  listaTipoGrupos.length,
                  (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        listaTipoGrupos[index].nombre,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
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
    Grupo(idTipoGrupo: 1, nombre: 'Grupo A', detalles: 'Detalles del Grupo A', fechaCreacion: '2023-06-01T12:00:00'),
    Grupo(idTipoGrupo: 2, nombre: 'Grupo B', detalles: 'Detalles del Grupo B', fechaCreacion: '2023-06-02T14:30:00'),
    Grupo(idTipoGrupo: 3, nombre: 'Grupo C', detalles: 'Detalles del Grupo C', fechaCreacion: '2023-06-03T09:15:00'),
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
              columns: const [
                DataColumn(
                  label: Text('Tipo de Grupo',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('Nombre',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('Detalles',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('Fecha de Creación',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              rows: gruposEjemplo.map((lg) {
                final fechaCreacion = DateTime.parse(lg.fechaCreacion);
                final nombreTipoGrupo = nombresTiposGrupo[lg.idTipoGrupo] ?? 'Desconocido';

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
                      return Colors.transparent; // Color transparente cuando no se cumple ninguna condición
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
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0), // Ajusta el relleno interno
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

