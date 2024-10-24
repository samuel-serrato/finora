import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:money_facil/screens/simGrupal.dart';
import 'package:money_facil/widgets/CardUserWidget.dart';

class SimuladorScreen extends StatefulWidget {
  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();

  final String username; // Agregar esta línea
  const SimuladorScreen({Key? key, required this.username}) : super(key: key);
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  bool isLoading = true;
  bool showErrorDialog = false;

  bool isGeneralSelected = true;
  bool isIndividualSelected = false;

  final TextEditingController montoController = TextEditingController();
  final TextEditingController plazoController = TextEditingController();
  final TextEditingController interesController = TextEditingController();
  String periodo = 'Semanal';
  double monto = 0.0;
  double interesMensual = 0.0;
  int plazoSemanas = 0;
  DateTime? fechaSeleccionada;
  double? tasaInteresMensualSeleccionada;
  int?
      plazoSeleccionado; // Cambia de 'int' a 'int?' para permitir valores nulos

  List<AmortizacionItem> tablaAmortizacion = [];

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
      padding: EdgeInsets.only(right: 10, left: 10, top: 0, bottom: 10),
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
    double parseAmount(String text) {
      String cleanedText = text.replaceAll(',', '');
      return double.tryParse(cleanedText) ?? 0.0;
    }

    void recalcular() {
      setState(() {
        monto = parseAmount(montoController.text);
        interesMensual = tasaInteresMensualSeleccionada ?? 0;
        plazoSemanas = plazoSeleccionado ?? 0; // Usar la opción seleccionada
      });
    }

    void selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: fechaSeleccionada ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(DateTime.now().year + 10),
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
                            Expanded(
                              child: Container(
                                height: 35, // Ajustar altura
                                child: TextField(
                                  controller: montoController,
                                  decoration: InputDecoration(
                                    labelText: 'Monto',
                                    labelStyle: TextStyle(
                                      fontSize: 12.0,
                                      color: Colors.grey[700],
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                        width: 2.0,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                      borderSide: BorderSide(
                                        color: Color(
                                            0xFFFB2056), // Color al enfocar el TextField
                                        width: 2.0,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 5.0,
                                        horizontal:
                                            10.0), // Reducir aún más la altura
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(fontSize: 14.0),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Container(
                                height: 35, // Ajustar altura
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  border: Border.all(
                                      color: Colors.grey[300]!, width: 2.0),
                                  borderRadius: BorderRadius.circular(15.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 5,
                                      offset: Offset(0,
                                          2), // Sombra para darle profundidad
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: periodo,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        periodo = newValue!;
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
                                    }).toList(),
                                    icon: Icon(Icons.arrow_drop_down,
                                        color: Color(0xFFFB2056)),
                                    dropdownColor: Colors
                                        .white, // Fondo del menú desplegable
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(15.0),
                                  border: Border.all(
                                      color: Colors.grey[300]!, width: 2.0),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.0), // Ajustar altura
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<double>(
                                    hint: Text(
                                      'Elige una tasa de interés',
                                      style: TextStyle(fontSize: 12),
                                    ), // Se mostrará hasta que se seleccione algo
                                    isExpanded: true,
                                    value: tasaInteresMensualSeleccionada,
                                    onChanged: (double? newValue) {
                                      setState(() {
                                        tasaInteresMensualSeleccionada =
                                            newValue!;
                                      });
                                    },
                                    items: <double>[
                                      6.00,
                                      8.00,
                                      8.12,
                                      8.20,
                                      8.52,
                                      8.60,
                                      8.80,
                                      9.00,
                                      9.28
                                    ].map<DropdownMenuItem<double>>(
                                        (double value) {
                                      return DropdownMenuItem<double>(
                                        value: value,
                                        child: Text(
                                          '$value %',
                                          style: TextStyle(
                                              fontSize: 12.0,
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
                            SizedBox(width: 20),
                            Expanded(
                              child: Container(
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(15.0),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 2.0,
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10.0),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    hint: Text(
                                      'Elige un plazo',
                                      style: TextStyle(fontSize: 12),
                                    ), // Se mostrará hasta que se seleccione algo
                                    isExpanded: true,
                                    value: plazoSeleccionado,
                                    onChanged: (int? newValue) {
                                      setState(() {
                                        plazoSeleccionado = newValue;
                                      });
                                    },
                                    items: <int>[
                                      12,
                                      14,
                                      16
                                    ].map<DropdownMenuItem<int>>((int value) {
                                      return DropdownMenuItem<int>(
                                        value: value,
                                        child: Text(
                                          '$value semanas',
                                          style: TextStyle(
                                              fontSize: 12.0,
                                              color: Colors.black),
                                        ),
                                      );
                                    }).toList(),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: Color(0xFFFB2056),
                                    ),
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
                    flex: 4, // 3 partes del ancho
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
                              // Columna izquierda
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Capital ${periodo.toLowerCase()}: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(monto / plazoSemanas)}',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                  Text(
                                    'Interés Semanal: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(calculateInterest(monto, interesMensual, plazoSemanas) / plazoSemanas)}',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                  Text(
                                    'Pago ${periodo.toLowerCase()}: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(calculateWeeklyPayment(monto, interesMensual, plazoSemanas))}',
                                    style: TextStyle(fontSize: 12.0),
                                  ),
                                ],
                              ),
                              SizedBox(width: 20), // Espacio entre las columnas
                              // Columna derecha
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
    if (fechaInicial.day <= 15) {
      return DateTime(fechaInicial.year, fechaInicial.month, 15);
    } else {
      return DateTime(fechaInicial.year, fechaInicial.month, 30);
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

    // Calcular capital y interés fijos por periodo
    double capitalSemanal =
        monto / plazoSemanas; // Capital fijo por semana o quincena
    double interesSemanal =
        interesTotal / plazoSemanas; // Interés fijo por semana o quincena

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

    // Calcular el pago total por cuota
    double pagoCuota =
        capitalSemanal + interesSemanal; // Total a pagar cada semana o quincena

    for (int i = 1; i <= plazoSemanas; i++) {
      // Actualizar el saldo restante después de pagar la cuota
      saldoRestante -= pagoCuota; // Resta el pago total por cuota
      totalPagado += pagoCuota; // Acumula el total pagado

      DateTime fechaPago =
          fechaInicio; // Asignar fechaInicio como valor por defecto

      // Ajuste condicional basado en el periodo seleccionado
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
        interesCantidad:
            interesSemanal, // Este es el interés fijo de cada periodo
        restante: saldoRestante,
        capitalSemanal: capitalSemanal, // Capital fijo por periodo
        interesSemanal: interesSemanal, // Interés fijo por periodo
        pagado: totalPagado, // Total pagado hasta el momento
      ));
    }
  }

  double calculateInterest(
      double monto, double interesMensual, int plazoSemanas) {
    double interesPeriodo = monto *
        (interesMensual / 100) *
        (plazoSemanas / (periodo == 'Semanal' ? 4.0 : 2.0));
    return interesPeriodo;
  }

  double calculateWeeklyPayment(
      double monto, double interesMensual, int plazoSemanas) {
    double total = calculateTotal(monto, interesMensual, plazoSemanas);
    return total / plazoSemanas;
  }

  double calculateTotal(double monto, double interesMensual, int plazoSemanas) {
    return monto + calculateInterest(monto, interesMensual, plazoSemanas);
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
