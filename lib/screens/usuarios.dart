import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:finora/models/usuarios.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/widgets/filtros_genericos_widget.dart';
import 'package:finora/widgets/pagination.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:finora/dialogs/usuario/editUsuario.dart';
import 'package:finora/dialogs/usuario/infoUsuario.dart';
import 'package:finora/dialogs/usuario/nUsuario.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GestionUsuariosScreen extends StatefulWidget {
  const GestionUsuariosScreen();

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  List<Usuario> listaUsuarios = [];
  bool isLoading = true;
  bool showErrorDialog = false;
  Timer? _timer;
  bool errorDeConexion = false;
  bool noUsersFound = false;
  Timer? _debounceTimer; // Para el debounce de la búsqueda
  final TextEditingController _searchController =
      TextEditingController(); // Controlador para el SearchBar

  int currentPage = 1;
  int totalPaginas = 1;
  int totalDatos = 0;

  int? _hoveredPage;
  String _currentSearchQuery = '';
  bool _isSearching = false;

  String?
      _sortColumnKey; // Clave de la API para la columna ordenada (ej: 'nombre')
  bool _sortAscending = true; // true para AZ, false para ZA

  // Variables para filtros
  Map<String, dynamic> _filtrosActivos = {};
  late List<ConfiguracionFiltro> _configuracionesFiltros;

  @override
  void initState() {
    super.initState();
    _initializarFiltros();
    obtenerUsuarios();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _initializarFiltros() {
    // Define aquí los filtros específicos para Grupos
    _configuracionesFiltros = [
      ConfiguracionFiltro(
        clave: 'tipoCliente', // Clave interna que usarás
        titulo: 'Tipo de Cliente',
        tipo: TipoFiltro.dropdown,
        opciones: ['Asalariado', 'Independiente', 'Comerciante', 'Jubilado'],
      ),
      ConfiguracionFiltro(
        clave: 'sexo', // Clave interna
        titulo: 'Sexo',
        tipo: TipoFiltro.dropdown,
        opciones: [
          'Masculino',
          'Femenino',
        ], // Opciones de ejemplo
      ),
      // NUEVO FILTRO AGREGADO:
      ConfiguracionFiltro(
        clave: 'estado',
        titulo: 'Estado',
        tipo: TipoFiltro.dropdown,
        opciones: [
          'Disponible',
          'En Credito',
        ], // Se llenará dinámicamente
      ),
    ];
  }

  final double textHeaderTableSize = 12.0;
  final double textTableSize = 12.0;

  Future<void> obtenerUsuarios({int page = 1}) async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noUsersFound = false;
      currentPage = page; // Update current page
    });

    String sortQuery = '';
    if (_sortColumnKey != null) {
      sortQuery = '&$_sortColumnKey=${_sortAscending ? 'AZ' : 'ZA'}';
    }

    bool dialogShown = false;

    _timer?.cancel(); // Cancela cualquier timer existente

    Future<void> fetchData() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        String filterQuery = _buildFilterQuery();
        final uri = Uri.parse(
            '$baseUrl/api/v1/usuarios?limit=12&page=$page$sortQuery&$filterQuery');
        print('Fetching: $uri'); // Para depuración

        final response = await http.get(
          uri,
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        if (mounted) {
          if (response.statusCode == 200) {
            int totalDatosResp =
                int.tryParse(response.headers['x-total-totaldatos'] ?? '0') ??
                    0;
            int totalPaginasResp =
                int.tryParse(response.headers['x-total-totalpaginas'] ?? '1') ??
                    1;

            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaUsuarios =
                  data.map((item) => Usuario.fromJson(item)).toList();
              listaUsuarios.sort((a, b) => b.fCreacion.compareTo(a.fCreacion));

              isLoading = false;
              errorDeConexion = false;
              totalDatos = totalDatosResp;
              totalPaginas = totalPaginasResp;
            });
            _timer?.cancel();
          } else {
            // In case of error, reset pagination
            setState(() {
              totalDatos = 0;
              totalPaginas = 1;
            });

            try {
              final errorData = json.decode(response.body);

              // Check for specific session change message
              if (errorData["Error"] != null &&
                  errorData["Error"]["Message"] ==
                      "La sesión ha cambiado. Cerrando sesión...") {
                if (mounted) {
                  setState(() => isLoading = false);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('tokenauth');
                  _timer?.cancel();

                  // Show dialog and redirect to login
                  mostrarDialogoCierreSesion(
                      'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false, // Remove all previous routes
                    );
                  });
                }
                return;
              }
              // Handle JWT expired error
              else if (response.statusCode == 404 &&
                  errorData["Error"]["Message"] == "jwt expired") {
                if (mounted) {
                  setState(() => isLoading = false);
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
              // Handle no users found error
              else if (response.statusCode == 400 &&
                  errorData["Error"]["Message"] ==
                      "No hay usuarios registrados") {
                setState(() {
                  listaUsuarios = [];
                  isLoading = false;
                  noUsersFound = true;
                });
                _timer?.cancel();
              }
              // Other errors
              else {
                setErrorState(dialogShown);
              }
            } catch (parseError) {
              // If response body cannot be parsed, handle as generic error
              setErrorState(dialogShown);
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setErrorState(dialogShown, e);
        }
      }
    }

    fetchData();

    if (!noUsersFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noUsersFound) {
          setState(() {
            isLoading = false;
            errorDeConexion = true;
          });
          dialogShown = true;
          mostrarDialogoError(
              'No se pudo conectar al servidor. Verifica tu red.');
        }
      });
    }
  }

  String _buildFilterQuery() {
    List<String> queryParams = [];
    _filtrosActivos.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        // Mapea las claves a los parámetros de la API para grupos
        String apiParam = _mapFilterKeyToApiParam(key);
        queryParams.add('$apiParam=${Uri.encodeComponent(value.toString())}');
      }
    });
    return queryParams.join('&');
  }

  String _mapFilterKeyToApiParam(String filterKey) {
    // IMPORTANTE: Ajusta estos case a los nombres de parámetros que espera tu API de grupos
    switch (filterKey) {
      case 'tipoGrupo':
        return 'tipogrupo'; // Ejemplo: el backend espera 'tipogrupo'
      case 'estadoGrupo':
        return 'estado'; // Ejemplo: el backend espera 'estado' o 'estadogrupo'
      case 'usuarioCampo':
        return 'asesor'; // AGREGAR ESTA LÍNEA (ajusta el nombre según tu API)
      default:
        return filterKey; // Como fallback
    }
  }

  Future<void> searchUsuarios(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      // Si la búsqueda está vacía, llama a obtenerCreditos que ya incluye el sort
      _isSearching = false;
      _currentSearchQuery = '';
      obtenerUsuarios(
          page: page); // Usará el _sortColumnKey y _sortAscending actuales
      return;
    }
    _isSearching = true;
    _currentSearchQuery = query;

    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noUsersFound = false;
      currentPage = page; // Actualizar página actual para búsqueda
    });

    String sortQuery = '';
    if (_sortColumnKey != null) {
      sortQuery = '&$_sortColumnKey=${_sortAscending ? 'AZ' : 'ZA'}';
    }

    String filterQuery = _buildFilterQuery();
    final encodedQuery = Uri.encodeComponent(query);
    final uri = Uri.parse(
        '$baseUrl/api/v1/usuarios/$encodedQuery?limit=12&page=$page$sortQuery&$filterQuery');
    print('Searching: $uri'); // Para depuración

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        uri,
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;

      print('Status code (search): ${response.statusCode}');

      if (response.statusCode == 200) {
        int totalDatosResp =
            int.tryParse(response.headers['x-total-totaldatos'] ?? '0') ?? 0;
        int totalPaginasResp =
            int.tryParse(response.headers['x-total-totalpaginas'] ?? '1') ?? 1;

        List<dynamic> data = json.decode(response.body);
        setState(() {
          listaUsuarios = data.map((item) => Usuario.fromJson(item)).toList();
          isLoading = false;
          totalDatos = totalDatosResp;
          totalPaginas = totalPaginasResp;
        });
      } else {
        try {
          final errorData = json.decode(response.body);

          // Check for specific session change message
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            if (mounted) {
              setState(() => isLoading = false);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');

              // Show dialog and redirect to login
              mostrarDialogoCierreSesion(
                  'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false, // Remove all previous routes
                );
              });
            }
            return;
          }
          // Handle JWT expired error
          else if (response.statusCode == 404 &&
              errorData["Error"] != null &&
              errorData["Error"]["Message"] == "jwt expired") {
            if (mounted) {
              setState(() => isLoading = false);
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
            }
            return;
          }
          // Handle 401 for expired token
          else if (response.statusCode == 401) {
            _handleTokenExpiration();
          }
          // Handle no users found error
          else if (response.statusCode == 400) {
            // If the message specifically says no results
            if (errorData["Error"] != null &&
                errorData["Error"]["Message"] ==
                    "No hay usuarios registrados") {
              setState(() {
                listaUsuarios = [];
                isLoading = false;
                noUsersFound = true;
              });
            } else {
              // Other 400 errors
              setState(() {
                listaUsuarios = [];
                isLoading = false;
                noUsersFound = true;
              });
            }
          }
          // Other errors
          else {
            setState(() {
              isLoading = false;
              errorDeConexion = true;
            });
          }
        } catch (parseError) {
          // If response body cannot be parsed, handle as generic error
          setState(() {
            isLoading = false;
            errorDeConexion = true;
          });
        }
      }
    } on SocketException catch (e) {
      print('SocketException: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
      }
    } on TimeoutException catch (_) {
      print('Timeout');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
      }
    } catch (e) {
      print('Error general: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
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

  void _handleTokenExpiration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tokenauth');

    if (mounted) {
      mostrarDialogoError(
        'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
        onClose: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
          );
        },
      );
    }
  }

  void setErrorState(bool dialogShown, [dynamic error]) {
    setState(() {
      isLoading = false;
      errorDeConexion = true;
    });
    if (!dialogShown) {
      dialogShown = true;
      if (error is SocketException) {
        mostrarDialogoError('Error de conexión. Verifica tu red.');
      } else {
        mostrarDialogoError('Ocurrió un error inesperado.');
      }
      _timer?.cancel();
    }
  }

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
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

  String formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Función para eliminar usuario
  Future<void> eliminarUsuario(String idUsuario) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/usuarios/$idUsuario'),
        headers: {'tokenauth': token},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Usuario eliminado correctamente',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        obtenerUsuarios();
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
          else if (response.statusCode == 401 ||
              (response.statusCode == 404 &&
                  errorData["Error"]["Message"] == "jwt expired")) {
            _handleTokenExpiration();
            return;
          }
          // Otros errores
          else {
            mostrarDialogoError(
                'Error al eliminar usuario: ${errorData["Error"]["Message"]}');
          }
        } catch (parseError) {
          // Si no se puede parsear el cuerpo de la respuesta, manejar como error genérico
          mostrarDialogoError('Error al procesar la respuesta del servidor');
        }
      }
    } on SocketException {
      mostrarDialogoError('Error de conexión. Verifica tu red.');
    } on TimeoutException {
      mostrarDialogoError('Tiempo de espera agotado. Intenta nuevamente.');
    } catch (e) {
      mostrarDialogoError('Error al eliminar usuario: $e');
    }
  }

// Diálogo de confirmación
  Future<bool> mostrarDialogoConfirmacion(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirmar eliminación'),
              content:
                  Text('¿Estás seguro de que deseas eliminar este usuario?'),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildPaginationControls(bool isDarkMode) {
    return PaginationWidget(
      currentPage: currentPage,
      totalPages: totalPaginas,
      currentPageItemCount: listaUsuarios.length,
      totalDatos: totalDatos,
      isDarkMode: isDarkMode,
      onPageChanged: (page) {
        if (_isSearching) {
          searchUsuarios(_currentSearchQuery, page: page);
        } else {
          obtenerUsuarios(page: page);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Scaffold(
      backgroundColor: isDarkMode
          ? Colors.grey[900]
          : const Color(0xFFF7F8FA), // Fondo dinámico
      appBar: CustomAppBar(
          isDarkMode: isDarkMode,
          toggleDarkMode: (value) {
            themeProvider.toggleDarkMode(value); // Cambia el tema
          },
          title: 'Gestión de Usuarios'),
      body: Column(
        children: [
          if (!errorDeConexion) filaBuscarYAgregar(context),
          Expanded(child: _buildTableContainer()),
        ],
      ),
    );
  }

  Widget _buildTableContainer() {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFF5162F6),
        ),
      );
    } else if (errorDeConexion) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No hay conexión o no se pudo cargar la información. Intenta más tarde.',
              style: TextStyle(
                  fontSize: 16, color: isDarkMode ? Colors.white : Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_searchController.text.trim().isEmpty) {
                  obtenerUsuarios();
                } else {
                  searchUsuarios(_searchController.text);
                }
              },
              child: Text('Recargar'),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Color(0xFF5162F6)),
                foregroundColor: MaterialStateProperty.all(Colors.white),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return noUsersFound || listaUsuarios.isEmpty
          ? Center(
              child: Text(
                'No hay usuarios para mostrar.',
                style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.grey),
              ),
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 0.5,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: tablaUsuarios(context),
                    ),
                    _buildPaginationControls(isDarkMode)
                  ],
                ),
              ),
            );
    }
  }

  Widget filaBuscarYAgregar(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    double maxWidth = MediaQuery.of(context).size.width * 0.35;
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 40,
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.grey[800]
                  : Colors.white, // Fondo dinámico
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8.0)],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide:
                      BorderSide(color: Color.fromARGB(255, 137, 192, 255)),
                ),
                prefixIcon: Icon(Icons.search,
                    color: isDarkMode ? Colors.white : Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: isDarkMode ? Colors.white : Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          // Si se borra el texto, se vuelve a cargar la lista completa
                          obtenerUsuarios();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode
                    ? Colors.grey[800]
                    : Colors.white, // Fondo dinámico
                hintText: 'Buscar...',
                hintStyle:
                    TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                if (_debounceTimer?.isActive ?? false) {
                  _debounceTimer!.cancel();
                }
                _debounceTimer = Timer(Duration(milliseconds: 500), () {
                  searchUsuarios(value);
                });
              },
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Color(0xFF5162F6)),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            onPressed: mostrarDialogAgregarUsuario,
            child: Text('Agregar Usuario'),
          ),
        ],
      ),
    );
  }

  void _onSort(String columnKey) {
    setState(() {
      if (_sortColumnKey == columnKey) {
        // Si es la misma columna, alternar entre ASC -> DESC -> SIN ORDEN
        if (_sortAscending) {
          _sortAscending = false; // Cambiar a descendente
        } else {
          // Si ya está en descendente, resetear completamente
          _sortColumnKey = null;
          _sortAscending = true;
        }
      } else {
        // Si es una columna diferente, establecer nueva columna en ascendente
        _sortColumnKey = columnKey;
        _sortAscending = true;
      }
      currentPage = 1; // Resetear a la primera página al cambiar el orden
    });

    // Volver a cargar los datos con el nuevo orden
    if (_searchController.text.trim().isNotEmpty) {
      searchUsuarios(_searchController.text, page: 1);
    } else {
      obtenerUsuarios(page: 1);
    }
  }

  DataColumn _buildSortableColumn(String label, String columnKey,
      {double? width}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    List<Widget> children = [
      Text(label, style: TextStyle(fontSize: textHeaderTableSize)),
      SizedBox(width: 2), // Espacio entre el texto y el icono
    ];

    // Solo mostrar icono de ordenamiento si esta columna está activa
    if (_sortColumnKey == columnKey) {
      children.add(
        Icon(
          _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: Colors.white,
        ),
      );
    } else {
      // Icono sutil para columnas inactivas pero ordenables
      children.add(
        Icon(
          Icons.unfold_more,
          size: 16,
          color: Colors.white.withOpacity(0.7),
        ),
      );
    }

    Widget labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    return DataColumn(
      label: SizedBox(
        width: width,
        child: InkWell(
          onTap: () => _onSort(columnKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: labelWidget,
          ),
        ),
      ),
    );
  }

  Widget tablaUsuarios(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(0),
        child: Container(
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color:
                isDarkMode ? Colors.grey[800] : Colors.white, // Fondo dinámico
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 0.5,
                blurRadius: 5,
              ),
            ],
          ),
          // ClipRRect para que el contenido respete los bordes redondeados
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            child: listaUsuarios.isEmpty
                ? Center(
                    child: Text(
                      'No hay usuarios para mostrar.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            // Si el contenido no ocupa todo el ancho, se centra
                            maxWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowColor: MaterialStateProperty.resolveWith(
                                (states) => const Color(0xFF5162F6)),
                            dataRowHeight: 50,
                            columnSpacing: 30,
                            horizontalMargin: 50,
                            // Texto del encabezado centrado y en blanco
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: textHeaderTableSize,
                            ),
                            columns: [
                              DataColumn(
                                  label: Text(
                                'Tipo',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: textHeaderTableSize),
                              )),
                              DataColumn(
                                  label: Text(
                                'Usuario',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: textHeaderTableSize),
                              )),
                             _buildSortableColumn(
                                  'Nombre', 'nombre'), // Clave API
                              DataColumn(
                                  label: Text(
                                'Email',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: textHeaderTableSize),
                              )),
                            _buildSortableColumn(
                                  'Fecha Creación', 'fCreacion'), // Clave API
                              DataColumn(
                                label: Text(
                                  'Acciones',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontSize: textHeaderTableSize),
                                ),
                              ),
                            ],
                            rows: listaUsuarios.map((usuario) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(
                                    usuario.tipoUsuario,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: textTableSize),
                                  )),
                                  DataCell(Text(
                                    usuario.usuario,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: textTableSize),
                                  )),
                                  DataCell(Text(
                                    usuario.nombreCompleto,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: textTableSize),
                                  )),
                                  DataCell(Text(
                                    usuario.email,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: textTableSize),
                                  )),
                                 DataCell(
  Tooltip(
    message: usuario.fCreacion, // Fecha completa en tooltip
    child: Text(
      usuario.fCreacion.split(' ')[0], // Solo la fecha
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: textTableSize),
    ),
  ),
),
                                  DataCell(
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Colors.grey),
                                          onPressed: () {
                                            mostrarDialogoEditarUsuario(
                                                usuario.idusuarios);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.grey),
                                          onPressed: () async {
                                            bool confirmado =
                                                await mostrarDialogoConfirmacion(
                                                    context);
                                            if (confirmado) {
                                              await eliminarUsuario(
                                                  usuario.idusuarios);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelectChanged: (isSelected) async {
                                  if (isSelected!) {
                                    final resultado = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => InfoUsuario(
                                        idUsuario: usuario.idusuarios,
                                      ),
                                    );
                                    if (resultado == true) {
                                      obtenerUsuarios();
                                    }
                                  }
                                },
                                color: MaterialStateColor.resolveWith((states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return Colors.blue.withOpacity(0.1);
                                  } else if (states
                                      .contains(MaterialState.hovered)) {
                                    return Colors.blue.withOpacity(0.2);
                                  }
                                  return Colors.transparent;
                                }),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  void mostrarDialogAgregarUsuario() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return nUsuarioDialog(
          onUsuarioAgregado: () {
            obtenerUsuarios();
          },
        );
      },
    );
  }

  void mostrarDialogoEditarUsuario(String idUsuario) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return editUsuarioDialog(
          idUsuario: idUsuario,
          onUsuarioEditado: () {
            obtenerUsuarios();
          },
        );
      },
    );
  }
}
