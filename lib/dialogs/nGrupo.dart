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

  // ¡NUEVO! Mapa para guardar los montos de adeudo por id de cliente
  final Map<String, double> _adeudosClientes = {};

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
            return [];
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
            return [];
          }
        } catch (parseError) {
          print('Error parseando respuesta: $parseError');
        }

        if (mounted && !_dialogShown) {
          _mostrarDialogo(
            title: 'Error',
            message: 'Error al buscar personas. Por favor intenta nuevamente.',
            isSuccess: false,
          );
        }
        return [];
      }
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

  // Nueva función para verificar si un cliente tiene adeudos
// Modificamos la función para que devuelva el monto del adeudo o null
  Future<double?> _verificarAdeudoCliente(String idCliente) async {
  if (idCliente.isEmpty) return null;

  print('🔍 Verificando adeudos para el cliente: $idCliente');

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';
    final url = Uri.parse(
        '$baseUrl/api/v1/grupodetalles/renovacion/clientes/$idCliente');

    final response = await http.get(
      url,
      headers: {'tokenauth': token},
    );

    print(
        '📥 Respuesta de adeudos [${response.statusCode}]: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      if (data.isNotEmpty) {
        // --- CAMBIO PRINCIPAL AQUÍ ---
        // Usamos fold para sumar todos los valores de 'descuento' en la lista.
        // Empezamos con un valor inicial de 0.0.
        final double totalAdeudo = data.fold<double>(0.0, (sum, item) {
          final descuento = item['descuento'];
          // Nos aseguramos que el descuento no sea nulo antes de sumarlo
          if (descuento != null) {
            // (descuento as num).toDouble() es para asegurar que manejamos int y double
            return sum + (descuento as num).toDouble();
          }
          return sum; // Si no hay descuento en este item, no sumamos nada.
        });
        // --- FIN DEL CAMBIO ---

        // Si el total es mayor que 0, significa que hay un adeudo.
        if (totalAdeudo > 0) {
          print('⚠️ ¡El cliente tiene un adeudo total de: $totalAdeudo!');
          return totalAdeudo;
        }
      }
    }
    // Si la respuesta no es 200, la lista está vacía o la suma es 0, no hay adeudo.
    print('✅ El cliente no tiene adeudos.');
    return null; // Devolvemos null para indicar que no hay adeudo
  } catch (e) {
    print('❌ Error al verificar adeudos del cliente: $e');
    return null; // En caso de error, asumimos que no hay adeudo
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

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      barrierDismissible: false, // Impide cerrar tocando fuera
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
    // Verificación para grupo individual con múltiples miembros
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

      if (cambiarAGrupal == true) {
        setState(() => selectedTipo = 'Grupal');
      } else {
        return;
      }
    }

    // Verificación para grupo grupal con un solo miembro
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
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            contentPadding: EdgeInsets.only(top: 20, bottom: 20),
            title: Column(
              children: [
                Icon(
                  Icons.group_remove,
                  size: 60,
                  color: Color(0xFF5162F6),
                ),
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
    // AHORA SOLO LLAMAMOS A UNA FUNCIÓN
    final bool exito = await _crearGrupoConMiembros();

    if (!mounted) return;

    if (exito) {
      // Si la función tuvo éxito, mostramos el mensaje y cerramos la pantalla
      widget.onGrupoAgregado();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Grupo agregado correctamente',
            style: TextStyle(color: Colors.white),
          )));
      Navigator.of(context).pop();
    }
    // No necesitamos un 'else' aquí, porque la función _crearGrupoConMiembros
    // ya se encarga de mostrar los diálogos de error.

  } finally {
    _timer?.cancel();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  // NUEVA FUNCIÓN QUE REEMPLAZA A LAS DOS ANTERIORES
Future<bool> _crearGrupoConMiembros() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    // 1. Construimos el cuerpo completo de la solicitud (el JSON que te pide el backend)
    final requestBody = {
      'nombreGrupo': nombreGrupoController.text,
      'detalles': descripcionController.text,
      'tipoGrupo': selectedTipo,
      'isAdicional': esAdicional ? 'Sí' : 'No',
      'idusuarios': _selectedUsuario?.idusuarios,
      'clientes': _selectedPersons.map((persona) => {
            // OJO: El backend pide 'idcliente', tu código anterior usaba 'idclientes'
            'idclientes': persona['idclientes'], 
            'nomCargo': _rolesSeleccionados[persona['idclientes']] ?? 'Miembro',
          }).toList(),
    };

    // Imprimimos para depuración (opcional pero recomendado)
    print('==== ENVIANDO DATOS AL NUEVO ENDPOINT ====');
    print('URL: $baseUrl/api/v1/grupodetalles'); // Asegúrate que esta sea la URL correcta
    print('Body: ${json.encode(requestBody)}');
    print('=========================================');

    // 2. Realizamos la llamada HTTP POST
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/grupodetalles'), // CONFIRMA SI ESTA ES LA URL CORRECTA DEL NUEVO ENDPOINT
      headers: {
        'tokenauth': token,
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );
    
    print('==== RESPUESTA RECIBIDA ====');
    print('Status code: ${response.statusCode}');
    print('Body: ${response.body}');
    print('===========================');

    if (!mounted) return false;

    // 3. Manejamos la respuesta
    if (response.statusCode == 201) {
      return true; // ¡Éxito!
    } else {
      // Reutilizamos toda tu excelente lógica de manejo de errores
      try {
        final errorData = json.decode(response.body);
        if (errorData["Error"] != null &&
            errorData["Error"]["Message"] == "La sesión ha cambiado. Cerrando sesión...") {
          if (mounted) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');
            _timer?.cancel();
            mostrarDialogoCierreSesion('La sesión ha cambiado. Cerrando sesión...', onClose: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            });
          }
        } else if (response.statusCode == 401 && errorData["Error"]["Message"] == "jwt expired" ||
                   response.statusCode == 404 && errorData["Error"]["Message"] == "jwt expired") { // Agrego 401 por si acaso
          if (mounted) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');
            _timer?.cancel();
            mostrarDialogoError('Tu sesión ha expirado. Por favor inicia sesión nuevamente.', onClose: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            });
          }
        } else {
          _handleResponseError(response); // Tu manejador de errores genérico
        }
      } catch (parseError) {
        _handleResponseError(response);
      }
      return false; // Hubo un error
    }
  } catch (e) {
    if (mounted && !_dialogShown) {
      _mostrarDialogo(
          title: 'Error de Conexión',
          message: e is SocketException ? 'No se pudo conectar al servidor. Verifica tu conexión a internet.' : 'Ocurrió un error inesperado.',
          isSuccess: false);
    }
    return false; // Hubo una excepción
  }
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
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor:
          isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA), // Fondo dinámico
      //surfaceTintColor: Colors.white,
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
            padding: EdgeInsets.symmetric(
                vertical: 20, horizontal: 10), // Espaciado vertical
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Paso 1
                _buildPasoItem(1, "Información del grupo", pasoActual == 1),
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
                      context: context,
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
                      context: context,
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Colores adaptados al tema
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[700]!;
    final Color backgroundMenuColor = Color(0xFF5162F6);
    final Color cardBackgroundColor =
        isDarkMode ? Colors.grey.shade800 : Colors.white;
    final Color inputBorderColor =
        isDarkMode ? Colors.grey.shade400 : Colors.black;

    int pasoActual = 2; // Paso actual que queremos marcar como activo

    return Form(
      key: _miembrosGrupoFormKey,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                color: backgroundMenuColor,
                borderRadius: BorderRadius.all(Radius.circular(20))),
            width: 250,
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Paso 1
                _buildPasoItem(1, "Información del grupo", pasoActual == 1),
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
                    style: TextStyle(color: textColor),
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
                    color: cardBackgroundColor,
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
                  onSelected: (person) async {
                    bool personaYaAgregada = _selectedPersons
                        .any((p) => p['idclientes'] == person['idclientes']);

                    if (personaYaAgregada) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'La persona ya ha sido agregada a la lista')));
                      _controller.clear();
                      return;
                    }

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Dialog(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 20),
                                Text("Verificando cliente..."),
                              ],
                            ),
                          ),
                        );
                      },
                    );

                    // La función ahora devuelve un double?
                    final double? montoAdeudo =
                        await _verificarAdeudoCliente(person['idclientes']);

                    if (mounted) Navigator.of(context).pop();

                    void agregarPersona() {
                      if (mounted) {
                        setState(() {
                          _selectedPersons.add(person);
                          _rolesSeleccionados[person['idclientes']] = roles[0];
                          // ¡NUEVO! Si hay adeudo, lo guardamos en nuestro mapa
                          if (montoAdeudo != null) {
                            _adeudosClientes[person['idclientes']] =
                                montoAdeudo;
                          }
                        });
                        _controller.clear();
                      }
                    }

                    // Comprobamos si el monto no es nulo
                    if (montoAdeudo != null) {
                      final bool? confirmar = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Cliente con Adeudo'),
                              ],
                            ),
                            // Mostramos el monto en el diálogo
                            content: Text(
                                'Este cliente parece tener un adeudo de \$${montoAdeudo.toStringAsFixed(2)}. ¿Deseas agregarlo al grupo de todas formas?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancelar'),
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                              ),
                              ElevatedButton(
                                child: const Text('Sí, agregar'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmar == true) {
                        agregarPersona();
                      }
                    } else {
                      agregarPersona();
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

                      // ¡NUEVO! Obtenemos el monto del adeudo desde nuestro mapa
                      final double? montoAdeudo = _adeudosClientes[idCliente];

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
                            Text(
                              'Teléfono: ${person['telefono'] ?? ''}',
                              style: TextStyle(color: subtitleColor),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'F. Nacimiento: ${person['fechaNac'] ?? ''}',
                              style: TextStyle(color: subtitleColor),
                            ),
                            SizedBox(width: 10),
                            // Aquí añadimos el estado al lado derecho
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
                            // ¡NUEVO! Mostramos el ícono y Tooltip si hay adeudo
                            if (montoAdeudo != null)
                              Tooltip(
                                message:
                                    'Adeudo anterior: \$${montoAdeudo.toStringAsFixed(2)}',
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                ),
                              ),

                            if (montoAdeudo != null) const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _rolesSeleccionados[idCliente],
                              dropdownColor: cardBackgroundColor,
                              onChanged: (nuevoRol) {
                                setState(() {
                                  _rolesSeleccionados[idCliente] = nuevoRol!;
                                });
                              },
                              items: roles
                                  .map<DropdownMenuItem<String>>(
                                    (rol) => DropdownMenuItem<String>(
                                      value: rol,
                                      child: Text(
                                        rol,
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            SizedBox(width: 10),
                            IconButton(
                              icon: Icon(Icons.delete,
                                  color: isDarkMode
                                      ? Colors.red.shade300
                                      : Colors.red),
                              onPressed: () {
                                setState(() {
                                  _selectedPersons.removeAt(index);
                                  _rolesSeleccionados.remove(idCliente);
                                  // ¡NUEVO! También lo quitamos de nuestro mapa de adeudos
                                  _adeudosClientes.remove(idCliente);
                                });
                              },
                            ),
                          ],
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
      case 'Disponible Extra':
        return Color(0xFFE53888).withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1); // Color suave de fondo por defecto
    }
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  required BuildContext context, // Añadido el parámetro BuildContext
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
  double fontSize = 12.0,
  int? maxLength,
  bool enabled = true,
}) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final isDarkMode = themeProvider.isDarkMode;

  // Colores para modo claro
  final lightTextColor = enabled ? Colors.black : Colors.grey;
  final lightIconColor = enabled ? Colors.black : Colors.grey;
  final lightLabelColor = enabled ? Colors.black : Colors.grey;
  final lightEnabledBorderColor = Colors.grey.shade700;
  final lightDisabledBorderColor = Colors.grey;
  final lightFillColor = Colors.white;

  // Colores para modo oscuro
  final darkTextColor = enabled ? Colors.white : Colors.grey.shade600;
  final darkIconColor = enabled ? Colors.grey.shade300 : Colors.grey.shade600;
  final darkLabelColor = enabled ? Colors.grey.shade300 : Colors.grey.shade600;
  final darkEnabledBorderColor = Colors.grey.shade500;
  final darkDisabledBorderColor = Colors.grey.shade700;
  final darkFillColor =
      enabled ? Color.fromARGB(255, 35, 35, 35) : Colors.grey.shade900;

  // Colores finales según el modo
  final textColor = isDarkMode ? darkTextColor : lightTextColor;
  final iconColor = isDarkMode ? darkIconColor : lightIconColor;
  final labelColor = isDarkMode ? darkLabelColor : lightLabelColor;
  final enabledBorderColor =
      isDarkMode ? darkEnabledBorderColor : lightEnabledBorderColor;
  final disabledBorderColor =
      isDarkMode ? darkDisabledBorderColor : lightDisabledBorderColor;
  final fillColor = isDarkMode ? darkFillColor : lightFillColor;
  final focusedBorderColor = isDarkMode ? Color(0xFF5162F6) : Colors.black;

  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    style: TextStyle(
      fontSize: fontSize,
      color: textColor,
    ),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: iconColor,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      labelStyle: TextStyle(
        fontSize: fontSize,
        color: labelColor,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: enabledBorderColor,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: disabledBorderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: focusedBorderColor,
          width: 1.5,
        ),
      ),
      fillColor: fillColor,
      filled: true,
    ),
    validator: validator,
    inputFormatters:
        maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : [],
    enabled: enabled,
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
