import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:money_facil/ip.dart';
import 'package:money_facil/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class renovarGrupoDialog extends StatefulWidget {
  final VoidCallback onGrupoRenovado;
  final String idGrupo; // Nuevo parámetro para recibir el idGrupo

  renovarGrupoDialog({required this.onGrupoRenovado, required this.idGrupo});

  @override
  _renovarGrupoDialogState createState() => _renovarGrupoDialogState();
}

class _renovarGrupoDialogState extends State<renovarGrupoDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController nombreGrupoController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController liderGrupoController = TextEditingController();
  final TextEditingController miembrosController = TextEditingController();

  final List<Map<String, dynamic>> _selectedPersons = [];
  final TextEditingController _controller = TextEditingController();

  Map<String, String> _originalCargos = {};

  List<String> _clientesEliminados =
      []; // Lista para almacenar los IDs de los clientes eliminados

  String? selectedTipo;

  List<String> tiposGrupo = [
    'Grupal',
    'Individual',
    'Selecto',
  ];

  List<String> cargos = ['Miembro', 'Presidente/a', 'Tesorero/a'];

  // Agregamos un mapa para guardar el rol de cada persona seleccionada
  Map<String, String> _cargosSeleccionados = {};

  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _infoGrupoFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _miembrosGrupoFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  Map<String, dynamic> grupoData = {};
  Timer? _timer; // Temporizador para el tiempo de espera
  bool dialogShown = false; // Evitar mostrar múltiples diálogos de error
  bool _dialogShown = false;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
    fetchGrupoData(); // Llamar a la función para obtener los datos del grupo

    print('Grupo seleccionado: ${widget.idGrupo}');
  }

  // Función para obtener los detalles del grupo
  // Función para obtener los detalles del grupo con manejo de token y errores
Future<void> fetchGrupoData() async {
  if (!mounted) return;
  
  print('Ejecutando fetchGrupoData');
  _timer?.cancel();

  setState(() => _isLoading = true);

  _timer = Timer(const Duration(seconds: 10), () {
    if (mounted && _isLoading && !_dialogShown) {
      setState(() => _isLoading = false);
      mostrarDialogoError('Error de conexión. Revise su red.');
      _dialogShown = true;
    }
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';
    
    final url = 'http://$baseUrl/api/v1/grupodetalles/${widget.idGrupo}';
    final response = await http.get(
      Uri.parse(url),
      headers: {'tokenauth': token},
    );

    if (!mounted) return;
    _timer?.cancel();

    if (response.statusCode == 200) {
      final data = json.decode(response.body)[0];
      List<Map<String, dynamic>> clientesActuales = [];

      if (mounted) {
        setState(() {
          grupoData = data;
          _isLoading = false;
          nombreGrupoController.text = data['nombreGrupo'] ?? '';
          descripcionController.text = data['detalles'] ?? '';
          selectedTipo = data['tipoGrupo'];
          _selectedPersons.clear();
          _cargosSeleccionados.clear();

          if (data['clientes'] != null) {
            clientesActuales = List<Map<String, dynamic>>.from(data['clientes']);
            _selectedPersons.addAll(clientesActuales);
            
            for (var cliente in clientesActuales) {
              String? idCliente = cliente['idclientes'];
              String? cargo = cliente['cargo'];
              if (idCliente != null && cargo != null) {
                _cargosSeleccionados[idCliente] = cargo;
                _originalCargos[idCliente] = cargo;
              }
            }
          }
        });
      }
      
      print('Clientes actuales del grupo:');
      clientesActuales.forEach((cliente) => print('id: ${cliente['idclientes']}, Nombre: ${cliente['nombres']}'));
    } else {
      _handleApiError(response, 'Error cargando grupo');
    }
  } catch (e) {
    _handleNetworkError(e);
  } finally {
    if (mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }
}

  // Función para mostrar el diálogo de error
  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    if (mounted) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onClose != null) onClose();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  bool _validarFormularioActual() {
    if (_currentIndex == 0) {
      return _infoGrupoFormKey.currentState?.validate() ?? false;
    } else if (_currentIndex == 1) {
      return _miembrosGrupoFormKey.currentState?.validate() ?? false;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> findPersons(String query) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';
    
    final response = await http.get(
      Uri.parse('http://$baseUrl/api/v1/clientes/$query'),
      headers: {'tokenauth': token},
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      _handleApiError(response, 'Error buscando personas');
      return [];
    }
  } catch (e) {
    _handleNetworkError(e);
    return [];
  }
}


  void _renovarGrupo() async {
  if (!mounted) return;
  
  setState(() => _isLoading = true);

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';
    
    final Map<String, dynamic> data = {
      'idgrupos': widget.idGrupo,
      'nombreGrupo': nombreGrupoController.text,
      'detalles': descripcionController.text,
      'tipoGrupo': selectedTipo,
    };

    final response = await http.post(
      Uri.parse('http://$baseUrl/api/v1/grupos/renovacion'),
      headers: {
        'Content-Type': 'application/json',
        'tokenauth': token,
      },
      body: json.encode(data),
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      final responseBody = jsonDecode(response.body);
      final idNuevoGrupo = responseBody['idgrupos'];
      
      if (_selectedPersons.isNotEmpty) {
        await _enviarMiembros(idNuevoGrupo, token);
      }

      if (mounted) {
        widget.onGrupoRenovado?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grupo renovado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      _handleApiError(response, 'Error renovando grupo');
    }
  } catch (e) {
    _handleNetworkError(e);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _enviarMiembros(String idGrupo, String token) async {
  try {
    final miembros = _selectedPersons.map((persona) => {
      'idclientes': persona['idclientes'],
      'nomCargo': _cargosSeleccionados[persona['idclientes']] ?? 'Miembro',
    }).toList();

    final response = await http.post(
      Uri.parse('http://$baseUrl/api/v1/grupodetalles/renovacion'),
      headers: {
        'Content-Type': 'application/json',
        'tokenauth': token,
      },
      body: json.encode({
        'idgrupos': idGrupo,
        'clientes': miembros,
        'idusuarios': 'WVI8HMQAG5',
      }),
    );

    if (response.statusCode != 201) {
      _handleApiError(response, 'Error agregando miembros');
    }
  } catch (e) {
    _handleNetworkError(e);
  }
}

void _handleApiError(http.Response response, String mensajeBase) {
  try {
    final errorData = json.decode(response.body);
    final errorMessage = (errorData['Error']?['Message'] ?? 
                        errorData['error']?['message'] ?? 
                        'Error desconocido').toString();

    if ([401, 403, 404].contains(response.statusCode) && 
       (errorMessage.toLowerCase().contains('jwt') || 
        errorMessage.toLowerCase().contains('token'))) {
      _handleTokenExpiration();
    } else {
      mostrarDialogoError('$mensajeBase: $errorMessage');
    }
  } catch (e) {
    mostrarDialogoError('$mensajeBase: Error desconocido');
  }
}

void _handleNetworkError(dynamic error) {
  if (error is SocketException) {
    mostrarDialogoError('Error de conexión. Verifique su internet');
  } else {
    mostrarDialogoError('Error inesperado: ${error.toString()}');
  }
}

void _handleTokenExpiration() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('tokenauth');
  
  if (mounted) {
    mostrarDialogoError(
      'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
      onClose: () => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      ),
    );
  }
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
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Text(
                    'Renovación de Grupo',
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
                          padding: const EdgeInsets.only(
                              right: 30, top: 10, bottom: 10, left: 0),
                          child: _paginaInfoGrupo(),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 30, top: 10, bottom: 10, left: 0),
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
                                if (_validarFormularioActual()) {
                                  _tabController.animateTo(_currentIndex + 1);
                                } else {
                                  print(
                                      "Validación fallida en la pestaña $_currentIndex");
                                }
                              },
                              child: Text('Siguiente'),
                            ),
                          if (_currentIndex == 1)
                            ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  _isLoading =
                                      true; // Muestra el CircularProgressIndicator
                                });

                                try {
                                  _renovarGrupo(); // Espera a que la función termine
                                } catch (e) {
                                  // Puedes manejar el error aquí si es necesario
                                  print("Error: $e");
                                } finally {
                                  if (mounted) {
                                    // Solo actualizamos el estado si el widget sigue montado
                                    setState(() {
                                      _isLoading =
                                          false; // Oculta el CircularProgressIndicator
                                    });
                                  }
                                }
                              },
                              child: _isLoading
                                  ? CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    )
                                  : Text('Guardar'),
                            )
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
                    enabled: false,
                    controller: nombreGrupoController,
                    label: 'Nombres del grupo',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el nombre del grupo';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: verticalSpacing),
                  _buildDropdown(
                    enabled: false,
                    value: selectedTipo,
                    hint: 'Tipo',
                    items: tiposGrupo,
                    onChanged: (value) {
                      setState(() {
                        selectedTipo = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, seleccione el Tipo de Grupo';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: verticalSpacing),
                  _buildTextField(
                    controller: descripcionController,
                    label: 'Descripción',
                    icon: Icons.description,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese una descripción';
                      }
                      return null;
                    },
                  )
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
                SizedBox(height: 20),
                TypeAheadField<Map<String, dynamic>>(
                  builder: (context, controller, focusNode) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
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
                    return await findPersons(search);
                  },
                  itemBuilder: (context, person) {
                    return ListTile(
                      title: Row(
                        children: [
                          Text(
                            '${person['nombres'] ?? ''} ${person['apellidoP'] ?? ''} ${person['apellidoM'] ?? ''}',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 10),
                          Text('-  F. Nacimiento: ${person['fechaNac'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey[700])),
                          SizedBox(width: 10),
                          Text('-  Teléfono: ${person['telefono'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey[700])),
                        ],
                      ),
                    );
                  },
                  onSelected: (person) {
                    // Verificar si la persona ya está en la lista usando el campo `idclientes`
                    bool personaYaAgregada = _selectedPersons
                        .any((p) => p['idclientes'] == person['idclientes']);

                    if (!personaYaAgregada) {
                      setState(() {
                        _selectedPersons.add(person);
                        _cargosSeleccionados[person['idclientes']] =
                            cargos[0]; // Rol predeterminado
                      });
                      _controller.clear();
                    } else {
                      // Mostrar mensaje indicando que la persona ya fue agregada
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'La persona ya ha sido agregada a la lista')));
                    }
                  },
                  controller: _controller,
                  loadingBuilder: (context) => const Text('Cargando...'),
                  errorBuilder: (context, error) =>
                      const Text('Error al cargar los datos!'),
                  emptyBuilder: (context) =>
                      const Text('No hay coincidencias!'),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _selectedPersons.length,
                    itemBuilder: (context, index) {
                      final person = _selectedPersons[index];
                      final nombre = person['nombres'] ?? '';
                      final idCliente = person['idclientes'];
                      final telefono = person['telefono'] ?? 'No disponible';
                      final fechaNac =
                          person['fechaNacimiento'] ?? 'No disponible';

                      return ListTile(
                        title: Row(
                          children: [
                            // Mostrar numeración antes del nombre
                            Text(
                              '${index + 1}. ', // Numeración
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black),
                            ),
                            // Nombre completo
                            Expanded(
                              child: Text(
                                '${nombre} ${person['apellidoP'] ?? ''} ${person['apellidoM'] ?? ''}',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Teléfono
                            Text(
                              'Teléfono: $telefono',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey[700],
                              ),
                            ),
                            // Fecha de nacimiento
                            SizedBox(width: 30),
                            Text(
                              'Fecha de Nacimiento: $fechaNac',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Dropdown para seleccionar cargo
                            DropdownButton<String>(
                              value:
                                  _cargosSeleccionados[person['idclientes']] ??
                                      'Miembro',
                              onChanged: (nuevoCargo) {
                                setState(() {
                                  _cargosSeleccionados[person['idclientes']] =
                                      nuevoCargo!;
                                });
                              },
                              items:
                                  cargos.map<DropdownMenuItem<String>>((cargo) {
                                return DropdownMenuItem<String>(
                                  value: cargo,
                                  child: Text(cargo),
                                );
                              }).toList(),
                            ),
                            SizedBox(
                                width:
                                    8), // Espaciado entre el dropdown y el ícono
                            // Ícono de eliminar
                            IconButton(
                              onPressed: () async {
                                final confirmDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Confirmar eliminación'),
                                    content: Text(
                                        '¿Estás seguro de que quieres eliminar a ${nombre} ${person['apellidoP'] ?? ''}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmDelete == true) {
                                  setState(() {
                                    _clientesEliminados.add(idCliente);
                                    _selectedPersons.removeAt(index);
                                  });
                                }
                              },
                              icon: Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
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
  bool enabled = true, // Campo habilitado por defecto
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    style: TextStyle(
      fontSize: fontSize,
      color: enabled ? Colors.black : Colors.grey, // Color del texto
    ),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: enabled ? Colors.black : Colors.grey, // Color del ícono
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      labelStyle: TextStyle(
        fontSize: fontSize,
        color: enabled ? Colors.black : Colors.grey, // Color del label
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.grey.shade700, // Borde cuando está habilitado
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.grey, // Borde cuando está deshabilitado
        ),
      ),
    ),
    validator: validator,
    inputFormatters:
        maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : [],
    enabled: enabled, // Controla si el campo está habilitado o deshabilitado
  );
}

Widget _buildDropdown({
  required String? value,
  required String hint,
  required List<String> items,
  required void Function(String?) onChanged,
  double fontSize = 12.0,
  String? Function(String?)? validator,
  bool enabled = true, // Habilitado por defecto
}) {
  return InputDecorator(
    decoration: InputDecoration(
      labelText: hint,
      labelStyle: TextStyle(
        fontSize: fontSize,
        color: enabled ? Colors.black : Colors.grey, // Cambiar color del hint
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: enabled ? Colors.grey.shade700 : Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black),
      ),
    ),
    isEmpty: value == null || value.isEmpty,
    child: enabled
        ? DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                hint,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.grey, // Cambiar color del hint
                ),
              ),
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
              style: TextStyle(fontSize: fontSize, color: Colors.black),
            ),
          )
        : Text(
            value ?? hint,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.grey, // Color del texto deshabilitado
            ),
          ),
  );
}
