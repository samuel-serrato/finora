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
import 'package:finora/dialogs/editGrupo.dart';
import 'package:finora/dialogs/infoGrupo.dart';
import 'package:finora/dialogs/nCliente.dart';
import 'package:finora/dialogs/nGrupo.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GruposScreen extends StatefulWidget {
  const GruposScreen();

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  List<Grupo> listaGrupos = [];
  bool isLoading = true;
  bool showErrorDialog = false;
  Timer? _timer;
  bool errorDeConexion = false;
  bool noGroupsFound = false;
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

  // 1. Agregar estas variables al inicio de la clase _GruposScreenState:
  List<Usuario> _usuarios = [];
  bool _isLoadingUsuarios = false;

  @override
  void initState() {
    super.initState();
    _initializarFiltros();
    obtenerGrupos();
    obtenerUsuariosCampo(); // AGREGAR ESTA LÍNEA
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
        clave: 'tipoGrupo', // Clave interna que usarás
        titulo: 'Tipo de Grupo',
        tipo: TipoFiltro.dropdown,
        opciones: ['Grupal', 'Individual', 'Automotriz', 'Empresarial'],
      ),
      ConfiguracionFiltro(
        clave: 'estadoGrupo', // Clave interna
        titulo: 'Estado del Grupo',
        tipo: TipoFiltro.dropdown,
        opciones: [
          'Activo',
          'Disponible',
          'Liquidado',
          'Finalizado',
          'Inactivo'
        ], // Opciones de ejemplo
      ),
      // NUEVO FILTRO AGREGADO:
      ConfiguracionFiltro(
        clave: 'usuarioCampo',
        titulo: 'Asesor',
        tipo: TipoFiltro.dropdown,
        opciones: [], // Se llenará dinámicamente
      ),
    ];
  }

// Función para actualizar las opciones del filtro de usuarios
  void _actualizarOpcionesUsuarios() {
    final filtroUsuario = _configuracionesFiltros.firstWhere(
      (config) => config.clave == 'usuarioCampo',
    );

    // Usar el campo nombreCompleto que viene de la API
    filtroUsuario.opciones =
        _usuarios.map((usuario) => usuario.nombreCompleto).toList();
  }

// 5. Modificar la función obtenerUsuariosCampo() existente:
  Future<void> obtenerUsuariosCampo() async {
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
          // Actualizar las opciones del filtro después de cargar los usuarios
          _actualizarOpcionesUsuarios();
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
                  (route) => false,
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
          // Manejar error 401 (token expirado)
          else if (response.statusCode == 401) {
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');
              mostrarDialogoError(
                  'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                  onClose: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              });
            }
            return;
          }
          // Otros errores
          else {
            print('Error ${response.statusCode}: ${errorData.toString()}');
          }
        } catch (parseError) {
          print('Error parseando respuesta: $parseError');
        }
      }
    } catch (e) {
      print('Error obteniendo usuarios: $e');
      // Manejar errores de conexión
      if (mounted) {
        mostrarDialogoError('Error de conexión al obtener usuarios campo.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsuarios = false);
      }
    }
  }

  final double textHeaderTableSize = 12.0;
  final double textTableSize = 12.0;

  Future<void> obtenerGrupos({int page = 1}) async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noGroupsFound = false;
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
            '$baseUrl/api/v1/grupodetalles?limit=12&page=$page$sortQuery&$filterQuery');
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
              listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
              // listaGrupos.sort((a, b) => b.fCreacion.compareTo(a.fCreacion));

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
              // Handle no groups found error
              else if (response.statusCode == 400 &&
                  errorData["Error"]["Message"] ==
                      "No hay detalle de grupos registrados") {
                setState(() {
                  listaGrupos = [];
                  isLoading = false;
                  noGroupsFound = true;
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

    if (!noGroupsFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noGroupsFound) {
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

  Future<void> searchGrupos(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      // Si la búsqueda está vacía, llama a obtenerCreditos que ya incluye el sort
      _isSearching = false;
      _currentSearchQuery = '';
      obtenerGrupos(
          page: page); // Usará el _sortColumnKey y _sortAscending actuales
      return;
    }
    _isSearching = true;
    _currentSearchQuery = query;

    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noGroupsFound = false;
      currentPage = page;
    });

    String sortQuery = '';
    if (_sortColumnKey != null) {
      sortQuery = '&$_sortColumnKey=${_sortAscending ? 'AZ' : 'ZA'}';
    }

    String filterQuery = _buildFilterQuery();
    final encodedQuery = Uri.encodeComponent(query);
    final uri = Uri.parse(
        '$baseUrl/api/v1/grupodetalles/$encodedQuery?limit=12&page=$page$sortQuery&$filterQuery');
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
          listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
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
          // Handle no groups found error
          else if (response.statusCode == 400) {
            // If the message specifically says no results
            if (errorData["Error"] != null &&
                errorData["Error"]["Message"] ==
                    "No hay detalle de grupos registrados") {
              setState(() {
                listaGrupos = [];
                isLoading = false;
                noGroupsFound = true;
              });
            } else {
              // Other 400 errors
              setState(() {
                listaGrupos = [];
                isLoading = false;
                noGroupsFound = true;
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

  String formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildFilterButton(BuildContext context, bool isDarkMode) {
    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        constraints: BoxConstraints(minWidth: 300), // Ajusta según necesites
        offset: Offset(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        elevation: 8,
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            enabled: false, // El contenido maneja la interacción
            child: _buildFilterContentConWidgetGenerico(context, isDarkMode),
          ),
        ],
        // onSelected no es necesario aquí si el widget interno maneja la lógica
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[700] : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8.0)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list,
                  size: 20, color: isDarkMode ? Colors.white : Colors.black87),
              SizedBox(width: 6),
              Text('Filtros',
                  style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black87)),
              if (_filtrosActivos.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Color(0xFF5162F6),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${_filtrosActivos.length}',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterContentConWidgetGenerico(
      BuildContext context, bool isDarkMode) {
    // Asegúrate de que FiltrosGenericosWidgetInline esté bien implementado
    // y pueda manejar el tema oscuro si es necesario.
    return FiltrosGenericosWidgetInline(
      configuraciones: _configuracionesFiltros,
      valoresIniciales: _filtrosActivos,
      titulo: 'Filtros de Grupos', // Título específico
      onAplicar: (filtros) {
        setState(() {
          _filtrosActivos = Map<String, dynamic>.from(filtros);
        });
        _aplicarFiltros();
        if (Navigator.canPop(context)) {
          // Cierra el PopupMenu si está abierto
          Navigator.of(context).pop();
        }
      },
      onRestablecer: () {
        setState(() {
          _filtrosActivos.clear();
        });
        _aplicarFiltros();
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _aplicarFiltros() {
    // Vuelve a la página 1 al aplicar filtros
    setState(() {
      currentPage = 1;
    });
    if (_isSearching && _currentSearchQuery.isNotEmpty) {
      searchGrupos(_currentSearchQuery, page: 1);
    } else {
      obtenerGrupos(page: 1);
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

  Widget _buildPaginationControls(bool isDarkMode) {
    return PaginationWidget(
      currentPage: currentPage,
      totalPages: totalPaginas,
      currentPageItemCount: listaGrupos.length,
      totalDatos: totalDatos,
      isDarkMode: isDarkMode,
      onPageChanged: (page) {
        if (_isSearching) {
          searchGrupos(_currentSearchQuery, page: page);
        } else {
          obtenerGrupos(page: page);
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
      backgroundColor:
          isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA), // Fondo dinámico

      appBar: CustomAppBar(
          isDarkMode: isDarkMode,
          toggleDarkMode: (value) {
            themeProvider.toggleDarkMode(value); // Cambia el tema
          },
          title: 'Grupos'),
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
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_searchController.text.trim().isEmpty) {
                  obtenerGrupos();
                } else {
                  searchGrupos(_searchController.text);
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
      return noGroupsFound || listaGrupos.isEmpty
          ? Center(
              child: Text(
                'No hay grupos para mostrar.',
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
                      child: tablaGrupos(context),
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
                          obtenerGrupos();
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
                  searchGrupos(value);
                });
              },
            ),
          ),
          Row(
            children: [
              // Botón de Filtros
              _buildFilterButton(context, isDarkMode),
              SizedBox(width: 10), // Espaciado
              // Botón de Agregar Grupo
              ElevatedButton(
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(
                      EdgeInsets.symmetric(vertical: 15, horizontal: 20)),
                  backgroundColor: MaterialStateProperty.all(Color(0xFF5162F6)),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                onPressed: mostrarDialogAgregarGrupo,
                child: Text('Agregar Grupo'),
              ),
            ],
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
      searchGrupos(_searchController.text, page: 1);
    } else {
      obtenerGrupos(page: 1);
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

  Widget tablaGrupos(BuildContext context) {
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
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            child: listaGrupos.isEmpty
                ? Center(
                    child: Text(
                      'No hay grupos para mostrar.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      var gruposFiltrados = listaGrupos
                          .where((grupo) =>
                              grupo.estado == 'Disponible' ||
                              grupo.estado == 'Liquidado' ||
                              grupo.estado == 'Activo')
                          .toList();
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowColor: MaterialStateProperty.resolveWith(
                                (states) => const Color(0xFF5162F6)),
                            dataRowHeight: 50,
                            columnSpacing: 30,
                            horizontalMargin: 50,
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: textHeaderTableSize,
                            ),
                            columns: [
                              DataColumn(
                                  label: Text('Tipo Grupo',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              _buildSortableColumn('Nombre',
                                  'nombregrupo'), // Clave API 
                              DataColumn(
                                  label: Text('Detalles',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Asesor',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              _buildSortableColumn('Fecha Creación',
                                  'fCreacion'), // Clave API

                              DataColumn(
                                  label: Text('Estado',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                label: Text(
                                  'Acciones',
                                  style:
                                      TextStyle(fontSize: textHeaderTableSize),
                                ),
                              ),
                            ],
                            rows: gruposFiltrados.map((grupo) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(grupo.tipoGrupo.toString(),
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(grupo.nombreGrupo,
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(grupo.detalles,
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(grupo.asesor,
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                               DataCell(
  Tooltip(
    message: grupo.fCreacion, // Fecha completa en tooltip
    child: Text(
      grupo.fCreacion.split(' ')[0], // Solo la fecha
      style: TextStyle(fontSize: textTableSize),
    ),
  ),
),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(grupo.estado,
                                            context), // Fondo dinámico
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getStatusColor(
                                                  grupo.estado, context)
                                              .withOpacity(
                                                  0.6), // Borde dinámico
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        grupo.estado ?? 'N/A',
                                        style: TextStyle(
                                          color: _getStatusTextColor(
                                              grupo.estado,
                                              context), // Texto dinámico
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Colors.grey),
                                          onPressed: () {
                                            mostrarDialogoEditarCliente(
                                                grupo.idgrupos!);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.grey),
                                          onPressed: () {
                                            _eliminarGrupo(grupo.idgrupos);
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
                                      builder: (context) => InfoGrupo(
                                        idGrupo: grupo.idgrupos.toString(),
                                        nombreGrupo: grupo.nombreGrupo,
                                      ),
                                    );

                                    if (resultado == true) {
                                      obtenerGrupos();
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

  Color _getStatusColor(String? estado, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    switch (estado) {
      case 'Finalizado':
        return isDarkMode
            ? Color(0xFE73879)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFE73879).withOpacity(0.1); // Fondo claro para modo claro
      case 'Liquidado':
        return isDarkMode
            ? Color(0xFFFAA300)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFFFAA300).withOpacity(0.1); // Fondo claro para modo claro
      case 'Cancelado':
        return isDarkMode
            ? Color(0xFFA31D1D)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFFA31D1D).withOpacity(0.1); // Fondo claro para modo claro
      case 'Activo':
        return isDarkMode
            ? Color(0xFF3674B5)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFF3674B5).withOpacity(0.1); // Fondo claro para modo claro
      case 'Disponible':
        return isDarkMode
            ? Color(0xFF059212)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFF059212).withOpacity(0.1); // Fondo claro para modo claro
      default:
        return isDarkMode
            ? Colors.grey.withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Colors.grey.withOpacity(0.1); // Fondo claro para modo claro
    }
  }

  Color _getStatusTextColor(String? estado, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    if (isDarkMode) {
      // En modo oscuro, el texto será blanco para contrastar con el fondo oscuro
      return Colors.white;
    } else {
      // En modo claro, mantenemos el color original del texto
      switch (estado) {
        case 'Finalizado':
          return Color(0xFE73879)
              .withOpacity(0.8); // Color original para "Finalizado"
        case 'Liquidado':
          return Color(0xFFFAA300)
              .withOpacity(0.8); // Color original para "Liquidado"
        case 'Cancelado':
          return Color(0xFFA31D1D)
              .withOpacity(0.8); // Color original para "Cancelado"
        case 'Activo':
          return Color(0xFF3674B5)
              .withOpacity(0.8); // Color original para "Activo"
        case 'Disponible':
          return Color(0xFF059212)
              .withOpacity(0.8); // Color original para "Disponible"
        default:
          return Colors.grey.withOpacity(0.8); // Color original por defecto
      }
    }
  }

  Future<void> _eliminarGrupo(String idGrupo) async {
    print('[ELIMINAR GRUPO] Iniciando proceso...');

    // Diálogo de confirmación
    bool confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Grupo'),
        content: const Text(
            '¿Estás seguro de eliminar este grupo y todos sus clientes asociados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    print(
        '[ELIMINAR GRUPO] Confirmación del usuario: ${confirmado ? "Aceptada" : "Cancelada"}');
    if (confirmado != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';
    print(
        '[ELIMINAR GRUPO] Token obtenido: ${token.isNotEmpty ? "OK" : "ERROR - Token vacío"}');

    try {
      // 1. Obtener la lista de clientes asociados al grupo
      final urlClientes = '$baseUrl/api/v1/grupodetalles/$idGrupo';
      print('[ELIMINAR GRUPO] URL para obtener clientes: $urlClientes');

      final responseClientes = await http.get(
        Uri.parse(urlClientes),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      print(
          '[ELIMINAR GRUPO] Respuesta obtener clientes - Código: ${responseClientes.statusCode}');
      print(
          '[ELIMINAR GRUPO] Respuesta obtener clientes - Body: ${responseClientes.body}');

      if (responseClientes.statusCode == 200) {
        final data = json.decode(responseClientes.body) as List;
        print('[ELIMINAR GRUPO] Número de grupos encontrados: ${data.length}');

        // Recorrer cada grupo (aunque debería ser solo uno)
        for (var grupo in data) {
          final clientes = grupo['clientes'] as List;
          print(
              '[ELIMINAR GRUPO] Número de clientes en el grupo: ${clientes.length}');

          // 2. Eliminar cada cliente asociado al grupo
          for (var cliente in clientes) {
            final idCliente = cliente['idclientes'];
            final urlEliminarCliente =
                '$baseUrl/api/v1/grupodetalles/$idGrupo/$idCliente';
            print(
                '[ELIMINAR GRUPO] URL para eliminar cliente: $urlEliminarCliente');

            final responseEliminarCliente = await http.delete(
              Uri.parse(urlEliminarCliente),
              headers: {
                'tokenauth': token,
                'Content-Type': 'application/json',
              },
            );

            print(
                '[ELIMINAR GRUPO] Respuesta eliminar cliente $idCliente - Código: ${responseEliminarCliente.statusCode}');
            print(
                '[ELIMINAR GRUPO] Respuesta eliminar cliente $idCliente - Body: ${responseEliminarCliente.body}');

            // Verificar si hay error de sesión en la respuesta de eliminar cliente
            if (responseEliminarCliente.statusCode != 200) {
              try {
                final errorData = json.decode(responseEliminarCliente.body);

                // Verificar si es el mensaje específico de sesión cambiada
                if (errorData["Error"] != null &&
                    errorData["Error"]["Message"] ==
                        "La sesión ha cambiado. Cerrando sesión...") {
                  print('[ELIMINAR GRUPO] Sesión cambiada detectada');
                  if (mounted) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('tokenauth');
                    _timer?.cancel();

                    // Mostrar diálogo y redirigir al login
                    mostrarDialogoCierreSesion(
                        'La sesión ha cambiado. Cerrando sesión...',
                        onClose: () {
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
                else if (responseEliminarCliente.statusCode == 404 &&
                    errorData["Error"]["Message"] == "jwt expired") {
                  print('[ELIMINAR GRUPO] JWT expirado detectado');
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
                  print(
                      '[ELIMINAR GRUPO] Error al eliminar cliente $idCliente');
                  print(
                      '[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
                  // Use SnackBar to show the error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        errorData['Error']?['Message'] ??
                            'Error al eliminar cliente $idCliente',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              } catch (parseError) {
                print(
                    '[ELIMINAR GRUPO] Error al parsear respuesta: $parseError');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error al eliminar cliente $idCliente',
                      style: TextStyle(
                        color:
                            Colors.white, // Explicitly set text color to white
                      ),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
            }
          }
        }

        // 3. Eliminar el grupo
        final urlEliminarGrupo = '$baseUrl/api/v1/grupos/$idGrupo';
        print('[ELIMINAR GRUPO] URL para eliminar grupo: $urlEliminarGrupo');

        final responseEliminarGrupo = await http.delete(
          Uri.parse(urlEliminarGrupo),
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        print(
            '[ELIMINAR GRUPO] Respuesta eliminar grupo - Código: ${responseEliminarGrupo.statusCode}');
        print(
            '[ELIMINAR GRUPO] Respuesta eliminar grupo - Body: ${responseEliminarGrupo.body}');

        if (responseEliminarGrupo.statusCode == 200) {
          print('[ELIMINAR GRUPO] Eliminación exitosa, actualizando lista...');
          obtenerGrupos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Grupo y clientes asociados eliminados exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          try {
            final errorData = json.decode(responseEliminarGrupo.body);

            // Verificar si es el mensaje específico de sesión cambiada
            if (errorData["Error"] != null &&
                errorData["Error"]["Message"] ==
                    "La sesión ha cambiado. Cerrando sesión...") {
              print('[ELIMINAR GRUPO] Sesión cambiada detectada');
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
            else if (responseEliminarGrupo.statusCode == 404 &&
                errorData["Error"]["Message"] == "jwt expired") {
              print('[ELIMINAR GRUPO] JWT expirado detectado');
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
              print('[ELIMINAR GRUPO] Error al eliminar grupo');
              print('[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
              mostrarDialogoError(errorData['Error']['Message'] ??
                  'Error al eliminar el grupo');
            }
          } catch (parseError) {
            print('[ELIMINAR GRUPO] Error al parsear respuesta: $parseError');
            mostrarDialogoError('Error al eliminar el grupo');
          }
        }
      } else {
        try {
          final errorData = json.decode(responseClientes.body);

          // Verificar si es el mensaje específico de sesión cambiada
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            print('[ELIMINAR GRUPO] Sesión cambiada detectada');
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
          else if (responseClientes.statusCode == 404 &&
              errorData["Error"]["Message"] == "jwt expired") {
            print('[ELIMINAR GRUPO] JWT expirado detectado');
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
            print('[ELIMINAR GRUPO] Error al obtener clientes del grupo');
            print('[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
            mostrarDialogoError(errorData['Error']['Message'] ??
                'Error al obtener los clientes del grupo');
          }
        } catch (parseError) {
          print('[ELIMINAR GRUPO] Error al parsear respuesta: $parseError');
          mostrarDialogoError('Error al obtener los clientes del grupo');
        }
      }
    } catch (e) {
      print('[ELIMINAR GRUPO] Excepción capturada: $e');
      print('[ELIMINAR GRUPO] StackTrace: ${e is Error ? e.stackTrace : ""}');
      mostrarDialogoError('Error de conexión: $e');
    }

    print('[ELIMINAR GRUPO] Proceso finalizado');
  }

  void mostrarDialogAgregarGrupo() {
    showDialog(
      barrierDismissible: false, // Evita que se cierre al tocar fuera
      context: context,
      builder: (context) {
        return nGrupoDialog(
          onGrupoAgregado: () {
            obtenerGrupos(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }

  void mostrarDialogoEditarCliente(String idGrupo) {
    showDialog(
      barrierDismissible: false, // No se puede cerrar tocando fuera
      context: context,
      builder: (context) {
        return editGrupoDialog(
          idGrupo: idGrupo, // Pasamos el idGrupo al diálogo
          onGrupoEditado: () {
            obtenerGrupos();
          },
        );
      },
    );
  }
}

class Grupo {
  final String idgrupos;
  final String tipoGrupo;
  final String nombreGrupo;
  final String detalles;
  String asesor;
  final String fCreacion;
  final String estado; // Agregamos el campo 'estado'

  Grupo({
    required this.idgrupos,
    required this.tipoGrupo,
    required this.nombreGrupo,
    required this.detalles,
    required this.asesor,
    required this.fCreacion,
    required this.estado, // Inicializamos el campo 'estado' en el constructor
  });

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      idgrupos: json['idgrupos'],
      tipoGrupo: json['tipoGrupo'],
      nombreGrupo: json['nombreGrupo'],
      detalles: json['detalles'],
      asesor: json['asesor'],
      fCreacion: json['fCreacion'],
      estado:
          json['estado'], // Asignamos el valor del campo 'estado' desde el JSON
    );
  }
}
