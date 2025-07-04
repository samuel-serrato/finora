import 'dart:convert';
import 'package:finora/ip.dart'; // Asegúrate de que esta importación sea correcta
import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SOLUCIÓN 1: Conversión explícita en fromJson (RECOMENDADA)
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
      // Conversión segura: maneja tanto int como double
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

// --- NUEVO: Modelo para la configuración de moratorios ---
class MoratorioConfig {
  final int diasTolerancia;
  final double moratorio;
  final double moratorioExpandido;

  MoratorioConfig({
    required this.diasTolerancia,
    required this.moratorio,
    required this.moratorioExpandido,
  });

  factory MoratorioConfig.fromJson(Map<String, dynamic> json) {
    return MoratorioConfig(
      // Se manejan tanto int como double para mayor flexibilidad desde el backend
      diasTolerancia: (json['diasTolerancia'] as num).toInt(),
      moratorio: (json['moratorio'] as num).toDouble(),
      moratorioExpandido: (json['moratorioExpandido'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diasTolerancia': diasTolerancia,
      'moratorio': moratorio,
      'moratorioExpandido': moratorioExpandido,
    };
  }
}

// --- WIDGET PRINCIPAL CON TABS ---
// --- WIDGET PRINCIPAL CON TABS ---
class ConfiguracionCreditoWidget extends StatefulWidget {
  final double initialRoundingValue;
  final Function(double) onSave;

  const ConfiguracionCreditoWidget({
    Key? key,
    required this.initialRoundingValue,
    required this.onSave,
  }) : super(key: key);

  @override
  _ConfiguracionCreditoWidgetState createState() =>
      _ConfiguracionCreditoWidgetState();
}

class _ConfiguracionCreditoWidgetState extends State<ConfiguracionCreditoWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Estado para Redondeo
  late double _roundingThreshold;
  bool _isSavingRounding = false;

  // Estado para Tasas de Interés
  List<TasaInteres> _tasasDeInteres = [];
  bool _loadingTasas = true;

  // Estado para Duraciones
  List<Duracion> _duraciones = [];
  bool _loadingDuraciones = true;

  // --- NUEVO: Estado para Moratorios ---
  MoratorioConfig? _moratorioConfig;
  bool _loadingMoratorio = true;
  bool _isSavingMoratorio = false;
  final _moratorioFormKey = GlobalKey<FormState>();
  late TextEditingController _diasToleranciaController;
  late TextEditingController _moratorioController;
  late TextEditingController _moratorioExpandidoController;

  @override
  void initState() {
    super.initState();
    // --- MODIFICADO: Ahora son 4 tabs ---
    _tabController = TabController(length: 4, vsync: this);

    // Inicialización de estado de Redondeo
    _roundingThreshold = widget.initialRoundingValue;

    // --- NUEVO: Inicialización de controladores para Moratorios ---
    _diasToleranciaController = TextEditingController();
    _moratorioController = TextEditingController();
    _moratorioExpandidoController = TextEditingController();

    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // --- NUEVO: Liberar los nuevos controladores ---
    _diasToleranciaController.dispose();
    _moratorioController.dispose();
    _moratorioExpandidoController.dispose();
    super.dispose();
  }

  // =======================================================================
  // --- SECCIÓN DE PETICIONES HTTP ---
  // =======================================================================

  Future<void> _fetchData() async {
    // Ejecuta ambas cargas en paralelo para mayor eficiencia
    await Future.wait([
      _fetchTasasDeInteres(),
      _fetchDuraciones(),
      _fetchMoratorioConfig(), // --- NUEVO ---
    ]);
  }

  // --- NUEVO: Método GET para la configuración de Moratorios ---
  Future<void> _fetchMoratorioConfig() async {
    setState(() => _loadingMoratorio = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/configuracion/moratorio'),
        headers: {'tokenauth': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _moratorioConfig = MoratorioConfig.fromJson(data);
            // Llenar los controladores con los datos obtenidos
            _diasToleranciaController.text =
                _moratorioConfig!.diasTolerancia.toString();
            _moratorioController.text = _moratorioConfig!.moratorio.toString();
            _moratorioExpandidoController.text =
                _moratorioConfig!.moratorioExpandido.toString();
          });
        }
      } else {
        _showErrorSnackBar('Error al cargar moratorios: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al cargar moratorios: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingMoratorio = false);
      }
    }
  }

  // --- NUEVO: Método PUT para actualizar la configuración de Moratorios ---
  Future<void> _updateMoratorioConfig() async {
    if (!_moratorioFormKey.currentState!.validate()) return;

    setState(() => _isSavingMoratorio = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final url = Uri.parse('$baseUrl/api/v1/configuracion/moratorio');

      final body = MoratorioConfig(
        diasTolerancia: int.parse(_diasToleranciaController.text),
        moratorio: double.parse(_moratorioController.text),
        moratorioExpandido: double.parse(_moratorioExpandidoController.text),
      ).toJson();

      final response = await http.put(
        url,
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        _showSuccessSnackBar(
            'Configuración de moratorios guardada correctamente');
      } else {
        _showErrorSnackBar('Error al guardar moratorios: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al guardar moratorios: $e');
    } finally {
      if (mounted) setState(() => _isSavingMoratorio = false);
    }
  }

  // --- Métodos GET (ya existentes) ---
  Future<void> _fetchTasasDeInteres() async {
    setState(() => _loadingTasas = true);
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
            _tasasDeInteres =
                data.map((item) => TasaInteres.fromJson(item)).toList();
          });
        }
      } else {
        _showErrorSnackBar('Error al cargar tasas: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al cargar tasas: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingTasas = false);
      }
    }
  }

  Future<void> _fetchDuraciones() async {
    setState(() => _loadingDuraciones = true);
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
            _duraciones = data.map((item) => Duracion.fromJson(item)).toList();
          });
        }
      } else {
        _showErrorSnackBar('Error al cargar plazos: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al cargar plazos: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingDuraciones = false);
      }
    }
  }

  // --- Métodos POST, PUT, DELETE para TASAS DE INTERÉS ---

  Future<void> _createTasa(double mensual) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/tazainteres/'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'mensual': mensual.toString()}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSuccessSnackBar('Tasa creada correctamente.');
        _fetchTasasDeInteres(); // Recargar la lista
      } else {
        _showErrorSnackBar('Error al crear tasa: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al crear tasa: $e');
    }
  }

  Future<void> _updateTasa(int id, double mensual) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/tazainteres/$id'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'mensual': mensual.toString()}),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Tasa actualizada correctamente.');
        _fetchTasasDeInteres(); // Recargar la lista
      } else {
        _showErrorSnackBar('Error al actualizar tasa: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al actualizar tasa: $e');
    }
  }

  Future<void> _deleteTasa(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/tazainteres/$id'),
        headers: {'tokenauth': token},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSuccessSnackBar('Tasa eliminada correctamente.');
        // Para una respuesta más rápida, eliminamos el item localmente
        if (mounted) {
          setState(() {
            _tasasDeInteres.removeWhere((tasa) => tasa.idtipointeres == id);
          });
        }
      } else {
        _showErrorSnackBar('Error al eliminar tasa: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al eliminar tasa: $e');
    }
  }

  // --- Métodos POST, PUT, DELETE para PLAZOS (DURACIÓN) ---

  Future<void> _createDuracion(int plazo, String frecuencia) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/duracion'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'plazo': plazo,
          'frecuenciaPago': frecuencia,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSuccessSnackBar('Plazo creado correctamente.');
        _fetchDuraciones(); // Recargar la lista
      } else {
        _showErrorSnackBar('Error al crear plazo: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al crear plazo: $e');
    }
  }

  Future<void> _updateDuracion(int id, int plazo, String frecuencia) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/duracion/$id'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'plazo': plazo,
          'frecuenciaPago': frecuencia,
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Plazo actualizado correctamente.');
        _fetchDuraciones(); // Recargar la lista
      } else {
        _showErrorSnackBar('Error al actualizar plazo: ${response.body}');
        print('Error al actualizar plazo: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al actualizar plazo: $e');
    }
  }

  Future<void> _deleteDuracion(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/duracion/$id'),
        headers: {'tokenauth': token},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSuccessSnackBar('Plazo eliminado correctamente.');
        if (mounted) {
          setState(() {
            _duraciones.removeWhere((d) => d.idduracion == id);
          });
        }
      } else {
        _showErrorSnackBar('Error al eliminar plazo: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('Excepción al eliminar plazo: $e');
    }
  }

  // Función de Redondeo (sin cambios)
  Future<void> _guardarRedondeo() async {
    setState(() => _isSavingRounding = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final url = Uri.parse('$baseUrl/api/v1/configuracion/redondeo');

      final response = await http.put(
        url,
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
        body: jsonEncode({"redondeo": _roundingThreshold}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        widget.onSave(_roundingThreshold);
        _showSuccessSnackBar('Redondeo guardado correctamente');
      } else {
        _showErrorSnackBar('Error al guardar redondeo: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSavingRounding = false);
    }
  }

  // =======================================================================
  // --- SECCIÓN DE DIÁLOGOS Y WIDGETS AUXILIARES ---
  // =======================================================================

  // --- Diálogos Mejorados para Tasas ---
  void _showAddOrEditTasaDialog({TasaInteres? tasa}) {
    // Agregar listen: false aquí
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final _formKey = GlobalKey<FormState>();
    final _mensualController = TextEditingController(
      text: tasa != null ? tasa.mensual.toString() : '',
    );
    final isEditing = tasa != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con ícono
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.blue.shade900.withOpacity(0.3)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit : Icons.add,
                        color: isDarkMode
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Editar Tasa' : 'Nueva Tasa',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            'Configura la tasa de interés mensual',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Formulario
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _mensualController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Tasa Mensual',
                          labelStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          hintText: 'Ej: 9.5',
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                          ),
                          suffixText: '%',
                          suffixStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          prefixIcon: Icon(
                            Icons.percent,
                            color: isDarkMode
                                ? Colors.blue.shade300
                                : Colors.blue.shade600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade600,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.red.shade300
                                  : Colors.red.shade400,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.red.shade300
                                  : Colors.red.shade400,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La tasa es requerida';
                          }
                          final numero = double.tryParse(value);
                          if (numero == null) {
                            return 'Ingrese un número válido';
                          }
                          if (numero <= 0) {
                            return 'La tasa debe ser mayor a 0';
                          }
                          if (numero > 100) {
                            return 'La tasa no puede exceder 100%';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 8),

                      // Información adicional
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.blue.shade900.withOpacity(0.2)
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.blue.shade600
                                : Colors.blue.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: isDarkMode
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade700,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Esta tasa se aplicará mensualmente al capital',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: isDarkMode
                              ? Colors.grey.shade700.withOpacity(0.3)
                              : Colors.transparent,
                          side: isDarkMode
                              ? BorderSide(color: Colors.grey.shade600)
                              : null,
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final mensual =
                                double.parse(_mensualController.text);
                            if (isEditing) {
                              _updateTasa(tasa!.idtipointeres, mensual);
                            } else {
                              _createTasa(mensual);
                            }
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? Colors.blue.shade600
                              : Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Guardar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// --- Diálogos Mejorados para Duraciones ---
  // --- Diálogos Mejorados para Plazos (DISEÑO ACTUALIZADO) ---
  void _showAddOrEditDuracionDialog({Duracion? duracion}) {
    // Agregar listen: false para evitar errores en callbacks
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final _formKey = GlobalKey<FormState>();
    final _plazoController = TextEditingController(
      text: duracion != null ? duracion.plazo.toString() : '',
    );
    String _frecuenciaSeleccionada = duracion?.frecuenciaPago ?? 'Semanal';
    final isEditing = duracion != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calcular información útil
            int? plazoNumero = int.tryParse(_plazoController.text);
            int? totalSemanas;
            if (plazoNumero != null) {
              totalSemanas = _frecuenciaSeleccionada == 'Semanal'
                  ? plazoNumero
                  : plazoNumero * 2;
            }

            return Dialog(
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(maxWidth: 400),
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con ícono (estilo Tasa)
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.blue.shade900.withOpacity(0.3)
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_calendar : Icons.add_task,
                            color: isDarkMode
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Editar Plazo' : 'Nuevo Plazo',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                              ),
                              Text(
                                'Configura la duración del préstamo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Formulario
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Campo de Plazo (estilo Tasa)
                          TextFormField(
                            controller: _plazoController,
                            keyboardType: TextInputType.number,
                            onChanged: (value) => setState(() {}),
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Número de Pagos',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              hintText: 'Ej: 16',
                              hintStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade400,
                              ),
                              prefixIcon: Icon(
                                Icons.schedule,
                                color: isDarkMode
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade600,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'El plazo es requerido';
                              }
                              final numero = int.tryParse(value);
                              if (numero == null) {
                                return 'Ingrese un número entero válido';
                              }
                              if (numero <= 0) {
                                return 'El plazo debe ser mayor a 0';
                              }
                              if (numero > 100) {
                                return 'El plazo no puede exceder 100 pagos';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 16),

                          // Dropdown de Frecuencia (estilo Tasa)
                          DropdownButtonFormField<String>(
                            value: _frecuenciaSeleccionada,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                            dropdownColor:
                                isDarkMode ? Colors.grey[800] : Colors.white,
                            items: [
                              DropdownMenuItem(
                                value: 'Semanal',
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_view_week,
                                        size: 18,
                                        color: isDarkMode
                                            ? Colors.blue.shade300
                                            : Colors.blue.shade600),
                                    SizedBox(width: 8),
                                    Text('Semanal'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Quincenal',
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_view_month,
                                        size: 18,
                                        color: isDarkMode
                                            ? Colors.blue.shade300
                                            : Colors.blue.shade600),
                                    SizedBox(width: 8),
                                    Text('Quincenal'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _frecuenciaSeleccionada = value;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Frecuencia de Pago',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              prefixIcon: Icon(Icons.repeat,
                                  color: isDarkMode
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade600),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade600,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade50,
                            ),
                          ),

                          SizedBox(height: 16),

                          // Información calculada (estilo Tasa)
                          if (totalSemanas != null)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.blue.shade900.withOpacity(0.2)
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.blue.shade600
                                      : Colors.blue.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 16,
                                          color: isDarkMode
                                              ? Colors.blue.shade300
                                              : Colors.blue.shade700),
                                      SizedBox(width: 8),
                                      Text(
                                        'Resumen del Plazo',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode
                                              ? Colors.blue.shade300
                                              : Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '• Pagos: $plazoNumero ${_frecuenciaSeleccionada.toLowerCase()}es',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.blue.shade300
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                  Text(
                                    '• Duración total: $totalSemanas semanas (~${(totalSemanas / 4.33).toStringAsFixed(1)} meses)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.blue.shade300
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Botones de acción (estilo Tasa)
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: isDarkMode
                                  ? Colors.grey.shade700.withOpacity(0.3)
                                  : Colors.transparent,
                              side: isDarkMode
                                  ? BorderSide(color: Colors.grey.shade600)
                                  : null,
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                final plazo = int.parse(_plazoController.text);
                                if (isEditing) {
                                  _updateDuracion(duracion!.idduracion, plazo,
                                      _frecuenciaSeleccionada);
                                } else {
                                  _createDuracion(
                                      plazo, _frecuenciaSeleccionada);
                                }
                                Navigator.of(context).pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Guardar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Diálogo de Confirmación para Borrar (reutilizable) ---
  void _showDeleteConfirmationDialog({required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Eliminación'),
        content: Text(
            '¿Estás seguro de que deseas eliminar este elemento? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.of(context).pop();
            },
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- Widgets de Feedback (SnackBars) ---
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    maxLines: 3, overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // =======================================================================
  // --- SECCIÓN DE CONSTRUCCIÓN DE UI (BUILD) ---
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      child: Column(
        children: [
          // Header con gradiente
          Container(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, top: 10, bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            //color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: isDarkMode ? Colors.white : Colors.grey[700],
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestiona los parámetros de crédito',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Tabs personalizados
                  // --- MODIFICADO: Se actualiza el TabBar ---
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.3))),
                    child: SizedBox(
                      height: 40,
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color:
                              isDarkMode ? Color(0xFF5162F6) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: isDarkMode ? Colors.white : Colors.black,
                        unselectedLabelColor:
                            isDarkMode ? Colors.white : Colors.black,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        // --- MODIFICADO: Se añade la nueva Tab ---
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.adjust, size: 14),
                            text: 'Redondeo',
                          ),
                          Tab(
                            icon: Icon(Icons.trending_up, size: 14),
                            text: 'Tasas',
                          ),
                          Tab(
                            icon: Icon(Icons.calendar_today, size: 14),
                            text: 'Plazos',
                          ),
                          // --- NUEVO: Tab de Moratorios ---
                          Tab(
                            icon: Icon(Icons.warning_amber_rounded, size: 14),
                            text: 'Moratorios',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido de las tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRedondeoTab(),
                _buildTasasTab(),
                _buildDuracionesTab(),
                _buildMoratorioTab(), // --- NUEVO ---
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget para la Pestaña de Redondeo (sin cambios) ---
  Widget _buildRedondeoTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final List<double> options = [0.1, 0.25, 0.3, 0.5, 0.6, 0.75, 0.8, 0.9];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      child: Column(
        children: [
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5162F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.adjust,
                        color: Color(0xFF5162F6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Umbral de Redondeo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            'Configura desde qué valor redondear',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDarkMode ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((value) {
                    final isSelected = _roundingThreshold == value;
                    return GestureDetector(
                      onTap: () => setState(() => _roundingThreshold = value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF5162F6)
                              : isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF5162F6)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '≥ ${value.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : isDarkMode
                                    ? Colors.white
                                    : Colors.grey.shade700,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: _isSavingRounding
                      ? Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _guardarRedondeo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5162F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.save,
                                size: 20,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Guardar Configuración',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets para Pestañas de Datos con lógica conectada ---

  Widget _buildTasasTab() {
    return _buildDataTab<TasaInteres>(
      title: 'Tasas de Interés',
      subtitle: 'Gestiona las tasas disponibles',
      icon: Icons.trending_up,
      isLoading: _loadingTasas,
      dataList: _tasasDeInteres,
      onAddPressed: () => _showAddOrEditTasaDialog(), // <-- CONECTADO
      itemBuilder: (tasa) => _buildModernTasaCard(tasa),
    );
  }

  Widget _buildDuracionesTab() {
    return _buildDataTab<Duracion>(
      title: 'Plazos de Crédito',
      subtitle: 'Administra los plazos disponibles',
      icon: Icons.calendar_today,
      isLoading: _loadingDuraciones,
      dataList: _duraciones,
      onAddPressed: () => _showAddOrEditDuracionDialog(), // <-- CONECTADO
      itemBuilder: (duracion) => _buildModernDuracionCard(duracion),
    );
  }

  // --- Constructor genérico de pestañas (sin cambios) ---
  Widget _buildDataTab<T>({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isLoading,
    required List<T> dataList,
    required Widget Function(T) itemBuilder,
    required VoidCallback onAddPressed,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5162F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF5162F6), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              FloatingActionButton.small(
                onPressed: onAddPressed, // <-- Usamos el callback
                backgroundColor: const Color(0xFF5162F6),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : dataList.isEmpty
                  ? _buildEmptyState(title)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: dataList.length,
                      itemBuilder: (context, index) =>
                          itemBuilder(dataList[index]),
                    ),
        ),
      ],
    );
  }

  // --- Widget de estado vacío (sin cambios) ---
  Widget _buildEmptyState(String type) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay $type',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega el primer elemento para comenzar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // --- Cards de datos con lógica conectada ---

  Widget _buildModernTasaCard(TasaInteres tasa) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF5162F6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(tasa.mensual).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mensual',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    (tasa.fCreacion),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () =>
                      _showAddOrEditTasaDialog(tasa: tasa), // <-- CONECTADO
                  icon: Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? Colors.blue.shade50.withOpacity(0.1)
                        : Colors.blue.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showDeleteConfirmationDialog(
                    onConfirm: () =>
                        _deleteTasa(tasa.idtipointeres), // <-- CONECTADO
                  ),
                  icon:
                      Icon(Icons.delete, color: Colors.red.shade600, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? Colors.red.shade50.withOpacity(0.1)
                        : Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Card de Plazos (DISEÑO ACTUALIZADO) ---
  Widget _buildModernDuracionCard(Duracion duracion) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Barra de acento (estilo Tasa)
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF5162F6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${duracion.plazo} Pagos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Frecuencia: ${duracion.frecuenciaPago}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Creado: ${DateFormat('dd/MM/yyyy').format(duracion.fCreacion)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Botones (estilo Tasa)
            Row(
              children: [
                IconButton(
                  onPressed: () =>
                      _showAddOrEditDuracionDialog(duracion: duracion),
                  icon: Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? Colors.blue.shade50.withOpacity(0.1)
                        : Colors.blue.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showDeleteConfirmationDialog(
                    onConfirm: () => _deleteDuracion(duracion.idduracion),
                  ),
                  icon:
                      Icon(Icons.delete, color: Colors.red.shade600, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? Colors.red.shade50.withOpacity(0.1)
                        : Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- NUEVO: Widget para la Pestaña de Moratorios ---
  Widget _buildMoratorioTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    if (_loadingMoratorio) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_moratorioConfig == null) {
      return _buildEmptyState("Configuración de Moratorios");
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      child: Form(
        key: _moratorioFormKey,
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5162F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFF5162F6), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuración de Moratorios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'Define las penalizaciones por atraso',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Campo: Días de Tolerancia
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Número de días sin penalización después del vencimiento (Ej: 3)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _diasToleranciaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _buildInputDecoration(
                      label: 'Días de Tolerancia',
                      hint: 'Ej: 3',
                      icon: Icons.shield_outlined,
                      isDarkMode: isDarkMode),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Campo requerido';
                    final n = int.tryParse(value);
                    if (n == null) return 'Debe ser un número entero';
                    if (n < 0) return 'No puede ser negativo';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Campo: Tasa Moratoria
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Porcentaje de interés aplicado por cada día de atraso (Ej: 0.1 para 10%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _moratorioController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _buildInputDecoration(
                      label: 'Tasa Moratoria (%)',
                      hint: 'Ej: 0.1 para 10%',
                      icon: Icons.trending_down,
                      isDarkMode: isDarkMode),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Campo requerido';
                    final n = double.tryParse(value);
                    if (n == null) return 'Debe ser un número';
                    if (n < 0 || n > 1) return 'Debe ser un valor entre 0 y 1';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Campo: Tasa Moratoria Expandida
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasa adicional aplicada después de un período extendido de atraso (Ej: 0.05 para 5%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _moratorioExpandidoController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _buildInputDecoration(
                      label: 'Tasa Moratoria Expandida (%)',
                      hint: 'Ej: 0.05 para 5%',
                      icon: Icons.layers,
                      isDarkMode: isDarkMode),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Campo requerido';
                    final n = double.tryParse(value);
                    if (n == null) return 'Debe ser un número';
                    if (n < 0 || n > 1) return 'Debe ser un valor entre 0 y 1';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Botón de Guardar
            SizedBox(
              width: double.infinity,
              child: _isSavingMoratorio
                  ? Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : ElevatedButton(
                      onPressed: _updateMoratorioConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5162F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Guardar Configuración',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NUEVO: Helper para decorar los inputs y evitar repetición de código ---
  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
      hintText: hint,
      hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
      prefixIcon: Icon(
        icon,
        color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
          width: 2,
        ),
      ),
      filled: true,
      fillColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
    );
  }
}
