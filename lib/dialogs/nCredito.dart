import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:finora/formateador.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasaInteres {
  final int idtipointeres;
  final double mensual;
  final String fCreacion;

  TasaInteres({
    required this.idtipointeres,
    required this.mensual,
    required this.fCreacion,
  });

  factory TasaInteres.fromJson(Map<String, dynamic> json) {
    return TasaInteres(
      idtipointeres: json['idtipointeres'],
      mensual: (json['mensual'] as num).toDouble(),
      fCreacion: json['fCreacion'],
    );
  }
}

class Duracion {
  final int idduracion;
  final int plazo;
  final String frecuenciaPago;
  final DateTime fCreacion;

  Duracion({
    required this.idduracion,
    required this.plazo,
    required this.frecuenciaPago,
    required this.fCreacion,
  });

  factory Duracion.fromJson(Map<String, dynamic> json) {
    return Duracion(
      idduracion: json['idduracion'],
      plazo: json['plazo'],
      frecuenciaPago: json['frecuenciaPago'],
      fCreacion: DateTime.parse(json['fCreacion']),
    );
  }
}

class nCreditoDialog extends StatefulWidget {
  final VoidCallback onCreditoAgregado;

  nCreditoDialog({required this.onCreditoAgregado});

  @override
  _nCreditoDialogState createState() => _nCreditoDialogState();
}

class _nCreditoDialogState extends State<nCreditoDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // Formulario general
  final GlobalKey<FormState> _infoGrupoFormKey =
      GlobalKey<FormState>(); // Formulario de Datos Generales
  final GlobalKey<FormState> _miembrosGrupoFormKey =
      GlobalKey<FormState>(); // Formulario de Integrantes

  late ScrollController _scrollControllerIntegrantes;
  late ScrollController _scrollControllerCPagos;

  String? garantia;
  String? frecuenciaPago;
  String? diaPago;
  DateTime fechaInicio = DateTime.now();

  final montoController = TextEditingController();

  // --- NUEVO: Estado para configuración de crédito ---
  bool _cargandoConfig = true;
  String? _errorConfig;
  List<TasaInteres> _listaTasas = [];
  List<Duracion> _listaDuraciones = [];

  // --- MODIFICADO: Usamos los modelos para la selección ---
  TasaInteres? _tasaSeleccionada;
  Duracion? _duracionSeleccionada;
  final tasaInteresController = TextEditingController();
  final plazoController = TextEditingController();

  // En la parte superior de tu clase, declara las variables
  double pagoTotal = 0.0; // Agregar como variable de clase
  double montoGarantia = 0.0; // Agregar como variable de clase

  // Datos para los integrantes y sus montos individuales
  List<Cliente> integrantes = [];

  // Inicializamos montosIndividuales como un Map<String, double>
  Map<String, double> montosIndividuales = {};

  double? tasaInteresMensualSeleccionada;

  bool _isSaving = false;

  List<double> tasas = [
    6.00,
    8.00,
    8.12,
    8.20,
    8.52,
    8.60,
    8.80,
    9.00,
    9.28,
    0.0 // Representa la opción "Otro"
  ];

  String? otroValor; // Para almacenar el valor del TextField

  TextEditingController _otroValorController = TextEditingController();

  List<Grupo> listaGrupos = [];
  String? selectedGrupo;
  bool isLoading = true;
  bool errorDeConexion = false;
  bool noGroupsFound = false;
  bool dialogShown = false;
  Timer? _timer;

  String _formatearFecha(DateTime fecha) {
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  String _formatearFechaServidor(DateTime fecha) {
    return DateFormat('yyyy-MM-dd').format(fecha);
  }

  // Declaración de variables
  String? tasaInteres = '';
  double tasaInteresMensualCalculada = 0.0;
  String? garantiaTexto = '';
  String? frecuenciaPagoTexto = '';
  double interesGlobal = 0.0;
  String? montoAutorizado = '';
  double interesTotal = 0.0;
  double totalARecuperar = 0.0;
  int plazoNumerico = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentIndex = _tabController.index);
    });

    _scrollControllerIntegrantes = ScrollController();
    _scrollControllerCPagos = ScrollController();

    diaPago = _diaDeLaSemana(fechaInicio);
    frecuenciaPago = "Semanal"; // Valor predeterminado

    // --- NUEVO: Cargar toda la data inicial en paralelo ---
    _cargarDatosIniciales();
  }

  // --- NUEVO: Método central para cargar datos de grupos y configuración ---
  Future<void> _cargarDatosIniciales() async {
    setState(() {
      isLoading = true; // Carga de grupos
      _cargandoConfig = true; // Carga de configuración
    });

    // Ejecuta la carga de grupos y de configuración en paralelo
    await Future.wait([
      obtenerGrupos(),
      _cargarConfiguracionCredito(),
    ]);

    // Actualiza el estado de carga general al finalizar
    if (mounted) {
      setState(() {
        isLoading = false;
        _cargandoConfig = false;
      });
    }
  }

  // --- NUEVO: Lógica para obtener Tasas de Interés de la API ---
  Future<void> _fetchTasasDeInteres() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/tazainteres/'),
        headers: {'tokenauth': token},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _listaTasas =
                data.map((item) => TasaInteres.fromJson(item)).toList();
          });
        }
      } else {
        throw Exception('Error al cargar tasas: ${response.body}');
      }
    } catch (e) {
      throw Exception('Excepción al cargar tasas: $e');
    }
  }

  // --- NUEVO: Lógica para obtener Duraciones de la API ---
  Future<void> _fetchDuraciones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/duracion'),
        headers: {'tokenauth': token},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _listaDuraciones =
                data.map((item) => Duracion.fromJson(item)).toList();
          });
        }
      } else {
        throw Exception('Error al cargar plazos: ${response.body}');
      }
    } catch (e) {
      throw Exception('Excepción al cargar plazos: $e');
    }
  }

  // --- NUEVO: Gestor de carga para la configuración ---
  Future<void> _cargarConfiguracionCredito() async {
    try {
      // Reinicia el estado
      if (mounted) setState(() => _errorConfig = null);

      await Future.wait([
        _fetchTasasDeInteres(),
        _fetchDuraciones(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorConfig = e.toString();
        });
      }
    }
  }

  // --- NUEVO: Getter para filtrar duraciones por frecuencia ---
  List<Duracion> get _duracionesFiltradas {
    if (frecuenciaPago == null) return [];
    // Filtra la lista de duraciones basándose en la frecuencia seleccionada
    return _listaDuraciones
        .where((d) => d.frecuenciaPago == frecuenciaPago)
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollControllerIntegrantes.dispose();
    _scrollControllerCPagos.dispose();
    _timer?.cancel();
    montoController.dispose();
    super.dispose();
  }

  Future<void> _mostrarDialogoAdvertencia(BuildContext context) async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¡Advertencia!'),
        content: Text(
            'La suma de los montos individuales no coincide con el monto total.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _validarSumaMontos(BuildContext context) async {
    // Obtener monto total convertido a double
    double montoTotal = obtenerMontoReal(montoController.text);

    // Sumar montos individuales ya convertidos
    double sumaMontosIndividuales = montosIndividuales.values
        .fold(0.0, (previousValue, element) => previousValue + element);

    print('Suma individual: $sumaMontosIndividuales');
    print('Monto total: $montoTotal');

    // Comparar con margen de error para decimales
    if ((sumaMontosIndividuales - montoTotal).abs() > 0.001) {
      await _mostrarDialogoAdvertencia(context);
      return false;
    }
    return true;
  }

  Future<bool> _validarFormularioActual(BuildContext context) async {
    if (_currentIndex == 0) {
      return _infoGrupoFormKey.currentState?.validate() ??
          false; // Validar Datos Generales
    } else if (_currentIndex == 1) {
      bool sumaValida = await _validarSumaMontos(context);
      if (!sumaValida) {
        return false; // Si la suma no es válida, no permitir continuar
      }
      return _miembrosGrupoFormKey.currentState?.validate() ??
          false; // Validar Integrantes
    } else if (_currentIndex == 2) {
      return _formKey.currentState?.validate() ?? false; // Validar Resumen
    }
    return false; // Si el índice no coincide con ningún caso
  }

  String _diaDeLaSemana(DateTime fecha) {
    const dias = [
      "Domingo",
      "Lunes",
      "Martes",
      "Miércoles",
      "Jueves",
      "Viernes",
      "Sábado"
    ];
    return dias[fecha.weekday % 7];
  }

  void _guardarCredito() async {
    if (_isSaving) return;

    setState(() => _isSaving = true); // Activar overlay

    try {
      final datosParaServidor = generarDatosParaServidor();
      await enviarCredito(datosParaServidor);
      print('Datos a enviar: ${jsonEncode(datosParaServidor)}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false); // Desactivar overlay
      }
    }
  }

  // Actualiza el método enviarCredito
  Future<void> enviarCredito(Map<String, dynamic> datos) async {
    final String url = '$baseUrl/api/v1/creditos';

    try {
      // Imprimir los datos antes de enviar
      print('══════════════ DATOS A ENVIAR ══════════════');
      print('URL: $url');
      print('Datos: ${jsonEncode(datos)}');
      print('══════════════════════════════════════════');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(datos),
      );

      if (mounted) {
        // Respuesta exitosa
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Crédito guardado exitosamente',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
          widget.onCreditoAgregado();
          Navigator.of(context).pop();
        } else {
          // Imprimir detalles del error en consola
          print('══════════════ ERROR ══════════════');
          print('Status Code: ${response.statusCode}');
          print('Response Body: ${response.body}');
          print('═══════════════════════════════════');

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
              await prefs.remove('tokenauth');
              mostrarDialogoError(
                'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                onClose: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
              );
              return;
            } else {
              _mostrarError(
                  'Error del servidor: ${errorData["Error"]["Message"] ?? "Error desconocido"}');
            }
          } catch (e) {
            print('Error al decodificar respuesta: $e');
            _mostrarError('Error inesperado: ${response.body}');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        print('══════════════ EXCEPCIÓN ══════════════');
        print('Error completo: $e');
        if (e is http.ClientException) {
          print('Error de conexión: ${e.message}');
          print('URI: ${e.uri}');
        }
        print('══════════════════════════════════════');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión. Verifica tu red.'),
            backgroundColor: Colors.red,
          ),
        );
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

  void _mostrarError(String mensaje) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Aceptar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> obtenerGrupos() async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noGroupsFound = false;
    });

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/grupodetalles'),
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        if (mounted) {
          if (response.statusCode == 200) {
            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaGrupos = data
                  .map((item) => Grupo.fromJson(item))
                  .where((grupo) =>
                      grupo.estado == "Disponible") // Filtrar por estado
                  .toList();
              isLoading = false;
              errorDeConexion = false;
            });
            _timer?.cancel();
          } else {
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
                  _timer?.cancel(); // Cancela el temporizador antes de navegar

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
              } else if (response.statusCode == 400 &&
                  errorData["Error"] != null &&
                  errorData["Error"]["Message"] ==
                      "No hay grupos registrados") {
                setState(() {
                  listaGrupos = [];
                  isLoading = false;
                  noGroupsFound = true;
                });
                _timer?.cancel();
              } else {
                setErrorState(dialogShown);
              }
            } catch (parseError) {
              // Si no podemos parsear la respuesta, delegamos al manejador de errores existente
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
      _timer?.cancel(); // Detener intentos de reconexión en caso de error
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    final width = MediaQuery.of(context).size.width * 0.9;
    final height = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      backgroundColor: isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA),
      //surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(children: [
        Container(
          width: width,
          height: height,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Agregar/Asignar Crédito',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Focus(
                canRequestFocus: false,
                descendantsAreFocusable: false,
                child: IgnorePointer(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF5162F6),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF5162F6),
                    tabs: const [
                      Tab(text: 'Datos Generales'),
                      Tab(text: 'Integrantes'),
                      Tab(text: 'Resumen'),
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
                      child: _paginaDatosGenerales(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          right: 30, top: 10, bottom: 10, left: 0),
                      child: _paginaIntegrantes(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          right: 30, top: 10, bottom: 10, left: 0),
                      child: _paginaResumen(),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
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
                      if (_currentIndex < 2)
                        ElevatedButton(
                          onPressed: () async {
                            bool esValido = await _validarFormularioActual(
                                context); // Esperamos la validación
                            if (esValido) {
                              _tabController.animateTo(_currentIndex +
                                  1); // Solo si es válido, avanzamos
                            }
                          },
                          child: Text('Siguiente'),
                        ),
                      // En la sección del botón:
                      if (_currentIndex == 2)
                        ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : _guardarCredito, // Deshabilitar durante el guardado
                          child: Text('Guardar'),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Overlay de carga
        // Overlay de carga con fondo blanco
        if (_isSaving)
          IgnorePointer(
            // Bloquea las interacciones
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey[900]
                    : Color(0xFFF7F8FA), // Fondo dinámico
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF5162F6),
                  strokeWidth: 4,
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _paginaDatosGenerales() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    int pasoActual = 1; // Paso actual para esta página

    // --- 1. Manejo de estados de Carga y Error (sin cambios) ---
    if (_cargandoConfig || isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF5162F6)),
            SizedBox(height: 16),
            Text("Cargando configuración...",
                style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
          ],
        ),
      );
    }

    if (_errorConfig != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text('Error al cargar la configuración',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text(
                  'No se pudieron obtener las tasas y plazos. Por favor, verifica tu conexión a internet.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _cargarDatosIniciales,
                icon: Icon(Icons.refresh),
                label: Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF5162F6)),
              ),
            ],
          ),
        ),
      );
    }

    // --- 2. Construcción del Formulario con TU DISEÑO ORIGINAL ---
    return Form(
      key: _infoGrupoFormKey,
      child: Row(
        children: [
          // Si usas un recuadro de pasos, iría aquí.
          _recuadroPasos(pasoActual),

          SizedBox(width: 50), // Tu espaciador

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 10),
              // Estructura de Column para organizar las filas
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- PRIMERA FILA: Grupo y Monto ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          context: context,
                          value: selectedGrupo,
                          hint: 'Seleccionar Grupo',
                          items: listaGrupos
                              .map((grupo) => grupo.nombreGrupo)
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedGrupo = value;
                              if (value != null) {
                                var grupoSeleccionado = listaGrupos
                                    .firstWhere((g) => g.nombreGrupo == value);
                                integrantes = grupoSeleccionado.clientes;
                                montosIndividuales.clear();
                              }
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Seleccione un grupo' : null,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          context,
                          controller: montoController,
                          label: 'Monto Autorizado',
                          icon: Icons.attach_money,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))
                          ],
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Ingrese el monto' : null,
                          onChanged: (value) {
                            String formatted = formatMonto(value);
                            if (montoController.text != formatted) {
                              montoController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                    offset: formatted.length),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),

                  // --- SEGUNDA FILA: Tasa y Garantía ---
                  Row(
                    children: [
                      // --- REEMPLAZO: Dropdown de Tasa de Interés (dinámico) ---
                      Expanded(
                        child: _buildModelDropdown<TasaInteres>(
                          context: context,
                          value: _tasaSeleccionada,
                          hint: 'Tasa de Interés',
                          items: _listaTasas,
                          itemBuilder: (tasa) => Text('${tasa.mensual}% '),
                          onChanged: (tasa) =>
                              setState(() => _tasaSeleccionada = tasa),
                          validator: (tasa) =>
                              tasa == null ? 'Seleccione una tasa' : null,
                        ),
                      ),
                      SizedBox(width: 10),

                      // --- Dropdown de Garantía (original) ---
                      Expanded(
                        child: _buildDropdown(
                          context: context,
                          value: garantia,
                          hint: 'Garantía',
                          items: ["Sin garantía", "5%", "10%"],
                          onChanged: (value) =>
                              setState(() => garantia = value),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),

                  // --- TERCERA FILA: Frecuencia y Plazo ---
                  Row(
                    children: [
                      // --- Dropdown de Frecuencia (original) ---
                      Expanded(
                        child: _buildDropdown(
                          context: context,
                          value: frecuenciaPago,
                          hint: 'Frecuencia de Pago',
                          items: ["Semanal", "Quincenal"],
                          onChanged: (value) {
                            setState(() {
                              frecuenciaPago = value;
                              _duracionSeleccionada = null;
                            });
                          },
                          validator: (v) =>
                              v == null ? 'Seleccione la frecuencia' : null,
                        ),
                      ),
                      SizedBox(width: 10),

                      // --- REEMPLAZO: Dropdown de Plazo (dinámico y filtrado) ---
                      Expanded(
                        child: _buildModelDropdown<Duracion>(
                          context: context,
                          value: _duracionSeleccionada,
                          hint: 'Plazo',
                          items: _duracionesFiltradas,
                          itemBuilder: (d) => Text('${d.plazo} pagos'),
                          onChanged: (duracion) =>
                              setState(() => _duracionSeleccionada = duracion),
                          validator: (d) =>
                              d == null ? 'Seleccione un plazo' : null,
                          isEnabled: frecuenciaPago != null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),

                  // --- CUARTA FILA: Fecha de Inicio y Día de Pago ---
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fecha de Inicio: ${_formatearFecha(fechaInicio)}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        child: Text(
                          'Cambiar',
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.blue[300]
                                  : Color(0xFF5162F6)),
                        ),
                        onPressed: () async {
                          final nuevaFecha = await showDatePicker(
                            context: context,
                            initialDate: fechaInicio,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            locale: Locale('es', 'ES'),
                            builder: (BuildContext context, Widget? child) {
                              return Theme(
                                data: isDarkMode
                                    ? ThemeData.dark().copyWith(
                                        colorScheme:
                                            ColorScheme.dark().copyWith(
                                          primary: Color(0xFF5162F6),
                                          surface: Color(0xFF303030),
                                          onSurface: Colors.white,
                                        ),
                                        dialogBackgroundColor:
                                            Color(0xFF1F1F1F),
                                      )
                                    : ThemeData.light().copyWith(
                                        primaryColor: Colors.white,
                                        colorScheme:
                                            ColorScheme.fromSwatch().copyWith(
                                          primary: Color(0xFF5162F6),
                                        ),
                                      ),
                                child: child!,
                              );
                            },
                          );

                          if (nuevaFecha != null) {
                            setState(() {
                              fechaInicio = nuevaFecha;
                              diaPago = _diaDeLaSemana(fechaInicio);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Día de Pago: $diaPago',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lista para almacenar los controladores de los TextFields
  List<TextEditingController> _controladoresIntegrantes = [];

  Widget _paginaIntegrantes() {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    int pasoActual = 2; // Paso actual para esta página

// Línea corregida
    if (_controladoresIntegrantes.length != integrantes.length) {
      // Obtener el grupo seleccionado
      var grupoSeleccionado = listaGrupos.firstWhere((grupo) =>
          grupo.nombreGrupo ==
          selectedGrupo); // Seleccionamos el grupo por nombre

      // Usamos los clientes del grupo seleccionado
      integrantes = grupoSeleccionado.clientes;

      // Inicializamos los montos individuales en 0.0 para cada cliente
      for (var i = 0; i < integrantes.length; i++) {
        montosIndividuales[integrantes[i].idclientes] =
            0.0; // Asignamos explícitamente 0.0
      }

      // Inicializamos los controladores asociados a cada integrante
      // Inicializamos los controladores asociados a cada integrante
      _controladoresIntegrantes = List.generate(
        integrantes.length,
        (index) =>
            TextEditingController(), // <-- CAMBIO CLAVE: Sin texto inicial
      );
    }

    // Calculamos la suma total aquí para asegurar que se recalcula cada vez que se renderiza el widget
    double sumaTotal = 0.0;
    montosIndividuales.forEach((key, value) {
      sumaTotal += value ?? 0.0;
    });

    return Row(
      children: [
        _recuadroPasos(pasoActual), // Recuadro de pasos
        SizedBox(width: 50), // Espacio entre el recuadro y el contenido

        // Contenido de la página
        Expanded(
          child: Form(
            key: _miembrosGrupoFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asignar Monto a Integrantes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),

                // Lista de integrantes
                Expanded(
                  child: ListView.builder(
                    itemCount: integrantes.length,
                    itemBuilder: (context, index) {
                      final cliente = integrantes[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                cliente.nombres ?? 'Integrante ${index + 1}',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: _buildTextField(
                                context,
                                controller: _controladoresIntegrantes[index],
                                label: 'Monto',
                                icon: Icons.attach_money,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[\d\.]')),
                                ],
                                keyboardType: TextInputType.numberWithOptions(
                                    decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Ingrese monto';
                                  return null;
                                },
                                onChanged: (value) {
                                  String formatted = formatMonto(value);
                                  if (_controladoresIntegrantes[index].text !=
                                      formatted) {
                                    _controladoresIntegrantes[index].value =
                                        TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(
                                          offset: formatted.length),
                                    );
                                  }
                                  // Actualizar mapa de montos
                                  double parsedValue = double.tryParse(
                                          formatted.replaceAll(',', '')) ??
                                      0.0;
                                  montosIndividuales[cliente.idclientes] =
                                      parsedValue;

                                  // Actualizar la UI para reflejar el nuevo total
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: 20),

                // Sección de suma total de montos
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color.fromARGB(255, 48, 48, 48)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Suma Total:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '\$${formatearNumero(sumaTotal)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Color(0xFF5162F6),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double obtenerMontoReal(String formattedValue) {
    if (formattedValue.isEmpty) return 0.0;

    // 1. Quitar todas las comas
    String sanitized = formattedValue.replaceAll(',', '');

    // 2. Convertir a double
    try {
      return double.parse(sanitized);
    } catch (e) {
      print('Error al convertir: "$formattedValue"');
      return 0.0;
    }
  }

  DateTime calcularFechaTermino(
      DateTime fechaInicio, String frecuenciaPago, int plazo) {
    // Verificar si la frecuencia de pago es "Semanal" o "Quincenal"
    int diasSumar = 0;
    if (frecuenciaPago == "Semanal") {
      diasSumar = plazo * 7; // Si es semanal, multiplicamos el plazo por 7 días
    } else if (frecuenciaPago == "Quincenal") {
      diasSumar =
          plazo * 15; // Si es quincenal, multiplicamos el plazo por 15 días
    }

    return fechaInicio.add(
        Duration(days: diasSumar)); // Sumamos los días a la fecha de inicio
  }

  Widget _paginaResumen() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    int pasoActual = 3;

    // --- CAMBIO CLAVE: Añadir validación ---
    // Si no se han seleccionado los datos, muestra un mensaje y no intentes calcular.
    if (_duracionSeleccionada == null || _tasaSeleccionada == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Datos incompletos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Por favor, complete los Datos Generales para ver el resumen.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // --- CAMBIO CLAVE: Obtener datos de los modelos seleccionados ---
    final double monto = obtenerMontoReal(montoController.text);
    final int plazoNumerico = _duracionSeleccionada!
        .plazo; // <-- CAMBIO: Leer de _duracionSeleccionada
    final double tasaInteresMensualCalculada =
        _tasaSeleccionada!.mensual; // <-- CAMBIO: Leer de _tasaSeleccionada
    final String tasaInteres = "${tasaInteresMensualCalculada}%";

    // Cálculos de resumen (ahora correctos)
    double capitalPago = 0.0;
    double interesPago = 0.0;
    double interesPorcentaje = 0.0;
    double interesTotal = 0.0;
    double interesGlobal = 0.0;
    int pagosTotales = plazoNumerico; // El plazo ya es el número de pagos

    if (frecuenciaPago == "Semanal") {
      interesGlobal = ((tasaInteresMensualCalculada / 4) * plazoNumerico);
      // Evitar división por cero si plazo es 0 (aunque la validación de arriba lo previene)
      capitalPago = (pagosTotales > 0) ? (monto / pagosTotales) : 0;
      interesPago = (monto * (tasaInteresMensualCalculada / 4 / 100));
      interesPorcentaje = (tasaInteresMensualCalculada / 4);
      interesTotal = (interesPago * pagosTotales);
    } else if (frecuenciaPago == "Quincenal") {
      interesGlobal = ((tasaInteresMensualCalculada / 2) * plazoNumerico);
      capitalPago = (pagosTotales > 0) ? (monto / pagosTotales) : 0;
      interesPago = (monto * (tasaInteresMensualCalculada / 2 / 100));
      interesPorcentaje = (tasaInteresMensualCalculada / 2);
      interesTotal = (interesPago * pagosTotales);
    }

    // Si capitalPago es 0, pagoTotal será solo el interés, y viceversa.
    double pagoTotal = capitalPago + interesPago;
    double totalARecuperar = pagoTotal * pagosTotales;

    // Formatear los datos para mostrarlos
    String montoAutorizado = formatearNumero(monto);
    String garantiaTexto = garantia ?? "No especificada";
    String frecuenciaPagoTexto = frecuenciaPago ?? "No especificada";

    DateTime fechaTerminoCalculada =
        calcularFechaTermino(fechaInicio, frecuenciaPago!, plazoNumerico);

    double calcularMontoGarantia(String garantiaTexto, double montoAutorizado) {
      if (garantiaTexto == "Sin garantía") {
        return 0.0;
      }
      RegExp regex = RegExp(r'(\d+(\.\d+)?)');
      Match? match = regex.firstMatch(garantiaTexto);
      if (match != null) {
        double porcentajeGarantia = double.parse(match.group(1)!);
        return montoAutorizado * (porcentajeGarantia / 100);
      }
      return 0.0;
    }

    double montoGarantia = calcularMontoGarantia(garantiaTexto, monto);
    double montoDesembolsadoNumerico = monto - montoGarantia;
    String montoDesembolsadoFormateado =
        formatearNumero(montoDesembolsadoNumerico);

    // El resto de tu widget puede permanecer igual, ya que ahora las variables tienen los valores correctos.
    // ... (El código de la UI del resumen que ya tienes)
    // Por ejemplo:
    return Row(
      children: [
        _recuadroPasos(pasoActual),
        SizedBox(width: 50),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen del Crédito',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  // Sección Datos Generales
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              'Datos Generales - ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                selectedGrupo ?? "No especificado",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('Duración: '),
                            Text(
                              '${_formatearFecha(fechaInicio)}',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w400),
                            ),
                            Text(' - '),
                            Text(
                              '${_formatearFecha(fechaTerminoCalculada)}',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                        Divider(),
                        // Fila 1
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoRow(
                                'Monto autorizado: ', '\$${montoAutorizado}'),
                            _infoRow('Monto Desembolsado: ',
                                '\$${montoDesembolsadoFormateado}'),
                          ],
                        ),
                        // Fila 2
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoRow('Garantía: ', garantiaTexto),
                            _infoRow('Tasa de interés mensual: ', tasaInteres),
                          ],
                        ),
                        // Fila 3
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoRow('Monto Garantía: ',
                                '\$${formatearNumero(montoGarantia)}'),
                            _infoRow(
                              frecuenciaPago == "Semanal"
                                  ? 'Interés Semanal (%): '
                                  : 'Interés Quincenal (%): ',
                              '${interesPorcentaje.toStringAsFixed(2)} %',
                            ),
                          ],
                        ),
                        // Fila 4
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoRow(
                                'Frecuencia de pago: ', frecuenciaPagoTexto),
                            _infoRow('Plazo: ', plazoNumerico.toString()),
                          ],
                        ),
                        // Fila 5
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoRow('Interés Global: ',
                                '${formatearNumero(interesGlobal)}%'),
                            _infoRow(
                                'Día de pago: ', diaPago ?? "No especificado"),
                          ],
                        ),
                        // Fila 6
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoRow(
                                frecuenciaPago == "Semanal"
                                    ? 'Capital Semanal: '
                                    : 'Capital Quincenal: ',
                                '\$${formatearNumero(capitalPago)}'),
                            _infoRow(
                                frecuenciaPago == "Semanal"
                                    ? 'Interés Semanal (\$): '
                                    : 'Interés Quincenal (\$): ',
                                '\$${formatearNumero(interesPago)}'),
                          ],
                        ),
                        // Fila 7
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoRow(
                              frecuenciaPago == "Semanal"
                                  ? 'Pago Semanal: '
                                  : 'Pago Quincenal: ',
                              '\$${formatearNumero(redondearDecimales(pagoTotal, context))}',
                            ),
                            _infoRow('Interés Total: ',
                                '\$${formatearNumero(interesTotal)}'),
                          ],
                        ),
                        // Fila 8
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoRow('Total a Recuperar: ',
                                '\$${formatearNumero(totalARecuperar)}'),
                            Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),
                  // Sección Integrantes y Montos
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 5,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Integrantes y Montos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Divider(),
                        integrantes.isNotEmpty
                            ? Scrollbar(
                                thickness: 7,
                                thumbVisibility:
                                    true, // Hace visible el thumb del Scrollbar
                                trackVisibility:
                                    true, // Hace visible el track del Scrollbar
                                controller:
                                    _scrollControllerIntegrantes, // Controlador del Scrollbar
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: _scrollControllerIntegrantes,
                                  child: DataTable(
                                    columnSpacing:
                                        20, // Espaciado entre columnas
                                    columns: [
                                      DataColumn(
                                          label: Text(
                                        'Integrante',
                                        style: TextStyle(fontSize: 12),
                                      )),
                                      DataColumn(
                                          label: Text(
                                        'Monto Individual',
                                        style: TextStyle(fontSize: 12),
                                      )),
                                      DataColumn(
                                          label: Text(
                                        'Capital Semanal',
                                        style: TextStyle(fontSize: 12),
                                      )),
                                      DataColumn(
                                          label: Text(
                                        'Interés Semanal',
                                        style: TextStyle(fontSize: 12),
                                      )),
                                      DataColumn(
                                          label: Text(
                                        'Total Capital',
                                        style: TextStyle(fontSize: 12),
                                      )),
                                      DataColumn(
                                          label: Text(
                                        'Total Intereses',
                                        style: TextStyle(fontSize: 12),
                                      )),
                                      DataColumn(
                                          label: Text(
                                        'Pago Semanal',
                                        style: TextStyle(fontSize: 12),
                                      )),
                                      DataColumn(
                                          label: Text(
                                        'Pago Total',
                                        style: TextStyle(fontSize: 12),
                                      )),
                                    ],
                                    rows:
                                        integrantes.map<DataRow>((integrante) {
                                      final montoIndividual =
                                          montosIndividuales[
                                                  integrante.idclientes] ??
                                              0.0;
                                      final pagosTotales =
                                          (frecuenciaPago == "Semanal")
                                              ? plazoNumerico
                                              // ANTES: : plazoNumerico * 2;
                                              : plazoNumerico; // <-- CAMBIO

                                      final capitalSemanal =
                                          (montoIndividual / pagosTotales);
                                      final interesSemanal = (montoIndividual *
                                          (tasaInteresMensualCalculada /
                                              (frecuenciaPago == "Semanal"
                                                  ? 4
                                                  : 2) /
                                              100));
                                      final pagoSemanal =
                                          (capitalSemanal + interesSemanal);
                                      final totalCapital =
                                          (capitalSemanal * pagosTotales);
                                      final totalIntereses =
                                          (interesSemanal * pagosTotales);
                                      final pagoTotal =
                                          (totalCapital + totalIntereses);

                                      return DataRow(cells: [
                                        DataCell(Text(
                                          integrante.nombres ??
                                              'No especificado',
                                          style: TextStyle(fontSize: 12),
                                        )),
                                        DataCell(Text(
                                          '\$${formatearNumero(montoIndividual)}',
                                          style: TextStyle(fontSize: 12),
                                        )),
                                        DataCell(Text(
                                          '\$${formatearNumero(capitalSemanal)}',
                                          style: TextStyle(fontSize: 12),
                                        )),
                                        DataCell(Text(
                                          '\$${formatearNumero(interesSemanal)}',
                                          style: TextStyle(fontSize: 12),
                                        )),
                                        DataCell(Text(
                                          '\$${formatearNumero(totalCapital)}',
                                          style: TextStyle(fontSize: 12),
                                        )),
                                        DataCell(Text(
                                          '\$${formatearNumero(totalIntereses)}',
                                          style: TextStyle(fontSize: 12),
                                        )),
                                        DataCell(Text(
                                          '\$${formatearNumero(pagoSemanal)}',
                                          style: TextStyle(fontSize: 12),
                                        )),
                                        DataCell(Text(
                                          '\$${formatearNumero(pagoTotal)}',
                                          style: TextStyle(fontSize: 12),
                                        )),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              )
                            : Text('No se han asignado integrantes.'),
                      ],
                    ),
                  ),
                  // Sección Calendario de Pagos
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 5,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calendario de Pagos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Divider(),
                        Scrollbar(
                          thickness: 7,
                          thumbVisibility: true,
                          controller: _scrollControllerCPagos,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _scrollControllerCPagos,
                            child: DataTable(
                              columnSpacing: 40,
                              columns: [
                                DataColumn(
                                    label: Text('Pago',
                                        style: TextStyle(fontSize: 12.0))),
                                DataColumn(
                                    label: Text('Fecha',
                                        style: TextStyle(fontSize: 12.0))),
                                DataColumn(
                                    label: Text('Capital',
                                        style: TextStyle(fontSize: 12.0))),
                                DataColumn(
                                    label: Text('Interés',
                                        style: TextStyle(fontSize: 12.0))),
                                DataColumn(
                                    label: Text('Pago Total',
                                        style: TextStyle(fontSize: 12.0))),
                                DataColumn(
                                    label: Text('Pagado',
                                        style: TextStyle(fontSize: 12.0))),
                                DataColumn(
                                    label: Text('Restante',
                                        style: TextStyle(fontSize: 12.0))),
                              ],
                              rows: [
                                // Semana 0 (Fecha de inicio)
                                DataRow(
                                  cells: [
                                    DataCell(Text('0',
                                        style: TextStyle(fontSize: 12.0))),
                                    DataCell(Text(_formatearFecha(fechaInicio),
                                        style: TextStyle(fontSize: 12.0))),
                                    DataCell(Text('\$0.00',
                                        style: TextStyle(fontSize: 12.0))),
                                    DataCell(Text('\$0.00',
                                        style: TextStyle(fontSize: 12.0))),
                                    DataCell(Text('\$0.00',
                                        style: TextStyle(fontSize: 12.0))),
                                    DataCell(Text('\$0.00',
                                        style: TextStyle(fontSize: 12.0))),
                                    DataCell(Text(
                                        '\$${formatearNumero(totalARecuperar)}',
                                        style: TextStyle(fontSize: 12.0))),
                                  ],
                                ),
                                // Generar filas con fechas de pago semanal
                                ...List.generate(
                                  frecuenciaPago == "Semanal"
                                      ? plazoNumerico
                                      // ANTES: : plazoNumerico * 2,
                                      : plazoNumerico, // <-- CAMBIO
                                  (index) {
                                    DateTime fechaPago;
                                    if (frecuenciaPago == "Semanal") {
                                      // Si es semanal, el primer pago es la siguiente semana
                                      fechaPago = fechaInicio
                                          .add(Duration(days: (index + 1) * 7));
                                    } else {
                                      // Si es quincenal, utilizamos las fechas calculadas con las quincenas
                                      // ANTES: final fechasDePago = calcularFechasDePago(fechaInicio);
                                      final fechasDePago = calcularFechasDePago(
                                          fechaInicio,
                                          plazoNumerico); // <-- CAMBIO: Pasar plazoNumerico
                                      // Aquí es donde ocurría el error, asegúrate que fechasDePago tenga suficientes elementos.
                                      // Si plazoNumerico es 8, y calcularFechasDePago ahora genera 8 fechas,
                                      // y el List.generate itera 8 veces (index de 0 a 7), esto debería estar bien.
                                      if (index < fechasDePago.length) {
                                        // Añadir una comprobación de seguridad
                                        fechaPago =
                                            DateTime.parse(fechasDePago[index]);
                                      } else {
                                        // Manejar el caso donde no hay suficientes fechas, aunque no debería ocurrir con el fix
                                        print(
                                            "Error: Faltan fechas de pago para el índice $index");
                                        fechaPago = DateTime
                                            .now(); // Fallback, o lanzar un error más descriptivo
                                      }
                                    }

                                    final pagosTotales =
                                        frecuenciaPago == "Semanal"
                                            ? plazoNumerico
                                            // ANTES: : plazoNumerico * 2;
                                            : plazoNumerico; // <-- CAMBIO

                                    double capitalGrupal =
                                        (integrantes.fold<double>(
                                      0.0,
                                      (suma, integrante) {
                                        final montoIndividual =
                                            montosIndividuales[
                                                    integrante.idclientes] ??
                                                0.0;
                                        return suma +
                                            (montoIndividual / pagosTotales);
                                      },
                                    ));

                                    double interesGrupal =
                                        (integrantes.fold<double>(
                                      0.0,
                                      (suma, integrante) {
                                        final montoIndividual =
                                            montosIndividuales[
                                                    integrante.idclientes] ??
                                                0.0;
                                        return suma +
                                            (montoIndividual *
                                                (tasaInteresMensualCalculada /
                                                    (frecuenciaPago == "Semanal"
                                                        ? 4
                                                        : 2) /
                                                    100));
                                      },
                                    ));

                                    final pagoGrupal =
                                        (capitalGrupal + interesGrupal);
                                    double totalPagado =
                                        (pagoGrupal * (index + 1));
                                    double totalRestante =
                                        (totalARecuperar - totalPagado);
                                    //IMPRIMIR EN CONSOLA
                                    /*   imprimirDatosGenerales();
                                    imprimirIntegrantesYMontosEnJSON();
                                    imprimirCalendarioDePagosEnJSON(); */
                                    print(
                                        'datos para servidor: ${generarDatosParaServidor()}');
                                    return DataRow(
                                      cells: [
                                        DataCell(Text('${index + 1}',
                                            style: TextStyle(fontSize: 12.0))),
                                        DataCell(Text(
                                            _formatearFecha(fechaPago),
                                            style: TextStyle(fontSize: 12.0))),
                                        DataCell(Text(
                                            '\$${formatearNumero(capitalGrupal)}',
                                            style: TextStyle(fontSize: 12.0))),
                                        DataCell(Text(
                                            '\$${formatearNumero(interesGrupal)}',
                                            style: TextStyle(fontSize: 12.0))),
                                        DataCell(Text(
                                            '\$${formatearNumero(pagoGrupal)}',
                                            style: TextStyle(fontSize: 12.0))),
                                        DataCell(Text(
                                            '\$${formatearNumero(totalPagado)}',
                                            style: TextStyle(fontSize: 12.0))),
                                        DataCell(Text(
                                            '\$${formatearNumero(totalRestante)}',
                                            style: TextStyle(fontSize: 12.0))),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  dynamic redondearDecimales(dynamic valor, BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final double umbralRedondeo = userData.redondeo;

    if (valor is double) {
      if ((valor - valor.truncateToDouble()).abs() < 0.000001) {
        return valor.truncateToDouble();
      } else {
        double parteDecimal = valor - valor.truncateToDouble();

        if (parteDecimal >= umbralRedondeo) {
          return valor.ceilToDouble();
        } else {
          return valor.floorToDouble();
        }
      }
    } else if (valor is int) {
      return valor.toDouble();
    } else if (valor is List) {
      return valor.map((e) => redondearDecimales(e, context)).toList();
    } else if (valor is Map) {
      return valor.map<String, dynamic>(
        (key, value) => MapEntry(key, redondearDecimales(value, context)),
      );
    }
    return valor;
  }

  // Coloca esta función fuera de tu clase State, en el mismo archivo.
  double redondearADosDecimales(double valor) {
    return double.parse(valor.toStringAsFixed(2));
  }

// Reemplaza tu función actual con esta.
  Map<String, dynamic> generarDatosParaServidor() {
    // --- 1. Validaciones cruciales ---
    if (selectedGrupo == null ||
        _tasaSeleccionada == null ||
        _duracionSeleccionada == null) {
      print("Error: Faltan datos esenciales para generar el crédito.");
      return {};
    }

    // --- 2. Extraer datos ---
    final grupoSeleccionado =
        listaGrupos.firstWhere((g) => g.nombreGrupo == selectedGrupo);
    final TasaInteres tasa = _tasaSeleccionada!;
    final Duracion duracion = _duracionSeleccionada!;
    final double montoTotalCredito = obtenerMontoReal(montoController.text);
    final int numeroDePagos = duracion.plazo;
    final double tasaMensualDecimal = tasa.mensual / 100.0;

    // --- 3. Lógica para la Garantía ---
    String valorGarantiaString;
    double porcentajeGarantia = 0;
    if (garantia == "Sin garantía" || garantia == null) {
      valorGarantiaString = "0%";
    } else {
      valorGarantiaString = garantia!;
      porcentajeGarantia =
          (double.tryParse(garantia!.replaceAll('%', '')) ?? 0) / 100.0;
    }
    final double montoGarantiaCalculado =
        montoTotalCredito * porcentajeGarantia;

    // --- 4. Cálculo del Interés por Periodo ($) ---
    double interesPorPeriodo;
    if (duracion.frecuenciaPago == "Semanal") {
      interesPorPeriodo = montoTotalCredito * (tasaMensualDecimal / 4);
    } else {
      interesPorPeriodo = montoTotalCredito * (tasaMensualDecimal / 2);
    }

    final double interesTotalCalculado =
        redondearADosDecimales(interesPorPeriodo * numeroDePagos);
    final double totalARecuperar = montoTotalCredito + interesTotalCalculado;
    final double pagoPorCuota =
        redondearADosDecimales(totalARecuperar / numeroDePagos);

    // --- 4.5. CÁLCULO DEL INTERÉS GLOBAL (%) ---
    double interesGlobalCalculado = 0.0;
    if (duracion.frecuenciaPago == "Semanal") {
      interesGlobalCalculado = (tasa.mensual / 4) * numeroDePagos;
    } else {
      interesGlobalCalculado = (tasa.mensual / 2) * numeroDePagos;
    }

    // --- 5. Generación de las Fechas de Pago ---
    List<String> fechasDePago = [];
    fechasDePago.add(_formatearFechaServidor(fechaInicio));
    int diasEntrePagos = (duracion.frecuenciaPago == "Semanal") ? 7 : 14;
    for (int i = 0; i < numeroDePagos; i++) {
      DateTime fechaPago =
          fechaInicio.add(Duration(days: (i + 1) * diasEntrePagos));
      fechasDePago.add(_formatearFechaServidor(fechaPago));
    }

    // --- 6. Generación de los Montos Individuales de Clientes ---
    List<Map<String, dynamic>> clientesMontosIndividuales = [];
    for (var integrante in integrantes) {
      double capitalIndividual =
          montosIndividuales[integrante.idclientes] ?? 0.0;
      double interesIndividualPorPeriodo;
      if (duracion.frecuenciaPago == "Semanal") {
        interesIndividualPorPeriodo =
            capitalIndividual * (tasaMensualDecimal / 4);
      } else {
        interesIndividualPorPeriodo =
            capitalIndividual * (tasaMensualDecimal / 2);
      }

      double capitalPorPeriodo =
          redondearADosDecimales(capitalIndividual / numeroDePagos);
      double interesTotalIndividual =
          redondearADosDecimales(interesIndividualPorPeriodo * numeroDePagos);
      double pagoTotalIndividual = capitalIndividual + interesTotalIndividual;
      double pagoCuotaIndividual = redondearADosDecimales(
          capitalPorPeriodo + interesIndividualPorPeriodo);

      clientesMontosIndividuales.add({
        "iddetallegrupos": integrante.iddetallegrupos,
        "capitalIndividual": capitalIndividual,
        "periodoCapital": capitalPorPeriodo,
        "periodoInteres": redondearADosDecimales(interesIndividualPorPeriodo),
        "periodoInteresPorcentaje": tasa.mensual,
        "totalCapital": capitalIndividual,
        "totalIntereses": interesTotalIndividual,
        "capitalMasInteres": pagoCuotaIndividual,
        "pagoTotal": redondearADosDecimales(pagoTotalIndividual),
      });
    }

    // --- 7. Construcción del Objeto Final para el Servidor ---
    final Map<String, dynamic> datosParaServidor = {
      "idgrupos": grupoSeleccionado.idgrupos,
      "ti_mensual": tasa.mensual.toString(), // <-- LÍNEA CORREGIDA
      "plazo": duracion.plazo,
      "frecuenciaPago": duracion.frecuenciaPago,
      "garantia": valorGarantiaString,
      "montoTotal": montoTotalCredito,
      "interesGlobal": redondearADosDecimales(interesGlobalCalculado),
      "pagoCuota": pagoPorCuota,
      "montoGarantia": redondearADosDecimales(montoGarantiaCalculado),
      "interesTotal": interesTotalCalculado,
      "montoMasInteres": redondearADosDecimales(totalARecuperar),
      "diaPago": diaPago,
      "fechasPago": fechasDePago,
      "clientesMontosInd": clientesMontosIndividuales,
    };

    return datosParaServidor;
  }

  // Función para calcular las fechas de pago semanal con las condiciones corregidas
  List<String> calcularFechasDePagoSemanal(
      DateTime fechaInicio, int cantidadPagos) {
    List<String> fechasDePago = [];

    // El primer pago es exactamente una semana después de la fecha de inicio
    DateTime primerPago = fechaInicio.add(Duration(days: 7));

    // Generar las fechas de pago semanales
    for (int i = 0; i < cantidadPagos; i++) {
      fechasDePago
          .add(_dateFormat.format(primerPago)); // Usamos el formato dd/MM/yyyy
      primerPago = primerPago.add(Duration(days: 7)); // Se avanza una semana
    }

    return fechasDePago;
  }

// Función para calcular el siguiente lunes desde la fecha
  DateTime _calcularSiguienteLunes(DateTime fechaInicio) {
    int diasHastaLunes = DateTime.monday - fechaInicio.weekday;
    if (diasHastaLunes <= 0) {
      diasHastaLunes += 7; // Si el día es lunes o después, sumamos 7 días
    }
    return fechaInicio.add(Duration(days: diasHastaLunes));
  }

// Función para calcular las fechas de pago quincenales con las condiciones corregidas
// Alrededor de la línea 1530
// ANTES: List<String> calcularFechasDePago(DateTime fechaInicio) {
  List<String> calcularFechasDePago(
      DateTime fechaInicio, int numeroDePagosQuincenales) {
    // <-- CAMBIO: Añadir parámetro
    List<String> fechasDePago = [];
    DateTime primerPago = _calcularPrimerPago(fechaInicio);

    // ANTES: for (int i = 0; i < 8; i++) {
    for (int i = 0; i < numeroDePagosQuincenales; i++) {
      // <-- CAMBIO: Usar el parámetro
      fechasDePago.add(primerPago.toIso8601String().substring(0, 10));

      // Lógica para la siguiente quincena:
      // Si el día actual es 15, el siguiente será 30 (o fin de mes para febrero)
      // Si el día actual es 30 (o fin de mes), el siguiente será 15 del próximo mes.
      if (primerPago.day == 15) {
        // Siguiente es el 30 del mes actual (o fin de mes)
        if (primerPago.month == 2) {
          // Febrero
          bool esBisiesto =
              (primerPago.year % 4 == 0 && primerPago.year % 100 != 0) ||
                  (primerPago.year % 400 == 0);
          primerPago =
              DateTime(primerPago.year, primerPago.month, esBisiesto ? 29 : 28);
        } else if ([4, 6, 9, 11].contains(primerPago.month)) {
          // Meses con 30 días
          primerPago = DateTime(primerPago.year, primerPago.month, 30);
        } else {
          // Meses con 31 días
          primerPago = DateTime(primerPago.year, primerPago.month, 30);
        }
      } else {
        // Siguiente es el 15 del próximo mes
        int siguienteMes = primerPago.month == 12 ? 1 : primerPago.month + 1;
        int siguienteAno =
            primerPago.month == 12 ? primerPago.year + 1 : primerPago.year;
        primerPago = DateTime(siguienteAno, siguienteMes, 15);
      }
    }
    return fechasDePago;
  }

// Función para calcular el primer pago (quincenal)
  DateTime _calcularPrimerPago(DateTime fechaInicio) {
    int dia = fechaInicio.day;

    if (dia <= 10) {
      // Antes del 10: paga el 15 del mes
      return DateTime(fechaInicio.year, fechaInicio.month, 15);
    } else if (dia > 10 && dia <= 25) {
      // Entre el 11 y el 25: paga el 30 del mes
      return DateTime(fechaInicio.year, fechaInicio.month, 30);
    } else {
      // Después del 25: paga el 15 del próximo mes
      int siguienteMes = fechaInicio.month == 12 ? 1 : fechaInicio.month + 1;
      int siguienteAno =
          fechaInicio.month == 12 ? fechaInicio.year + 1 : fechaInicio.year;
      return DateTime(siguienteAno, siguienteMes, 15);
    }
  }

// Función para calcular la siguiente quincena después de la fecha dada
  DateTime _siguienteQuincena(DateTime fecha, int dia) {
    // Verificamos si el día solicitado (30) es válido para el mes
    if (dia == 30) {
      // Si es febrero, verificamos si el año es bisiesto
      if (fecha.month == 2) {
        if (fecha.year % 4 == 0 &&
            (fecha.year % 100 != 0 || fecha.year % 400 == 0)) {
          return DateTime(
              fecha.year, fecha.month, 29); // Año bisiesto, febrero tiene 29
        }
        return DateTime(
            fecha.year, fecha.month, 28); // Febrero en años no bisiestos
      }

      // Si el mes es de 30 días (abril, junio, septiembre, noviembre), retornamos el día 30
      if ([4, 6, 9, 11].contains(fecha.month)) {
        return DateTime(fecha.year, fecha.month, 30);
      }

      // Si el mes tiene 31 días, el día 30 es válido, así que lo dejamos tal cual
      return DateTime(fecha.year, fecha.month, 30);
    } else {
      // Si es el 15, simplemente retornamos el 15 del siguiente mes
      return DateTime(fecha.year, fecha.month + 1, 15);
    }
  }

// Método para crear una fila de información clave: valor
  Widget _infoRow(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12)),
          Text(value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String formatearNumero(double numero) {
    final formatter = NumberFormat("#,##0.00", "en_US"); // Formato español
    return formatter.format(numero);
  }

// Widget para cada sección del resumen
  Widget _seccionResumen(
      {required String titulo, required List<String> contenido}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        ...contenido.map((linea) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              linea,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _recuadroPasos(int pasoActual) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF5162F6),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      width: 250,
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Paso 1
          _buildPasoItem(1, "Datos Generales", pasoActual == 1),
          SizedBox(height: 20),

          // Paso 2
          _buildPasoItem(2, "Monto por Integrante", pasoActual == 2),
          SizedBox(height: 20),

          // Paso 3
          _buildPasoItem(3, "Resumen", pasoActual == 3),
        ],
      ),
    );
  }
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
              color: Colors.white, width: 2), // Borde blanco en todos los casos
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

Widget _buildTextField(
  BuildContext context, {
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
  double fontSize = 12.0,
  int? maxLength,
  List<TextInputFormatter>? inputFormatters, // Nuevo parámetro
  void Function(String)? onChanged, // Callback para cambios
  double borderThickness = 1.5, // Nuevo parámetro para el grosor del borde
}) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final isDarkMode = themeProvider.isDarkMode;

  final Color fillColor = isDarkMode ? Colors.grey.shade800 : Colors.white;

  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    style: TextStyle(fontSize: fontSize),
    /*   decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(fontSize: fontSize),
    ), */
    decoration: InputDecoration(
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide:
            BorderSide(color: Colors.grey.shade400, width: borderThickness),
      ),
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: Colors.grey.shade700,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      labelStyle: TextStyle(fontSize: fontSize),
      filled: true,
      fillColor: fillColor,
    ),
    textCapitalization: TextCapitalization.characters,
    validator: validator,
    onChanged: onChanged,
    inputFormatters: [
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ...(inputFormatters ?? []), // Agrega los formateadores personalizados
    ],
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
  double borderThickness = 1.5, // Parámetro para el grosor del borde
}) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final isDarkMode = themeProvider.isDarkMode;

  final Color fillColor = isDarkMode ? Colors.grey.shade800 : Colors.white;

  // Colores adaptados según el tema
  final Color textColor = isDarkMode ? Colors.white : Colors.black;
  final Color labelColor = isDarkMode ? Colors.grey.shade300 : Colors.black;
  final Color borderColor = isDarkMode ? Colors.grey.shade500 : Colors.black;
  final Color enabledBorderColor =
      isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;
  final Color iconColor = isDarkMode ? Color(0xFF5162F6) : Color(0xFF5162F6);
  final Color dropdownColor = isDarkMode ? Colors.grey.shade800 : Colors.white;

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
    icon: Icon(Icons.arrow_drop_down, color: iconColor),
    dropdownColor: dropdownColor,
    onChanged: onChanged,
    validator: validator,
    decoration: InputDecoration(
      labelText: value != null ? hint : null,
      labelStyle: TextStyle(color: labelColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: borderColor, width: borderThickness),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide:
            BorderSide(color: enabledBorderColor, width: borderThickness),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: borderColor, width: borderThickness),
      ),
      // Añadido para modo oscuro
      filled: true,
      fillColor: fillColor,
    ),
    style: TextStyle(fontSize: fontSize, color: textColor),
  );
}

// NUEVO WIDGET ADAPTADO: Usa el estilo de tu dropdown pero es genérico
Widget _buildModelDropdown<T>({
  required T? value,
  required String hint,
  required List<T> items,
  required BuildContext context,
  required Widget Function(T) itemBuilder,
  required void Function(T?) onChanged,
  double fontSize = 12.0,
  String? Function(T?)? validator,
  double borderThickness = 1.5,
  bool isEnabled = true,
}) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final isDarkMode = themeProvider.isDarkMode;

  final Color textColor = isDarkMode ? Colors.white : Colors.black;
  final Color? labelColor =
      isDarkMode ? Colors.grey.shade300 : Colors.grey[600];
  final Color borderColor = Color(0xFF5162F6);
  final Color enabledBorderColor =
      isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;
  final Color iconColor = Color(0xFF5162F6);
  final Color dropdownColor = isDarkMode ? Colors.grey.shade800 : Colors.white;
  final Color fillColor = isEnabled
      ? (isDarkMode ? Colors.grey.shade800 : Colors.white)
      : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200);

  return DropdownButtonFormField<T>(
    value: value,
    hint: Text(hint, style: TextStyle(fontSize: fontSize, color: labelColor)),
    items: items.map((item) {
      return DropdownMenuItem<T>(
        value: item,
        child: DefaultTextStyle(
          style: TextStyle(fontSize: fontSize, color: textColor),
          child: itemBuilder(item),
        ),
      );
    }).toList(),
    icon: Icon(Icons.arrow_drop_down, color: iconColor),
    dropdownColor: dropdownColor,
    onChanged: isEnabled ? onChanged : null,
    validator: validator,
    decoration: InputDecoration(
      labelText: value != null ? hint : null,
      labelStyle: TextStyle(color: labelColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: borderColor, width: borderThickness),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide:
            BorderSide(color: enabledBorderColor, width: borderThickness),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: borderColor, width: borderThickness),
      ),
      filled: true,
      fillColor: fillColor,
    ),
  );
}

class Grupo {
  final String idgrupos;
  final String tipoGrupo;
  final String nombreGrupo;
  final String detalles;
  final String asesor;
  final String fCreacion;
  final String estado;
  final List<Cliente> clientes; // Usamos la lista de objetos Cliente

  Grupo({
    required this.idgrupos,
    required this.tipoGrupo,
    required this.nombreGrupo,
    required this.detalles,
    required this.asesor,
    required this.fCreacion,
    required this.estado,
    required this.clientes, // Inicializamos la lista de clientes
  });

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      idgrupos: json['idgrupos'],
      tipoGrupo: json['tipoGrupo'],
      nombreGrupo: json['nombreGrupo'],
      detalles: json['detalles'],
      asesor: json['asesor'],
      fCreacion: json['fCreacion'],
      estado: json['estado'],
      clientes: (json['clientes'] as List)
          .map((clienteJson) => Cliente.fromJson(clienteJson))
          .toList(), // Convertimos cada cliente a un objeto Cliente
    );
  }
}

class Cliente {
  final String iddetallegrupos;
  final String idclientes;
  final String nombres;
  final String telefono;
  final String fechaNacimiento;
  final String cargo;
  final double? montoIndividual;

  Cliente({
    required this.iddetallegrupos,
    required this.idclientes,
    required this.nombres,
    required this.telefono,
    required this.fechaNacimiento,
    required this.cargo,
    this.montoIndividual,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      iddetallegrupos: json['iddetallegrupos'],
      idclientes: json['idclientes'],
      nombres: json['nombres'],
      telefono: json['telefono'],
      fechaNacimiento: json['fechaNacimiento'],
      cargo: json['cargo'],
      montoIndividual: json['montoIndividual']?.toDouble(),
    );
  }
}
