import 'dart:convert';

import 'package:flutter/material.dart';

class nClienteDialog extends StatefulWidget {
  final VoidCallback onClienteAgregado;

  nClienteDialog({required this.onClienteAgregado});

  @override
  _nClienteDialogState createState() => _nClienteDialogState();
}

class _nClienteDialogState extends State<nClienteDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController nombresController = TextEditingController();
  final TextEditingController apellidoPController = TextEditingController();
  final TextEditingController apellidoMController = TextEditingController();
  final TextEditingController calleController = TextEditingController();
  final TextEditingController entreCalleController = TextEditingController();
  final TextEditingController coloniaController = TextEditingController();
  final TextEditingController cpController = TextEditingController();
  final TextEditingController nExtController = TextEditingController();
  final TextEditingController nIntController = TextEditingController();
  final TextEditingController estadoController = TextEditingController();
  final TextEditingController municipioController = TextEditingController();
  final TextEditingController curpController = TextEditingController();
  final TextEditingController rfcController = TextEditingController();
  final TextEditingController tiempoViviendoController =
      TextEditingController();
  final TextEditingController emailClientecontroller = TextEditingController();
  final TextEditingController telefonoClienteController =
      TextEditingController();

  String? selectedSexo;
  String? selectedECivil;
  String? selectedTipoCliente;
  DateTime? selectedDate;

  final List<String> sexos = ['Masculino', 'Femenino'];
  final List<String> estadosCiviles = [
    'Soltero',
    'Casado',
    'Divorciado',
    'Viudo'
  ];
  final List<String> tiposClientes = [
    'Asalariado',
    'Independiente',
    'Jubilado'
  ];
  final List<Map<String, dynamic>> ingresosEgresos = [];

  List<Map<String, String>> referencias =
      []; // Lista para almacenar referencias

  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _personalFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _ingresosEgresosFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _referenciasFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Agregar Cliente',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            IgnorePointer(
              child: TabBar(
                controller: _tabController,
                labelColor: Color(0xFFFB2056),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFFFB2056),
                tabs: [
                  Tab(text: 'Información Personal'),
                  Tab(text: 'Ingresos y Egresos'),
                  Tab(text: 'Referencias'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 30, top: 10, bottom: 10, left: 0),
                    child: _paginaInfoPersonal(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 30, top: 10, bottom: 10, left: 0),
                    child: _paginaIngresosEgresos(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 30, top: 10, bottom: 10, left: 0),
                    child: _paginaReferencias(),
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
                    if (_currentIndex < 2)
                      ElevatedButton(
                        onPressed: () {
                          // Validar según el índice actual
                          if (_currentIndex == 0 &&
                              _personalFormKey.currentState!.validate()) {
                            _tabController.animateTo(_currentIndex + 1);
                          } else if (_currentIndex == 1 &&
                              _ingresosEgresosFormKey.currentState!
                                  .validate()) {
                            _tabController.animateTo(_currentIndex + 1);
                          }
                        },
                        child: Text('Siguiente'),
                      ),
                    if (_currentIndex == 2)
                      ElevatedButton(
                        onPressed: _agregarCliente,
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

  Widget _paginaInfoPersonal() {
    const double verticalSpacing = 20.0; // Variable para el espaciado vertical
    //const double fontSize = 12.0; // Tamaño de fuente más pequeño
    int pasoActual = 1; // Paso actual que queremos marcar como activo

    return Form(
      key: _personalFormKey, // Asignar la clave al formulario
      child: Row(
        children: [
          // Columna a la izquierda con el círculo y el ícono
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
                _buildPasoItem(1, "Información Personal", pasoActual == 1),
                SizedBox(height: 20),

                // Paso 2
                _buildPasoItem(2, "Ingresos y Egresos", pasoActual == 2),
                SizedBox(height: 20),

                // Paso 3
                _buildPasoItem(3, "Referencias", pasoActual == 3),
              ],
            ),
          ),
          SizedBox(width: 50), // Espacio entre la columna y el formulario

          // Columna con el formulario
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Alinear el texto a la izquierda
                children: [
                  SizedBox(height: verticalSpacing),

                  // Sección de Datos Personales
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      'Información Básica',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: nombresController,
                          label: 'Nombres',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese nombres';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: apellidoPController,
                          label: 'Apellido Paterno',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Apellido Paterno';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: apellidoMController,
                          label: 'Apellido Materno',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Apellido Materno';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),

                  // Agrupamos Dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: selectedTipoCliente,
                          hint: 'Tipo de Cliente',
                          items: tiposClientes,
                          onChanged: (value) {
                            setState(() {
                              selectedTipoCliente = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, seleccione el Tipo de Cliente';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          value: selectedSexo,
                          hint: 'Sexo',
                          items: sexos,
                          onChanged: (value) {
                            setState(() {
                              selectedSexo = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, seleccione el Sexo';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),

                  // Agrupamos Estado Civil y Fecha de Nacimiento
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: selectedECivil,
                          hint: 'Estado Civil',
                          items: estadosCiviles,
                          onChanged: (value) {
                            setState(() {
                              selectedECivil = value;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 50, // Disminuir altura
                          color: Colors.transparent,
                          child: TextButton(
                            onPressed: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  selectedDate = pickedDate;
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 10), // Disminuir padding
                              side: BorderSide(
                                  color: Colors.grey.shade800, width: 1.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                selectedDate != null
                                    ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                                    : 'Selecciona una fecha de nacimiento',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: selectedDate != null
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: telefonoClienteController,
                          label: 'Teléfono',
                          icon: Icons.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese el teléfono';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: emailClientecontroller,
                          label: 'Correo electróncio',
                          icon: Icons.email,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese el correo electrónico';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  // Sección de Domicilio
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      'Domicilio',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Agrupamos Calle, No. Ext y No. Int
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildTextField(
                          controller: calleController,
                          label: 'Calle',
                          icon: Icons.location_on,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Calle';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: nExtController,
                          label: 'No. Ext',
                          icon: Icons.house,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese No. Ext';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: nIntController,
                          label: 'No. Int',
                          icon: Icons.house,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese No. Int';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),

                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildTextField(
                          controller: entreCalleController,
                          label: 'Entre Calle',
                          icon: Icons.location_on,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Entre Calle';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: cpController,
                          label: 'Código Postal',
                          icon: Icons.mail,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Código Postal';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: tiempoViviendoController,
                          label: 'Tiempo Viviendo',
                          icon: Icons.timelapse,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Tiempo Viviendo';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),

                  // Agrupamos Colonia, Estado y Municipio
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: coloniaController,
                          label: 'Colonia',
                          icon: Icons.location_city,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Colonia';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          value: estadoController.text.isNotEmpty
                              ? estadoController.text
                              : null,
                          hint: 'Estado',
                          items: ['Guerrero'],
                          onChanged: (newValue) {
                            if (newValue != null) {
                              estadoController.text =
                                  newValue; // Actualiza el controlador
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, seleccione el estado';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: municipioController,
                          label: 'Municipio',
                          icon: Icons.map,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Municipio';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      'Datos adicionales',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Agrupamos Calle, No. Ext y No. Int
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: curpController,
                          label: 'CURP',
                          icon: Icons
                              .account_box, // Ícono de identificación más relevante
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese CURP';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: rfcController,
                          label: 'RFC',
                          icon: Icons
                              .assignment_ind, // Ícono de archivo/identificación
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese RFC';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaIngresosEgresos() {
    int pasoActual = 2; // Paso actual en la página de "Ingresos y Egresos"

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contenedor azul a la izquierda para los pasos
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
              _buildPasoItem(1, "Información Personal", pasoActual == 1),
              SizedBox(height: 20),

              // Paso 2
              _buildPasoItem(2, "Ingresos y Egresos", pasoActual == 2),
              SizedBox(height: 20),

              // Paso 3
              _buildPasoItem(3, "Referencias", pasoActual == 3),
            ],
          ),
        ),
        SizedBox(width: 50), // Espacio entre el contenedor azul y la lista

        // Contenido principal: Lista de ingresos y egresos
        Expanded(
          child: Form(
            // Asegúrate de envolver esto en un Form
            key: _ingresosEgresosFormKey, // Usar el GlobalKey aquí
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: ingresosEgresos.length,
                    itemBuilder: (context, index) {
                      final item = ingresosEgresos[index];
                      return ListTile(
                        title: Text(item['descripcion']),
                        subtitle: Text('${item['tipo']} - \$${item['monto']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _mostrarDialogIngresoEgreso(
                                  index: index, item: item),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  ingresosEgresos.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _mostrarDialogIngresoEgreso(),
                  child: Text('Añadir Ingreso/Egreso'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paginaReferencias() {
    int pasoActual = 3; // Paso actual en la página de "Ingresos y Egresos"

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFFB2056),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          width: 250,
          height: 500,
          padding: EdgeInsets.symmetric(
              vertical: 20, horizontal: 10), // Espaciado vertical
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Paso 1
              _buildPasoItem(1, "Información Personal", pasoActual == 1),
              SizedBox(height: 20),

              // Paso 2
              _buildPasoItem(2, "Ingresos y Egresos", pasoActual == 2),
              SizedBox(height: 20),

              // Paso 3
              _buildPasoItem(3, "Referencias", pasoActual == 3),
            ],
          ),
        ),
        SizedBox(width: 50), // Espacio entre el contenedor rojo y la lista
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: referencias.length,
                  itemBuilder: (context, index) {
                    final referencia = referencias[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      child: ListTile(
                        title: Text(
                          '${referencia['nombres']} ${referencia['apellidoP']} ${referencia['apellidoM']}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Parentesco: ${referencia['parentesco']}'),
                            Text('Teléfono: ${referencia['telefono']}'),
                            Text(
                                'Tiempo de conocer: ${referencia['tiempoConocer']}'),
                            Text('Calle: ${referencia['calle']}'),
                            Text('Num Ext: ${referencia['nExt']}'),
                            Text('Num Ext: ${referencia['nInt']}'),
                            Text('Entre calles: ${referencia['entreCalle']}'),
                            Text('Colonia: ${referencia['colonia']}'),
                            Text('CP: ${referencia['cp']}'),
                            Text('Estado: ${referencia['estado']}'),
                            Text('Municipio: ${referencia['municipio']}'),
                            Text(
                                'Tiempo viviendo: ${referencia['tiempoViviendo']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _mostrarDialogReferencia(
                                  index: index, item: referencia),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  referencias.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                margin: EdgeInsets.only(top: 10),
                child: ElevatedButton(
                  onPressed: _mostrarDialogReferencia,
                  child: Text('Añadir Referencia'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _mostrarDialogReferencia({int? index, Map<String, dynamic>? item}) {
// Asignación inicial para dropdowns
    String? selectedParentesco = item?['parentesco'];

    final tiempoConocerController =
        TextEditingController(text: item?['tiempoConocer'] ?? '');
    final tiempoViviendoController =
        TextEditingController(text: item?['tiempoViviendo'] ?? '');
    final nombresController =
        TextEditingController(text: item?['nombres'] ?? '');
    final apellidoPController =
        TextEditingController(text: item?['apellidoP'] ?? '');
    final apellidoMController =
        TextEditingController(text: item?['apellidoM'] ?? '');

    final telefonoController =
        TextEditingController(text: item?['telefono'] ?? '');

    final calleController = TextEditingController(text: item?['calle'] ?? '');
    final entreCalleController =
        TextEditingController(text: item?['entreCalle'] ?? '');
    final coloniaController =
        TextEditingController(text: item?['colonia'] ?? '');
    final cpController = TextEditingController(text: item?['cp'] ?? '');
    final nExtController = TextEditingController(text: item?['nExt'] ?? '');
    final nIntController = TextEditingController(text: item?['nInt'] ?? '');
    final estadoController = TextEditingController(text: item?['estado'] ?? '');
    final municipioController =
        TextEditingController(text: item?['municipio'] ?? '');

    final width = MediaQuery.of(context).size.width * 0.7;
    final height = MediaQuery.of(context).size.height * 0.6;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        title: Center(
          child: Text(
            index == null ? 'Nueva Referencia' : 'Editar Referencia',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        content: Container(
          width: width,
          height: height,
          child: SingleChildScrollView(
            child: Form(
              key: _referenciasFormKey, // Asigna la clave al formulario
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información de la persona de referencia',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Divider(color: Colors.grey[300]),
                          SizedBox(height: 10),
                          _buildTextField(
                            controller: nombresController,
                            label: 'Nombres',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese su nombre';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          _buildTextField(
                            controller: apellidoPController,
                            label: 'Apellido Paterno',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese su apellido paterno';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          _buildTextField(
                            controller: apellidoMController,
                            label: 'Apellido Materno',
                            icon: Icons.person_outline,
                          ),
                          SizedBox(height: 10),
                          _buildDropdown(
                            value: selectedParentesco,
                            hint: 'Parentesco',
                            items: [
                              'Padre',
                              'Madre',
                              'Hermano/a',
                              'Amigo/a',
                              'Veceino',
                              'Otro'
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedParentesco = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, seleccione el parentesco';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          _buildTextField(
                            controller: telefonoController,
                            label: 'Teléfono',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese su teléfono';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          _buildTextField(
                            controller: tiempoConocerController,
                            label: 'Tiempo de conocer',
                            icon: Icons.timelapse_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese el tiempo de conocer';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Datos del domicilio de la referencia',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Divider(color: Colors.grey[300]),
                          SizedBox(height: 10),
                          _buildTextField(
                            controller: calleController,
                            label: 'Calle',
                            icon: Icons.location_on,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese la calle';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: nExtController,
                                  label: 'Núm. Ext',
                                  icon: Icons.house,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, ingrese el número exterior';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: nIntController,
                                  label: 'Núm. Int',
                                  icon: Icons.house,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, ingrese el número interior';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          _buildTextField(
                            controller: entreCalleController,
                            label: 'Entre Calle',
                            icon: Icons.location_on,
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: coloniaController,
                                  label: 'Colonia',
                                  icon: Icons.location_city,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, ingrese la colonia';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: cpController,
                                  label: 'Código Postal',
                                  icon: Icons.mail,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, ingrese el código postal';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  value: estadoController.text.isNotEmpty
                                      ? estadoController.text
                                      : null,
                                  hint: 'Estado',
                                  items: ['Guerrero'],
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      estadoController.text =
                                          newValue; // Actualiza el controlador
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, seleccione el estado';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: municipioController,
                                  label: 'Municipio',
                                  icon: Icons.map,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, ingrese el municipio';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          _buildTextField(
                            controller: tiempoViviendoController,
                            label: 'Tiempo viviendo',
                            icon: Icons.access_time,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese el tiempo viviendo';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_referenciasFormKey.currentState!.validate()) {
                setState(() {
                  Map<String, String> nuevaReferencia = {
                    'nombres': nombresController.text.isNotEmpty
                        ? nombresController.text
                        : '',
                    'apellidoP': apellidoPController.text.isNotEmpty
                        ? apellidoPController.text
                        : '',
                    'apellidoM': apellidoMController.text.isNotEmpty
                        ? apellidoMController.text
                        : '',
                    'parentesco': selectedParentesco ??
                        '', // Proporciona un valor por defecto
                    'telefono': telefonoController.text.isNotEmpty
                        ? telefonoController.text
                        : '',
                    'tiempoConocer': tiempoConocerController.text.isNotEmpty
                        ? tiempoConocerController.text
                        : '',
                    'calle': calleController.text.isNotEmpty
                        ? calleController.text
                        : '',
                    'entreCalle': entreCalleController.text.isNotEmpty
                        ? entreCalleController.text
                        : '',
                    'colonia': coloniaController.text.isNotEmpty
                        ? coloniaController.text
                        : '',
                    'cp': cpController.text.isNotEmpty ? cpController.text : '',
                    'nExt': nExtController.text.isNotEmpty
                        ? nExtController.text
                        : '',
                    'nInt': nIntController.text.isNotEmpty
                        ? nIntController.text
                        : '',
                    'estado': estadoController.text.isNotEmpty
                        ? estadoController.text
                        : '',
                    'municipio': municipioController.text.isNotEmpty
                        ? municipioController.text
                        : '',
                    'tiempoViviendo': tiempoViviendoController.text.isNotEmpty
                        ? tiempoViviendoController.text
                        : '',
                  };

                  if (index == null) {
                    referencias.add(nuevaReferencia);
                  } else {
                    referencias[index] = nuevaReferencia;
                  }
                });
                Navigator.pop(context);
              }
            },
            child: Text(index == null ? 'Añadir' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogIngresoEgreso({int? index, Map<String, dynamic>? item}) {
    String? selectedTipo = item?['tipo'];
    final descripcionController =
        TextEditingController(text: item?['descripcion'] ?? '');
    final montoController =
        TextEditingController(text: item?['monto']?.toString() ?? '');

    // Crea un nuevo GlobalKey para el formulario del diálogo
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    final width = MediaQuery.of(context).size.width * 0.4;
    final height = MediaQuery.of(context).size.height * 0.5;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            index == null ? 'Nuevo Ingreso/Egreso' : 'Editar Ingreso/Egreso'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              width: width,
              height: height,
              child: Form(
                key: dialogFormKey, // Usar el nuevo GlobalKey aquí
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdown(
                      value: selectedTipo,
                      hint: 'Tipo',
                      items: ['Ingreso', 'Egreso'],
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
                    SizedBox(height: 10),
                    _buildTextField(
                      controller: descripcionController,
                      label: 'Descripción',
                      icon: Icons.description,
                      fontSize: 14.0,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese una descripción';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    _buildTextField(
                      controller: montoController,
                      label: 'Monto',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      fontSize: 14.0,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese el monto';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'Ingrese un monto válido';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Valida el formulario antes de continuar
              if (dialogFormKey.currentState!.validate() &&
                  selectedTipo != null) {
                final nuevoItem = {
                  'tipo': selectedTipo,
                  'descripcion': descripcionController.text,
                  'monto': montoController.text,
                };
                setState(() {
                  if (index == null) {
                    ingresosEgresos.add(nuevoItem);
                  } else {
                    ingresosEgresos[index] = nuevoItem;
                  }
                });
                Navigator.pop(context);
              }
            },
            child: Text(index == null ? 'Añadir' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    double fontSize = 12.0, // Tamaño de fuente por defecto
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

  void _agregarCliente() {
  final datosCliente = {
    "InformacionPersonal": {
      "nombres": nombresController.text,
      "apellidoPaterno": apellidoPController.text,
      "apellidoMaterno": apellidoMController.text,
      "tipoCliente": selectedTipoCliente,
      "sexo": selectedSexo,
      "estadoCivil": selectedECivil,
      "fechaNacimiento": selectedDate != null
          ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
          : null,
      "telefono": telefonoClienteController.text,
      "correoElectronico": emailClientecontroller.text,
      "domicilio": {
        "calle": calleController.text,
        "noExt": nExtController.text,
        "noInt": nIntController.text,
        "entreCalle": entreCalleController.text,
        "codigoPostal": cpController.text,
        "tiempoViviendo": tiempoViviendoController.text,
        "colonia": coloniaController.text,
        "estado": estadoController.text,
        "municipio": municipioController.text
      },
      "curp": curpController.text,
      "rfc": rfcController.text,
    },
     "IngresosEgresos": ingresosEgresos.map((item) => {
      "descripcion": item['descripcion'],
      "tipo": item['tipo'],
      "monto": item['monto']
    }).toList(),
     "Referencias": referencias.map((referencia) => {
      "nombres": referencia['nombres'],
      "apellidoP": referencia['apellidoP'],
      "apellidoM": referencia['apellidoM'],
      "parentesco": referencia['parentesco'],
      "telefono": referencia['telefono'],
      "tiempoConocer": referencia['tiempoConocer'],
      "calle": referencia['calle'],
      "nExt": referencia['nExt'],
      "nInt": referencia['nInt'],
      "entreCalle": referencia['entreCalle'],
      "colonia": referencia['colonia'],
      "cp": referencia['cp'],
      "estado": referencia['estado'],
      "municipio": referencia['municipio'],
      "tiempoViviendo": referencia['tiempoViviendo']
    }).toList()
  };

  // Convertir a JSON y mostrar en consola
  print(jsonEncode(datosCliente));
}
}
