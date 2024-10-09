import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/custom_app_bar.dart';
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

  bool isGrupalSelected = true;

  final TextEditingController montoController = TextEditingController();
  final TextEditingController plazoController = TextEditingController();
  final TextEditingController interesController = TextEditingController();
  String periodo = 'Semanal';
  double monto = 0.0;
  double interesMensual = 0.0;
  int plazoSemanas = 0;
  DateTime? fechaSeleccionada;

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

  Widget filaTitulo(context) {
    return Container(
      padding: EdgeInsets.only(right: 10, left: 10, top: 0, bottom: 10),
      child: Row(
        children: <Widget>[
          Spacer(), // Espacio flexible para empujar los ChoiceChip a la derecha
          SizedBox(
            child: ChoiceChip(
              labelPadding: EdgeInsets.all(0),
              label: Text(
                'Grupal',
                style: TextStyle(
                    color: isGrupalSelected
                        ? Colors.white
                        : Color(
                            0xFFFB2056), // Cambia el color del texto según la selección
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
              selected: isGrupalSelected,
              onSelected: (isSelected) {
                setState(() {
                  isGrupalSelected = true;
                });
              },
              backgroundColor:
                  Colors.white, // Color del chip cuando no está seleccionado
              selectedColor:
                  Color(0xFFFB2056), // Color del chip cuando está seleccionado
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    15.0), // Bordes redondeados para un diseño moderno
                side: BorderSide(
                  color: Color(0xFFFB2056), // Borde del chip
                  width: 2.0, // Ancho del borde
                ),
              ),
              elevation: 5.0, // Sombras para dar efecto de profundidad
              pressElevation: 10.0, // Elevación al presionar
            ),
          ),
          SizedBox(width: 10), // Espacio entre los ChoiceChips
          /* ChoiceChip(
            label: Text('Individual'),
            selected:
                !isGrupalSelected, // Puedes ajustar este valor según el estado
            onSelected: (isSelected) {
              // Acción cuando se selecciona el chip
              setState(() {
                isGrupalSelected = false;
              });
            },
          ), */
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
              ),
              child: /* isGrupalSelected ?  */
                  simuladorGrupal() /* : simuladorIndividual(), */
              ),
        ),
      ),
    );
  }

  Widget simuladorGrupal() {
    double parseAmount(String text) {
      String cleanedText = text.replaceAll(',', '');
      return double.tryParse(cleanedText) ?? 0.0;
    }

    void recalcular() {
      setState(() {
        monto = parseAmount(montoController.text);
        interesMensual = double.tryParse(interesController.text) ?? 0.0;
        plazoSemanas = int.tryParse(plazoController.text) ?? 0;
        generarTablaAmortizacion();
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
                    flex: 2,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: montoController,
                                decoration: InputDecoration(
                                  labelText: 'Monto',
                                  labelStyle: TextStyle(
                                    fontSize: 14.0,
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
                                ),
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 14.0),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: TextField(
                                controller: plazoController,
                                decoration: InputDecoration(
                                  labelText: 'Plazo ($periodo)',
                                  labelStyle: TextStyle(
                                    fontSize: 14.0,
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
                                      color: Color(0xFFFB2056),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 14.0),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
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
                                            style: TextStyle(fontSize: 14.0)),
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
                            SizedBox(width: 20),
                            Expanded(
                              child: TextField(
                                controller: interesController,
                                decoration: InputDecoration(
                                  labelText: 'Tasa de interés mensual (%)',
                                  labelStyle: TextStyle(
                                    fontSize: 14.0,
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
                                      color: Color(0xFFFB2056),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 14.0),
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
                                  style: TextStyle(fontSize: 14.0),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            if (fechaSeleccionada != null)
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy', 'es')
                                    .format(fechaSeleccionada!),
                                style: TextStyle(
                                    fontSize: 14.0, color: Colors.grey[700]),
                              ),
                            Spacer(),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  // Limpiar los campos del formulario
                                  montoController.clear();
                                  plazoController.clear();
                                  interesController.clear();
                                  periodo =
                                      'Semanal'; // Restablecer el valor predeterminado del dropdown
                                  fechaSeleccionada =
                                      null; // Restablecer la fecha seleccionada
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
                                  style: TextStyle(fontSize: 14.0),
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
                    child: Container(
                      margin: EdgeInsets.only(bottom: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Resumen:',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.bold), // Ajuste de tamaño
                          ),
                          Text(
                              'Monto a prestar: \$${NumberFormat.decimalPattern('es').format(monto).replaceAll('.', ',')}',
                              style: TextStyle(fontSize: 12.0)),
                          Text(
                              'Intereses Totales: \$${NumberFormat.decimalPattern('es').format(calculateInterest(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}',
                              style: TextStyle(fontSize: 12.0)),
                          Text(
                              'Pago ${periodo.toLowerCase()}: \$${NumberFormat.decimalPattern('es').format(calculateWeeklyPayment(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}',
                              style: TextStyle(fontSize: 12.0)),
                          Text(
                              'Interés ${periodo.toLowerCase()}: ${(interesMensual / (periodo == 'Semanal' ? 4.0 : 2.0)).toStringAsFixed(2)}%',
                              style: TextStyle(fontSize: 12.0)),
                          SizedBox(height: 10),
                          Text(
                              'Total: \$${NumberFormat.decimalPattern('es').format(calculateTotal(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}',
                              style: TextStyle(fontSize: 12.0)),
                          SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Color(0xFFFB2056),
                                ),
                                onPressed: recalcular,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Calcular',
                                      style: TextStyle(
                                          fontSize: 12.0)), // Ajuste de tamaño
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
                              style: TextStyle(
                                  fontSize: 12.0))), // Ajuste de tamaño
                      DataColumn(
                          label: Text('Fecha de Pago',
                              style: TextStyle(
                                  fontSize: 12.0))), // Ajuste de tamaño
                      DataColumn(
                          label: Text('Pago por Cuota',
                              style: TextStyle(
                                  fontSize: 12.0))), // Ajuste de tamaño
                      DataColumn(
                          label: Text('Restante',
                              style: TextStyle(
                                  fontSize: 12.0))), // Ajuste de tamaño
                    ],
                    rows: tablaAmortizacion.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item.numero.toString(),
                            style:
                                TextStyle(fontSize: 12.0))), // Ajuste de tamaño
                        DataCell(Text(
                            item.numero == 0
                                ? ''
                                : DateFormat('dd/MM/yyyy', 'es')
                                    .format(item.fecha)
                                    .replaceAll('.', ','),
                            style:
                                TextStyle(fontSize: 12.0))), // Ajuste de tamaño
                        DataCell(Text(
                            item.numero == 0
                                ? ''
                                : '\$${NumberFormat.decimalPattern('es').format(item.pagoCuota).replaceAll('.', ',')}',
                            style:
                                TextStyle(fontSize: 12.0))), // Ajuste de tamaño
                        DataCell(Text(
                            '\$${NumberFormat.decimalPattern('es').format(item.restante).replaceAll('.', ',')}',
                            style:
                                TextStyle(fontSize: 12.0))), // Ajuste de tamaño
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

  void generarTablaAmortizacion() {
    tablaAmortizacion.clear();
    double saldoRestante = calculateTotal(monto, interesMensual, plazoSemanas);
    double interesTotal =
        calculateInterest(monto, interesMensual, plazoSemanas);
    DateTime fechaInicio = fechaSeleccionada ?? DateTime.now();

    // Primera fila para el desembolso inicial
    tablaAmortizacion.add(AmortizacionItem(
      numero: 0,
      fecha: fechaInicio,
      pagoCuota: 0.0,
      interesPorcentaje: 0.0,
      interesCantidad: interesTotal,
      restante: saldoRestante,
    ));

    double pagoCuota =
        calculateWeeklyPayment(monto, interesMensual, plazoSemanas);

    for (int i = 1; i <= plazoSemanas; i++) {
      double pagoInteres = saldoRestante *
          (interesMensual / 100) /
          (periodo == 'Semanal' ? 4.0 : 2.0);
      saldoRestante -= pagoCuota;

      DateTime fechaPago =
          fechaInicio.add(Duration(days: (periodo == 'Semanal' ? 7 : 14) * i));

      tablaAmortizacion.add(AmortizacionItem(
        numero: i,
        fecha: fechaPago,
        pagoCuota: pagoCuota,
        interesPorcentaje:
            (interesMensual / (periodo == 'Semanal' ? 4.0 : 2.0)),
        interesCantidad: pagoInteres,
        restante: saldoRestante,
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

  AmortizacionItem({
    required this.numero,
    required this.fecha,
    required this.pagoCuota,
    required this.interesPorcentaje,
    required this.interesCantidad,
    required this.restante,
  });
}
