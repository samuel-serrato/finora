import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class renovarGrupoDialog extends StatefulWidget {
  final VoidCallback onGrupoRenovado;
  final String idGrupo;

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

  List<String> _clientesEliminados = [];

  String? selectedTipo;

  List<String> tiposGrupo = ['Grupal', 'Individual', 'Selecto'];
  List<String> cargos = ['Miembro', 'Presidente/a', 'Tesorero/a'];

  Map<String, String> _cargosSeleccionados = {};

  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _infoGrupoFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _miembrosGrupoFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  Map<String, dynamic> grupoData = {};
  Timer? _timer;
  bool dialogShown = false;
  bool _dialogShown = false;

  // <-- NUEVO: Variables de estado para los descuentos de renovación
  bool _cargandoDescuentos = false;
  Map<String, double> _descuentosRenovacion = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
    fetchGrupoData();
    _fetchDescuentosRenovacion(widget
        .idGrupo); // <-- NUEVO: Llamamos a la función para obtener los adeudos

    print('Grupo seleccionado para renovar: ${widget.idGrupo}');
  }

  // <-- NUEVO: La función que me proporcionaste para obtener los adeudos
  Future<void> _fetchDescuentosRenovacion(String idgrupo) async {
  // Si no hay ID de grupo, no hacemos nada.
  if (idgrupo.isEmpty) return;

  if (!mounted) return;
  setState(() {
    _cargandoDescuentos = true;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';
    final url =
        Uri.parse('$baseUrl/api/v1/grupodetalles/renovacion/$idgrupo');

    final response = await http.get(
      url,
      headers: {'tokenauth': token},
    );

    // El mapa donde acumularemos los totales por cliente.
    final Map<String, double> descuentosObtenidos = {};

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      // Iteramos sobre cada registro de descuento recibido.
      for (var item in data) {
        final String? idCliente = item['idclientes'];
        final num? descuento = item['descuento'];
        final String? idGrupoNuevo = item['idgrupoNuevo'];

        // Verificamos que los datos necesarios existan y que no sea del mismo grupo.
        if (idCliente != null && descuento != null && idgrupo != idGrupoNuevo) {

          // --- LÓGICA DE SUMA MODIFICADA ---
          // Obtenemos el descuento ya acumulado para este cliente (o 0.0 si es el primero)
          // y le sumamos el valor del descuento actual.
          descuentosObtenidos[idCliente] = (descuentosObtenidos[idCliente] ?? 0.0) + descuento.toDouble();
          // --- FIN DE LA MODIFICACIÓN ---

        }
      }
      print("Adeudos de renovación totales por cliente: $descuentosObtenidos");

    } else {
      print(
          'Respuesta de descuentos no fue 200: ${response.statusCode} - ${response.body}');
    }

    if (mounted) {
      setState(() {
        _descuentosRenovacion = descuentosObtenidos;
        _cargandoDescuentos = false;
      });
    }
  } catch (e) {
    print('Error al obtener descuentos de renovación: $e');
    if (mounted) {
      setState(() {
        _cargandoDescuentos = false;
      });
    }
  }
}

  // Función para obtener los detalles del grupo
  // Función para obtener los detalles del grupo con manejo de token y errores
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
              clientesActuales =
                  List<Map<String, dynamic>>.from(data['clientes']);
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
        clientesActuales.forEach((cliente) => print(
            'id: ${cliente['idclientes']}, Nombre: ${cliente['nombres']}'));
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
          } else {
            _handleApiError(response, 'Error cargando grupo');
          }
        } catch (parseError) {
          // Si no se puede parsear el cuerpo de la respuesta, manejar como error genérico
          _handleApiError(response, 'Error cargando grupo');
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
        Uri.parse('$baseUrl/api/v1/clientes/$query'),
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

  // Esta es la única función que necesitas ahora para renovar
void _renovarGrupo() async {
  if (!mounted) return;

  setState(() => _isLoading = true);

  // El timer para controlar el tiempo de espera sigue siendo una excelente idea
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

    // 1. Construimos el cuerpo completo de la solicitud (el nuevo JSON)
    final Map<String, dynamic> requestBody = {
      // Datos del grupo a renovar y sus nuevas propiedades
      'idgrupos': widget.idGrupo, // El ID del grupo original que se está renovando
      'nombreGrupo': nombreGrupoController.text,
      'detalles': descripcionController.text,
      'tipoGrupo': selectedTipo,
      // NOTA: El JSON de ejemplo incluye 'isAdicional'. Asegúrate de tener esta variable.
      // Si no la tienes, puedes quitar esta línea o ajustarla.
      //'isAdicional': esAdicional ? 'Sí' : 'No', 

      // Datos de los miembros y el usuario
      // NOTA: Tu código anterior usaba 'grupoData['idusuario']'. Asegúrate de que esta variable esté disponible aquí.
      'idusuarios': grupoData['idusuario'], 
      'clientes': _selectedPersons.map((persona) => {
            // OJO: El backend ahora pide 'idcliente' (singular), no 'idclientes' (plural)
            'idclientes': persona['idclientes'],
            'nomCargo': _cargosSeleccionados[persona['idclientes']] ?? 'Miembro',
          }).toList(),
    };

    // 2. Definimos la URL del endpoint unificado
    // CONFIRMA si esta es la URL correcta. A menudo es la misma que la anterior para renovar el grupo.
    final url = '$baseUrl/api/v1/grupodetalles/renovacion';

    // Logs para depuración (muy útiles)
    print('🔁 Renovando grupo (Endpoint Unificado)...');
    print('⏩ POST $url');
    print('📤 Body: ${json.encode(requestBody)}');

    // 3. Realizamos la única llamada HTTP
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'tokenauth': token,
      },
      body: json.encode(requestBody),
    );

    print('📥 Código de respuesta: ${response.statusCode}');
    print('📦 Cuerpo de respuesta: ${response.body}');

    if (!mounted) return;
    _timer?.cancel();

    // 4. Manejamos la respuesta
    if (response.statusCode == 201) {
      // ¡Éxito! Ya no necesitamos obtener un nuevo ID ni llamar a otra función.
      widget.onGrupoRenovado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grupo renovado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      // Probablemente quieras cerrar la pantalla después de renovar con éxito
      //Navigator.of(context).pop();

    } else {
      // Reutilizamos tu excelente lógica de manejo de errores
      try {
        final errorData = json.decode(response.body);
        if (errorData["Error"] != null &&
            errorData["Error"]["Message"] ==
                "La sesión ha cambiado. Cerrando sesión...") {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');

            mostrarDialogoCierreSesion(
                'La sesión ha cambiado. Cerrando sesión...', onClose: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            });
            return;
          } else if (response.statusCode == 404 &&
              errorData["Error"]?["Message"] == "jwt expired") {
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
          } else {
            _handleApiError(response, 'Error renovando grupo');
          }
        } catch (parseError) {
          _handleApiError(response, 'Error renovando grupo');
        }
      }
    } catch (e) {
      print('❌ Excepción renovando grupo: $e');
      _handleNetworkError(e);
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _enviarMiembros(String idGrupo, String token) async {
    try {
      final miembros = _selectedPersons
          .map((persona) => {
                'idclientes': persona['idclientes'],
                'nomCargo':
                    _cargosSeleccionados[persona['idclientes']] ?? 'Miembro',
              })
          .toList();

      final requestBody = {
        'idgrupos': idGrupo,
        'clientes': miembros,
        'idusuarios': grupoData['idusuario'],
      };

      final url = '$baseUrl/api/v1/grupodetalles/renovacion';

      print('👥 Enviando miembros...');
      print('⏩ POST $url');
      print('📤 Headers: {Content-Type: application/json, tokenauth: $token}');
      print('📤 Body: $requestBody');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'tokenauth': token,
        },
        body: json.encode(requestBody),
      );

      print('📥 Código de respuesta: ${response.statusCode}');
      print('📦 Cuerpo de respuesta: ${response.body}');

      if (response.statusCode != 201) {
        try {
          final errorData = json.decode(response.body);

          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');

            mostrarDialogoCierreSesion(
                'La sesión ha cambiado. Cerrando sesión...', onClose: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            });
            return;
          } else if (response.statusCode == 404 &&
              errorData["Error"]?["Message"] == "jwt expired") {
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
          } else {
            _handleApiError(response, 'Error agregando miembros');
          }
        } catch (parseError) {
          _handleApiError(response, 'Error agregando miembros');
        }
      }
    } catch (e) {
      print('❌ Excepción al enviar miembros: $e');
      _handleNetworkError(e);
    }
  }

  void _handleApiError(http.Response response, String mensajeBase) {
    try {
      final errorData = json.decode(response.body);
      final errorMessage = (errorData['Error']?['Message'] ??
              errorData['error']?['message'] ??
              'Error desconocido')
          .toString();

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
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA),
      //surfaceTintColor: Colors.white,
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
                    context: context,
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    return Form(
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF5162F6), // El color principal se mantiene
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            width: 250,
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
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[400]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0xFF5162F6),
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  decorationBuilder: (context, child) => Material(
                    type: MaterialType.card,
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
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
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            '-  F. Nacimiento: ${person['fechaNac'] ?? ''}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            '-  Teléfono: ${person['telefono'] ?? ''}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                            ),
                          ),
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
                        content:
                            Text('La persona ya ha sido agregada a la lista'),
                        backgroundColor: isDarkMode ? Colors.grey[800] : null,
                      ));
                    }
                  },
                  controller: _controller,
                  loadingBuilder: (context) => Text(
                    'Cargando...',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  errorBuilder: (context, error) => Text(
                    'Error al cargar los datos!',
                    style: TextStyle(
                      color: isDarkMode ? Colors.red[300] : Colors.red,
                    ),
                  ),
                  emptyBuilder: (context) => Text(
                    'No hay coincidencias!',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
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

                      // <-- MODIFICADO: Lógica para verificar el adeudo
                      final tieneAdeudo =
                          _descuentosRenovacion.containsKey(idCliente);
                      final montoAdeudo =
                          tieneAdeudo ? _descuentosRenovacion[idCliente] : 0.0;

                      return // OPCIÓN 1: Mover el ícono al trailing junto con los otros controles
                          ListTile(
                        title: Row(
                          children: [
                            // Mostrar numeración antes del nombre
                            Text(
                              '${index + 1}. ', // Numeración
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            // Nombre completo
                            Expanded(
                              child: Text(
                                '${nombre} ${person['apellidoP'] ?? ''} ${person['apellidoM'] ?? ''}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
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
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                            // Fecha de nacimiento
                            SizedBox(width: 30),
                            Text(
                              'F. de Nacimiento: $fechaNac',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                            SizedBox(width: 10),
                            // Container para el estado
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              decoration: BoxDecoration(
                                color: _getStatusColor(person['estado']),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(person['estado'])
                                      .withOpacity(0.6),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                person['estado'] ?? 'N/A',
                                style: TextStyle(
                                  color: _getStatusColor(person['estado'])
                                      .withOpacity(0.8),
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
                            // ÍCONO DE WARNING AQUÍ - mejor alineado
                            if (tieneAdeudo)
                              Tooltip(
                                message:
                                    'Adeudo anterior: \$${montoAdeudo?.toStringAsFixed(2)}',
                                child: Container(
                                  margin: EdgeInsets.only(right: 8.0),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                ),
                              ),
                            SizedBox(width: 8),
                            // Dropdown para seleccionar cargo
                            Theme(
                              data: Theme.of(context).copyWith(
                                canvasColor: isDarkMode
                                    ? Colors.grey[850]
                                    : Colors.white,
                              ),
                              child: DropdownButton<String>(
                                value: _cargosSeleccionados[
                                        person['idclientes']] ??
                                    'Miembro',
                                onChanged: (nuevoCargo) {
                                  setState(() {
                                    _cargosSeleccionados[person['idclientes']] =
                                        nuevoCargo!;
                                  });
                                },
                                items: cargos
                                    .map<DropdownMenuItem<String>>((cargo) {
                                  return DropdownMenuItem<String>(
                                    value: cargo,
                                    child: Text(
                                      cargo,
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                dropdownColor: isDarkMode
                                    ? Colors.grey[850]
                                    : Colors.white,
                                style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Ícono de eliminar
                            IconButton(
                              onPressed: () async {
                                final confirmDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: isDarkMode
                                        ? Colors.grey[850]
                                        : Colors.white,
                                    title: Text(
                                      'Confirmar eliminación',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    content: Text(
                                      '¿Estás seguro de que quieres eliminar a ${nombre} ${person['apellidoP'] ?? ''}?',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(
                                          'Cancelar',
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.grey[300]
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(
                                          'Eliminar',
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.red[300]
                                                : Colors.red,
                                          ),
                                        ),
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
      case 'Disponible Extra':
        return Color(0xFFE53888).withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1); // Color suave de fondo por defecto
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
    final darkLabelColor =
        enabled ? Colors.grey.shade300 : Colors.grey.shade600;
    final darkEnabledBorderColor = Colors.grey.shade500;
    final darkDisabledBorderColor = Colors.grey.shade700;
    final darkFillColor = enabled ? Colors.grey.shade800 : Colors.grey.shade900;

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
      inputFormatters: maxLength != null
          ? [LengthLimitingTextInputFormatter(maxLength)]
          : [],
      enabled: enabled,
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
}
