import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/widgets/CardUserWidget.dart';

class SimuladorScreen extends StatefulWidget {
  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();

  final String username; // Agregar esta línea
  const SimuladorScreen({Key? key, required this.username}) : super(key: key);
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  List<Usuario> listausuarios = [];
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
    obtenerusuarios();
  }

  void obtenerusuarios() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response =
          await http.get(Uri.parse('https://api.escuelajs.co/api/v1/users'));
      if (response.statusCode == 200) {
        final parsedJson = json.decode(response.body);

        setState(() {
          listausuarios = (parsedJson as List)
              .map((item) => Usuario(
                    item['id'],
                    item['email'],
                    item['password'],
                    item['name'],
                  ))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          showErrorDialog = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        showErrorDialog = true;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEFF5FD),
      body: content(context),
    );
  }

  Widget content(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Container(
            // color: Colors.red,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: CardUserWidget(
                    username: widget.username,
                  ),
                ),
              ],
            ),
          ),
        ),
        filaTitulo(context),
        filaTabla(context),
      ],
    );
  }

  Widget filaTitulo(context) {
  return Container(
    color: Color(0xFFEFF5FD),
    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Simulador',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Spacer(), // Espacio flexible para empujar los ChoiceChip a la derecha
        ChoiceChip(
          label: Text('Grupal'),
          selected: isGrupalSelected, // Puedes ajustar este valor según el estado
          onSelected: (isSelected) {
            // Acción cuando se selecciona el chip
            setState(() {
              isGrupalSelected = true;
            });
          },
        ),
        SizedBox(width: 10), // Espacio entre los ChoiceChips
        ChoiceChip(
          label: Text('Individual'),
          selected: !isGrupalSelected, // Puedes ajustar este valor según el estado
          onSelected: (isSelected) {
            // Acción cuando se selecciona el chip
            setState(() {
              isGrupalSelected = false;
            });
          },
        ),
      ],
    ),
  );
}

  Widget filaTabla(BuildContext context) {
    return Expanded(
      child: Container(
        color: Color(0xFFEFF5FD),
        padding: EdgeInsets.all(20),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: isGrupalSelected ? simuladorGrupal(): simuladorIndividual(),
          ),
        ),
      ),
    );
  }

  Widget simuladorIndividual() {

    double parseAmount(String text) {
  // Reemplaza las comas con nada para convertir a un formato numérico válido
  String cleanedText = text.replaceAll(',', '');
  // Intenta convertir el texto a double
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
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Individual'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
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
                                decoration: InputDecoration(labelText: 'Monto'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: TextField(
                                controller: plazoController,
                                decoration: InputDecoration(
                                  labelText: 'Plazo ($periodo)',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 60,
                                padding: EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
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
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Container(
                                height: 60,
                                child: TextField(
                                  controller: interesController,
                                  decoration: InputDecoration(
                                    labelText: 'Tasa de interés mensual (%)',
                                  ),
                                  keyboardType: TextInputType.number,
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
                            SizedBox(width: 20),
                            if (fechaSeleccionada != null)
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy', 'es')
                                    .format(fechaSeleccionada!),
                                style: TextStyle(fontSize: 16.0),
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
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                              'Monto a prestar: \$${NumberFormat.decimalPattern('es').format(monto).replaceAll('.', ',')}'),
                          Text(
                              'Intereses Totales: \$${NumberFormat.decimalPattern('es').format(calculateInterest(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}'),
                          Text(
                              'Pago ${periodo.toLowerCase()}: \$${NumberFormat.decimalPattern('es').format(calculateWeeklyPayment(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}'),
                          Text(
                              'Interés ${periodo.toLowerCase()}: ${(interesMensual / (periodo == 'Semanal' ? 4.0 : 2.0)).toStringAsFixed(2)}%'),
                          SizedBox(height: 10),
                          Text(
                              'Total: \$${NumberFormat.decimalPattern('es').format(calculateTotal(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}'),
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
                                  child: Text('Calcular'),
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
          Divider(), // Añade el Divider aquí
          SizedBox(height: 20),
          if (tablaAmortizacion.isNotEmpty) ...[
            Text(
              'Tabla de Amortización:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('No. $periodo')),
                      DataColumn(label: Text('Fecha de Pago')),
                      DataColumn(label: Text('Pago por Cuota')),
                      DataColumn(label: Text('Restante')),
                    ],
                    rows: tablaAmortizacion.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item.numero.toString())),
                        DataCell(Text(item.numero == 0
                            ? ''
                            : DateFormat('dd/MM/yyyy', 'es').format(item.fecha).replaceAll('.', ','))),
                        DataCell(Text(item.numero == 0
                            ? ''
                            : '\$${NumberFormat.decimalPattern('es').format(item.pagoCuota).replaceAll('.', ',')}')),
                        DataCell(Text('\$${NumberFormat.decimalPattern('es').format(item.restante).replaceAll('.', ',')}')),

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


  Widget simuladorGrupal() {

    double parseAmount(String text) {
  // Reemplaza las comas con nada para convertir a un formato numérico válido
  String cleanedText = text.replaceAll(',', '');
  // Intenta convertir el texto a double
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
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
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
                                decoration: InputDecoration(labelText: 'Monto'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: TextField(
                                controller: plazoController,
                                decoration: InputDecoration(
                                  labelText: 'Plazo ($periodo)',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 60,
                                padding: EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
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
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Container(
                                height: 60,
                                child: TextField(
                                  controller: interesController,
                                  decoration: InputDecoration(
                                    labelText: 'Tasa de interés mensual (%)',
                                  ),
                                  keyboardType: TextInputType.number,
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
                            SizedBox(width: 20),
                            if (fechaSeleccionada != null)
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy', 'es')
                                    .format(fechaSeleccionada!),
                                style: TextStyle(fontSize: 16.0),
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
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                              'Monto a prestar: \$${NumberFormat.decimalPattern('es').format(monto).replaceAll('.', ',')}'),
                          Text(
                              'Intereses Totales: \$${NumberFormat.decimalPattern('es').format(calculateInterest(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}'),
                          Text(
                              'Pago ${periodo.toLowerCase()}: \$${NumberFormat.decimalPattern('es').format(calculateWeeklyPayment(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}'),
                          Text(
                              'Interés ${periodo.toLowerCase()}: ${(interesMensual / (periodo == 'Semanal' ? 4.0 : 2.0)).toStringAsFixed(2)}%'),
                          SizedBox(height: 10),
                          Text(
                              'Total: \$${NumberFormat.decimalPattern('es').format(calculateTotal(monto, interesMensual, plazoSemanas)).replaceAll('.', ',')}'),
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
                                  child: Text('Calcular'),
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
          Divider(), // Añade el Divider aquí
          SizedBox(height: 20),
          if (tablaAmortizacion.isNotEmpty) ...[
            Text(
              'Tabla de Amortización:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('No. $periodo')),
                      DataColumn(label: Text('Fecha de Pago')),
                      DataColumn(label: Text('Pago por Cuota')),
                      DataColumn(label: Text('Restante')),
                    ],
                    rows: tablaAmortizacion.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item.numero.toString())),
                        DataCell(Text(item.numero == 0
                            ? ''
                            : DateFormat('dd/MM/yyyy', 'es').format(item.fecha).replaceAll('.', ','))),
                        DataCell(Text(item.numero == 0
                            ? ''
                            : '\$${NumberFormat.decimalPattern('es').format(item.pagoCuota).replaceAll('.', ',')}')),
                        DataCell(Text('\$${NumberFormat.decimalPattern('es').format(item.restante).replaceAll('.', ',')}')),

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

class Usuario {
  final int id;
  final String email;
  final String password;
  final String name;

  Usuario(this.id, this.email, this.password, this.name);
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
