import 'dart:convert';
import 'dart:io';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/widgets/filtros_genericos_widget.dart';
import 'package:finora/widgets/pagination.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:finora/dialogs/infoCliente.dart';
import 'package:finora/dialogs/nCliente.dart';
import 'dart:async';

import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' show max, min; // Add this import at the top of the file

class ClientesScreen extends StatefulWidget {
  const ClientesScreen();

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> listaClientes = [];
  bool isLoading = true;
  bool showErrorDialog = false;
  Timer? _timer;
  bool errorDeConexion = false;
  bool noClientsFound = false;
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
    obtenerClientes();
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
        clave: 'tipocliente', // Clave interna que usarás
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
          'En Grupo'
        ], // Se llenará dinámicamente
      ),
    ];
  }

  final double textHeaderTableSize = 12.0;
  final double textTableSize = 12.0;

  Future<void> obtenerClientes({int page = 1}) async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noClientsFound = false;
      currentPage = page; // Actualizar página actual
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
            '$baseUrl/api/v1/clientes?limit=12&page=$page$sortQuery&$filterQuery');
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
              listaClientes =
                  data.map((item) => Cliente.fromJson(item)).toList();
              //listaClientes.sort((a, b) => b.fCreacion.compareTo(a.fCreacion));

              isLoading = false;
              errorDeConexion = false;
              totalDatos = totalDatosResp;
              totalPaginas = totalPaginasResp;
            });
            _timer?.cancel();
          } else {
            // En caso de error, resetear paginación
            setState(() {
              totalDatos = 0;
              totalPaginas = 1;
            });
            // Intentar decodificar el cuerpo de la respuesta para verificar mensajes de error específicos
            try {
              final errorData = json.decode(response.body);

              // Verificar si es el mensaje específico de sesión cambiada
              if (errorData["Error"] != null &&
                  errorData["Error"]["Message"] ==
                      "La sesión ha cambiado. Cerrando sesión...") {
                if (mounted) {
                  setState(() => isLoading = false);
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
              // Manejar error de no hay clientes
              else if (response.statusCode == 400 &&
                  errorData["Error"]["Message"] ==
                      "No hay ningun cliente registrado") {
                setState(() {
                  listaClientes = [];
                  isLoading = false;
                  noClientsFound = true;
                });
                _timer?.cancel();
              }
              // Otros errores
              else {
                setErrorState(dialogShown);
              }
            } catch (parseError) {
              // Si no se puede parsear el cuerpo de la respuesta, manejar como error genérico
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

    if (!noClientsFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noClientsFound) {
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

  // Reemplaza el método _buildPaginationControls por:
  Widget _buildPaginationControls(bool isDarkMode) {
    return PaginationWidget(
      currentPage: currentPage,
      totalPages: totalPaginas,
      currentPageItemCount: listaClientes.length,
      totalDatos: totalDatos,
      isDarkMode: isDarkMode,
      onPageChanged: (page) {
        if (_isSearching) {
          searchClientes(_currentSearchQuery, page: page);
        } else {
          obtenerClientes(page: page);
        }
      },
    );
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

  Future<void> searchClientes(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      // Si la búsqueda está vacía, llama a obtenerCreditos que ya incluye el sort
      _isSearching = false;
      _currentSearchQuery = '';
      obtenerClientes(
          page: page); // Usará el _sortColumnKey y _sortAscending actuales
      return;
    }
    _isSearching = true;
    _currentSearchQuery = query;

    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noClientsFound = false;
      currentPage = page; // Actualizar página actual para búsqueda
    });

    String sortQuery = '';
    if (_sortColumnKey != null) {
      sortQuery = '&$_sortColumnKey=${_sortAscending ? 'AZ' : 'ZA'}';
    }

    String filterQuery = _buildFilterQuery();
    final encodedQuery = Uri.encodeComponent(query);
    final uri = Uri.parse(
        '$baseUrl/api/v1/clientes/$encodedQuery?limit=12&page=$page$sortQuery&$filterQuery');
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
          listaClientes = data.map((item) => Cliente.fromJson(item)).toList();
          isLoading = false;
          totalDatos = totalDatosResp;
          totalPaginas = totalPaginasResp;
        });
      } else {
        // Intentar decodificar el cuerpo de la respuesta para verificar mensajes de error específicos
        try {
          final errorData = json.decode(response.body);

          // Verificar si es el mensaje específico de sesión cambiada
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            if (mounted) {
              setState(() => isLoading = false);
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
          // Manejar 401 para token expirado
          else if (response.statusCode == 401) {
            _handleTokenExpiration();
          }
          // Manejar error de no hay clientes
          else if (response.statusCode == 400) {
            // Si el mensaje específicamente dice que no hay resultados
            if (errorData["Error"] != null &&
                errorData["Error"]["Message"] ==
                    "No hay ningun cliente registrado") {
              setState(() {
                listaClientes = [];
                isLoading = false;
                noClientsFound = true;
              });
            } else {
              // Otros errores 400
              setState(() {
                listaClientes = [];
                isLoading = false;
                noClientsFound = true;
              });
            }
          }
          // Otros errores
          else {
            setState(() {
              isLoading = false;
              errorDeConexion = true;
            });
          }
        } catch (parseError) {
          // Si no se puede parsear el cuerpo de la respuesta, manejar como error genérico
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

  // Función para eliminar el cliente
  Future<void> eliminarCliente(BuildContext context, String idCliente) async {
    // Muestra el diálogo de confirmación
    bool? confirm = await mostrarDialogoConfirmacion(context);
    if (confirm == true) {
      // Muestra el CircularProgressIndicator mientras se realiza la eliminación
      showDialog(
        context: context,
        barrierDismissible:
            false, // No permite cerrar el diálogo tocando fuera de él
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Realiza la solicitud DELETE a la API
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        final response = await http.delete(
          Uri.parse('$baseUrl/api/v1/clientes/$idCliente'),
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        // Siempre cerramos el diálogo de carga antes de mostrar cualquier otro diálogo
        Navigator.pop(context); // Cierra el CircularProgressIndicator

        if (response.statusCode == 200) {
          print('Cliente eliminado con éxito. ID: $idCliente');
          mostrarSnackBar(context, 'Cliente eliminado correctamente');
          obtenerClientes();
        } else {
          // Intenta decodificar la respuesta del servidor
          try {
            final Map<String, dynamic> errorData = json.decode(response.body);

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
            // Para otros errores, mostramos el mensaje del error
            else {
              final errorMessage =
                  errorData["Error"]["Message"] ?? "Error desconocido";
              print('Error al eliminar el cliente: ${response.statusCode}');
              print('Respuesta del servidor: ${response.body}');
              mostrarMensajeError(context, errorMessage);
            }
          } catch (e) {
            // Si no se puede decodificar el JSON, muestra un mensaje genérico
            print('Error al decodificar la respuesta del servidor: $e');
            print('Respuesta del servidor sin decodificar: ${response.body}');
            mostrarMensajeError(context, 'Error al eliminar el cliente');
          }
        }
      } catch (e) {
        // Cerramos el diálogo de carga si hay una excepción
        Navigator.pop(context);

        print('Error de conexión al eliminar el cliente: $e');
        mostrarMensajeError(context, 'Error de conexión');
      }
    }
  }

// Función para mostrar un SnackBar con el mensaje de éxito
  void mostrarSnackBar(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

// Función para mostrar el diálogo de confirmación
  Future<bool?> mostrarDialogoConfirmacion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // No cierra el diálogo al tocar fuera de él
      builder: (context) => AlertDialog(
        title: Text('¿Confirmar eliminación?'),
        content: Text('¿Estás seguro de que deseas eliminar este cliente?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

// Función para mostrar mensajes de error
  void mostrarMensajeError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema
    return Scaffold(
      backgroundColor:
          isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA), // Fondo dinámico
      appBar: CustomAppBar(
          isDarkMode: isDarkMode,
          toggleDarkMode: (value) {
            themeProvider.toggleDarkMode(value); // Cambia el tema
          },
          title: 'Clientes'),
      body: Column(
        children: [
          if (!errorDeConexion) filaBuscarYAgregar(context),
          Expanded(child: _buildTableContainer()),
        ],
      ),
    );
  }

  Widget _buildTableContainer() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

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
                  obtenerClientes();
                } else {
                  searchClientes(_searchController.text);
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
      return noClientsFound || listaClientes.isEmpty
          ? Center(
              child: Text(
                'No hay clientes para mostrar.',
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
                      child: tablaClientes(context),
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
                          _currentSearchQuery = '';
                          setState(() => _isSearching = false);
                          obtenerClientes();
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
                _currentSearchQuery = value;
                if (_debounceTimer?.isActive ?? false) {
                  _debounceTimer!.cancel();
                }
                _debounceTimer = Timer(Duration(milliseconds: 500), () {
                  if (_currentSearchQuery.trim().isEmpty) {
                    setState(() => _isSearching = false);
                    obtenerClientes();
                  } else {
                    setState(() => _isSearching = true);
                    searchClientes(_currentSearchQuery,
                        page: 1); // Siempre empieza en página 1 al buscar
                  }
                });
              },
            ),
          ),
          Row(
            children: [
              _buildFilterButton(context, isDarkMode),
              SizedBox(width: 10), // Espaciado
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
                onPressed: mostrarDialogoAgregarCliente,
                child: Text('Agregar Clientes'),
              ),
            ],
          ),
        ],
      ),
    );
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
      searchClientes(_currentSearchQuery, page: 1);
    } else {
      obtenerClientes(page: 1);
    }
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
      searchClientes(_searchController.text, page: 1);
    } else {
      obtenerClientes(page: 1);
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

  Widget tablaClientes(BuildContext context) {
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
            child: listaClientes.isEmpty
                ? Center(
                    child: Text(
                      'No hay clientes para mostrar.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
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
                                  label: Text('Tipo Cliente',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              _buildSortableColumn(
                                  'Nombre', 'nombrecompleto'), // Clave API
                              /*   DataColumn(
                                  label: Text('F. Nac',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))), */
                              DataColumn(
                                  label: Text('Sexo',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Teléfono',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Email',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              _buildSortableColumn(
                                  'Fecha Creación', 'fCreacion'), // Clave API
                              DataColumn(
                                  label: Text('Estado',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Acciones',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                            ],
                            rows: listaClientes.map((cliente) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(cliente.tipoclientes ?? 'N/A',
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(
                                      '${cliente.nombres ?? 'N/A'} ${cliente.apellidoP ?? 'N/A'} ${cliente.apellidoM ?? 'N/A'}',
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  /*    DataCell(Text(
                                      formatDate(cliente.fechaNac) ?? 'N/A',
                                      style:
                                          TextStyle(fontSize: textTableSize))), */
                                  DataCell(Text(cliente.sexo ?? 'N/A',
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(cliente.telefono ?? 'N/A',
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(cliente.email ?? 'N/A',
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(
                                    Tooltip(
                                      message: cliente.fCreacion ??
                                          'N/A', // Fecha completa en tooltip
                                      child: Text(
                                        cliente.fCreacion != null
                                            ? cliente.fCreacion!
                                                .split(' ')[0] // Solo la fecha
                                            : 'N/A', // Si es null, mostrar 'N/A'
                                        style:
                                            TextStyle(fontSize: textTableSize),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(cliente.estado,
                                            context), // Fondo dinámico
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getStatusColor(
                                                  cliente.estado, context)
                                              .withOpacity(
                                                  0.6), // Borde dinámico
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        cliente.estado ?? 'N/A',
                                        style: TextStyle(
                                          color: _getStatusTextColor(
                                              cliente.estado,
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
                                                cliente.idclientes!);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.grey),
                                          onPressed: () async {
                                            await eliminarCliente(
                                                context, cliente.idclientes!);
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
                                      builder: (context) => InfoCliente(
                                          idCliente: cliente.idclientes!),
                                    );
                                    if (resultado == true) {
                                      obtenerClientes();
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
      case 'En Credito':
        return isDarkMode
            ? Color(0xFFA31D1D)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFFA31D1D).withOpacity(0.1); // Fondo claro para modo claro
      case 'En Grupo':
        return isDarkMode
            ? Color(0xFF3674B5)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFF3674B5).withOpacity(0.1); // Fondo claro para modo claro
      case 'Disponible':
        return isDarkMode
            ? Color(0xFF059212)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFF059212).withOpacity(0.1); // Fondo claro para modo claro
      case 'Disponible Extra':
        return isDarkMode
            ? Color(0xFFE53888)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFFE53888).withOpacity(0.1); // Fondo claro para modo claro
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
        case 'En Credito':
          return Color(0xFFA31D1D)
              .withOpacity(0.8); // Color original para "En Credito"
        case 'En Grupo':
          return Color(0xFF3674B5)
              .withOpacity(0.8); // Color original para "En Grupo"
        case 'Disponible':
          return Color(0xFF059212)
              .withOpacity(0.8); // Color original para "Disponible"
        case 'Disponible Extra':
          return Color(0xFFE53888)
              .withOpacity(0.8); // Color original para "Disponible"
        default:
          return Colors.grey.withOpacity(0.8); // Color original por defecto
      }
    }
  }

  void mostrarDialogoAgregarCliente() {
    showDialog(
      barrierDismissible: false, // No se puede cerrar tocando fuera
      context: context,
      builder: (context) {
        return nClienteDialog(
          onClienteAgregado: () {
            obtenerClientes(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }

  void mostrarDialogoEditarCliente(String idCliente) {
    showDialog(
      barrierDismissible: false, // No se puede cerrar tocando fuera
      context: context,
      builder: (context) {
        return nClienteDialog(
          idCliente: idCliente, // Pasa el ID del cliente a editar
          onClienteEditado: () {
            obtenerClientes(); // Refresca la lista de clientes después de editar uno
          },
        );
      },
    );
  }
}

class Cliente {
  final String idclientes;
  final String tipoclientes;
  final String? nombres; // Cambiar a String?
  final String? apellidoP; // Cambiar a String?
  final String? apellidoM; // Cambiar a String?
  final String fechaNac;
  final String sexo;
  final String? telefono; // Cambiar a String?
  final String? email; // Cambiar a String?
  final String eCilvi;
  final String estado;
  final String fCreacion;

  Cliente({
    required this.idclientes,
    required this.tipoclientes,
    this.nombres,
    this.apellidoP,
    this.apellidoM,
    required this.fechaNac,
    required this.sexo,
    this.telefono,
    this.email,
    required this.eCilvi,
    required this.estado,
    required this.fCreacion,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      idclientes: json['idclientes'],
      tipoclientes: json['tipo_cliente'],
      nombres: json['nombres'] ?? 'N/A', // Proveer 'N/A' si es null
      apellidoP: json['apellidoP'] ?? 'N/A', // Proveer 'N/A' si es null
      apellidoM: json['apellidoM'] ?? 'N/A', // Proveer 'N/A' si es null
      fechaNac: json['fechaNac'],
      sexo: json['sexo'],
      telefono: json['telefono'] ?? 'N/A', // Proveer 'N/A' si es null
      email: json['email'] == null || json['email'].trim().isEmpty
          ? 'No asignado'
          : json['email'],
      eCilvi: json['eCivil'],
      estado: json['estado'] ?? 'N/A',
      fCreacion: json['fCreacion'],
    );
  }
}
