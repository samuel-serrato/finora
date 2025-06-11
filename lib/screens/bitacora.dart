import 'dart:async';
import 'dart:convert';
import 'package:finora/ip.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:finora/custom_app_bar.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NUEVO: Modelo para los datos del usuario, basado en tu JSON.
class Usuario {
  final String idusuarios;
  final String usuario;
  final String tipoUsuario;
  final String nombreCompleto;
  final String email;
  final List<String> roles;
  final String fCreacion;

  Usuario({
    required this.idusuarios,
    required this.usuario,
    required this.tipoUsuario,
    required this.nombreCompleto,
    required this.email,
    required this.roles,
    required this.fCreacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      idusuarios: json['idusuarios'] ?? '',
      usuario: json['usuario'] ?? '',
      tipoUsuario: json['tipoUsuario'] ?? '',
      nombreCompleto: json['nombreCompleto'] ?? 'Nombre no disponible',
      email: json['email'] ?? '',
      roles: List<String>.from(json['roles'] ?? []),
      fCreacion: json['fCreacion'] ?? '',
    );
  }

  // Sobrescribimos '==' y 'hashCode' para que el Dropdown pueda comparar objetos Usuario.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Usuario &&
          runtimeType == other.runtimeType &&
          idusuarios == other.idusuarios;

  @override
  int get hashCode => idusuarios.hashCode;
}

class BitacoraScreen extends StatefulWidget {
  const BitacoraScreen({Key? key}) : super(key: key);

  @override
  State<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> {
  bool isLoading = false;
  bool hasGenerated = false;
  String? selectedFilterType = 'Todas las actividades';
  DateTime? selectedDate;
  List<Map<String, dynamic>> bitacoraData = [];
  List<Map<String, dynamic>> filteredData = [];

  // NUEVO: Estado para manejar la lista de usuarios y el usuario seleccionado.
  List<Usuario> _usuarios = [];
  Usuario? _selectedUsuario;
  bool _isUsuariosLoading = true;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  final List<String> filterTypes = [
    'Todas las actividades',
    'Inicios de sesión',
    'Pagos',
    'Configuraciones',
    'Errores del sistema',
  ];

  @override
  void initState() {
    super.initState();
    print('🚀 BitacoraScreen inicializado');
    // NUEVO: Llamamos a la función para obtener los usuarios cuando la pantalla se carga.
    _fetchUsuarios();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  // NUEVO: Función para obtener la lista de usuarios desde la API.
  Future<void> _fetchUsuarios() async {
    setState(() {
      _isUsuariosLoading = true;
    });

    try {
      final String url = '$baseUrl/api/v1/usuarios';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse(url),
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        setState(() {
          _usuarios =
              jsonData.map((userJson) => Usuario.fromJson(userJson)).toList();
        });
      } else {
        print(
            '❌ ERROR al obtener usuarios: Status code ${response.statusCode}');
        mostrarDialogoError(
            'Error al cargar la lista de usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ EXCEPCIÓN al obtener usuarios: $e');
      mostrarDialogoError(
          'Error de conexión al cargar usuarios: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUsuariosLoading = false;
        });
      }
    }
  }

  Future<void> obtenerBitacora() async {
    if (selectedFilterType == null || selectedDate == null) {
      mostrarDialogoError('Selecciona tipo de filtro y fecha');
      return;
    }

    setState(() {
      isLoading = true;
      hasGenerated = true;
    });

    try {
      String fechaFormateada = DateFormat('yyyy-MM-dd').format(selectedDate!);
      // MODIFICADO: Construcción de la URL base
      String url = '$baseUrl/api/v1/bitacora/$fechaFormateada';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // MODIFICADO: Añadimos el query parameter si hay un usuario seleccionado.
      if (_selectedUsuario != null &&
          _selectedUsuario!.nombreCompleto.isNotEmpty) {
        // Usamos Uri.encodeComponent para manejar espacios y caracteres especiales en el nombre.
        final nombreCompletoEncoded =
            Uri.encodeComponent(_selectedUsuario!.nombreCompleto);
        url += '?nombre=$nombreCompletoEncoded';
      }

      print('=== PETICIÓN HTTP ===');
      print('URL: $url'); // La URL ahora puede contener el filtro de usuario
      print('Método: GET');
      print('Fecha seleccionada: ${selectedDate.toString()}');
      print('Filtro seleccionado: $selectedFilterType');
      print(
          'Usuario seleccionado: ${_selectedUsuario?.nombreCompleto ?? 'Todos'}');
      print('========================');

      final response = await http.get(
        Uri.parse(url),
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
      );

      print('=== RESPUESTA HTTP ===');
      print('Status Code: ${response.statusCode}');
      print('Body (raw): ${response.body}');
      print('========================');

      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        setState(() {
          bitacoraData = jsonData.cast<Map<String, dynamic>>();
          _aplicarFiltro();
        });
      } else {
        print('❌ ERROR: Status code ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        mostrarDialogoError(
            'Error al obtener la bitácora: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ EXCEPCIÓN CAPTURADA: $e');
      mostrarDialogoError('Error de conexión: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _aplicarFiltro() {
    // La lógica de filtro por tipo de actividad se mantiene igual.
    // El filtrado por usuario ya se hizo en la petición a la API.
    print('=== APLICANDO FILTRO DE ACTIVIDAD ===');
    print('Filtro seleccionado: $selectedFilterType');
    print('Total de registros antes del filtro: ${bitacoraData.length}');

    if (selectedFilterType == 'Todas las actividades') {
      filteredData = List.from(bitacoraData);
    } else {
      filteredData = bitacoraData.where((item) {
        String accion = item['accion']?.toString().toLowerCase() ?? '';
        switch (selectedFilterType) {
          case 'Inicios de sesión':
            return accion.contains('inicio') ||
                accion.contains('login') ||
                accion.contains('sesión');
          case 'Pagos':
            return accion.contains('pago') ||
                accion.contains('transacción') ||
                accion.contains('cobro');
          case 'Configuraciones':
            return accion.contains('actualiz') ||
                accion.contains('configur') ||
                accion.contains('permiso');
          case 'Errores del sistema':
            return accion.contains('error') ||
                accion.contains('fallo') ||
                accion.contains('excepción');
          default:
            return true;
        }
      }).toList();
    }

    print('Total de registros después del filtro: ${filteredData.length}');
    print('=======================================');
  }

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onClose?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA),
      appBar: CustomAppBar(
          isDarkMode: isDarkMode,
          toggleDarkMode: (value) {
            themeProvider.toggleDarkMode(value);
          },
          title: 'Bitácora del Sistema'),
      body: Column(
        children: [
          // MODIFICADO: La fila de filtros ahora incluye el dropdown de usuarios.
          _buildFilterRow(),
          Expanded(
            child: hasGenerated
                ? isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: isDarkMode
                                ? Colors.white70
                                : Color(0xFF5162F6)))
                    : _buildBitacoraContent()
                : _buildInitialMessage(),
          ),
        ],
      ),
    );
  }

  // MODIFICADO: Se añade el dropdown de usuarios.
  Widget _buildFilterRow() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final boxDecoration = BoxDecoration(
      color: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: isDarkMode
              ? Colors.black.withOpacity(0.4)
              : Colors.black.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 2,
          offset: const Offset(0, 3),
        ),
      ],
    );
    final inputDecoration = InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
    );
    final textStyle = TextStyle(
        fontSize: 14, color: isDarkMode ? Colors.white : Colors.black);
    final hintStyle = TextStyle(
        fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black54);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(
            flex: 4, // Ajusta el espacio para los dropdowns
            child: Container(
              decoration: boxDecoration,
              child: SizedBox(
                height: 40,
                child: DropdownButtonFormField<String>(
                  value: selectedFilterType,
                  items: filterTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type, style: textStyle),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    selectedFilterType = value;
                    hasGenerated = false;
                  }),
                  decoration: inputDecoration,
                  hint: Text('Selecciona tipo de actividad', style: hintStyle),
                  style: textStyle,
                  dropdownColor: isDarkMode ? Color(0xFF2A2D3E) : Colors.white,
                  icon: Icon(Icons.arrow_drop_down,
                      color: isDarkMode ? Colors.white70 : Colors.black54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),

          // NUEVO: Dropdown para seleccionar el usuario.
          Expanded(
            flex: 4, // Ajusta el espacio para los dropdowns
            child: Container(
              decoration: boxDecoration,
              child: SizedBox(
                height: 40,
                child: _isUsuariosLoading
                    ? Center(
                        child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Color(0xFF5162F6))))
                    : DropdownButtonFormField<Usuario>(
                        value: _selectedUsuario,
                        // Añadimos una opción para "Todos los usuarios" que corresponde a un valor nulo.
                        items: [
                          DropdownMenuItem<Usuario>(
                            value: null, // Valor nulo para "Todos"
                            child: Text("Todos los usuarios", style: textStyle),
                          ),
                          ..._usuarios
                              .map((user) => DropdownMenuItem<Usuario>(
                                    value: user,
                                    child: Text(user.nombreCompleto,
                                        style: textStyle),
                                  ))
                              .toList()
                        ],
                        onChanged: (value) => setState(() {
                          _selectedUsuario = value;
                          hasGenerated = false;
                        }),
                        decoration: inputDecoration,
                        hint: Text('Seleccionar usuario', style: hintStyle),
                        style: textStyle,
                        dropdownColor:
                            isDarkMode ? Color(0xFF2A2D3E) : Colors.white,
                        icon: Icon(Icons.arrow_drop_down,
                            color:
                                isDarkMode ? Colors.white70 : Colors.black54),
                      ),
              ),
            ),
          ),

          const SizedBox(width: 15),
          Expanded(
            flex: 2, // Ajusta el espacio para los dropdowns
            child: InkWell(
              onTap: _selectDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                decoration: boxDecoration,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 18,
                        color: isDarkMode ? Colors.white70 : Colors.black87),
                    const SizedBox(width: 10),
                    Text(
                      selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                          : 'Seleccionar Fecha',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            width: 150,
            child: ElevatedButton(
              onPressed: (selectedFilterType != null && selectedDate != null)
                  ? () => obtenerBitacora()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5162F6),
                disabledBackgroundColor:
                    isDarkMode ? Colors.grey[700] : Colors.grey[300],
                disabledForegroundColor:
                    isDarkMode ? Colors.grey[500] : Colors.grey[600],
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Filtrar', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          /* const SizedBox(width: 15),
          Visibility(
            visible: hasGenerated,
            child: Container(
              width: 180,
              child: ElevatedButton(
                onPressed: () async {
                  if (selectedFilterType == null || selectedDate == null) {
                    mostrarDialogoError('Primero genera la bitácora');
                    return;
                  }
                  await exportarBitacora();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5162F6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Exportar',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ), */
        ],
      ),
    );
  }

  // El resto del código (_selectDate, _buildInitialMessage, _buildBitacoraContent, etc.)
  // no necesita cambios significativos para esta funcionalidad.
  // ... (Pega aquí el resto de tu código sin modificar)
  // ...

  //--- Pega aquí el resto de tu código desde `Future<void> _selectDate() async` hasta el final de la clase ---//

  Future<void> _selectDate() async {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Selecciona fecha',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
              headerBackgroundColor:
                  isDarkMode ? Color(0xFF5162F6) : Colors.blue,
              headerForegroundColor: Colors.white,
              dayForegroundColor: MaterialStateProperty.resolveWith(
                (states) => states.contains(MaterialState.selected)
                    ? Colors.white
                    : isDarkMode
                        ? Colors.white
                        : null,
              ),
              yearForegroundColor: MaterialStateProperty.resolveWith(
                (states) => states.contains(MaterialState.selected)
                    ? Colors.white
                    : isDarkMode
                        ? Colors.white
                        : null,
              ),
              dayBackgroundColor: MaterialStateProperty.resolveWith(
                (states) => states.contains(MaterialState.selected)
                    ? isDarkMode
                        ? Color(0xFF5162F6)
                        : Colors.blue
                    : null,
              ),
              yearBackgroundColor: MaterialStateProperty.resolveWith(
                (states) => states.contains(MaterialState.selected)
                    ? isDarkMode
                        ? Color(0xFF5162F6)
                        : Colors.blue
                    : null,
              ),
              weekdayStyle: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            colorScheme: ColorScheme(
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
              primary: isDarkMode ? Color(0xFF5162F6) : Colors.blue,
              onPrimary: Colors.white,
              secondary: isDarkMode ? Color(0xFF5162F6) : Colors.blue,
              onSecondary: Colors.white,
              error: isDarkMode ? Colors.redAccent : Colors.red,
              onError: Colors.white,
              background: isDarkMode ? Color(0xFF2A2D3E) : Colors.white,
              onBackground: isDarkMode ? Colors.white : Colors.black,
              surface: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Widget _buildInitialMessage() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history,
              size: 50, color: isDarkMode ? Colors.white54 : Colors.grey[600]),
          const SizedBox(height: 20),
          Text(
            'Selecciona los filtros y fecha\npara consultar la bitácora del sistema',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBitacoraContent() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    if (filteredData.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 60,
                color: isDarkMode ? Colors.white38 : Colors.grey[400],
              ),
              const SizedBox(height: 15),
              Text(
                'No se encontraron registros',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'para los filtros seleccionados',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5162F6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF3A3D4E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFF5162F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.assignment,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Registro de Actividades (${filteredData.length} registros)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _verticalScrollController,
              child: ListView.builder(
                controller: _verticalScrollController,
                padding: const EdgeInsets.all(20),
                itemCount: filteredData.length,
                itemBuilder: (context, index) {
                  final item = filteredData[index];
                  return _buildActivityCard(item, index, isDarkMode);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
      Map<String, dynamic> item, int index, bool isDarkMode) {
    final String? fechaHoraString = item['createAt'];
    DateTime? dateTime;

    if (fechaHoraString != null && fechaHoraString.isNotEmpty) {
      try {
        final inputFormat = DateFormat('dd/MM/yyyy hh:mm a', 'en_US');
        dateTime = inputFormat.parse(fechaHoraString.trim());
      } catch (e) {
        print('Error al parsear la fecha "$fechaHoraString". Error: $e');
      }
    }

    final String fechaFormateada = dateTime != null
        ? DateFormat('dd/MM/yyyy').format(dateTime)
        : 'Fecha inválida';

    final String horaFormateada = dateTime != null
        ? DateFormat('hh:mm a').format(dateTime)
        : 'Hora inválida';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF2A2D3E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF5162F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['usuario'] ?? 'Usuario desconocido',
                      style: TextStyle(
                        color: Color(0xFF5162F6),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['nombreCompleto'] ?? 'Usuario desconocido',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Color(0xFF202128),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '#${index + 1}',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white60 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fechaFormateada,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    horaFormateada,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white60 : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item['accion'] ?? 'Acción no especificada',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (item['nombreAfectado'] != null &&
              item['nombreAfectado'] != 'N/A') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF1A1D2E) : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode
                      ? Color(0xFF5162F6).withOpacity(0.3)
                      : Colors.blue[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFF5162F6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['nombreAfectado'],
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.blue[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> exportarBitacora() async {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: isDarkMode ? Color(0xFF2A2D3E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 50),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF5162F6),
                ),
                const SizedBox(height: 20),
                Text(
                  'Exportando bitácora...',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      await Future.delayed(Duration(seconds: 2));

      Navigator.pop(context);

      print('Exportando ${filteredData.length} registros de bitácora...');

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Éxito'),
          content: Text(
              'Bitácora exportada correctamente (${filteredData.length} registros)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      mostrarDialogoError('Error al exportar: ${e.toString()}');
    }
  }
}
