import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class nGrupoDialog extends StatefulWidget {
  final VoidCallback onGrupoAgregado;

  nGrupoDialog({required this.onGrupoAgregado});

  @override
  _nGrupoDialogState createState() => _nGrupoDialogState();
}

class _nGrupoDialogState extends State<nGrupoDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController nombreGrupoController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController liderGrupoController = TextEditingController();
  final TextEditingController miembrosController = TextEditingController();

  final List<Person> _selectedPersons = [];
  final TextEditingController _controller = TextEditingController();

  List<String> tiposGrupo = [
    'Grupal',
    'Individual',
    'Selecto',
  ];

  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _infoGrupoFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _miembrosFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Agregar Grupo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            TabBar(
              controller: _tabController,
              labelColor: Color(0xFFFB2056),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFFFB2056),
              tabs: [
                Tab(text: 'Información del Grupo'),
                Tab(text: 'Miembros del Grupo'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: _paginaInfoGrupo(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: _paginaMiembros(),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Cancelar'),
                ),
                Row(
                  children: [
                    if (_currentIndex > 0)
                      TextButton(
                        onPressed: () {
                          _tabController.animateTo(_currentIndex - 1);
                        },
                        child: Text('Atrás'),
                      ),
                    if (_currentIndex < 1)
                      ElevatedButton(
                        onPressed: () {
                          if (_currentIndex == 0 &&
                              _infoGrupoFormKey.currentState!.validate()) {
                            _tabController.animateTo(_currentIndex + 1);
                          }
                        },
                        child: Text('Siguiente'),
                      ),
                    if (_currentIndex == 1)
                      ElevatedButton(
                        onPressed: _agregarGrupo,
                        child: Text('Agregar'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Función que crea cada paso con el círculo y el texto
  Widget _buildPasoItem(int numeroPaso, String titulo, bool isActive) {
    return Row(
      children: [
        // Círculo numerado para el paso
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.white
                : Colors.transparent, // Fondo blanco solo si está activo
            border: Border.all(
                color: Colors.white,
                width: 2), // Borde blanco en todos los casos
          ),
          alignment: Alignment.center,
          child: Text(
            numeroPaso.toString(),
            style: TextStyle(
              color: isActive
                  ? Color(0xFFFB2056)
                  : Colors.white, // Texto rojo si está activo, blanco si no
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(width: 10),

        // Texto del paso
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _paginaInfoGrupo() {
    int pasoActual = 1; // Paso actual que queremos marcar como activo
    const double verticalSpacing = 20.0; // Variable para el espaciado vertical

    String? selectedTipo;

    return Form(
      key: _infoGrupoFormKey,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                color: Color(0xFFFB2056),
                borderRadius: BorderRadius.all(Radius.circular(20))),
            width: 250,
            height: 500,
            padding: EdgeInsets.symmetric(
                vertical: 20, horizontal: 10), // Espaciado vertical
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Paso 1
                _buildPasoItem(1, "Informacion del grupo", pasoActual == 1),
                SizedBox(height: 20),

                // Paso 2
                _buildPasoItem(2, "Integrantes del grupo", pasoActual == 2),
                SizedBox(height: 20),
              ],
            ),
          ),
          SizedBox(width: 50), // Espacio entre la columna y el formulario
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  // Contenedor circular de fondo rojo con el ícono
                  Container(
                    width: 120, // Ajustar tamaño del contenedor
                    height: 120,
                    decoration: BoxDecoration(
                      color: Color(0xFFFB2056), // Color de fondo rojo
                      shape: BoxShape.circle, // Forma circular
                    ),
                    child: Center(
                      child: Icon(
                        Icons.group,
                        size: 80, // Tamaño del ícono
                        color: Colors.white, // Color del ícono
                      ),
                    ),
                  ),
                  SizedBox(height: verticalSpacing), // Espacio debajo del ícono
                  _buildTextField(
                    controller: nombreGrupoController,
                    label: 'Nombres del grupo',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Campo requerido';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: verticalSpacing),
                  _buildDropdown(
                    value: selectedTipo,
                    hint: 'Tipo',
                    items: tiposGrupo,
                    onChanged: (value) {
                      setState(() {
                        selectedTipo = value;
                      });
                    },
                    fontSize: 14.0,
                    validator: (value) {
                      if (value == null) {
                        return 'Por favor, seleccione el tipo';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: verticalSpacing),
                  _buildTextField(
                    controller: descripcionController,
                    label: 'Descripción',
                    icon: Icons.person,
                    /*  validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Campo requerido';
                      }
                      return null;
                    }, */
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaMiembros() {
    int pasoActual = 2; // Paso actual que queremos marcar como activo

    return Form(
      key: _miembrosFormKey,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                color: Color(0xFFFB2056),
                borderRadius: BorderRadius.all(Radius.circular(20))),
            width: 250,
            height: 500,
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Paso 1
                _buildPasoItem(1, "Informacion del grupo", pasoActual == 1),
                SizedBox(height: 20),

                // Paso 2
                _buildPasoItem(2, "Integrantes del grupo", pasoActual == 2),
                SizedBox(height: 20),
              ],
            ),
          ),
          SizedBox(width: 50), // Espacio entre la columna y el formulario
          Expanded(
            child: Column(
              children: [
                TypeAheadField<Person>(
                  builder: (context, controller, focusNode) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    style: TextStyle(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Escribe para buscar',
                    ),
                  ),
                  decorationBuilder: (context, child) => Material(
                    type: MaterialType.card,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: child,
                  ),
                  suggestionsCallback: (search) async {
                    if (search.isEmpty) {
                      return [];
                    }
                    return await PersonService().find(search);
                  },
                  itemBuilder: (context, person) {
                    return ListTile(
                      title: Text(person.nombre),
                      subtitle: Text(
                          '${person.pais} - Nacimiento: ${person.fechaNacimiento}'),
                    );
                  },
                  onSelected: (person) {
                    setState(() {
                      _selectedPersons.add(person);
                    });
                    _controller.clear();
                  },
                  controller: _controller,
                  loadingBuilder: (context) => const Text('Cargando...'),
                  errorBuilder: (context, error) => const Text('Error!'),
                  emptyBuilder: (context) =>
                      const Text('No hay coincidencias!'),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _selectedPersons.length,
                    itemBuilder: (context, index) {
                      final person = _selectedPersons[index];
                      return ListTile(
                        title: Text(person.nombre),
                        subtitle: Text(
                            '${person.pais} - Nacimiento: ${person.fechaNacimiento}'),
                      );
                    },
                  ),
                ),
                // Aquí puedes añadir más campos para agregar detalles específicos de los miembros
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _agregarGrupo() {
    if (_infoGrupoFormKey.currentState!.validate() &&
        _miembrosFormKey.currentState!.validate()) {
      widget.onGrupoAgregado();
      Navigator.of(context).pop();
    }
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
  double fontSize = 12.0, // Tamaño de fuente por defecto
  int? maxLength, // Longitud máxima opcional
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    style: TextStyle(fontSize: fontSize),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(fontSize: fontSize),
    ),
    validator: validator, // Asignar el validador
    inputFormatters: maxLength != null
        ? [
            LengthLimitingTextInputFormatter(maxLength)
          ] // Limita a la longitud especificada
        : [], // Sin limitación si maxLength es null
  );
}

Widget _buildDropdown({
  required String? value,
  required String hint,
  required List<String> items,
  required void Function(String?) onChanged,
  double fontSize = 12.0,
  String? Function(String?)? validator,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    hint: value == null
        ? Text(
            hint,
            style: TextStyle(fontSize: fontSize, color: Colors.black),
          )
        : null,
    items: items.map((item) {
      return DropdownMenuItem(
        value: item,
        child: Text(
          item,
          style: TextStyle(fontSize: fontSize, color: Colors.black),
        ),
      );
    }).toList(),
    onChanged: onChanged,
    validator: validator, // Validación para el Dropdown
    decoration: InputDecoration(
      labelText: value != null ? hint : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black),
      ),
    ),
    style: TextStyle(fontSize: fontSize, color: Colors.black),
  );
}

class Person {
  final String nombre;
  final String pais;
  final String fechaNacimiento;

  Person(this.nombre, this.pais, this.fechaNacimiento);
}

class PersonService {
  Future<List<Person>> find(String query) async {
    List<Person> persons = [
      Person('Juan Pérez', 'Argentina', '1990-05-14'),
      Person('María López', 'España', '1985-08-21'),
      Person('John Smith', 'USA', '1978-12-02'),
      Person('Yuki Tanaka', 'Japón', '1992-03-15'),
    ];

    return persons
        .where((person) =>
            person.nombre.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
