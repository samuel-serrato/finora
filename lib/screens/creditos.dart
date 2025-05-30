import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:finora/models/credito.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:finora/widgets/filtros_genericos_widget.dart';
import 'package:finora/widgets/pagination.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:finora/dialogs/infoCredito.dart';
import 'package:finora/dialogs/nCredito.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para manejar fechas
import 'package:dropdown_button2/dropdown_button2.dart';

class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen();

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  // Datos estáticos de ejemplo de créditos activos
  List<Credito> listaCreditos = [];

  bool isLoading = false; // Para indicar si los datos están siendo cargados.
  bool errorDeConexion = false; // Para indicar si hubo un error de conexión.
  bool noCreditsFound = false; // Para indicar si no se encontraron créditos.
  Timer?
      _timer; // Para manejar el temporizador que muestra el mensaje de error después de cierto tiempo.
  Timer? _debounceTimer; // Para el debounce de la búsqueda
  final TextEditingController _searchController = TextEditingController();

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

  // Configuraciones de filtros
  late List<ConfiguracionFiltro> _configuracionesFiltros;

  @override
  void initState() {
    super.initState();
    _initializarFiltros();
    obtenerCreditos();
  }

  void _initializarFiltros() {
    _configuracionesFiltros = [
      ConfiguracionFiltro(
        clave: 'tipoCredito',
        titulo: 'Tipo de Crédito',
        tipo: TipoFiltro.dropdown,
        opciones: ['Grupal', 'Individual', 'Automotriz', 'Empresarial'],
      ),
      ConfiguracionFiltro(
        clave: 'frecuencia',
        titulo: 'Frecuencia',
        tipo: TipoFiltro.dropdown,
        opciones: ['Semanal', 'Quincenal', 'Mensual', 'Bimestral'],
      ),
      ConfiguracionFiltro(
        clave: 'diaPago',
        titulo: 'Día de Pago',
        tipo: TipoFiltro.dropdown,
        opciones: [
          'Lunes',
          'Martes',
          'Miércoles',
          'Jueves',
          'Viernes',
          'Sábado',
          'Domingo'
        ],
      ),
      ConfiguracionFiltro(
        clave: 'numeroPago',
        titulo: 'Número de Pago',
        tipo: TipoFiltro.dropdown,
        opciones: [
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '10',
          '11',
          '12',
          '13',
          '14',
          '15',
          '16',
          '17',
          '18',
          '19',
          '20'
        ],
      ),
      ConfiguracionFiltro(
        clave: 'estadopago',
        titulo: 'Estado de Pago',
        tipo: TipoFiltro.dropdown,
        opciones: ['Pagado', 'Pendiente', 'Retraso', 'Desembolso'],
      ),
      ConfiguracionFiltro(
        clave: 'estadocredito',
        titulo: 'Estado del Crédito',
        tipo: TipoFiltro.dropdown,
        opciones: ['Activo', 'Finalizado', 'En mora'],
      ),
    ];
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancela el temporizador al destruir el widget
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> obtenerCreditos({int page = 1}) async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noCreditsFound = false;
      currentPage = page;
    });

    String sortQuery = '';
    if (_sortColumnKey != null) {
      sortQuery = '&$_sortColumnKey=${_sortAscending ? 'AZ' : 'ZA'}';
    }

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        String filterQuery = _buildFilterQuery();
        final uri = Uri.parse(
            '$baseUrl/api/v1/creditos?limit=12&page=$page$sortQuery&$filterQuery');
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
              listaCreditos =
                  data.map((item) => Credito.fromJson(item)).toList();
              //listaCreditos.sort((a, b) => b.fCreacion.compareTo(a.fCreacion));

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
              // Handle no credits found error
              else if (response.statusCode == 400 &&
                  errorData["Error"]["Message"] ==
                      "No hay ningun credito registrado") {
                setState(() {
                  listaCreditos = [];
                  isLoading = false;
                  noCreditsFound = true;
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

    if (!noCreditsFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noCreditsFound) {
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

  // Función para buscar créditos según el texto ingresado
  Future<void> searchCreditos(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      // Si la búsqueda está vacía, llama a obtenerCreditos que ya incluye el sort
      _isSearching = false;
      _currentSearchQuery = '';
      obtenerCreditos(
          page: page); // Usará el _sortColumnKey y _sortAscending actuales
      return;
    }
    _isSearching = true;
    _currentSearchQuery = query;

    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noCreditsFound = false;
      currentPage = page;
    });

    String sortQuery = '';
    if (_sortColumnKey != null) {
      sortQuery = '&$_sortColumnKey=${_sortAscending ? 'AZ' : 'ZA'}';
    }

    String filterQuery = _buildFilterQuery();
    final encodedQuery = Uri.encodeComponent(query);
    final uri = Uri.parse(
        '$baseUrl/api/v1/creditos/$encodedQuery?limit=12&page=$page$sortQuery&$filterQuery');
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
          listaCreditos = data.map((item) => Credito.fromJson(item)).toList();
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
          // Handle no credits found error
          else if (response.statusCode == 400) {
            // If the message specifically says no results
            if (errorData["Error"] != null &&
                errorData["Error"]["Message"] ==
                    "No hay ningun credito registrado") {
              setState(() {
                listaCreditos = [];
                isLoading = false;
                noCreditsFound = true;
              });
            } else {
              // Other 400 errors
              setState(() {
                listaCreditos = [];
                isLoading = false;
                noCreditsFound = true;
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
      });
    }
  }

  void setErrorState(bool dialogShown, [dynamic error]) {
    _timer?.cancel(); // Cancela el temporizador antes de navegar
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
      _timer?.cancel(); // Detener intentos de reconexión en caso de error
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

  Widget _buildPaginationControls(bool isDarkMode) {
    return PaginationWidget(
      currentPage: currentPage,
      totalPages: totalPaginas,
      currentPageItemCount: listaCreditos.length,
      totalDatos: totalDatos,
      isDarkMode: isDarkMode,
      onPageChanged: (page) {
        if (_isSearching) {
          searchCreditos(_currentSearchQuery, page: page);
        } else {
          obtenerCreditos(page: page);
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
      appBar: CustomAppBar(
          isDarkMode: isDarkMode,
          toggleDarkMode: (value) {
            themeProvider.toggleDarkMode(value); // Cambia el tema
          },
          title: 'Créditos Activos'),
      backgroundColor:
          isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA), // Fondo dinámico
      body: Column(
        children: [
          // Solo muestra la fila de búsqueda si NO hay error de conexión
          if (!errorDeConexion) filaBuscarYAgregar(context),
          Expanded(child: _buildTableContainer()),
        ],
      ),
    );
  }

  // Se encapsula el contenedor de la tabla para que sea lo único que se actualice al buscar
  // Este widget se encarga de mostrar el contenedor de la tabla o, en su defecto,
// un CircularProgressIndicator mientras se realiza la petición.
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
                  obtenerCreditos();
                } else {
                  searchCreditos(_searchController.text);
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
      return noCreditsFound || listaCreditos.isEmpty
          ? Center(
              child: Text(
                'No hay créditos para mostrar.',
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
                      child: tablaCreditos(context),
                    ),
                    _buildPaginationControls(isDarkMode)
                  ],
                ),
              ),
            );
    }
  }

  Widget filaBuscarYAgregar(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
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
              color: isDarkMode ? Colors.grey[800] : Colors.white,
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
                          obtenerCreditos();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
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
                  searchCreditos(value);
                });
              },
            ),
          ),

          // Contenedor para los botones (Filtros y Agregar Crédito)
          Row(
            children: [
              // Botón de Filtros con PopupMenu
              _buildFilterButton(context, isDarkMode),

              SizedBox(width: 10), // Espaciado entre botones

              // Botón de Agregar Crédito
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
                onPressed: mostrarDialogAgregarCredito,
                child: Text('Agregar Crédito'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Reemplaza tu método _buildFilterButton actual con este:
  // 2. Reemplaza tu método _buildFilterButton actual con este (mantiene el estilo PopupMenu):
  // 2. REEMPLAZA tu método _buildFilterButton con esta versión simplificada:
// 1. MANTÉN tu método _buildFilterButton exactamente igual (con PopupMenu):
  Widget _buildFilterButton(BuildContext context, bool isDarkMode) {
    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        constraints: BoxConstraints(minWidth: 300),
        offset: Offset(0, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        elevation: 8,
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: _buildFilterContentConWidgetGenerico(context, isDarkMode),
          ),
        ],
        onSelected: (value) {
          // Esta función se ejecuta cuando se selecciona algo del menú
        },
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
              Icon(
                Icons.filter_list,
                size: 20,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              SizedBox(width: 6),
              Text(
                'Filtros',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              // Indicador de filtros activos
              if (_filtrosActivos.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Color(0xFF5162F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filtrosActivos.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

// 2. NUEVO método que usa tu widget genérico DENTRO del PopupMenu:
  Widget _buildFilterContentConWidgetGenerico(
      BuildContext context, bool isDarkMode) {
    return FiltrosGenericosWidgetInline(
      configuraciones: _configuracionesFiltros,
      valoresIniciales: _filtrosActivos,
      titulo: 'Filtros de Créditos',
      onAplicar: (filtros) {
        setState(() {
          _filtrosActivos = Map<String, dynamic>.from(filtros);
        });
        _aplicarFiltros();
        Navigator.of(context).pop(); // Cierra el PopupMenu
      },
      onRestablecer: () {
        setState(() {
          _filtrosActivos.clear();
        });
        _aplicarFiltros();
        Navigator.of(context).pop(); // Cierra el PopupMenu
      },
    );
  }

  // 4. Método para aplicar filtros
  void _aplicarFiltros() {
    if (_isSearching && _currentSearchQuery.isNotEmpty) {
      searchCreditos(_currentSearchQuery, page: 1);
    } else {
      obtenerCreditos(page: 1);
    }
  }

  // 5. Actualiza el método _buildFilterQuery para usar los nuevos filtros
  String _buildFilterQuery() {
    List<String> queryParams = [];

    _filtrosActivos.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        // Mapea las claves a los parámetros de la API
        String apiParam = _mapFilterKeyToApiParam(key);
        queryParams.add('$apiParam=${Uri.encodeComponent(value.toString())}');
      }
    });

    return queryParams.join('&');
  }

  // 6. Método helper para mapear claves de filtros a parámetros de API
  String _mapFilterKeyToApiParam(String filterKey) {
    switch (filterKey) {
      case 'tipoCredito':
        return 'tipogrupo';
      case 'frecuencia':
        return 'frecuencia';
      case 'diaPago':
        return 'diapago';
      case 'numeroPago':
        return 'numPago';
      case 'estadoPago':
        return 'estadoPago';
      case 'estadoCredito':
        return 'estadocredito';
      default:
        return filterKey;
    }
  }

// Método para aplicar filtros actualizado
  void aplicarFiltros(
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    String? tipoCredito,
    String? frecuencia,
    String? diapago,
    int? numeroPago,
    String? estadoPago,
    String? estadoCredito,
  ) {
    print('Aplicando filtros de créditos:');
    print('Fecha desde: ${fechaDesde?.toString()}');
    print('Fecha hasta: ${fechaHasta?.toString()}');
    print('Tipo de crédito: $tipoCredito');
    print('Frecuencia: $frecuencia');
    print('Día de pago: $diapago');
    print('Número de pago: $numeroPago');
    print('Estado de pago: $estadoPago');
    print('Estado de crédito: $estadoCredito');
    //print('Búsqueda: $busquedaPorPalabras');

    // Aquí implementarías la lógica para filtrar los créditos
    // obtenerCreditosFiltrados(fechaDesde, fechaHasta, tipoCredito, frecuencia, diapago, numeroPago, estadoPago, estadoCredito, busquedaPorPalabras);
    setState(() {
      currentPage = 1;
    });

    if (_searchController.text.trim().isNotEmpty) {
      searchCreditos(_searchController.text);
    } else {
      obtenerCreditos();
    }
  }

  void mostrarDialogAgregarCredito() {
    showDialog(
      barrierDismissible: false, // Evita que se cierre al tocar fuera
      context: context,
      builder: (context) {
        return nCreditoDialog(
          onCreditoAgregado: () {
            obtenerCreditos(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }

  Widget tablaCreditos(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Container(
      padding: const EdgeInsets.all(0),
      child: Center(
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
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(child: tabla(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Función para manejar el clic en el encabezado de la columna
  // Función para manejar el clic en el encabezado de la columna
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
      searchCreditos(_searchController.text, page: 1);
    } else {
      obtenerCreditos(page: 1);
    }
  }

// Helper para construir los encabezados de columna ordenables
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

  final double textHeaderTableSize = 12.0;
  final double textTableSize = 12.0;

  Widget tabla(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final userData = Provider.of<UserDataProvider>(context, listen: false);

    // Las claves de API para las columnas que SÍ serán ordenables
    // Asegúrate que coincidan con tu API

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowColor:
            MaterialStateProperty.resolveWith((states) => Color(0xFF5162F6)),
        columnSpacing: 10,
        headingRowHeight: 50,
        dataRowHeight: 60,
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.white,
          fontSize: textHeaderTableSize,
        ),
        columns: [
          // Columnas NO ordenables
          DataColumn(
              label: Text('Tipo',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              label: Text('Frecuencia',
                  style: TextStyle(fontSize: textHeaderTableSize))),

          // Columnas SÍ ordenables
          _buildSortableColumn('Nombre', 'nombre'), // Clave API: 'nombre'
          _buildSortableColumn(
              'Autorizado', 'montoautorizado'), // Clave API: 'montoautorizado'

          _buildSortableColumn(
              'Interés', 'interes'), // Clave API: 'montorecuperar'
          _buildSortableColumn(
              'M. Recuperar', 'montorecuperar'), // Clave API: 'montorecuperar'

          DataColumn(
              label: Text('Día Pago', // NO ordenable
                  style: TextStyle(fontSize: textHeaderTableSize))),
          _buildSortableColumn(
              'Monto Ficha', 'pagoperiodo'), // Clave API: 'pagoperiodo'

          DataColumn(
              label: Text('Núm de Pago',
                  style: TextStyle(fontSize: textHeaderTableSize))),
          DataColumn(
              // Asumimos que 'Estado Pago' no es ordenable según la lista que diste
              label:
                  Text('Estado Pago', // NO ordenable (o cámbialo si sí lo es)
                      style: TextStyle(fontSize: textHeaderTableSize))),
          // Si 'Estado Pago' SÍ debe ser ordenable, usa:
          // _buildSortableColumn('Estado Pago', 'estadopago'),
          /*   DataColumn(
              label: Text('Duración',
                  style: TextStyle(fontSize: textHeaderTableSize))), */
          _buildSortableColumn(
              'F. Creación', 'fCreacion'), // Clave API: 'montoautorizado'

          DataColumn(
              // Asumimos que 'Estado Crédito' no es ordenable
              label: Text(
                  'Estado Crédito', // NO ordenable (o cámbialo si sí lo es)
                  style: TextStyle(fontSize: textHeaderTableSize))),
          // Si 'Estado Crédito' SÍ debe ser ordenable, usa:
          // _buildSortableColumn('Estado Crédito', 'estadocredito'),
          DataColumn(
            label: Text(
              'Acciones',
              style: TextStyle(fontSize: textHeaderTableSize),
            ),
          ),
        ],
        rows: listaCreditos.map((credito) {
          return DataRow(
            onSelectChanged: (isSelected) {
              if (isSelected == true) {
                showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (context) => InfoCredito(
                    folio: credito.folio,
                    tipoUsuario: userData.tipoUsuario,
                  ),
                );
              }
            },
            cells: [
              DataCell(Text(credito.tipo,
                  style: TextStyle(fontSize: textTableSize))),
              DataCell(Text(credito.tipoPlazo,
                  style: TextStyle(fontSize: textTableSize))),
              DataCell(Container(
                width: 80,
                child: Text(
                  credito.nombreGrupo,
                  style: TextStyle(fontSize: textTableSize),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: true,
                ),
              )),
              DataCell(Center(
                  child: Text('\$${formatearNumero(credito.montoTotal)}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  // Interés
                  child: Text('${credito.ti_mensual}%',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  // Monto a Recuperar
                  child: Text('\$${formatearNumero(credito.montoMasInteres)}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  // Día Pago
                  child: Text('${credito.diaPago}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  // Pago Periodo
                  child: Text('\$${formatearNumero(credito.pagoCuota)}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text('${credito.numPago}',
                      style: TextStyle(fontSize: textTableSize)))),
              DataCell(Center(
                  child: Text(credito.estadoInterno!,
                      style: TextStyle(fontSize: textTableSize)))),
              /*   DataCell(Container(
                width: 70,
                child: Text(
                  credito.fechasIniciofin,
                  style: TextStyle(fontSize: textTableSize),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: true,
                ),
              )), */
              // En tu DataCell
// En tu DataCell
              DataCell(
                Center(
                  child: Tooltip(
                    message: DateFormat('yyyy-MM-dd hh:mm a')
                        .format(credito.fCreacion),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(credito.fCreacion),
                      style: TextStyle(fontSize: textTableSize),
                    ),
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(credito.estado, context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(credito.estado, context)
                          .withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    credito.estado ?? 'N/A',
                    style: TextStyle(
                      color: _getStatusTextColor(credito.estado, context),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(
                Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding:
                          EdgeInsets.zero, // <-- elimina el padding interno
                      iconSize: 20, // <-- ajusta tamaño si quieres más compacto
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirmar eliminación'),
                            content: const Text(
                                '¿Estás seguro de eliminar este crédito?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _eliminarCredito(credito.idcredito);
                                },
                                child: const Text('Eliminar',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
            ],
            color: MaterialStateColor.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.blue.withOpacity(0.1);
              } else if (states.contains(MaterialState.hovered)) {
                return Colors.blue.withOpacity(0.2);
              }
              return Colors.transparent;
            }),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String? estado, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    switch (estado) {
      case 'Activo':
        return isDarkMode
            ? Color(0xFF3674B5)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFF3674B5).withOpacity(0.1); // Fondo claro para modo claro
      case 'Finalizado':
        return isDarkMode
            ? Color(0xFFA31D1D)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFFA31D1D).withOpacity(0.1); // Fondo claro para modo claro
      default:
        return isDarkMode
            ? Colors.grey.withOpacity(0.2) // Fondo más oscuro para modo oscuro
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
        case 'Activo':
          return Color(0xFF3674B5)
              .withOpacity(0.8); // Color original para "Activo"
        case 'Finalizado':
          return Color(0xFFA31D1D)
              .withOpacity(0.8); // Color original para "Finalizado"
        default:
          return Colors.grey.withOpacity(0.8); // Color original por defecto
      }
    }
  }

  Future<void> _eliminarCredito(String idCredito) async {
    // Mostrar SnackBar de carga
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 20),
            Text('Eliminando crédito...'),
          ],
        ),
        duration: const Duration(
            minutes: 1), // Duración larga para mantenerlo visible
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/creditos/$idCredito'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        // Actualizar lista
        obtenerCreditos();
        // Mostrar SnackBar de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Crédito eliminado exitosamente',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
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
            // Limpiar token y redirigir
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
          } else if (response.statusCode == 401) {
            _handleTokenExpiration();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error al eliminar: ${errorData['Error']['Message']}',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (parseError) {
          // Si no podemos parsear la respuesta, mostramos un error genérico
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al procesar la respuesta del servidor',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error de conexión. Verifica tu red.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error inesperado: $e',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void mostrarDialogoExito(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Éxito'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Función para formatear números
String formatearNumero(double numero) {
  final formatter = NumberFormat("#,##0.00", "en_US");
  return formatter.format(numero);
}
