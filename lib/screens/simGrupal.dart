import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:money_facil/formateador.dart';

class simuladorGrupal extends StatefulWidget {
  @override
  _simuladorGrupalState createState() => _simuladorGrupalState();
}

class _simuladorGrupalState extends State<simuladorGrupal> {
  int numeroUsuarios = 1;
  List<TextEditingController> montoPorUsuarioControllers = [];
  String frecuenciaPrestamo = 'Semanal';
  double monto = 0.0;
  final TextEditingController plazoController = TextEditingController();
  final TextEditingController montoController = TextEditingController();
  final TextEditingController interesController = TextEditingController();
  double tasaInteresMensual = 0.0;
  int plazoSemanas = 0;
  DateTime? fechaSeleccionada;
  int?
      plazoSeleccionado; // Cambia de 'int' a 'int?' para permitir valores nulos
  double? tasaInteresMensualSeleccionada;

  List<UsuarioPrestamo> listaUsuarios = [];

  // Define un ScrollController en la clase de tu widget.
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _inicializarMontosUsuarios();
  }

  void _inicializarMontosUsuarios() {
    montoPorUsuarioControllers =
        List.generate(numeroUsuarios, (index) => TextEditingController());
  }

  void _actualizarNumeroUsuarios(int nuevoNumero) {
    setState(() {
      numeroUsuarios = nuevoNumero;
      _inicializarMontosUsuarios();
    });
  }

  double parseAmount(String text) {
    String cleanedText = text.replaceAll(',', '');
    return double.tryParse(cleanedText) ?? 0.0;
  }

  void recalcular() {
    setState(() {
      monto = parseAmount(montoController.text);
      //tasaInteresMensual = double.tryParse(interesController.text) ?? 0.0;
      plazoSemanas = plazoSeleccionado ?? 0; // Usar la opción seleccionada
      tasaInteresMensual = tasaInteresMensualSeleccionada ?? 0;

      // Para depuración
      print(
          'Monto: $monto, Tasa de Interés: $tasaInteresMensual, Plazo en Semanas: $plazoSemanas');
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();

    for (var controller in montoPorUsuarioControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> fechasDePago =
        generarFechasDePago(fechaSeleccionada ?? DateTime.now(), plazoSemanas);

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row para el formulario y el recuadro verde
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  // Formulario con flex 6
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Monto Total y Tasa de Interés en columnas
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 35, // Ajustar altura
                                    child: TextField(
                                      controller: montoController,
                                      decoration: InputDecoration(
                                        labelText: 'Monto Total',
                                        labelStyle: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700]),
                                        filled: true,
                                        fillColor: Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(15.0),
                                          borderSide: BorderSide(
                                              color: Colors.grey[300]!,
                                              width: 2.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(15.0),
                                          borderSide: BorderSide(
                                              color: Color(0xFFFB2056),
                                              width: 2.0),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 5.0, horizontal: 10.0),
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(fontSize: 12.0),
                                      onChanged: (value) {
                                        // Llama a la función de formateo directamente aquí
                                        String formatted = formatMonto(value);
                                        montoController.value =
                                            TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(
                                              offset: formatted.length),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Container(
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
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
                                ],
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 35,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 0),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                                color: Colors.grey[300]!,
                                                width: 2.0),
                                            borderRadius:
                                                BorderRadius.circular(15.0),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.1),
                                                blurRadius: 5,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: frecuenciaPrestamo,
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  frecuenciaPrestamo =
                                                      newValue!;
                                                });
                                              },
                                              items: <String>[
                                                'Semanal',
                                              ].map<DropdownMenuItem<String>>(
                                                  (String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(value,
                                                      style: TextStyle(
                                                          fontSize: 12.0,
                                                          color: Colors.black)),
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
                                  Container(
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15.0),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 2.0,
                                      ),
                                    ),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10.0),
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
                                        items: <int>[12, 14, 16]
                                            .map<DropdownMenuItem<int>>(
                                                (int value) {
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
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),

                        // Cantidad de usuarios y montos por usuario
                        // Tu Row con los TextFields formateados
                        Row(
                          children: [
                            Text('Cantidad de usuarios:',
                                style: TextStyle(fontSize: 12)),
                            SizedBox(width: 10),
                            DropdownButton<int>(
                              value: numeroUsuarios,
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  _actualizarNumeroUsuarios(newValue);
                                }
                              },
                              items: List<DropdownMenuItem<int>>.generate(
                                12,
                                (index) => DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text('${index + 1}',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Listener(
                                onPointerSignal: (pointerSignal) {
                                  if (pointerSignal is PointerScrollEvent) {
                                    _scrollController.jumpTo(
                                      _scrollController.offset +
                                          pointerSignal.scrollDelta.dy,
                                    );
                                  }
                                },
                                child: SizedBox(
                                  width: 100,
                                  child: Scrollbar(
                                    controller: _scrollController,
                                    thumbVisibility: true,
                                    thickness: 8.0,
                                    radius: Radius.circular(10),
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      scrollDirection: Axis.horizontal,
                                      physics: ClampingScrollPhysics(),
                                      child: Row(
                                        children: List.generate(numeroUsuarios,
                                            (index) {
                                          return Container(
                                            height: 55,
                                            width: 150,
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 5),
                                            padding: EdgeInsets.symmetric(
                                                vertical: 10),
                                            child: TextField(
                                              controller:
                                                  montoPorUsuarioControllers[
                                                      index],
                                              textAlignVertical:
                                                  TextAlignVertical.center,
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Usuario ${index + 1}',
                                                labelStyle: TextStyle(
                                                    fontSize: 12.0,
                                                    color: Colors.grey[700]),
                                                filled: true,
                                                fillColor: Colors.white,
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          15.0),
                                                  borderSide: BorderSide(
                                                      color: Colors.grey[300]!,
                                                      width: 2.0),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          15.0),
                                                  borderSide: BorderSide(
                                                      color: Color(0xFFFB2056),
                                                      width: 2.0),
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        vertical: 15.0,
                                                        horizontal: 10.0),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              style: TextStyle(fontSize: 12.0),
                                              inputFormatters: [
                                                NumberFormatter(), // Aplica el formateo de comas
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
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

                                  // Limpiar los controladores de los montos individuales
                                  for (var controller
                                      in montoPorUsuarioControllers) {
                                    controller.clear();
                                  }

                                  // Restablecer las variables clave
                                  monto = 0.0;
                                  tasaInteresMensualSeleccionada =
                                      null; // O el valor predeterminado
                                  plazoSeleccionado =
                                      null; // O el valor predeterminado
                                  listaUsuarios
                                      .clear(); // Limpiar la tabla de usuarios
                                  fechaSeleccionada =
                                      null; // Limpiar la fecha seleccionada

                                  // Si tienes otras listas o tablas, también las puedes limpiar aquí
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
                                    horizontal: 20, vertical: 0),
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
                  // Recuadro verde a la derecha con flex 4
                  SizedBox(width: 20),
                  // Recuadro verde a la derecha con flex 4
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        //color: Colors.green,
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Resumen:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'Monto a prestar: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(monto)}',
                            style:
                                TextStyle(fontSize: 12.0, color: Colors.black),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Columna izquierda
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Capital Semanal
                                  Text(
                                    'Capital Semanal: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(monto / plazoSemanas)}',
                                    style: TextStyle(
                                        fontSize: 12.0, color: Colors.black),
                                  ),
                                  // Interés Semanal
                                  Text(
                                    'Interés Semanal: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(monto * (tasaInteresMensual / 4 / 100))}', // Asegúrate de dividir la tasa por 100
                                    style: TextStyle(
                                        fontSize: 12.0, color: Colors.black),
                                  ),
                                  // Pago Semanal
                                  Text(
                                    'Pago Semanal: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format((monto / plazoSemanas) + (monto * (tasaInteresMensual / 4 / 100)))}',
                                    style: TextStyle(
                                        fontSize: 12.0, color: Colors.black),
                                  ),
                                ],
                              ),
                              SizedBox(width: 20), // Espacio entre las columnas
                              // Columna derecha
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Interés Total
                                  Text(
                                    'Interés Total: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(monto * (tasaInteresMensual / 4 / 100) * plazoSemanas)}',
                                    style: TextStyle(
                                        fontSize: 12.0, color: Colors.black),
                                  ),
                                  // Interés Semanal (%)
                                  Text(
                                    'Interés Semanal: ${(tasaInteresMensual / 4).toStringAsFixed(2)}%',
                                    style: TextStyle(
                                        fontSize: 12.0, color: Colors.black),
                                  ),
                                  // Interés Global (%)
                                  Text(
                                    'Interés Global: ${(tasaInteresMensual / 4 * plazoSemanas).toStringAsFixed(2)}%',
                                    style: TextStyle(
                                        fontSize: 12.0, color: Colors.black),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Total a Recuperar: \$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(monto + (monto * (tasaInteresMensual / 4 / 100) * plazoSemanas))}',
                              style: TextStyle(
                                  fontSize: 12.0, color: Colors.black),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                // Primero actualizamos las variables clave que afectan los cálculos
                                recalcular();

                                // Bandera para determinar si hay errores
                                bool hayErrores = false;

                                // Verificar si el plazo no ha sido seleccionado
                                if (plazoSemanas == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Error: Debes seleccionar el plazo de semanas.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  hayErrores =
                                      true; // Marcamos que hay un error
                                }

                                // Verificar si la tasa de interés no ha sido seleccionada
                                if (tasaInteresMensual == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Error: Debes seleccionar una tasa de interés.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  hayErrores =
                                      true; // Marcamos que hay un error
                                }

                                // Si hay errores, salimos de la ejecución sin calcular la tabla
                                if (hayErrores) return;

                                // Función para limpiar las comas y convertir a número
                                double parseAmountWithoutCommas(String text) {
                                  // Elimina las comas y convierte el texto a double
                                  String cleanText = text.replaceAll(',', '');
                                  return double.tryParse(cleanText) ?? 0.0;
                                }

                                // Calculamos el total del préstamo ingresado por cada usuario
                                double totalPrestamo =
                                    montoPorUsuarioControllers.fold(
                                  0.0,
                                  (sum, controller) =>
                                      sum +
                                      parseAmountWithoutCommas(controller
                                          .text), // Limpiamos las comas
                                );

                                // Obtenemos el monto total ingresado por el usuario
                                double montoTotal = parseAmountWithoutCommas(
                                    montoController
                                        .text); // Limpiamos las comas

                                // Imprimir cada monto ingresado por los usuarios en consola
                                for (int i = 0;
                                    i < montoPorUsuarioControllers.length;
                                    i++) {
                                  double montoUsuario =
                                      parseAmountWithoutCommas(
                                          montoPorUsuarioControllers[i].text);
                                  print(
                                      'Monto del Usuario ${i + 1}: \$${montoUsuario.toStringAsFixed(2)}');
                                }

                                // Verificamos si la suma coincide con el monto total
                                if (totalPrestamo != montoTotal) {
                                  // Mostrar un SnackBar con un mensaje de error
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Error: La suma de los montos individuales (\$$totalPrestamo) no coincide con el monto total (\$$montoTotal).'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } else {
                                  // Si coinciden, calculamos la tabla
                                  listaUsuarios = calcularTabla();

                                  // Mostrar un SnackBar con el total del préstamo
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Total del préstamo grupal: \$${totalPrestamo.toStringAsFixed(2)}'),
                                    ),
                                  );
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Color(0xFFFB2056),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('Calcular',
                                  style: TextStyle(fontSize: 12.0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Divider(thickness: 2, color: Colors.grey[300]),
            // Mostrar la tabla de resultados si hay datos
            if (listaUsuarios.isNotEmpty)
              Expanded(
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tabla de resultados
                  Expanded(
                    flex: 3, // Define cuánto espacio ocupará la tabla
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical, // Desplazamiento vertical
                      child: TablaResultados(listaUsuarios: listaUsuarios),
                    ),
                  ),
                  // Relleno para mantener espacio entre tabla y recuadro verde
                  SizedBox(width: 20),
                  // Recuadro verde a la derecha
                  CustomTable(
                      title: 'Fechas de Pago', fechasDePago: fechasDePago),
                ],
              )),
          ],
        ));
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

  // Función que limpia las comas y convierte el texto a double
double parseAmountWithoutCommas(String text) {
  // Elimina las comas y convierte el texto a double
  String cleanText = text.replaceAll(',', '');  // Elimina las comas
  return double.tryParse(cleanText) ?? 0.0;     // Convierte a double o devuelve 0.0 si falla
}


  List<UsuarioPrestamo> calcularTabla() {
  List<UsuarioPrestamo> listaUsuarios = [];

  // Interés semanal calculado a partir del interés mensual dividido entre 4 semanas
  double interesSemanal = tasaInteresMensual / 4;

  int plazo = plazoSeleccionado ?? 0;

  if (plazo <= 0) {
    print('El plazo debe ser mayor que 0');
    return listaUsuarios;
  }

  double totalMontoIndividual = 0.0;
  double totalCapitalSemanal = 0.0;
  double totalInteresIndividualSemanal = 0.0;
  double totalTotalIntereses = 0.0;
  double totalPagoIndSemanal = 0.0;
  double totalPagoIndTotal = 0.0;
  double totalCapitalTotal = 0.0;  // Nuevo acumulador para total capital

  for (var controller in montoPorUsuarioControllers) {
    double montoIndividual = parseAmountWithoutCommas(controller.text);

    double capitalSemanal = montoIndividual / plazo;
    double interesIndividualSemanal = (montoIndividual * (interesSemanal / 100));
    double totalIntereses = interesIndividualSemanal * plazo;
    double pagoIndSemanal = capitalSemanal + interesIndividualSemanal;
    double pagoIndTotal = pagoIndSemanal * plazo;

    // Nuevo cálculo para el total capital (capital + intereses)
    double totalCapital = capitalSemanal * plazo;

    listaUsuarios.add(UsuarioPrestamo(
      montoIndividual: montoIndividual,
      capitalSemanal: capitalSemanal,
      interesIndividualSemanal: interesIndividualSemanal,
      totalIntereses: totalIntereses,
      pagoIndSemanal: pagoIndSemanal,
      pagoIndTotal: pagoIndTotal,
      totalCapital: totalCapital,  // Agregar este valor al objeto
    ));

    totalMontoIndividual += montoIndividual;
    totalCapitalSemanal += capitalSemanal;
    totalInteresIndividualSemanal += interesIndividualSemanal;
    totalTotalIntereses += totalIntereses;
    totalPagoIndSemanal += pagoIndSemanal;
    totalPagoIndTotal += pagoIndTotal;
    totalCapitalTotal += totalCapital;  // Acumular el total capital
  }

  listaUsuarios.add(UsuarioPrestamo(
    montoIndividual: totalMontoIndividual,
    capitalSemanal: totalCapitalSemanal,
    interesIndividualSemanal: totalInteresIndividualSemanal,
    totalIntereses: totalTotalIntereses,
    pagoIndSemanal: totalPagoIndSemanal,
    pagoIndTotal: totalPagoIndTotal,
    totalCapital: totalCapitalTotal,  // Agregar total capital a la fila de totales
  ));

  return listaUsuarios;
}



}

// Nuevo widget para mostrar la tabla
class TablaResultados extends StatelessWidget {
  final List<UsuarioPrestamo> listaUsuarios;

  const TablaResultados({Key? key, required this.listaUsuarios})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey, width: 1),
            ),
            dataRowHeight: 30,
            columnSpacing: 0,
            columns: const [
              DataColumn(
                  label: Text('Integrantes', style: TextStyle(fontSize: 12))),
              DataColumn(
                  label: Text('Monto individual', style: TextStyle(fontSize: 12))),
              DataColumn(
                  label: Text('Capital Semanal', style: TextStyle(fontSize: 12))),
              DataColumn(
                  label: Text('Interés Semanal', style: TextStyle(fontSize: 12))),
                  DataColumn(
                  label: Text('Total Capital', style: TextStyle(fontSize: 12))), // Nueva columna
              DataColumn(
                  label: Text('Total Intereses', style: TextStyle(fontSize: 12))),
              DataColumn(
                  label: Text('Pago Ind. Sem.', style: TextStyle(fontSize: 12))),
              DataColumn(
                  label: Text('Pago Ind. Total', style: TextStyle(fontSize: 12))),
              
            ],
            rows: List<DataRow>.generate(listaUsuarios.length, (index) {
              final usuario = listaUsuarios[index];

              bool isTotalRow = index == listaUsuarios.length - 1;

              return DataRow(cells: [
                DataCell(Text(
                  isTotalRow ? 'Total' : 'Usuario ${index + 1}',
                  style: TextStyle(
                      fontWeight:
                          isTotalRow ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12),
                )),
                DataCell(Text(
                  '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(usuario.montoIndividual)}',
                  style: TextStyle(
                      fontWeight:
                          isTotalRow ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12),
                )),
                DataCell(Text(
                  '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(usuario.capitalSemanal)}',
                  style: TextStyle(
                      fontWeight:
                          isTotalRow ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12),
                )),
                DataCell(Text(
                  '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(usuario.interesIndividualSemanal)}',
                  style: TextStyle(
                      fontWeight:
                          isTotalRow ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12),
                )),
                DataCell(Text(
                  '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(usuario.totalCapital)}',  // Nueva celda
                  style: TextStyle(
                      fontWeight:
                          isTotalRow ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12),
                )),
                DataCell(Text(
                  '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(usuario.totalIntereses)}',
                  style: TextStyle(
                      fontWeight:
                          isTotalRow ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12),
                )),
                DataCell(Text(
                  '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(usuario.pagoIndSemanal)}',
                  style: TextStyle(
                      fontWeight:
                          isTotalRow ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12),
                )),
                DataCell(Text(
                  '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(usuario.pagoIndTotal)}',
                  style: TextStyle(
                      fontWeight:
                          isTotalRow ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12),
                )),
                
              ]);
            }),
          ),
        ),
      ),
    );
  }
}


List<String> generarFechasDePago(DateTime fechaInicial, int semanas) {
  List<String> fechas = [];
  for (int i = 0; i <= semanas; i++) {
    // Añadir una semana a la fecha inicial por cada iteración
    DateTime fechaPago = fechaInicial.add(Duration(days: 7 * i));
    fechas.add("${fechaPago.day}/${fechaPago.month}/${fechaPago.year}");
  }
  return fechas;
}

class CustomTable extends StatelessWidget {
  final String title;
  final List<String> fechasDePago;

  CustomTable({required this.title, required this.fechasDePago});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Container(
        height: double.infinity, // Se ajusta al espacio disponible
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFB2056),
                ),
              ),
              SizedBox(height: 10),
              // Tabla dentro del widget
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey, width: 1),
                ),
                children: [
                  TableRow(
                    children: _buildTableHeader(['Semana', 'Fecha de Pago']),
                  ),
                  ..._buildTableRows(fechasDePago),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTableHeader(List<String> headers) {
    return headers
        .map((header) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                header,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ))
        .toList();
  }

  List<TableRow> _buildTableRows(List<String> fechas) {
    return List<TableRow>.generate(fechas.length, (index) {
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              style: TextStyle(fontSize: 12),
              "Semana $index", // Aquí empieza desde Semana 0
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              style: TextStyle(fontSize: 12),
              fechas[index],
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    });
  }
}

// Modelo de datos
class UsuarioPrestamo {
  final double montoIndividual;
  final double capitalSemanal;
  final double interesIndividualSemanal;
  final double  totalCapital;
  final double totalIntereses;
  final double pagoIndSemanal;
  final double pagoIndTotal;

  UsuarioPrestamo({
    required this.montoIndividual,
    required this.capitalSemanal,
    required this.interesIndividualSemanal,
    required this.totalCapital,
    required this.totalIntereses,
    required this.pagoIndSemanal,
    required this.pagoIndTotal,
  });
}

// Formato para el texto con comas
class NumberFormatter extends TextInputFormatter {
  final NumberFormat numberFormat = NumberFormat("#,###");

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Elimina las comas antes de hacer cualquier cálculo
    String valueWithoutCommas = newValue.text.replaceAll(',', '');
    double parsedValue = double.tryParse(valueWithoutCommas) ?? 0;

    // Formatea el número con comas
    String formattedValue = numberFormat.format(parsedValue);

    // Devuelve el nuevo valor con formato
    return TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }
}
