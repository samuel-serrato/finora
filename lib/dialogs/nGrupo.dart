import 'package:flutter/material.dart';

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
    final height = MediaQuery.of(context).size.height * 0.7;

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
            child: Column(
              children: [
                TextFormField(
                  controller: nombreGrupoController,
                  decoration: InputDecoration(labelText: 'Nombre del Grupo'),
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                ),
                TextFormField(
                  controller: descripcionController,
                  decoration: InputDecoration(labelText: 'Descripción'),
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                ),
                TextFormField(
                  controller: liderGrupoController,
                  decoration: InputDecoration(labelText: 'Líder del Grupo'),
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                ),
              ],
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
            child: Column(
              children: [
                TextFormField(
                  controller: miembrosController,
                  decoration: InputDecoration(labelText: 'Miembros del Grupo'),
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                ),
                // Puedes añadir más campos para agregar detalles específicos de los miembros
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
