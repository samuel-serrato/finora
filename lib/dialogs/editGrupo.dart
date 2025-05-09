import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finora/models/usuarios.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class editGrupoDialog extends StatefulWidget {
  final VoidCallback onGrupoEditado;
  final String idGrupo; // Nuevo parámetro para recibir el idGrupo

  editGrupoDialog({required this.onGrupoEditado, required this.idGrupo});

  @override
  _editGrupoDialogState createState() => _editGrupoDialogState();
}

class _editGrupoDialogState extends State<editGrupoDialog>
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
  bool _dialogShown = false; // Evitar mostrar múltiples diálogos de error
  Set<String> originalMemberIds = {};

  Usuario? _selectedUsuario; // En lugar de 'late Usuario? _selectedUsuario'
  List<Usuario> _usuarios = [];
  bool _cargandoUsuarios = false;
  bool _isLoadingUsuarios = true; // Nueva variable de estado

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
    obtenerUsuarios(); // Agregar esta línea para cargar los usuarios

    print('Grupo seleccionado: ${widget.idGrupo}');
  }

  // Función para obtener los detalles del grupo
  // Función para obtener los detalles del grupo
  Future<void> fetchGrupoData() async {
    if (!mounted) return;

    print('Ejecutando fetchGrupoData');
    _timer?.cancel();

    setState(() => _isLoading = true);

    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading && !_dialogShown) {
        setState(() => _isLoading = false);
        mostrarDialogoError(
          'No se pudo conectar al servidor. Por favor, revise su conexión de red.',
        );
        _dialogShown = true;
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final url = '$baseUrl/api/v1/grupodetalles/${widget.idGrupo}';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;
      _timer?.cancel();

      if (response.statusCode == 200) {
        final data = json.decode(response.body)[0];
        List<Map<String, dynamic>> clientesActuales = [];

        setState(() {
          grupoData = data;
          _isLoading = false;
          nombreGrupoController.text = data['nombreGrupo'] ?? '';
          descripcionController.text = data['detalles'] ?? '';
          selectedTipo = data['tipoGrupo'];

          _selectedPersons.clear();
          _cargosSeleccionados.clear();
          originalMemberIds.clear();

          if (data['clientes'] != null) {
            clientesActuales =
                List<Map<String, dynamic>>.from(data['clientes']);
            _selectedPersons.addAll(clientesActuales);
            originalMemberIds = Set.from(
                clientesActuales.map((c) => c['idclientes'].toString()));

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

        // Llamar a _setInitialAsesor después de cargar los datos del grupo
        if (_usuarios.isNotEmpty) {
          _setInitialAsesor();
        }

        print('Clientes actuales del grupo:');
        for (var cliente in clientesActuales) {
          print(
              'id: ${cliente['idclientes']}, Nombre: ${cliente['nombres']}, Cargo: ${cliente['cargo']}');
        }
      } else {
        // Intentamos decodificar la respuesta para verificar mensajes específicos de error
        try {
          final errorData = json.decode(response.body);

          // Verificar si es el mensaje específico de sesión cambiada
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');

            // Mostrar diálogo y redirigir al login
            mostrarDialogoCierreSesion(
                'La sesión ha cambiado. Cerrando sesión...', onClose: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false, // Elimina todas las rutas anteriores
              );
            });
            return;
          }
          // Manejar error JWT expirado
          else if (response.statusCode == 404 &&
              errorData["Error"] != null &&
              errorData["Error"]["Message"] == "jwt expired") {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');

            mostrarDialogoError(
                'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                onClose: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            });
            return;
          }
          // Otros errores
          else {
            _handleResponseErrors(response);
          }
        } catch (parseError) {
          // Si no podemos parsear la respuesta, delegamos al manejador de errores existente
          _handleResponseErrors(response);
        }
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> obtenerUsuarios() async {
    setState(() => _isLoadingUsuarios = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/usuarios/tipo/campo'),
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

        // Llamar a _setInitialAsesor después de cargar los usuarios
        if (grupoData.isNotEmpty) {
          _setInitialAsesor();
        }
      } else {
        try {
          final errorData = json.decode(response.body);

          // Verificar si es el mensaje específico de sesión cambiada
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');
              _timer?.cancel();

              // Mostrar diálogo y redirigir al login
              mostrarDialogoCierreSesion(
                  'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false, // Elimina todas las rutas anteriores
                );
              });
            }
            return;
          }
          // Manejar error JWT expirado
          else if (response.statusCode == 404 &&
              errorData["Error"]["Message"] == "jwt expired") {
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');
              _timer?.cancel();
              mostrarDialogoError(
                  'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                  onClose: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              });
            }
            return;
          }
        } catch (parseError) {
          print('Error parseando respuesta: $parseError');
        }
      }
    } catch (e) {
      print('Error obteniendo usuarios: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsuarios = false);
      }
    }
  }

  void _setInitialAsesor() {
    if (grupoData['asesor'] != null && _usuarios.isNotEmpty) {
      // Buscar por ID si está disponible
      if (grupoData['idusuario'] != null) {
        Usuario? foundUsuario = _usuarios.firstWhere(
          (usuario) => usuario.idusuarios == grupoData['idusuario'],
          orElse: () => null!,
        );
        if (foundUsuario != null) {
          setState(() => _selectedUsuario = foundUsuario);
          return;
        }
      }

      // Fallback a búsqueda por nombre
      Usuario? foundUsuario = _usuarios.firstWhere(
        (usuario) => usuario.nombreCompleto == grupoData['asesor'],
        orElse: () => null!,
      );
      if (foundUsuario != null) {
        setState(() => _selectedUsuario = foundUsuario);
      }
    }
  }

  void mostrarDialogoCierreSesion(String mensaje,
      {required Function() onClose}) {
    // Detectar si estamos en modo oscuro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          contentPadding: EdgeInsets.only(top: 25, bottom: 10),
          title: Column(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 60,
                color: Colors.red[700],
              ),
              SizedBox(height: 15),
              Text(
                'Sesión Finalizada',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          actionsPadding: EdgeInsets.only(bottom: 20, right: 25, left: 25),
          actions: [
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(double.infinity, 48), // Ancho completo
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onClose();
              },
              child: Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleResponseErrors(http.Response response) {
    print('Error response body: ${response.body}');
    print('Status code: ${response.statusCode}');

    try {
      final dynamic errorData = json.decode(response.body);
      final String errorMessage = _extractErrorMessage(errorData);
      final int statusCode = response.statusCode;

      if (_isTokenExpiredError(statusCode, errorMessage)) {
        _handleTokenExpiration();
      } else if (statusCode == 404) {
        mostrarDialogoError('Recurso no encontrado (404)');
      } else {
        mostrarDialogoError('Error $statusCode: $errorMessage');
      }
    } catch (e) {
      mostrarDialogoError('Error desconocido: ${response.body}');
    }
  }

  String _extractErrorMessage(dynamic errorData) {
    try {
      return errorData?['error']?['message']?.toString() ??
          errorData?['Error']?['Message']?.toString() ??
          errorData?['message']?.toString() ??
          'Mensaje de error no disponible';
    } catch (e) {
      return 'Error al parsear mensaje';
    }
  }

  bool _isTokenExpiredError(int statusCode, String errorMessage) {
    final lowerMessage = errorMessage.toLowerCase();
    return statusCode == 401 ||
        statusCode == 403 ||
        (statusCode == 404 && lowerMessage.contains('token')) ||
        lowerMessage.contains('jwt') ||
        lowerMessage.contains('expir');
  }

  // Función para mostrar el diálogo de error
  // Función para mostrar el diálogo de error
  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    if (!mounted) return;

    _dialogShown = true;
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
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    ).then((_) => _dialogShown = false);
  }

  bool _validarFormularioActual() {
    if (_currentIndex == 0) {
      return _infoGrupoFormKey.currentState?.validate() ?? false;
    } else if (_currentIndex == 1) {
      // Si no hay campos obligatorios en miembros, retorna true directamente
      return true;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> findPersons(String query) async {
    if (query.isEmpty) return [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/clientes/$query'),
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

  Future<void> actualizarAsesor(String idGrupo, String idUsuario) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/grupodetalles/$idGrupo'),
        headers: {'Content-Type': 'application/json', 'tokenauth': token},
        body: json.encode({"idusuarios": idUsuario}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // 1. Actualizar el estado local del grupo editado
        setState(() {
          grupoData['idusuario'] = idUsuario;
          grupoData['asesor'] = _usuarios
              .firstWhere((u) => u.idusuarios == idUsuario)
              .nombreCompleto;
        });

        // 2. Notificar a la pantalla principal para refrescar
        widget.onGrupoEditado();

        if (mounted) {
          /* ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Asesor actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          ); */
        }
      } else {
        final errorData = json.decode(response.body);
        final mensajeError =
            errorData['error']?['message'] ?? 'Error desconocido';

        if (mounted) {
          mostrarDialogoError('Error al actualizar asesor: $mensajeError');
        }
      }
    } catch (e) {
      _handleNetworkError(e);
      if (mounted) {
        mostrarDialogoError('Error de conexión al actualizar asesor');
      }
    }
  }

  Future<void> enviarGrupo() async {
    if (!mounted) return;

    if (nombreGrupoController.text.isEmpty ||
        descripcionController.text.isEmpty ||
        selectedTipo == null) {
      mostrarDialogoError("Por favor, completa todos los campos obligatorios.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/grupos/${widget.idGrupo}'),
        headers: {'Content-Type': 'application/json', 'tokenauth': token},
        body: json.encode({
          "nombreGrupo": nombreGrupoController.text,
          "detalles": descripcionController.text,
          "tipoGrupo": selectedTipo
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        widget.onGrupoEditado();
        if (mounted) {
          /* ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grupo actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          ); */
        }
      } else {
        try {
          final errorData = json.decode(response.body);

          // Verificar si es el mensaje específico de sesión cambiada
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');
              _timer?.cancel();

              // Mostrar diálogo y redirigir al login
              mostrarDialogoCierreSesion(
                  'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false, // Elimina todas las rutas anteriores
                );
              });
            }
            return;
          }
          // Manejar error JWT expirado
          else if (response.statusCode == 404 &&
              errorData["Error"]["Message"] == "jwt expired") {
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');
              _timer?.cancel();
              mostrarDialogoError(
                  'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                  onClose: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              });
            }
            return;
          }
          // Manejar códigos de error específicos
          else if (response.statusCode == 401 || response.statusCode == 403) {
            _handleTokenExpiration();
          } else {
            _handleApiError(response, 'Error al actualizar el grupo');
          }
        } catch (parseError) {
          // Si no se puede parsear el JSON, usar el manejador de API error genérico
          _handleApiError(response, 'Error al actualizar el grupo');
        }
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 1. Modificar _enviarMiembros para enviar todos los miembros en una sola solicitud
  Future<bool> _enviarMiembros(String idGrupo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // Filtrar solo nuevos miembros (no existentes originalmente)
      final nuevosMiembros = _selectedPersons
          .where((persona) =>
              !originalMemberIds.contains(persona['idclientes'].toString()))
          .toList();

      if (nuevosMiembros.isEmpty) return true; // No hay miembros nuevos

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/grupodetalles/'),
        headers: {'Content-Type': 'application/json', 'tokenauth': token},
        body: json.encode({
          'idgrupos': idGrupo,
          'clientes': nuevosMiembros
              .map((persona) => {
                    'idclientes':
                        persona['idclientes'].toString(), // Asegurar string
                    'nomCargo': _cargosSeleccionados[
                        persona['idclientes'] ?? 'Miembro'],
                  })
              .toList(),
          'idusuarios': grupoData['idusuario'], // Ajustar según tu lógica
        }),
      );

      print('Body enviado: ${json.encode({
            'idgrupos': idGrupo,
            'clientes': nuevosMiembros
                .map((persona) => {
                      'idclientes': persona['idclientes'].toString(),
                      'nomCargo': _cargosSeleccionados[persona['idclientes']] ??
                          'Miembro',
                    })
                .toList(),
            'idusuarios': grupoData['idusuario'] ?? '6KNV796U0O',
          })}');

      if (!mounted) return false;

      if (response.statusCode == 201) {
        return true;
      } else {
        _handleApiError(response, 'Error al agregar miembros');
        return false;
      }
    } catch (e) {
      _handleNetworkError(e);
      return false;
    }
  }

// 2. Actualizar editarGrupo para manejar el nuevo flujo
  Future<void> editarGrupo() async {
    if (!_validarFormularioActual()) return;

    // Validación para tipo Individual con múltiples miembros
    if (selectedTipo == 'Individual' && _selectedPersons.length > 1) {
      bool? cambiarAGrupal = await showDialog<bool>(
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
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            contentPadding: EdgeInsets.only(top: 20, bottom: 20),
            title: Column(
              children: [
                Icon(
                  Icons.group_add,
                  size: 60,
                  color: Color(0xFF5162F6),
                ),
                SizedBox(height: 15),
                Text(
                  'Varios Integrantes',
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
                'Has seleccionado ${_selectedPersons.length} integrantes, pero el tipo de grupo es "Individual".\n\n'
                '¿Desea cambiar el tipo a "Grupal" para continuar?',
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

      if (cambiarAGrupal != true) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) setState(() => selectedTipo = 'Grupal');
    }

    // Validación para tipo Grupal con menos de 2 miembros
    if (selectedTipo == 'Grupal' && _selectedPersons.length < 2) {
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
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0)),
                  contentPadding: EdgeInsets.only(top: 20, bottom: 20),
                  title: Column(
                    children: [
                      Icon(Icons.group_remove,
                          size: 60, color: Color(0xFF5162F6)),
                      SizedBox(height: 15),
                      Text(
                        'Grupo Incompleto',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ],
                  ),
                  content: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Los grupos de tipo "Grupal" requieren mínimo 2 integrantes.\n\n'
                      '¿Desea cambiar el tipo a "Individual" para continuar?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[700], height: 1.4),
                    ),
                  ),
                  actionsPadding:
                      EdgeInsets.only(bottom: 20, right: 25, left: 25),
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
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancelar')),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF5162F6),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('Cambiar Tipo')),
                        ),
                      ],
                    ),
                  ],
                ),
              ));

      if (cambiarAIndividual != true) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) setState(() => selectedTipo = 'Individual');
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // 1. Actualizar datos básicos del grupo
      await enviarGrupo();

      // 2. Actualizar asesor si hubo cambios
      final String? idAsesorOriginal = grupoData['idusuario'];
      final String? nuevoIdAsesor = _selectedUsuario?.idusuarios;

      if (nuevoIdAsesor != null && nuevoIdAsesor != idAsesorOriginal) {
        await actualizarAsesor(widget.idGrupo, nuevoIdAsesor);
      }

      // 3. Resto del proceso (miembros, etc.)
      await eliminarClienteGrupo(widget.idGrupo, token);
      verificarCambios();
      final success = await _enviarMiembros(widget.idGrupo);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grupo actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      mostrarDialogoError('Error durante la actualización: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> eliminarClienteGrupo(String idGrupo, String token) async {
    if (_clientesEliminados.isEmpty) return;

    try {
      for (String idCliente in _clientesEliminados) {
        final response = await http.delete(
          Uri.parse('$baseUrl/api/v1/grupodetalles/$idGrupo/$idCliente'),
          headers: {'tokenauth': token},
        );

        if (response.statusCode != 200) {
          throw Exception('Error al eliminar cliente: ${response.body}');
        }
      }
    } finally {
      _clientesEliminados.clear();
    }
  }

  void verificarCambios() async {
    if (!mounted) return;

    List<Map<String, dynamic>> cambios = [];
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    _originalCargos.forEach((idCliente, cargoOriginal) {
      final cargoEditado = _cargosSeleccionados[idCliente];
      if (cargoOriginal != cargoEditado) {
        cambios.add({
          'idCliente': idCliente,
          'cargoOriginal': cargoOriginal,
          'cargoEditado': cargoEditado,
        });
      }
    });

    if (cambios.isNotEmpty) {
      print('Cambios detectados:');
      for (var cambio in cambios) {
        print(
            'Cliente: ${cambio['idCliente']}, Cargo Original: ${cambio['cargoOriginal']}, Cargo Editado: ${cambio['cargoEditado']}');

        try {
          await actualizarCargo(
              widget.idGrupo,
              cambio['idCliente'].toString(), // Asegurar conversión a String
              cambio['cargoEditado'].toString(),
              token // Enviamos el token aquí
              );
        } catch (e) {
          if (mounted) {
            mostrarDialogoError('Error actualizando cargo: ${e.toString()}');
          }
        }
      }
    } else {
      print('No hay cambios detectados.');
    }
  }

  Future<void> actualizarCargo(
    String idGrupo,
    String idCliente,
    String nuevoCargo,
    String token,
  ) async {
    print('Actualizando cargo: $idGrupo, $idCliente, $nuevoCargo'); // Log
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/grupodetalles/cargo/$idGrupo/$idCliente'),
        headers: {'Content-Type': 'application/json', 'tokenauth': token},
        body: json.encode({'nomCargo': nuevoCargo}),
      );

      print('Respuesta actualizar cargo: ${response.statusCode}'); // Log
      if (response.statusCode != 200) {
        throw Exception('Error actualizando cargo: ${response.body}');
      }
    } catch (e) {
      print('Error al actualizar cargo: $e');
      rethrow;
    }
  }

// Funciones de ayuda para manejo de errores

  void _handleApiError(http.Response response, String mensajeBase) {
    final errorData = json.decode(response.body);
    final mensajeError = errorData['error']?['message'] ?? 'Error desconocido';

    mostrarDialogoError(
        '$mensajeBase: $mensajeError (Código: ${response.statusCode})');
  }

  void _handleNetworkError(dynamic e) {
    if (e is SocketException) {
      mostrarDialogoError(
          'Error de conexión. Verifica tu conexión a internet.');
    } else {
      mostrarDialogoError('Error inesperado: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: isDarkMode ? Color(0xFF212121) : Colors.white,
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
                    'Editar Grupo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                                  await editarGrupo(); // Espera a que la función termine
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
            child: Padding(
              padding: EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  // Contenedor circular de fondo rojo con el ícono
                  Container(
                    width: 120, // Ajustar tamaño del contenedor
                    height: 120,
                    decoration: BoxDecoration(
                      color: Color(0xFF5162F6), // Color de fondo rojo
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
                        return 'Por favor ingrese el nombre del grupo';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: verticalSpacing),
                  _buildDropdown(
                    context: context,
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
                    context: context,
                    value: _selectedUsuario,
                    hint: 'Seleccionar Asesor',
                    usuarios: _usuarios,
                    onChanged: (Usuario? newValue) {
                      setState(() => _selectedUsuario = newValue);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Seleccione un asesor';
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
    );
  }

  Widget _paginaMiembros() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    int pasoActual = 2; // Paso actual que queremos marcar como activo

    // Colores adaptados al tema
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[700]!;
    final Color backgroundMenuColor = Color(0xFF5162F6);
    final Color cardBackgroundColor =
        isDarkMode ? Colors.grey.shade800 : Colors.white;
    final Color inputBorderColor =
        isDarkMode ? Colors.grey.shade400 : Colors.black;

    return Form(
      key: _miembrosGrupoFormKey, // ¡Agrega esta línea!
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
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: inputBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color:
                                isDarkMode ? Colors.blue : Color(0xFF5162F6)),
                      ),
                      hintText: 'Escribe para buscar',
                      hintStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
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
                                color: textColor,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 10),
                          Text('-  F. Nacimiento: ${person['fechaNac'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: subtitleColor)),
                          SizedBox(width: 10),
                          Text('-  Teléfono: ${person['telefono'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: subtitleColor)),
                          Expanded(
                              child:
                                  SizedBox()), // Esto empuja el estado hacia la derecha
                          // Container para el estado
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(person['estado']),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(person['estado'])
                                    .withOpacity(
                                        0.6), // Borde con el mismo color pero más fuerte
                                width: 1, // Grosor del borde
                              ),
                            ),
                            child: Text(
                              person['estado'] ?? 'N/A',
                              style: TextStyle(
                                color: _getStatusColor(person['estado'])
                                    .withOpacity(
                                        0.8), // Color del texto más oscuro
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                  loadingBuilder: (context) =>
                      Text('Cargando...', style: TextStyle(color: textColor)),
                  errorBuilder: (context, error) => Text(
                      'Error al cargar los datos!',
                      style: TextStyle(
                          color:
                              isDarkMode ? Colors.red.shade300 : Colors.red)),
                  emptyBuilder: (context) => Text('No hay coincidencias!',
                      style: TextStyle(color: textColor)),
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
                            Text(
                              '${index + 1}. ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textColor),
                            ),
                            Text(
                              '${nombre} ${person['apellidoP'] ?? ''} ${person['apellidoM'] ?? ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textColor,
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
                                  color: subtitleColor),
                            ),
                            // Fecha de nacimiento
                            SizedBox(width: 30),
                            Text(
                              'Fecha de Nacimiento: $fechaNac',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: subtitleColor),
                            ),
                            SizedBox(width: 10),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              decoration: BoxDecoration(
                                color: _getStatusColor(person['estado']),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(person['estado'])
                                      .withOpacity(
                                          0.6), // Borde con el mismo color pero más fuerte
                                  width: 1, // Grosor del borde
                                ),
                              ),
                              child: Text(
                                person['estado'] ?? 'N/A',
                                style: TextStyle(
                                  color: _getStatusColor(person['estado'])
                                      .withOpacity(
                                          0.8), // Color del texto más oscuro
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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

  Color _getStatusColor(String? estado) {
    switch (estado) {
      case 'En Credito':
        return Color(0xFFA31D1D)
            .withOpacity(0.1); // Color suave de fondo para "En Credito"
      case 'En Grupo':
        return Color(0xFF3674B5)
            .withOpacity(0.1); // Color suave de fondo para "En Grupo"
      case 'Disponible':
        return Color(0xFF059212)
            .withOpacity(0.1); // Color suave de fondo para "Disponible"
      default:
        return Colors.grey.withOpacity(0.1); // Color suave de fondo por defecto
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
  required BuildContext context,
  required void Function(String?) onChanged,
  double fontSize = 12.0,
  String? Function(String?)? validator,
}) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final isDarkMode = themeProvider.isDarkMode;

  // Colores adaptados según el tema
  final Color textColor = isDarkMode ? Colors.white : Colors.black;
  final Color borderColor = isDarkMode ? Colors.grey.shade400 : Colors.black;
  final Color enabledBorderColor =
      isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700;
  final Color iconColor = isDarkMode ? Colors.white70 : Colors.black87;

  return DropdownButtonFormField<String>(
    value: value,
    hint: value == null
        ? Text(
            hint,
            style: TextStyle(fontSize: fontSize, color: textColor),
          )
        : null,
    items: items.map((item) {
      return DropdownMenuItem(
        value: item,
        child: Text(
          item,
          style: TextStyle(fontSize: fontSize, color: textColor),
        ),
      );
    }).toList(),
    onChanged: onChanged,
    validator: validator,
    decoration: InputDecoration(
      labelText: value != null ? hint : null,
      labelStyle: TextStyle(color: textColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
    ),
    style: TextStyle(fontSize: fontSize, color: textColor),
    dropdownColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
    icon: Icon(Icons.arrow_drop_down, color: iconColor),
  );
}

Widget _buildUsuarioDropdown({
  required Usuario? value,
  required String hint,
  required List<Usuario> usuarios,
  required BuildContext context,
  required void Function(Usuario?) onChanged,
  double fontSize = 12.0,
  String? Function(Usuario?)? validator,
}) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final isDarkMode = themeProvider.isDarkMode;

  // Colores adaptados según el tema
  final Color textColor = isDarkMode ? Colors.white : Colors.black;
  final Color borderColor = isDarkMode ? Colors.grey.shade400 : Colors.black;
  final Color enabledBorderColor =
      isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700;
  final Color iconColor = isDarkMode ? Colors.white70 : Colors.black87;

  return DropdownButtonFormField<Usuario>(
    value: value,
    hint: Text(
      hint,
      style: TextStyle(fontSize: fontSize, color: textColor),
    ),
    items: usuarios.map((usuario) {
      return DropdownMenuItem<Usuario>(
        value: usuario,
        child: Text(
          usuario.nombreCompleto,
          style: TextStyle(fontSize: fontSize, color: textColor),
        ),
      );
    }).toList(),
    onChanged: onChanged,
    validator: validator,
    decoration: InputDecoration(
      labelText: value != null ? hint : null,
      labelStyle: TextStyle(color: textColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      prefixIcon: Icon(Icons.person, color: iconColor),
    ),
    style: TextStyle(fontSize: fontSize, color: textColor),
    dropdownColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
    icon: Icon(Icons.arrow_drop_down, color: iconColor),
  );
}
