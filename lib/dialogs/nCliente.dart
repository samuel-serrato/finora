import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:money_facil/ip.dart';

class nClienteDialog extends StatefulWidget {
  final VoidCallback onClienteAgregado;

  nClienteDialog({required this.onClienteAgregado});

  @override
  _nClienteDialogState createState() => _nClienteDialogState();
}

class _nClienteDialogState extends State<nClienteDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController apellidoPController = TextEditingController();
  final TextEditingController nombresController = TextEditingController();
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

  final TextEditingController nombrePropietarioController =
      TextEditingController();
  final TextEditingController parentescoPropietarioController =
      TextEditingController();

  final TextEditingController nombrePropietarioRefController =
      TextEditingController();
  final TextEditingController parentescoRefPropController =
      TextEditingController();

  final TextEditingController ocupacionController = TextEditingController();
  final TextEditingController depEconomicosController = TextEditingController();

  final TextEditingController nombreConyugeController = TextEditingController();
  final TextEditingController telefonoConyugeController =
      TextEditingController();
  final TextEditingController ocupacionConyugeController =
      TextEditingController();

  String? selectedSexo;
  String? selectedECivil;
  String? selectedTipoCliente;
  DateTime? selectedDate;
  String? selectedTipoDomicilio;
  String? selectedTipoDomicilioRef;

  bool _isLoading = false; // Estado para controlar el CircularProgressIndicator

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
    'Comerciante',
    'Jubilado'
  ];

  List<String> tiposIngresoEgreso = [
    'Actividad economica',
    'Actividad Laboral',
    'Credito con otras financieras',
    'Aportaciones del esposo',
    'Otras aportaciones'
  ];

  // Lista de bancos
  final List<String> _bancos = [
    "BBVA",
    "Santander",
    "Banorte",
    "HSBC",
    "Citibanamex",
    "Scotiabank"
  ];

  // Mapa para asociar tipos con sus respectivos IDs
  Map<String, int> tiposIngresoEgresoIds = {
    'Actividad economica': 1,
    'Actividad Laboral': 2,
    'Credito con otras financieras': 3,
    'Aportaciones del esposo': 4,
    'Otras aportaciones': 5
  };

  final List<String> tiposDomicilio = [
    'Propio',
    'Familiar',
    'Rentado',
    'Prestado'
  ];

  final List<Map<String, dynamic>> ingresosEgresos = [];

  List<Map<String, String>> referencias =
      []; // Lista para almacenar referencias

  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _personalFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _cuentaBancariaFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _ingresosEgresosFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _referenciasFormKey = GlobalKey<FormState>();

  bool _noCuentaBancaria = false;
  // Controladores de texto para los campos
  final TextEditingController _numCuentaController = TextEditingController();
  final TextEditingController _numTarjetaController = TextEditingController();

  // Variables para manejar el banco seleccionado
  String? _nombreBanco; // Almacena el nombre del banco seleccionado

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        child:
            _isLoading // Si está cargando, muestra el CircularProgressIndicator
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : Column(
                    children: [
                      Text(
                        'Agregar Cliente',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      TabBar(
                        controller: _tabController,
                        labelColor: Color(0xFFFB2056),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Color(0xFFFB2056),
                        tabs: [
                          Tab(text: 'Información Personal'),
                          Tab(text: 'Cuenta Bancaria'),
                          Tab(text: 'Ingresos y Egresos'),
                          Tab(text: 'Referencias'),
                        ],
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
                              child: _paginaCuentaBancaria(),
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
                              if (_currentIndex <= 3)
                                ElevatedButton(
                                  onPressed: () {
                                    if (_currentIndex < 3) {
                                      if (_validarFormularioActual()) {
                                        print(
                                            "Validación exitosa para la pestaña $_currentIndex");
                                        _tabController
                                            .animateTo(_currentIndex + 1);
                                      } else {
                                        print(
                                            "Validación fallida en la pestaña $_currentIndex");
                                      }
                                    } else if (_currentIndex == 3 &&
                                        _validarFormularioActual()) {
                                      print("Llamando a _agregarCliente");
                                      _agregarCliente();
                                    } else {
                                      print(
                                          "Error en la validación de la pestaña final");
                                    }
                                  },
                                  child: Text(_currentIndex == 3
                                      ? 'Agregar'
                                      : 'Siguiente'),
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

  bool _validarFormularioActual() {
    if (_currentIndex == 0) {
      return _personalFormKey.currentState?.validate() ?? false;
    } else if (_currentIndex == 1) {
      return _cuentaBancariaFormKey.currentState?.validate() ?? false;
    } else if (_currentIndex == 2) {
      return _ingresosEgresosFormKey.currentState?.validate() ?? false;
    } else if (_currentIndex == 3) {
      return _referenciasFormKey.currentState?.validate() ?? false;
    }
    return false;
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
                _buildPasoItem(2, "Cuenta Bancaria", pasoActual == 2),
                SizedBox(height: 20),

                // Paso 3
                _buildPasoItem(3, "Ingresos y Egresos", pasoActual == 3),
                SizedBox(height: 20),

                // Paso 4
                _buildPasoItem(4, "Referencias", pasoActual == 4),
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: ocupacionController,
                          label: 'Ocupación',
                          icon: Icons.work,
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
                          controller: depEconomicosController,
                          label: 'Dependientes económicos',
                          icon: Icons.family_restroom,
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
                  // Agrupamos Estado Civil y Fecha de Nacimiento
                  Column(
                    children: [
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
                      if (selectedECivil ==
                          'Casado') // Condición para mostrar la fila solo si el estado civil es 'Casado'
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: nombreConyugeController,
                                label: 'Nombre del Conyuge',
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
                                controller: telefonoConyugeController,
                                label: 'Número celular del Conyuge',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, ingrese el dato';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: ocupacionConyugeController,
                                label: 'Ocupación',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, ingrese el dato';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
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
                        flex: 3,
                        child: _buildDropdown(
                          value: selectedTipoDomicilio,
                          hint: 'Tipo de Domicilio',
                          items: tiposDomicilio,
                          onChanged: (value) {
                            setState(() {
                              selectedTipoDomicilio = value;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 10),
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
                        ),
                      ),
                    ],
                  ),

// Aquí agregamos el nuevo Row que aparece si no es "Propio"
                  // Verificar si `selectedTipoDomicilio` no es vacío y no es "Propio"
                  if (selectedTipoDomicilio != null &&
                      selectedTipoDomicilio != 'Propio') ...[
                    SizedBox(height: 20), // Espacio entre los rows
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildTextField(
                            controller: nombrePropietarioController,
                            label: 'Nombre del Propietario',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese el nombre del propietario';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: _buildTextField(
                            controller: parentescoPropietarioController,
                            label: 'Parentesco',
                            icon: Icons.family_restroom,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese el parentesco';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

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
                              return 'Por favor ingrese el CURP';
                            } else if (value.length != 18) {
                              return 'El dato tener exactamente 18 dígitos';
                            }
                            return null; // Si es válido
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
                                return 'Por favor ingrese el RFC';
                              } else if (value.length != 12 &&
                                  value.length != 13) {
                                return 'El RFC debe tener 12 o 13 caracteres';
                              }
                              return null;
                            }),
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

  Widget _paginaCuentaBancaria() {
    int pasoActual = 2; // Paso actual en la página de "Cuenta Bancaria"

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contenedor azul a la izquierda para los pasos
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFFB2056),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          width: 250,
          height: 500,
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Paso 1
              _buildPasoItem(1, "Información Personal", pasoActual == 1),
              SizedBox(height: 20),

              // Paso 2
              _buildPasoItem(2, "Cuenta Bancaria", pasoActual == 2),
              SizedBox(height: 20),

              // Paso 3
              _buildPasoItem(3, "Ingresos y Egresos", pasoActual == 3),
              SizedBox(height: 20),

              // Paso 4
              _buildPasoItem(4, "Referencias", pasoActual == 4),
            ],
          ),
        ),
        SizedBox(width: 50), // Espacio entre el contenedor azul y la lista

        // Contenido principal: Formulario de cuenta bancaria
        Expanded(
          child: Form(
            key: _cuentaBancariaFormKey, // Usar el GlobalKey aquí
            child: Column(
              children: [
                SizedBox(
                    height: 20), // Espacio entre el contenedor azul y la lista
                // Opción de "No tiene cuenta bancaria"
                CheckboxListTile(
                  title: Text("No tiene cuenta bancaria"),
                  value: _noCuentaBancaria,
                  onChanged: (bool? value) {
                    setState(() {
                      _noCuentaBancaria = value ?? false;
                      // Limpiar los campos si se selecciona "No tiene cuenta bancaria"
                      if (_noCuentaBancaria) {
                        _nombreBanco = null;
                        _numCuentaController.clear();
                        _numTarjetaController.clear();
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 0), // Eliminar padding horizontal
                  visualDensity: VisualDensity.compact,
                ),

                SizedBox(height: 20),
                if (!_noCuentaBancaria) ...[
                  _buildDropdown(
                    value: _nombreBanco,
                    hint: 'Seleccione un Banco',
                    items: _bancos,
                    onChanged: (value) {
                      setState(() {
                        _nombreBanco = value; // Asigna el banco seleccionado
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Por favor seleccione un banco';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10), // Espacio entre los campos
                  _buildTextField(
                    controller: _numCuentaController,
                    label: 'Número de Cuenta',
                    icon: Icons.account_balance,
                    keyboardType: TextInputType.number,
                    maxLength: 11, // Especificar la longitud máxima aquí
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el número de cuenta';
                      } else if (value.length != 11) {
                        return 'El número de cuenta debe tener exactamente 11 dígitos';
                      }
                      return null; // Si es válido
                    },
                  ),

                  SizedBox(height: 10), // Espacio entre los campos
                  _buildTextField(
                    controller: _numTarjetaController,
                    label: 'Número de Tarjeta',
                    icon: Icons.credit_card,
                    keyboardType: TextInputType.number,
                    maxLength: 16, // Especificar la longitud máxima aquí
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el número de cuenta';
                      } else if (value.length != 16) {
                        return 'El número de cuenta debe tener exactamente 16 dígitos';
                      }
                      return null; // Si es válido
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paginaIngresosEgresos() {
    int pasoActual = 3; // Paso actual en la página de "Ingresos y Egresos"

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
              _buildPasoItem(2, "Cuenta Bancaria", pasoActual == 2),
              SizedBox(height: 20),

              // Paso 3
              _buildPasoItem(3, "Ingresos y Egresos", pasoActual == 3),
              SizedBox(height: 20),

              // Paso 4
              _buildPasoItem(4, "Referencias", pasoActual == 4),
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item['tipo']} - \$${item['monto']}'),
                            Text(
                                'Años en Actividad - ${item['añosenActividad']}'),
                          ],
                        ),
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
    int pasoActual = 4; // Paso actual en la página de "Ingresos y Egresos"

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
              _buildPasoItem(2, "Cuenta Bancaria", pasoActual == 2),
              SizedBox(height: 20),

              // Paso 3
              _buildPasoItem(3, "Ingresos y Egresos", pasoActual == 3),
              SizedBox(height: 20),

              // Paso 4
              _buildPasoItem(4, "Referencias", pasoActual == 4),
            ],
          ),
        ),
        SizedBox(width: 50), // Espacio entre el contenedor rojo y la lista
        Expanded(
          child: Form(
            key: _referenciasFormKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: referencias.length,
                    itemBuilder: (context, index) {
                      final referencia = referencias[index];
                      return Card(
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        child: ListTile(
                          title: Text(
                            '${referencia['nombresRef']} ${referencia['apellidoPRef']} ${referencia['apellidoMRef']}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Datos de la referencia
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      'Parentesco: ${referencia['parentescoRef']}'),
                                  Text(
                                      'Teléfono: ${referencia['telefonoRef']}'),
                                  Text(
                                      'Tiempo de conocer: ${referencia['tiempoConocerRef']}'),
                                ],
                              ),

                              SizedBox(height: 10), // Separador

                              // Datos del domicilio de la referencia
                              Text('Domicilio',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          'Tipo: ${referencia['tipoDomicilioRef']}')),
                                  Expanded(
                                      child: Text(
                                          'Propietario: ${referencia['nombrePropietarioRef']}')),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          'Parentesco con propietario: ${referencia['parentescoRefProp']}')),
                                  Expanded(
                                      child: Text(
                                          'Calle: ${referencia['calleRef']}')),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          'Num Ext: ${referencia['nExtRef']}')),
                                  Expanded(
                                      child: Text(
                                          'Num Int: ${referencia['nIntRef']}')),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                      child: Text(
                                          'Entre calles: ${referencia['entreCalleRef']}')),
                                  Expanded(
                                    child: Text(
                                        'Tiempo viviendo: ${referencia['tiempoViviendoRef']}'),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                      child: Text(
                                          'Colonia: ${referencia['coloniaRef']}')),
                                  Expanded(
                                      child:
                                          Text('CP: ${referencia['cpRef']}')),
                                ],
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          'Estado: ${referencia['estadoRef']}')),
                                  Expanded(
                                      child: Text(
                                          'Municipio: ${referencia['municipioRef']}')),
                                ],
                              ),
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
        ),
      ],
    );
  }

  void _mostrarDialogReferencia({int? index, Map<String, dynamic>? item}) {
    final GlobalKey<FormState> dialogAddReferenciasFormKey =
        GlobalKey<FormState>();

    // Asignación inicial para dropdowns
    String? selectedParentesco = item?['parentescoRef'];
    String? selectedTipoDomicilioRef = item?['tipoDomicilioRef'];

    // Controladores
    final parentescoRefPropController =
        TextEditingController(text: item?['parentescoRefProp'] ?? '');
    final nombrePropietarioRefController =
        TextEditingController(text: item?['nombrePropietarioRef'] ?? '');
    final tiempoConocerRefController =
        TextEditingController(text: item?['tiempoConocerRef'] ?? '');
    final nombresRefController =
        TextEditingController(text: item?['nombresRef'] ?? '');
    final apellidoPRefController =
        TextEditingController(text: item?['apellidoPRef'] ?? '');
    final apellidoMRefController =
        TextEditingController(text: item?['apellidoMRef'] ?? '');
    final telefonoRefController =
        TextEditingController(text: item?['telefonoRef'] ?? '');

    // Controladores de domicilio de referencia
    final calleRefController =
        TextEditingController(text: item?['calleRef'] ?? '');
    final nExtRefController =
        TextEditingController(text: item?['nExtRef'] ?? '');
    final nIntRefController =
        TextEditingController(text: item?['nIntRef'] ?? '');
    final entreCalleRefController =
        TextEditingController(text: item?['entreCalleRef'] ?? '');
    final coloniaRefController =
        TextEditingController(text: item?['coloniaRef'] ?? '');
    final cpRefController = TextEditingController(text: item?['cpRef'] ?? '');
    final estadoRefController =
        TextEditingController(text: item?['estadoRef'] ?? '');
    final municipioRefController =
        TextEditingController(text: item?['municipioRef'] ?? '');
    final tiempoViviendoRefController =
        TextEditingController(text: item?['tiempoViviendoRef'] ?? '');

    // Configuración del diálogo
    final width = MediaQuery.of(context).size.width * 0.7;
    final height = MediaQuery.of(context).size.height * 0.55;

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
        content: StatefulBuilder(
          builder: (context, setState) => Container(
            width: width,
            height: height,
            child: SingleChildScrollView(
              child: Form(
                key: dialogAddReferenciasFormKey,
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
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Divider(color: Colors.grey[300]),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: nombresRefController,
                              label: 'Nombres',
                              icon: Icons.person,
                              validator: (value) => value?.isEmpty == true
                                  ? 'Por favor, ingrese su nombre'
                                  : null,
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: apellidoPRefController,
                              label: 'Apellido Paterno',
                              icon: Icons.person_outline,
                              validator: (value) => value?.isEmpty == true
                                  ? 'Por favor, ingrese su apellido paterno'
                                  : null,
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: apellidoMRefController,
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
                                'Vecino',
                                'Otro'
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedParentesco = value;
                                });
                              },
                              validator: (value) => value == null
                                  ? 'Por favor, seleccione el parentesco'
                                  : null,
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: telefonoRefController,
                              label: 'Teléfono',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              validator: (value) => value?.isEmpty == true
                                  ? 'Por favor, ingrese su teléfono'
                                  : null,
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: tiempoConocerRefController,
                              label: 'Tiempo de conocer',
                              icon: Icons.timelapse_rounded,
                              validator: (value) => value?.isEmpty == true
                                  ? 'Por favor, ingrese el tiempo de conocer'
                                  : null,
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
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Divider(color: Colors.grey[300]),
                            Text(
                              'Los datos de domicilio de la referencia son opcionales',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[700]),
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildDropdown(
                                    value: selectedTipoDomicilioRef,
                                    hint: 'Tipo Domicilio',
                                    items: [
                                      'Propio',
                                      'Alquilado',
                                      'Prestado',
                                      'Otro'
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        selectedTipoDomicilioRef = value;
                                        // Imprimir en consola para verificar el valor seleccionado
                                        print(
                                            "selectedTipoDomicilioRef: $selectedTipoDomicilioRef");
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 6,
                                  child: _buildTextField(
                                    controller: calleRefController,
                                    label: 'Calle',
                                    icon: Icons.location_on,
                                    /*   validator: (value) => value?.isEmpty == true
                                        ? 'Por favor, ingrese Calle'
                                        : null, */
                                  ),
                                ),
                              ],
                            ),

                            // Mostrar los campos adicionales solo si selectedTipoDomicilioRef es diferente de Propio
                            if (selectedTipoDomicilioRef != null &&
                                selectedTipoDomicilioRef != 'Propio') ...[
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _buildTextField(
                                      controller:
                                          nombrePropietarioRefController,
                                      label: 'Nombre del Propietario',
                                      icon: Icons.person,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    flex: 4,
                                    child: _buildTextField(
                                      controller: parentescoRefPropController,
                                      label: 'Parentesco con propietario',
                                      icon: Icons.family_restroom,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: nExtRefController,
                                    label: 'No. Ext',
                                    icon: Icons.house,
                                    keyboardType: TextInputType.number,
                                    /*  validator: (value) => value?.isEmpty == true
                                        ? 'Por favor, ingrese No. Ext'
                                        : null, */
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: nIntRefController,
                                    label: 'No. Int',
                                    icon: Icons.house,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: entreCalleRefController,
                              label: 'Entre Calle',
                              icon: Icons.location_on,
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: coloniaRefController,
                                    label: 'Colonia',
                                    icon: Icons.location_city,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _buildTextField(
                                    controller: cpRefController,
                                    label: 'Código Postal',
                                    icon: Icons.mail,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDropdown(
                                    value: estadoRefController.text.isNotEmpty
                                        ? estadoRefController.text
                                        : null,
                                    hint: 'Estado',
                                    items: ['Guerrero'],
                                    onChanged: (value) {
                                      setState(() {
                                        estadoRefController.text = value ?? '';
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _buildTextField(
                                    controller: municipioRefController,
                                    label: 'Municipio',
                                    icon: Icons.map,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: tiempoViviendoRefController,
                              label: 'Tiempo Viviendo',
                              icon: Icons.timelapse,
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
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (_referenciasFormKey.currentState!.validate()) {
                // Recoger los datos de los controladores
                final nuevaReferencia = {
                  'nombresRef': nombresRefController.text.isNotEmpty
                      ? nombresRefController.text
                      : '',
                  'apellidoPRef': apellidoPRefController.text.isNotEmpty
                      ? apellidoPRefController.text
                      : '',
                  'apellidoMRef': apellidoMRefController.text.isNotEmpty
                      ? apellidoMRefController.text
                      : '',
                  'parentescoRef': selectedParentesco ?? '',
                  'telefonoRef': telefonoRefController.text.isNotEmpty
                      ? telefonoRefController.text
                      : '',
                  'tiempoConocerRef': tiempoConocerRefController.text.isNotEmpty
                      ? tiempoConocerRefController.text
                      : '',
                  'tipoDomicilioRef': selectedTipoDomicilioRef ?? '',
                  'calleRef': calleRefController.text.isNotEmpty
                      ? calleRefController.text
                      : '',
                  'nExtRef': nExtRefController.text.isNotEmpty
                      ? nExtRefController.text
                      : '',
                  'nIntRef': nIntRefController.text.isNotEmpty
                      ? nIntRefController.text
                      : '',
                  'entreCalleRef': entreCalleRefController.text.isNotEmpty
                      ? entreCalleRefController.text
                      : '',
                  'coloniaRef': coloniaRefController.text.isNotEmpty
                      ? coloniaRefController.text
                      : '',
                  'cpRef': cpRefController.text.isNotEmpty
                      ? cpRefController.text
                      : '',
                  'estadoRef': estadoRefController.text.isNotEmpty
                      ? estadoRefController.text
                      : '',
                  'municipioRef': municipioRefController.text.isNotEmpty
                      ? municipioRefController.text
                      : '',
                  'tiempoViviendoRef':
                      tiempoViviendoRefController.text.isNotEmpty
                          ? tiempoViviendoRefController.text
                          : '',
                  if (selectedTipoDomicilioRef != 'Propio')
                    'nombrePropietarioRef':
                        nombrePropietarioRefController.text.isNotEmpty
                            ? nombrePropietarioRefController.text
                            : '',
                  if (selectedTipoDomicilioRef != 'Propio')
                    'parentescoRefProp':
                        parentescoRefPropController.text.isNotEmpty
                            ? parentescoRefPropController.text
                            : '',
                };

                // Lógica para agregar o actualizar la referencia
                setState(() {
                  if (index == null) {
                    referencias
                        .add(nuevaReferencia); // Agregar nueva referencia
                  } else {
                    referencias[index] =
                        nuevaReferencia; // Actualizar referencia existente
                  }
                });

                Navigator.pop(context); // Cerrar el formulario
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

    final anosenActividadController =
        TextEditingController(text: item?['añosenActividad']?.toString() ?? '');

    // Crea un nuevo GlobalKey para el formulario del diálogo
    final GlobalKey<FormState> dialogAddIngresosEgresosFormKey =
        GlobalKey<FormState>();

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
                key:
                    dialogAddIngresosEgresosFormKey, // Usar el nuevo GlobalKey aquí
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdown(
                      value: selectedTipo,
                      hint: 'Tipo',
                      items: tiposIngresoEgreso,
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
                    SizedBox(height: 10),
                    _buildTextField(
                      controller: anosenActividadController,
                      label: 'Años en Actividad',
                      icon: Icons.timelapse,
                      fontSize: 14.0,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese un dato';
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
              if (dialogAddIngresosEgresosFormKey.currentState!.validate() &&
                  selectedTipo != null) {
                final nuevoItem = {
                  'tipo': selectedTipo,
                  'descripcion': descripcionController.text,
                  'monto': montoController.text,
                  'añosenActividad': anosenActividadController.text,
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

  void _agregarCliente() async {
    setState(() {
      _isLoading = true; // Activa el indicador de carga
    });

    final clienteResponse = await _enviarCliente();
    if (clienteResponse != null) {
      final idCliente = clienteResponse["idclientes"];
      print("ID del cliente creado: $idCliente");

      if (idCliente != null) {
        // Paso 2: Crear cuenta bancaria
        await _enviarCuentaBanco(idCliente);

        // Paso 3: Crear domicilio
        await _enviarDomicilio(idCliente);

        // Paso 4: Crear datos adicionales
        await _enviarDatosAdicionales(idCliente);

        // Paso 5: Crear ingresos
        await _enviarIngresos(idCliente);

        // Paso 6: Crear referencias
        await _enviarReferencias(idCliente);

        // Llama al callback para refrescar la lista de clientes
        widget.onClienteAgregado();

        // Muestra el SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente agregado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Cierra el diálogo
        Navigator.of(context).pop();
      } else {
        print("Error: idCliente es nulo.");
      }
    } else {
      print("Error: clienteResponse es nulo.");
    }

    setState(() {
      _isLoading = false; // Desactiva el indicador de carga
    });
  }

  Future<Map<String, dynamic>?> _enviarCliente() async {
    final url = Uri.parse("http://$baseUrl/api/v1/clientes");

    final datosCliente = {
      "tipoclientes": selectedTipoCliente ?? "",
      "ocupacion": ocupacionController.text,
      "nombres": nombresController.text,
      "apellidoP": apellidoPController.text,
      "apellidoM": apellidoMController.text,
      "fechaNac": selectedDate != null
          ? "${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}"
          : null,
      "sexo": selectedSexo ?? "",
      "telefono": telefonoClienteController.text,
      "eCivil": selectedECivil ?? "",
      "email": emailClientecontroller.text,
      "dependientes_economicos": depEconomicosController.text,
      "nombreConyuge": nombreConyugeController.text,
      "telefonoConyuge": telefonoConyugeController.text,
      "ocupacionConyuge": ocupacionConyugeController.text
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(datosCliente),
      );
      print("Código de estado de la respuesta: ${response.statusCode}");
      print(
          "Cuerpo de la respuesta: ${response.body}"); // Imprime el cuerpo completo

      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        print(
            "Cuerpo decodificado: $responseBody"); // Verifica cómo se ve el JSON decodificado
        return responseBody; // Devuelve el objeto completo
      } else {
        print("Error en crear cliente: ${response.statusCode}");
      }
    } catch (e) {
      print("Error al enviar cliente: $e");
    }
    return null;
  }

  Future<void> _enviarCuentaBanco(String idCliente) async {
    final url = Uri.parse("http://$baseUrl/api/v1/cuentabanco");

    final datosCuentaBanco = {
      "idclientes": idCliente,
      "iddetallegrupos": "",
      "nombreBanco": _nombreBanco ?? "",
      "numCuenta": _numCuentaController.text,
      "numTarjeta": _numTarjetaController.text
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(datosCuentaBanco),
      );
      print(
          "Código de estado de la respuesta de cuenta bancaria: ${response.statusCode}");
      print("Cuerpo de la respuesta de cuenta bancaria: ${response.body}");

      if (response.statusCode == 201) {
        print("Cuenta bancaria creada correctamente");
      } else {
        print("Error al crear cuenta bancaria: ${response.statusCode}");
      }
    } catch (e) {
      print("Error al enviar cuenta bancaria: $e");
    }
  }

  Future<void> _enviarDomicilio(String idCliente) async {
    final url = Uri.parse("http://$baseUrl/api/v1/domicilios");

    // Convertir los datos en un array que contiene un solo map
    final datosDomicilio = [
      {
        "idclientes": idCliente,
        "tipo_domicilio": selectedTipoDomicilio ?? "",
        "nombre_propietario": nombrePropietarioController.text,
        "parentesco": parentescoPropietarioController.text,
        "calle": calleController.text,
        "nExt": nExtController.text,
        "nInt": nIntController.text,
        "entreCalle": entreCalleController.text,
        "colonia": coloniaController.text,
        "cp": cpController.text,
        "estado": estadoController.text,
        "municipio": municipioController.text,
        "tiempoViviendo": tiempoViviendoController.text
      }
    ];

    print('IMPRESION domicilio en array!');
    print(jsonEncode(datosDomicilio));

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(datosDomicilio),
      );
      if (response.statusCode == 201) {
        print("Domicilio agregado correctamente");
      } else {
        print("Error en agregar domicilio: ${response.statusCode}");
        print("Cuerpo de la respuesta: ${response.body}");
      }
    } catch (e) {
      print("Error al enviar domicilio: $e");
    }
  }

  Future<void> _enviarDatosAdicionales(String idCliente) async {
    final url = Uri.parse("http://$baseUrl/api/v1/datosadicionales");

    final datosAdicionales = {
      "idclientes": idCliente,
      "curp": curpController.text,
      "rfc": rfcController.text,
    };

    print('IMPRESION datos adicionales!');
    print(jsonEncode({
      "curp": curpController.text,
      "rfc": rfcController.text,
    }));

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(datosAdicionales),
      );
      if (response.statusCode == 201) {
        print("Datos adicionales agregados correctamente");
      } else {
        print("Error en agregar datos adicionales: ${response.statusCode}");
        print("Cuerpo de la respuesta: ${response.body}");
      }
    } catch (e) {
      print("Error al enviar datos adicionales: $e");
    }
  }

  Future<void> _enviarIngresos(String idCliente) async {
    final url = Uri.parse("http://$baseUrl/api/v1/ingresos");

    final ingresosData = ingresosEgresos
        .map((item) => {
              "idclientes": idCliente,
              "idinfo": tiposIngresoEgresoIds[item['tipo']] ??
                  0, // Obtener el ID en lugar del texto
              "años_actividad": item['añosenActividad'] ?? 0,
              "descripcion": item['descripcion'] ?? "",
              "monto_semanal": item['monto'] ?? 0
            })
        .toList();

    // Imprimir los datos antes de enviarlos
    print("Datos a enviar para ingresos:");
    print(jsonEncode(ingresosData));

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(ingresosData),
      );
      if (response.statusCode == 201) {
        print("Ingresos agregados correctamente");
      } else {
        print("Error en agregar ingresos: ${response.statusCode}");
        print("Cuerpo de la respuesta: ${response.body}");
      }
    } catch (e) {
      print("Error al enviar ingresos: $e");
    }
  }

  Future<void> _enviarReferencias(String idCliente) async {
    final url = Uri.parse("http://$baseUrl/api/v1/referencia");

    final referenciasData = referencias
        .map((referencia) => {
              "idclientes": idCliente,
              "nombres": referencia['nombresRef'] ?? "",
              "apellidoP": referencia['apellidoPRef'] ?? "",
              "apellidoM": referencia['apellidoMRef'] ?? "",
              "parentesco": referencia['parentescoRef'] ?? "",
              "telefono": referencia['telefonoRef'] ?? "",
              "tiempoConocer": referencia['tiempoConocerRef'] ?? "",
              //DOMICILIO
              "tipo_domicilio": referencia['tipoDomicilioRef'] ?? "",
              "nombre_propietario": referencia['nombrePropietarioRef'] ?? "",
              "parentescoRefProp": referencia['parentescoRefProp'] ?? "",
              "calle": referencia['calleRef'] ?? "",
              "nExt": referencia['nExtRef'] ?? "",
              "nInt": referencia['nIntRef'] ?? "",
              "entreCalle": referencia['entreCalleRef'] ?? "",
              "colonia": referencia['coloniaRef'] ?? "",
              "cp": referencia['cpRef'] ?? "",
              "estado": referencia['estadoRef'] ?? "",
              "municipio": referencia['municipioRef'] ?? "",
              "tiempoViviendo": referencia['tiempoViviendoRef'] ?? ""
            })
        .toList(growable: false);
    print("Datos a enviar para referencias:");
    print(jsonEncode(referenciasData));

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(referenciasData),
      );
      if (response.statusCode == 201) {
        print("Referencias agregadas correctamente");
      } else {
        print("Error en agregar referencias: ${response.statusCode}");
        print("Cuerpo de la respuesta: ${response.body}");
      }
    } catch (e) {
      print("Error al enviar referencias: $e");
    }
  }

  void imprimirDatosCliente() {
    final datosCliente = {
      "InformacionPersonal": {
        "nombres": nombresController.text,
        "apellidoPaterno": apellidoPController.text,
        "apellidoMaterno": apellidoMController.text,
        "tipoCliente": selectedTipoCliente ?? "",
        "sexo": selectedSexo ?? "",
        "estadoCivil": selectedECivil ?? "",
        "fechaNacimiento": selectedDate != null
            ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
            : null,
        "ocupacion": ocupacionController.text,
        "dependientes_economicos": depEconomicosController.text,
        "telefono": telefonoClienteController.text,
        "correoElectronico": emailClientecontroller.text,
        "nombreConyuge": nombreConyugeController.text,
        "numeroConyuge": telefonoConyugeController.text,
        "ocupacionConyuge": ocupacionConyugeController.text,
        "domicilio": {
          "tipoDomicilio": selectedTipoDomicilio ?? "",
          "nombredelPropietario": nombrePropietarioController.text,
          "parentescoPropietario": parentescoPropietarioController.text,
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
      "IngresosEgresos": ingresosEgresos
          .map((item) => {
                "descripcion": item['descripcion'] ?? "",
                "tipo": item['tipo'] ?? "",
                "monto": item['monto'] ?? 0,
                "añosenActividad": item['añosenActividad'] ?? 0
              })
          .toList(),
      "Referencias": referencias
          .map((referencia) => {
                "nombres": referencia['nombres'] ?? "",
                "apellidoP": referencia['apellidoP'] ?? "",
                "apellidoM": referencia['apellidoM'] ?? "",
                "parentesco": referencia['parentesco'] ?? "",
                "telefono": referencia['telefono'] ?? "",
                "tiempoConocer": referencia['tiempoConocer'] ?? "",
                "calle": referencia['calle'] ?? "",
                "nExt": referencia['nExt'] ?? "",
                "nInt": referencia['nInt'] ?? "",
                "entreCalle": referencia['entreCalle'] ?? "",
                "colonia": referencia['colonia'] ?? "",
                "cp": referencia['cp'] ?? "",
                "estado": referencia['estado'] ?? "",
                "municipio": referencia['municipio'] ?? "",
                "tiempoViviendo": referencia['tiempoViviendo'] ?? ""
              })
          .toList()
    };

    // Convertir a JSON y mostrar en consola
    try {
      print(jsonEncode(datosCliente));
    } catch (e) {
      print("Error al convertir a JSON: $e");
    }
  }
}
