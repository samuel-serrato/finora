import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:money_facil/screens/simGrupal.dart';
import 'package:money_facil/widgets/CardUserWidget.dart';
import 'package:money_facil/formateador.dart';

class SimuladorScreen extends StatefulWidget {
    final String username;
    final String tipoUsuario;


  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();

  const SimuladorScreen({Key? key, required this.username, required this.tipoUsuario}) : super(key: key);
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  bool isLoading = true;
  bool showErrorDialog = false;

  bool isGeneralSelected = true;
  bool isIndividualSelected = false;

  final TextEditingController montoController = TextEditingController();
  final TextEditingController plazoController = TextEditingController();
  final TextEditingController interesController = TextEditingController();

  String? otroValor; // Para almacenar el valor del TextField

  String periodo = 'Semanal';
  double monto = 0.0;
  double interesMensual = 0.0;
  int plazoSemanas = 0;
  DateTime? fechaSeleccionada;
  double? tasaInteresMensualSeleccionada;
  int?
      plazoSeleccionado; // Cambia de 'int' a 'int?' para permitir valores nulos

  List<AmortizacionItem> tablaAmortizacion = [];

  List<int> plazos = [12, 14, 16]; // Valor inicial de las semanas

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
  @override
  void initState() {
    super.initState();
  }

  bool _isDarkMode = false; // Estado del modo oscuro

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFf7f8fa),
      appBar: CustomAppBar(
        isDarkMode: _isDarkMode,
        toggleDarkMode: _toggleDarkMode,
        title: 'Simulador', // Título específico para esta pantalla
        nombre: widget.username,
        tipoUsuario: widget.tipoUsuario,
      ),
      body: content(context),
    );
  }

  Widget content(BuildContext context) {
    return Column(
      children: [
        filaTitulo(context),
        filaTabla(context),
      ],
    );
  }

  Widget filaTitulo(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(right: 10, left: 10, top: 10, bottom: 10),
      child: Row(
        children: <Widget>[
          Spacer(), // Espacio flexible para empujar los ChoiceChip a la derecha
          SizedBox(
            child: ChoiceChip(
              labelPadding: EdgeInsets.all(0),
              label: Text(
                'General',
                style: TextStyle(
                  color: isGeneralSelected
                      ? Colors.white
                      : Color(
                          0xFFFB2056), // Cambia el color del texto según la selección
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              selected: isGeneralSelected,
              onSelected: (isSelected) {
                setState(() {
                  isGeneralSelected = true;
                  isIndividualSelected =
                      false; // Asegúrate de que el otro sea falso
                });
              },
              backgroundColor: Colors.white,
              selectedColor: Color(0xFFFB2056),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
                side: BorderSide(
                  color: Color(0xFFFB2056),
                  width: 2.0,
                ),
              ),
              elevation: 5.0,
              pressElevation: 10.0,
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            child: ChoiceChip(
              labelPadding: EdgeInsets.all(0),
              label: Text(
                'Grupal',
                style: TextStyle(
                  color:
                      isIndividualSelected ? Colors.white : Color(0xFFFB2056),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              selected: isIndividualSelected,
              onSelected: (isSelected) {
                setState(() {
                  isIndividualSelected = true;
                  isGeneralSelected =
                      false; // Asegúrate de que el otro sea falso
                });
              },
              backgroundColor: Colors.white,
              selectedColor: Color(0xFFFB2056),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
                side: BorderSide(
                  color: Color(0xFFFB2056),
                  width: 2.0,
                ),
              ),
              elevation: 5.0,
              pressElevation: 10.0,
            ),
          ),
          SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget filaTabla(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.only(top: 0, bottom: 20, right: 20, left: 20),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), // Color de la sombra
                  spreadRadius: 0.5, // Expansión de la sombra
                  blurRadius: 5, // Difuminado de la sombra
                  offset: Offset(2, 2), // Posición de la sombra
                ),
              ],
            ),
            child: isGeneralSelected
                ? simuladorGeneral()
                : simuladorGrupal(), // Cambia según la selección
          ),
        ),
      ),
    );
  }

  Widget simuladorGeneral() {
    double capitalQuincenal = monto / (plazoSemanas * 2); // Capital quincenal
    double interesQuincenal =
        (monto * (interesMensual / 100) / 4) * 2; // Interés quincenal

    double parseAmount(String text) {
      String cleanedText = text.replaceAll(',', '');
      return double.tryParse(cleanedText) ?? 0.0;
    }

    void recalcular() {
      setState(() {
        monto = parseAmount(montoController.text);

        // Verificar si se seleccionó "Otro" y usar el valor del TextField
        if (tasaInteresMensualSeleccionada == 0.0) {
          // Convierte el valor del TextField a un double
          interesMensual = double.tryParse(otroValor!) ??
              0; // Si no se puede parsear, usar 0
        } else {
          interesMensual = tasaInteresMensualSeleccionada ?? 0;
        }

        plazoSemanas = plazoSeleccionado ?? 0; // Usar la opción seleccionada
      });
    }

    void selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: fechaSeleccionada ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(DateTime.now().year + 10),
        locale: Locale('es', 'ES'),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              primaryColor:
                  Colors.white, // Cambia el color de los elementos destacados

              colorScheme: ColorScheme.fromSwatch().copyWith(
                primary: Color(0xFFFB2056),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && picked != fechaSeleccionada) {
        setState(() {
          fechaSeleccionada = picked;
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 6, // 7 partes del ancho
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Flexible(
                              flex: 2,
                              child: Container(
                                height: 40, // Consistencia en altura
                                child: TextField(
                                  controller: montoController,
                                  decoration: InputDecoration(
                                    labelText: 'Monto',
                                    labelStyle: TextStyle(
                                        fontSize: 12.0,
                                        color: Colors.grey[700]),
                                    filled: true,
                                    fillColor: Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                      borderSide: BorderSide(
                                          color: Colors.grey[300]!, width: 2.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                      borderSide: BorderSide(
                                        color: Color(
                                            0xFFFB2056), // Color al enfocar
                                        width: 2.0,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 10),
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(fontSize: 14.0),
                                  onChanged: (value) {
                                    // Llama a la función de formateo directamente aquí
                                    String formatted = formatMonto(value);
                                    montoController.value = TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(
                                          offset: formatted.length),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Flexible(
                              flex: 2,
                              child: Container(
                                height: 40, // Consistencia en altura
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: Colors.grey[300]!, width: 2.0),
                                  borderRadius: BorderRadius.circular(15.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: periodo,
                                    hint: Text('Selecciona periodo',
                                        style: TextStyle(fontSize: 12)),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        periodo = newValue!;
                                        if (periodo == 'Quincenal') {
                                          plazos = [
                                            4
                                          ]; // Plazos para "Quincenal"
                                        } else if (periodo == 'Semanal') {
                                          plazos = [
                                            12,
                                            14,
                                            16
                                          ]; // Plazos para "Semanal"
                                        } else {
                                          plazos = [
                                            3,
                                            6,
                                            12,
                                            24
                                          ]; // Valores predeterminados
                                        }
                                        plazoSeleccionado =
                                            null; // Reiniciar selección de plazo
                                      });
                                    },
                                    items: <String>['Semanal', 'Quincenal']
                                        .map<DropdownMenuItem<String>>(
                                      (String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value,
                                              style: TextStyle(fontSize: 12.0)),
                                        );
                                      },
                                    ).toList(),
                                    icon: Icon(Icons.arrow_drop_down,
                                        color: Color(0xFFFB2056)),
                                    dropdownColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            // Dropdown de tasa de interés (que incluye "Otro")
                            Flexible(
                              flex: 1,
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15.0),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1.5,
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10.0),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<double>(
                                    hint: Text(
                                      'Elige una tasa de interés',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700]),
                                    ),
                                    isExpanded: true,
                                    value: tasaInteresMensualSeleccionada,
                                    onChanged: (double? newValue) {
                                      setState(() {
                                        tasaInteresMensualSeleccionada =
                                            newValue!;
                                        if (newValue == 0.0) {
                                          otroValor =
                                              ''; // Limpiar si selecciona "Otro"
                                        }
                                      });
                                    },
                                    items: tasas.map<DropdownMenuItem<double>>(
                                        (double value) {
                                      return DropdownMenuItem<double>(
                                        value: value,
                                        child: Text(
                                          value == 0.0 ? 'Otro' : '$value %',
                                          style: TextStyle(
                                              fontSize: 14.0,
                                              color: Colors.black),
                                        ),
                                      );
                                    }).toList(),
                                    icon: Icon(Icons.arrow_drop_down,
                                        color: Color(0xFFFB2056)),
                                    dropdownColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            // Mostrar el TextField solo si se selecciona "Otro"
                            if (tasaInteresMensualSeleccionada == 0.0) ...[
                              SizedBox(width: 10), // Espaciado entre widgets
                              Flexible(
                                flex: 1,
                                child: Container(
                                  margin: EdgeInsets.only(right: 10),
                                  height: 40,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Especificar Tasa',
                                      hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(15.0),
                                        borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                            width: 1.5),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(15.0),
                                        borderSide: BorderSide(
                                            color: Color(0xFFFB2056),
                                            width: 1.5),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 10),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        otroValor = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],

                            // Espaciado adicional solo si no se selecciona "Otro"
                            if (tasaInteresMensualSeleccionada != 0.0)
                              SizedBox(
                                  width: 10), // Espaciado entre los dropdowns

                            // Dropdown de Plazos
                            Flexible(
                              flex: tasaInteresMensualSeleccionada == 0.0
                                  ? 2
                                  : 1, // Si se selecciona "Otro", ocupa menos espacio
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15.0),
                                  border: Border.all(
                                      color: Colors.grey[300]!, width: 1.5),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10.0),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    hint: Text(
                                      'Elige un plazo',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700]),
                                    ),
                                    isExpanded: true,
                                    value: plazoSeleccionado,
                                    onChanged: (int? newValue) {
                                      setState(() {
                                        plazoSeleccionado = newValue;
                                      });
                                    },
                                    items: plazos.map<DropdownMenuItem<int>>(
                                        (int value) {
                                      return DropdownMenuItem<int>(
                                        value: value,
                                        child: Text(
                                          '$value ${periodo == "Semanal" ? "semanas" : "meses"}',
                                          style: TextStyle(
                                              fontSize: 14.0,
                                              color: Colors.black),
                                        ),
                                      );
                                    }).toList(),
                                    icon: Icon(Icons.arrow_drop_down,
                                        color: Color(0xFFFB2056)),
                                    dropdownColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => selectDate(context),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Color(0xFFFB2056),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  fechaSeleccionada == null
                                      ? 'Seleccionar Fecha de Inicio'
                                      : 'Fecha de Inicio: ${DateFormat('dd/MM/yyyy', 'es').format(fechaSeleccionada!)}',
                                  style: TextStyle(fontSize: 12.0),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            if (fechaSeleccionada != null)
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy', 'es')
                                    .format(fechaSeleccionada!),
                                style: TextStyle(
                                    fontSize: 12.0, color: Colors.grey[700]),
                              ),
                            Spacer(),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  // Limpiar los campos del formulario
                                  montoController.clear();
                                  plazoController.clear();
                                  interesController.clear();
                                  monto = 0.0;
                                  interesMensual = 0.0;
                                  periodo =
                                      'Semanal'; // Restablecer el valor predeterminado del dropdown
                                  fechaSeleccionada =
                                      null; // Restablecer la fecha seleccionada
                                  tasaInteresMensualSeleccionada =
                                      null; // O el valor predeterminado
                                  plazoSeleccionado =
                                      null; // O el valor predeterminado

                                  tablaAmortizacion.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    Colors.grey, // Botón de limpieza en gris
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: Text(
                                  'Limpiar Campos',
                                  style: TextStyle(fontSize: 12.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Resumen:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Monto a prestar: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(monto)}',
                            style: TextStyle(fontSize: 12.0),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Capital ${periodo.toLowerCase()}: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format((periodo == 'Quincenal') ? capitalQuincenal : monto / plazoSemanas)}',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                  Text(
                                    'Interés ${periodo.toLowerCase()}: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format((periodo == 'Quincenal') ? interesQuincenal : (monto * (interesMensual / 100) / 4))}',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                  Text(
                                    'Pago ${periodo.toLowerCase()}: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format((periodo == 'Quincenal') ? (capitalQuincenal + interesQuincenal) : ((monto / plazoSemanas) + (monto * (interesMensual / 100) / 4)))}',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                ],
                              ),
                              SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Intereses Totales: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(calculateInterest(monto, interesMensual, plazoSemanas))}',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                  Text(
                                    'Interés ${periodo.toLowerCase()}: ${(interesMensual / (periodo == 'Semanal' ? 4.0 : 2.0)).toStringAsFixed(2)}%',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                  Text(
                                    'Interés Global: ${((calculateInterest(monto, interesMensual, plazoSemanas) / monto) * 100).toStringAsFixed(2)}%',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Total a recuperar: \$${NumberFormat.currency(locale: 'es', symbol: '', decimalDigits: 2).format(calculateTotal(monto, interesMensual, plazoSemanas))}',
                            style: TextStyle(fontSize: 12.0),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Color(0xFFFB2056),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    recalcular();
                                    // Imprimir los valores para verificar si están actualizados correctamente
                                    print(
                                        'Plazo semanas al presionar el botón: $plazoSemanas');
                                    print(
                                        'Tasa interés mensual al presionar el botón: $interesMensual');

                                    bool hayErrores = false;

                                    // Verificar si el plazo no ha sido seleccionado
                                    if (plazoSemanas == 0) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Error: Debes seleccionar el plazo de semanas.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      hayErrores = true;
                                    }

                                    // Verificar si la tasa de interés no ha sido seleccionada
                                    if (interesMensual <= 0) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Error: Debes seleccionar una tasa de interés.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      hayErrores = true;
                                    }

                                    // Si hay errores, salimos de la ejecución
                                    if (hayErrores) {
                                      return;
                                    }

                                    // Si no hay errores, recalculamos y generamos la tabla
                                    generarTablaAmortizacion();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Calcular',
                                      style: TextStyle(fontSize: 12.0)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(),
          SizedBox(height: 20),
          if (tablaAmortizacion.isNotEmpty) ...[
            Text(
              'Tabla de Amortización:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold), // Ajuste de tamaño
            ),
            SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                child: SingleChildScrollView(
                  child: DataTable(
                    dataRowHeight: 30,
                    columns: [
                      DataColumn(
                          label: Text('No. $periodo',
                              style: TextStyle(fontSize: 12.0))),
                      DataColumn(
                          label: Text('Fecha de Pago',
                              style: TextStyle(fontSize: 12.0))),
                      DataColumn(
                          label: Text('Capital',
                              style: TextStyle(fontSize: 12.0))),
                      DataColumn(
                          label: Text('Interés',
                              style: TextStyle(fontSize: 12.0))),
                      DataColumn(
                          label: Text('Pago por Cuota',
                              style: TextStyle(fontSize: 12.0))),
                      DataColumn(
                          label: Text('Pagado',
                              style:
                                  TextStyle(fontSize: 12.0))), // Nueva columna
                      DataColumn(
                          label: Text('Restante',
                              style: TextStyle(fontSize: 12.0))),
                    ],
                    rows: tablaAmortizacion.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item.numero.toString(),
                            style: TextStyle(fontSize: 12.0))),
                        DataCell(Text(
                            item.numero == 0
                                ? ''
                                : DateFormat('dd/MM/yyyy', 'es')
                                    .format(item.fecha)
                                    .replaceAll('.', ','),
                            style: TextStyle(fontSize: 12.0))),
                        DataCell(Text(
                            '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(item.capitalSemanal)}',
                            style: TextStyle(fontSize: 12.0))),
                        DataCell(Text(
                            '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(item.interesSemanal)}',
                            style: TextStyle(fontSize: 12.0))),
                        DataCell(Text(
                            '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(item.pagoCuota)}',
                            style: TextStyle(fontSize: 12.0))),
                        DataCell(Text(
                            '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(item.pagado)}',
                            style: TextStyle(
                                fontSize: 12.0))), // Muestra total pagado
                        DataCell(Text(
                            '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(item.restante)}',
                            style: TextStyle(fontSize: 12.0))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  DateTime ajustarFechaQuincenal(DateTime fechaInicial) {
    // Determinar si estamos en la primera quincena o la segunda
    if (fechaInicial.day <= 10) {
      // Si la fecha es antes o igual al 10, el primer pago será el 15 del mes actual
      return DateTime(fechaInicial.year, fechaInicial.month, 15);
    } else if (fechaInicial.day > 10 && fechaInicial.day <= 25) {
      // Si la fecha está entre el 11 y el 25, el primer pago será el 30 o el último día del mes
      int ultimoDiaDelMes =
          DateTime(fechaInicial.year, fechaInicial.month + 1, 0).day;

      // En febrero, devolver 28 si es menor a 30
      if (fechaInicial.month == 2 && ultimoDiaDelMes < 30) {
        return DateTime(fechaInicial.year, fechaInicial.month, 28);
      }

      // Para otros meses, usar 30 como referencia
      return DateTime(fechaInicial.year, fechaInicial.month,
          ultimoDiaDelMes < 30 ? ultimoDiaDelMes : 30);
    } else {
      // Si la fecha está después del 25, el pago será el 15 del próximo mes
      return DateTime(fechaInicial.year, fechaInicial.month + 1, 15);
    }
  }

  void generarTablaAmortizacion() {
    tablaAmortizacion.clear();
    DateTime fechaInicio = fechaSeleccionada ?? DateTime.now();

    // Calcular el interés total y el monto total a recuperar
    double interesTotal =
        calculateInterest(monto, interesMensual, plazoSemanas);
    double montoTotalRecuperar =
        monto + interesTotal; // Monto total a recuperar

    // Inicializar el saldo y el total pagado
    double saldoRestante = montoTotalRecuperar;
    double totalPagado = 0.0;

    // Calcular capital y interés por periodo (semana o quincena)
    double capitalPorPeriodo = (periodo == 'Semanal')
        ? monto / plazoSemanas // Capital fijo por semana
        : monto / (plazoSemanas * 2); // Capital fijo por quincena

    double interesPorPeriodo = (periodo == 'Semanal')
        ? interesTotal / plazoSemanas // Interés por semana
        : interesTotal / (plazoSemanas * 2); // Interés por quincena

    // Primera fila para el desembolso inicial
    tablaAmortizacion.add(AmortizacionItem(
      numero: 0,
      fecha: fechaInicio,
      pagoCuota: 0.0,
      interesPorcentaje: 0.0,
      interesCantidad: 0.0, // No hay interés en el desembolso inicial
      restante: saldoRestante,
      capitalSemanal: 0.0, // Inicializar
      interesSemanal: 0.0, // Inicializar
      pagado: totalPagado, // Inicializar total pagado
    ));

    // Calcular el pago total por cuota (semana o quincena)
    double pagoCuota = capitalPorPeriodo + interesPorPeriodo;

    int numPeriodos = (periodo == 'Semanal')
        ? plazoSemanas
        : plazoSemanas * 2; // Periodos totales

    for (int i = 1; i <= numPeriodos; i++) {
      // Actualizar el saldo restante después de pagar la cuota
      saldoRestante -= pagoCuota;
      totalPagado += pagoCuota;

      DateTime fechaPago = fechaInicio;

      if (periodo == 'Semanal') {
        fechaPago = fechaInicio.add(Duration(days: 7 * i));
      } else if (periodo == 'Quincenal') {
        fechaPago = ajustarFechaQuincenal(
            fechaInicio.add(Duration(days: 14 * (i - 1))));
      }

      tablaAmortizacion.add(AmortizacionItem(
        numero: i,
        fecha: fechaPago,
        pagoCuota: pagoCuota,
        interesPorcentaje:
            (interesMensual / (periodo == 'Semanal' ? 4.0 : 2.0)),
        interesCantidad: interesPorPeriodo,
        restante: saldoRestante,
        capitalSemanal: capitalPorPeriodo,
        interesSemanal: interesPorPeriodo,
        pagado: totalPagado,
      ));
    }
  }

  double calculateInterest(double monto, double interesMensual, int plazo) {
    if (periodo == 'Semanal') {
      // Interés semanal
      double interesSemanal = interesMensual / 4;
      return monto * (interesSemanal / 100) * plazo;
    } else {
      // Interés quincenal
      double interesSemanal = interesMensual / 4;
      double interesQuincenal = interesSemanal * 2;
      int quincenas = plazo * 2; // Plazo en quincenas
      return monto * (interesQuincenal / 100) * quincenas;
    }
  }

  double calculateWeeklyPayment(
      double monto, double interesMensual, int plazo) {
    double total = calculateTotal(monto, interesMensual, plazo);
    if (periodo == 'Semanal') {
      return total / plazo; // Pago semanal
    } else {
      int quincenas = plazo * 2; // Plazo en quincenas
      return total / quincenas; // Pago quincenal
    }
  }

  double calculateTotal(double monto, double interesMensual, int plazo) {
    return monto + calculateInterest(monto, interesMensual, plazo);
  }
}

class AmortizacionItem {
  final int numero;
  final DateTime fecha;
  final double pagoCuota;
  final double interesPorcentaje;
  final double interesCantidad;
  final double restante;
  final double capitalSemanal;
  final double interesSemanal;
  final double pagado; // Nueva propiedad para total pagado

  AmortizacionItem({
    required this.numero,
    required this.fecha,
    required this.pagoCuota,
    required this.interesPorcentaje,
    required this.interesCantidad,
    required this.restante,
    required this.capitalSemanal,
    required this.interesSemanal,
    required this.pagado, // Inicializa el total pagado
  });
}
