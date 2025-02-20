import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final List<Map<String, dynamic>> _selectedPersons = [];
  final TextEditingController _controller = TextEditingController();
  List<Usuario> _usuarios = [];
  Usuario? _selectedUsuario;
  bool _isLoadingUsuarios = true; // Nueva variable de estado

  String? selectedTipo;

  List<String> tiposGrupo = [
    'Grupal',
    'Individual',
    'Selecto',
  ];

  List<String> roles = ['Miembro', 'Presidente/a', 'Tesorero/a'];

  // Agregamos un mapa para guardar el rol de cada persona seleccionada
  Map<String, String> _rolesSeleccionados = {};

  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _infoGrupoFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _miembrosGrupoFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool esAdicional = false; // Variable para el estado del checkbox

  Timer? _timer;
  bool _dialogShown = false;
  bool _errorDeConexion = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
    obtenerUsuarios(); // Agregar esta línea
  }

  bool _validarFormularioActual() {
  bool isValid = false;
  
  if (_currentIndex == 0) {
    isValid = _infoGrupoFormKey.currentState?.validate() ?? false;
  } else if (_currentIndex == 1) {
    isValid = _miembrosGrupoFormKey.currentState?.validate() ?? false;
    
    // Validación adicional para tipo grupal
    if (isValid && selectedTipo == 'Grupal' && _selectedPersons.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Los grupos grupales requieren al menos 2 miembros'),
      ));
      return false;
    }
  }
  return isValid;
}

  Future<void> obtenerUsuarios() async {
    setState(() => _isLoadingUsuarios = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('http://$baseUrl/api/v1/usuarios/tipo/campo'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _usuarios = data.map((item) => Usuario.fromJson(item)).toList();
        });
      }
    } catch (e) {
      print('Error obteniendo usuarios: $e');
    } finally {
      setState(() => _isLoadingUsuarios = false);
    }
  }

  Future<List<Map<String, dynamic>>> findPersons(String query) async {
    if (query.isEmpty) return [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('http://$baseUrl/api/v1/clientes/$query'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else if (response.statusCode == 404) {
        final errorData = json.decode(response.body);
        if (errorData["Error"]["Message"] == "jwt expired") {
          _handleTokenExpiration();
        }
      }
      return [];
    } catch (e) {
      if (mounted && !_dialogShown) {
        _mostrarDialogo(
          title: 'Error',
          message:
              'Error de conexión: ${e is SocketException ? 'Verifica tu red' : 'Error inesperado'}',
          isSuccess: false,
        );
      }
      return [];
    }
  }

  void _handleTokenExpiration() async {
    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tokenauth');

      _mostrarDialogo(
        title: 'Sesión expirada',
        message: 'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
        isSuccess: false,
        onClose: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        ),
      );
    }
  }

  void _agregarGrupo() async {
   if (selectedTipo == 'Grupal' && _selectedPersons.length == 1) {
  bool? cambiarAIndividual = await showDialog<bool>(
    context: context,
    builder: (context) => Theme(
      data: Theme.of(context).copyWith(
        dialogBackgroundColor: Colors.white,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFF5162F6),
          ),
        ),
      ),
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        contentPadding: EdgeInsets.only(top: 20, bottom: 20),
        title: Column(
          children: [
            Icon(
              Icons.group_remove,
              size: 60,
              color: Color(0xFF5162F6),),
            SizedBox(height: 15),
            Text(
              'Grupo Incompleto',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Los grupos de tipo "Grupal" requieren mínimo 2 integrantes.\n\n'
            '¿Desea cambiar el tipo a "Individual" para continuar?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
        actionsPadding: EdgeInsets.only(bottom: 20, right: 25, left: 25),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar'),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF5162F6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Cambiar Tipo'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  if (cambiarAIndividual == true) {
    setState(() => selectedTipo = 'Individual');
  } else {
    return;
  }
}

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorDeConexion = false;
      _dialogShown = false;
    });

    _timer = Timer(Duration(seconds: 10), () {
      if (mounted && !_dialogShown) {
        setState(() {
          _isLoading = false;
          _errorDeConexion = true;
        });
        _mostrarDialogo(
          title: 'Error',
          message: 'Tiempo de espera agotado. Verifica tu conexión.',
          isSuccess: false,
        );
      }
    });

    try {
      final grupoResponse = await _enviarGrupo();
      if (!mounted) return;

      if (grupoResponse != null) {
        final idGrupo = grupoResponse["idgrupos"];
        if (idGrupo != null) {
          final miembrosAgregados = await _enviarMiembros(idGrupo);
          if (!mounted) return;

          if (miembrosAgregados) {
            widget.onGrupoAgregado();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: Colors.green,
                content: Text('Grupo agregado correctamente')));
            Navigator.of(context).pop();
          }
        }
      }
    } finally {
      _timer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _enviarGrupo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.post(
        Uri.parse('http://$baseUrl/api/v1/grupos'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nombreGrupo': nombreGrupoController.text,
          'detalles': descripcionController.text,
          'tipoGrupo': selectedTipo,
          'isAdicional': esAdicional ? 'Sí' : 'No',
        }),
      );

      if (!mounted) return null;

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        _handleResponseError(response);
      }
    } catch (e) {
      if (mounted && !_dialogShown) {
        _mostrarDialogo(
            title: 'Error',
            message:
                'Error de conexión: ${e is SocketException ? 'Verifica tu red' : 'Error inesperado'}',
            isSuccess: false);
      }
    }
    return null;
  }

  void _handleResponseError(http.Response response) {
    final responseBody = jsonDecode(response.body);
    final errorCode = responseBody['Error']?['Code'] ?? response.statusCode;
    final errorMessage =
        responseBody['Error']?['Message'] ?? "Error desconocido";

    if (response.statusCode == 401 && errorMessage == "jwt expired") {
      _handleTokenExpiration();
    } else {
      _mostrarDialogo(
        title: 'Error ${response.statusCode}',
        message: errorMessage,
        isSuccess: false,
      );
    }
  }

// Función para enviar los miembros al grupo
  Future<bool> _enviarMiembros(String idGrupo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.post(
        Uri.parse('http://$baseUrl/api/v1/grupodetalles/'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'idgrupos': idGrupo,
          'clientes': _selectedPersons
              .map((persona) => {
                    'idcliente': persona['idclientes'],
                    'nomCargo':
                        _rolesSeleccionados[persona['idclientes']] ?? 'Miembro',
                  })
              .toList(),
          'idusuarios': _selectedUsuario?.idusuarios, // Agregar esta línea
        }),
      );

      if (!mounted) return false;

      if (response.statusCode == 201) return true;

      _handleResponseError(response);
      return false;
    } catch (e) {
      if (mounted && !_dialogShown) {
        _mostrarDialogo(
          title: 'Error',
          message:
              'Error de conexión: ${e is SocketException ? 'Verifica tu red' : 'Error inesperado'}',
          isSuccess: false,
        );
      }
      return false;
    }
  }

  void _mostrarDialogo({
    required String title,
    required String message,
    required bool isSuccess,
    VoidCallback? onClose,
  }) {
    if (!mounted || _dialogShown) return;

    _dialogShown = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose?.call();
            },
            child: Text('Aceptar'),
          ),
        ],
      ),
    ).then((_) => _dialogShown = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(20),
        child: _isLoadingUsuarios // Verificación principal aquí
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF5162F6),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Cargando usuarios...',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : _isLoading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : Column(
                    children: [
                      Text(
                        'Agregar Grupo',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Focus(
                        canRequestFocus: false,
                        descendantsAreFocusable: false,
                        child: IgnorePointer(
                          child: TabBar(
                            controller: _tabController,
                            labelColor: Color(0xFF5162F6),
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Color(0xFF5162F6),
                            tabs: [
                              Tab(text: 'Información del Grupo'),
                              Tab(text: 'Miembros del Grupo'),
                            ],
                          ),
                        ),
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
                                      _tabController
                                          .animateTo(_currentIndex + 1);
                                    } else {
                                      print(
                                          "Validación fallida en la pestaña $_currentIndex");
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
                  ? Color(0xFF5162F6)
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
                color: Color(0xFF5162F6),
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
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    // Contenedor circular de fondo rojo con el ícono
                    Container(
                      width: 120, // Ajustar tamaño del contenedor
                      height: 100,
                      decoration: BoxDecoration(
                        color: Color(0xFF5162F6), // Color de fondo rojo
                        shape: BoxShape.circle, // Forma circular
                      ),
                      child: Center(
                        child: Icon(
                          Icons.group,
                          size: 70, // Tamaño del ícono
                          color: Colors.white, // Color del ícono
                        ),
                      ),
                    ),
                    SizedBox(
                        height: verticalSpacing), // Espacio debajo del ícono
                    _buildTextField(
                      controller: nombreGrupoController,
                      label: 'Nombre del grupo',
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
                    ),
                    SizedBox(height: verticalSpacing),
                    _buildUsuarioDropdown(
                      value: _selectedUsuario,
                      hint: 'Seleccionar Asesor',
                      usuarios: _usuarios,
                      onChanged: (Usuario? newValue) {
                        setState(() {
                          _selectedUsuario = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Seleccione un asesor';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: verticalSpacing),
                    // Agregar el campo "¿Es Adicional?" como un checkbox
                    CheckboxListTile(
                      title: Text('¿Es Adicional?'),
                      value: esAdicional,
                      onChanged: (bool? newValue) {
                        setState(() {
                          esAdicional = newValue ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.symmetric(horizontal: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
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
      key: _miembrosGrupoFormKey,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                color: Color(0xFF5162F6),
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
                        _rolesSeleccionados[person['idclientes']] =
                            roles[0]; // Rol predeterminado
                      });
                      _controller.clear();
                    } else {
                      // Opcional: Mostrar un mensaje indicando que la persona ya fue agregada
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
                      final idCliente = person[
                          'idclientes']; // Usamos idclientes para acceder al rol

                      return ListTile(
                        title: Row(
                          children: [
                            // Mostrar la numeración antes del nombre
                            Text(
                              '${index + 1}. ', // Esto es para mostrar la numeración
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black),
                            ),
                            Text(
                              '${nombre} ${person['apellidoP'] ?? ''} ${person['apellidoM'] ?? ''}',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Teléfono: ${person['telefono'] ?? ''}'),
                            SizedBox(width: 10),
                            Text(
                                'Fecha de Nacimiento: ${person['fechaNac'] ?? ''}'),
                          ],
                        ),
                        trailing: DropdownButton<String>(
                          value: _rolesSeleccionados[
                              idCliente], // Usamos idCliente para obtener el rol seleccionado
                          onChanged: (nuevoRol) {
                            setState(() {
                              _rolesSeleccionados[idCliente] = nuevoRol!;
                            });
                          },
                          items: roles
                              .map<DropdownMenuItem<String>>(
                                (rol) => DropdownMenuItem<String>(
                                  value: rol,
                                  child: Text(rol),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
                ),
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

Widget _buildUsuarioDropdown({
  required Usuario? value,
  required String hint,
  required List<Usuario> usuarios,
  required void Function(Usuario?) onChanged,
  double fontSize = 12.0,
  String? Function(Usuario?)? validator,
}) {
  return DropdownButtonFormField<Usuario>(
    value: value,
    hint: Text(
      hint,
      style: TextStyle(fontSize: fontSize, color: Colors.black),
    ),
    items: usuarios.map((usuario) {
      return DropdownMenuItem<Usuario>(
        value: usuario,
        child: Text(
          usuario.nombreCompleto,
          style: TextStyle(fontSize: fontSize, color: Colors.black),
        ),
      );
    }).toList(),
    onChanged: onChanged,
    validator: validator,
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
      prefixIcon: Icon(Icons.person), // Icono agregado
    ),
    style: TextStyle(fontSize: fontSize, color: Colors.black),
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
    validator: validator,
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

class Usuario {
  final String idusuarios;
  final String usuario;
  final String tipoUsuario;
  final String nombreCompleto;
  final String fCreacion;

  Usuario({
    required this.idusuarios,
    required this.usuario,
    required this.tipoUsuario,
    required this.nombreCompleto,
    required this.fCreacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      idusuarios: json['idusuarios'],
      usuario: json['usuario'],
      tipoUsuario: json['tipoUsuario'],
      nombreCompleto: json['nombreCompleto'],
      fCreacion: json['fCreacion'],
    );
  }
}
