import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class nCreditoDialog extends StatefulWidget {
  final VoidCallback onGrupoAgregado;

  nCreditoDialog({required this.onGrupoAgregado});

  @override
  _nCreditoDialogState createState() => _nCreditoDialogState();
}

class _nCreditoDialogState extends State<nCreditoDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // Formulario general
  final GlobalKey<FormState> _infoGrupoFormKey =
      GlobalKey<FormState>(); // Formulario de Datos Generales
  final GlobalKey<FormState> _miembrosGrupoFormKey =
      GlobalKey<FormState>(); // Formulario de Integrantes

  String? selectedGrupo;
  String? garantia;
  String? frecuenciaPago;
  String? diaPago;
  DateTime fechaInicio = DateTime.now();

  final montoController = TextEditingController();
  final tasaInteresController = TextEditingController();
  final plazoController = TextEditingController();

  // Datos para los integrantes y sus montos individuales
  List<Map<String, dynamic>> integrantes = [];
  Map<int, double> montosIndividuales =
      {}; // Mapa de montos por cada integrante

  String _formatearFecha(DateTime fecha) {
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });

    // Inicializar con el día de la semana de la fecha de inicio
    diaPago = _diaDeLaSemana(fechaInicio);
    frecuenciaPago = "Semanal"; // Valor predeterminado
  }

  Future<void> _mostrarDialogoAdvertencia(BuildContext context) async {
    showDialog(
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
    // Sumar los montos individuales desde el mapa
    double sumaMontosIndividuales = montosIndividuales.values
        .fold(0.0, (previousValue, element) => previousValue + element);
    double montoTotal = double.tryParse(montoController.text) ?? 0.0;

    if (sumaMontosIndividuales != montoTotal) {
      // Mostrar un diálogo de advertencia si los montos no coinciden
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

  void _guardarCredito() {
    // Lógica para guardar el crédito con los datos ingresados
    print("Crédito guardado");
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
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
            TabBar(
              controller: _tabController,
              labelColor: Color(0xFFFB2056),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFFFB2056),
              tabs: [
                Tab(text: 'Datos Generales'),
                Tab(text: 'Integrantes'),
                Tab(text: 'Resumen'),
              ],
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
                    if (_currentIndex == 2)
                      ElevatedButton(
                        onPressed: _guardarCredito,
                        child: Text('Guardar'),
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

  Widget _paginaDatosGenerales() {
    int pasoActual = 1; // Paso actual que queremos marcar como activo
    const double verticalSpacing = 20.0; // Espaciado vertical constante

    return Form(
      key: _infoGrupoFormKey,
      child: Row(
        children: [
          _recuadroPasos(pasoActual), // Recuadro de pasos
          SizedBox(
              width: 50), // Espacio entre la columna izquierda y el formulario

          // Columna derecha con el formulario
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: selectedGrupo,
                          hint: 'Seleccionar Grupo',
                          items: ["Grupo 1", "Grupo 2"],
                          onChanged: (value) => setState(() {
                            selectedGrupo = value;
                          }),
                          validator: (value) =>
                              value == null ? 'Seleccione un grupo' : null,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: montoController,
                          label: 'Monto Autorizado',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Ingrese el monto autorizado'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: tasaInteresController,
                          label: 'Tasa de Interés (%)',
                          icon: Icons.percent,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          value: garantia,
                          hint: 'Garantía',
                          items: ["Garantía 1", "Garantía 2"],
                          onChanged: (value) => setState(() {
                            garantia = value;
                          }),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: frecuenciaPago,
                          hint: 'Frecuencia de Pago',
                          items: ["Semanal", "Quincenal"],
                          onChanged: (value) => setState(() {
                            frecuenciaPago = value;
                            plazoController.text = ""; // Reiniciar plazo
                          }),
                          validator: (value) => value == null
                              ? 'Seleccione una frecuencia de pago'
                              : null,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: frecuenciaPago == "Semanal"
                            ? _buildDropdown(
                                value: plazoController.text.isEmpty
                                    ? null
                                    : plazoController.text,
                                hint: 'Elige plazo',
                                items: ["12", "14", "16"],
                                onChanged: (value) {
                                  setState(() {
                                    plazoController.text = value ?? "";
                                  });
                                },
                                validator: (value) => value?.isEmpty ?? true
                                    ? 'Seleccione un plazo'
                                    : null,
                              )
                            : _buildDropdown(
                                value: plazoController.text.isEmpty
                                    ? null
                                    : plazoController.text,
                                hint: 'Elige plazo',
                                items: ["4 meses"],
                                onChanged: (value) {
                                  setState(() {
                                    plazoController.text = value ?? "";
                                  });
                                },
                                validator: (value) => value?.isEmpty ?? true
                                    ? 'Seleccione un plazo'
                                    : null,
                              ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            'Fecha de Inicio: ${_formatearFecha(fechaInicio)}'),
                      ),
                      TextButton(
                        child: Text('Cambiar'),
                        onPressed: () async {
                          final nuevaFecha = await showDatePicker(
                            context: context,
                            initialDate: fechaInicio,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
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
                  Text('Día de Pago: $diaPago'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaIntegrantes() {
  int pasoActual = 2; // Paso actual para esta página

  // Datos simulados de integrantes
  if (integrantes.isEmpty) {
    integrantes = [
      {'id': 1, 'nombre': 'Juan Pérez'},
      {'id': 2, 'nombre': 'Ana López'},
      {'id': 3, 'nombre': 'Luis Gómez'},
    ];

    // Inicializamos los montos individuales en 0.0
    for (var i = 0; i < integrantes.length; i++) {
      montosIndividuales[i] = 0.0;
    }
  }

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
                    final integrante = integrantes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              integrante['nombre'] ?? 'Integrante ${index + 1}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: _buildTextField(
                              controller: TextEditingController(
                                text: montosIndividuales[index]?.toStringAsFixed(2),
                              ),
                              label: 'Monto',
                              icon: Icons.attach_money,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa un monto';
                                }
                                return null;
                              },
                              fontSize: 16.0,
                              maxLength: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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


  Widget _paginaResumen() {
    int pasoActual = 3; // Paso actual para esta página

    return Row(
      children: [
        _recuadroPasos(pasoActual), // Recuadro de pasos
        SizedBox(width: 50), // Espacio entre el recuadro y el contenido

        // Contenido de la página
        Expanded(
          child: Center(
            child: Text(
              'Resumen del Crédito',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recuadroPasos(int pasoActual) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFB2056),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      width: 250,
      height: 500,
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
                ? Color(0xFFFB2056)
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
  required void Function(String?) onChanged,
  double fontSize = 12.0,
  String? Function(String?)? validator,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    hint: value == null
        ? Text(
            hint,
            style: TextStyle(fontSize: fontSize, color: Colors.black),
          )
        : null,
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
    validator: validator,
    decoration: InputDecoration(
      labelText: value != null ? hint : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black),
      ),
    ),
    style: TextStyle(fontSize: fontSize, color: Colors.black),
  );
}
