import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      tasaInteresMensual = double.tryParse(interesController.text) ?? 0.0;
      plazoSemanas = int.tryParse(plazoController.text) ?? 0;

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
                    flex: 7,
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
                                    height: 40, // Ajustar altura
                                    child: TextField(
                                      controller: montoController,
                                      decoration: InputDecoration(
                                        labelText: 'Monto Total',
                                        labelStyle: TextStyle(
                                            fontSize: 14.0,
                                            color: Colors.grey[700]),
                                        filled: true,
                                        fillColor: Colors.grey[100],
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
                                      style: TextStyle(fontSize: 14.0),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Container(
                                    height: 40, // Ajustar altura
                                    child: TextField(
                                      controller: interesController,
                                      onChanged: (value) {
                                        tasaInteresMensual =
                                            double.tryParse(value) ?? 0.0;
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Tasa de Interés (%)',
                                        labelStyle: TextStyle(
                                            fontSize: 14.0,
                                            color: Colors.grey[700]),
                                        filled: true,
                                        fillColor: Colors.grey[100],
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
                                      style: TextStyle(fontSize: 14.0),
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
                                          height: 40,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 0),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
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
                                                'Quincenal'
                                              ].map<DropdownMenuItem<String>>(
                                                  (String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(value,
                                                      style: TextStyle(
                                                          fontSize: 14.0)),
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
                                    height: 40, // Ajustar altura
                                    child: TextField(
                                      controller: plazoController,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Plazo (en semanas o quincenas)',
                                        labelStyle: TextStyle(
                                            fontSize: 14.0,
                                            color: Colors.grey[700]),
                                        filled: true,
                                        fillColor: Colors.grey[100],
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
                                      style: TextStyle(fontSize: 14.0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),

                        // Cantidad de usuarios y montos por usuario
                        Row(
                          children: [
                            Text('Cantidad de usuarios:',
                                style: TextStyle(fontSize: 14)),
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
                                      style: TextStyle(fontSize: 14)),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Listener(
                                onPointerSignal: (pointerSignal) {
                                  if (pointerSignal is PointerScrollEvent) {
                                    // Deslizar horizontalmente usando la rueda del mouse.
                                    _scrollController.jumpTo(
                                      _scrollController.offset +
                                          pointerSignal.scrollDelta.dy,
                                    );
                                  }
                                },
                                child: SizedBox(
                                  width:
                                      100, // Ajusta el ancho de la barra de desplazamiento aquí.
                                  child: Scrollbar(
                                    controller:
                                        _scrollController, // Conecta el ScrollController al Scrollbar.
                                    thumbVisibility:
                                        true, // Para que la barra de desplazamiento siempre esté visible.
                                    thickness:
                                        8.0, // Ajusta el grosor de la barra de desplazamiento aquí.
                                    radius: Radius.circular(
                                        10), // Opcional: agregar esquinas redondeadas.
                                    child: SingleChildScrollView(
                                      controller:
                                          _scrollController, // Conecta el ScrollController al SingleChildScrollView.
                                      scrollDirection: Axis.horizontal,
                                      physics:
                                          ClampingScrollPhysics(), // Física adecuada para escritorio.
                                      child: Row(
                                        children: List.generate(numeroUsuarios,
                                            (index) {
                                          return Container(
                                            height:
                                                60, // Aumenta la altura del contenedor para mayor espacio.
                                            width:
                                                150, // Ancho mínimo para los campos de texto.
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 5),
                                            padding: EdgeInsets.symmetric(
                                                vertical:
                                                    10), // Agrega padding adicional.
                                            child: TextField(
                                              controller:
                                                  montoPorUsuarioControllers[
                                                      index],
                                              textAlignVertical: TextAlignVertical
                                                  .center, // Alinea el texto verticalmente.
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Usuario ${index + 1}',
                                                labelStyle: TextStyle(
                                                    fontSize: 14.0,
                                                    color: Colors.grey[700]),
                                                filled: true,
                                                fillColor: Colors.grey[100],
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
                                                        horizontal:
                                                            10.0), // Ajusta el padding aquí.
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              style: TextStyle(fontSize: 14.0),
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
                                  monto = 0.0;
                                  /*  interesMensual = 0.0;
                                  periodo =
                                      'Semanal'; // Restablecer el valor predeterminado del dropdown
                                  fechaSeleccionada =
                                      null; // Restablecer la fecha seleccionada
                                  tablaAmortizacion.clear(); */
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
                  // Recuadro verde a la derecha con flex 4
                  SizedBox(width: 20),
                  // Recuadro verde a la derecha con flex 4
                  Expanded(
                    flex: 3,
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
                              fontSize: 14,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    listaUsuarios = calcularTabla();
                                  });

                                  double totalPrestamo =
                                      montoPorUsuarioControllers.fold(
                                    0.0,
                                    (sum, controller) =>
                                        sum +
                                        (double.tryParse(controller.text) ??
                                            0.0),
                                  );

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(
                                        'Total del préstamo grupal: \$${totalPrestamo.toStringAsFixed(2)}'),
                                  ));

                                  recalcular();
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Color(0xFFFB2056),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(15.0)),
                                ),
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
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: double
                          .infinity, // Permite que el contenedor se ajuste al espacio disponible
                      padding: EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        //color: Colors.green[100], // Fondo verde claro
                        border: Border.all(
                          color: Colors.grey, // Color del borde verde
                          width: 1.5, // Grosor del borde
                        ),
                        borderRadius:
                            BorderRadius.circular(10), // Bordes redondeados
                      ),
                      child: SingleChildScrollView(
                        scrollDirection:
                            Axis.vertical, // Desplazamiento vertical
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              'Recuadro verde',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFB2056),
                              ),
                            ),
                            SizedBox(height: 10),
                            // Tabla de ejemplo dentro del recuadro verde
                            Table(
                              border: TableBorder.all(color: Colors.grey),
                              children: [
                                // Cabecera de la tabla
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Header 1',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Header 2',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Header 3',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                ]),
                                // Filas de datos
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 1 Col 1',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 1 Col 2',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 1 Col 3',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ]),
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 2 Col 1',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 2 Col 2',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 2 Col 3',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ]),
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 3 Col 1',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 3 Col 2',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 3 Col 3',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ]),
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 4 Col 1',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 4 Col 2',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 4 Col 3',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ]),
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 5 Col 1',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 5 Col 2',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 5 Col 3',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ]),
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 6 Col 1',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 6 Col 2',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Row 6 Col 3',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ]),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
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

  List<UsuarioPrestamo> calcularTabla() {
    List<UsuarioPrestamo> listaUsuarios = [];

    // Interés semanal calculado a partir del interés mensual dividido entre 4 semanas
    double interesSemanal = tasaInteresMensual / 4;

    // Supongamos que el plazo es en semanas (esto debe ser ingresado por el usuario)
    int? plazo = int.tryParse(plazoController.text);

    // Variables para almacenar los totales
    double totalMontoIndividual = 0.0;
    double totalCapitalSemanal = 0.0;
    double totalInteresIndividualSemanal = 0.0;
    double totalTotalIntereses = 0.0;
    double totalPagoIndSemanal = 0.0;
    double totalPagoIndTotal = 0.0;

    for (var controller in montoPorUsuarioControllers) {
      double montoIndividual = double.tryParse(controller.text) ?? 0.0;

      // Calcular el capital semanal multiplicando el monto individual por el plazo
      double capitalSemanal = montoIndividual / plazo!;

      // Calcular el interés individual semanal
      double interesIndividualSemanal =
          (montoIndividual * (interesSemanal / 100));

      // Calcular el total de intereses multiplicando el interés semanal por el plazo
      double totalIntereses = interesIndividualSemanal * plazo;

      // Calcular el pago individual semanal sumando el capital semanal y el interés semanal
      double pagoIndSemanal = capitalSemanal + interesIndividualSemanal;

      // Calcular el pago individual total multiplicando el pago semanal por el plazo
      double pagoIndTotal = pagoIndSemanal * plazo;

      // Agregar los valores a la lista de usuarios
      listaUsuarios.add(UsuarioPrestamo(
        montoIndividual: montoIndividual,
        capitalSemanal: capitalSemanal,
        interesIndividualSemanal: interesIndividualSemanal,
        totalIntereses: totalIntereses,
        pagoIndSemanal: pagoIndSemanal,
        pagoIndTotal: pagoIndTotal,
      ));

      // Sumar los totales
      totalMontoIndividual += montoIndividual;
      totalCapitalSemanal += capitalSemanal;
      totalInteresIndividualSemanal += interesIndividualSemanal;
      totalTotalIntereses += totalIntereses;
      totalPagoIndSemanal += pagoIndSemanal;
      totalPagoIndTotal += pagoIndTotal;
    }

    // Agregar la fila de totales
    listaUsuarios.add(UsuarioPrestamo(
      montoIndividual: totalMontoIndividual,
      capitalSemanal: totalCapitalSemanal,
      interesIndividualSemanal: totalInteresIndividualSemanal,
      totalIntereses: totalTotalIntereses,
      pagoIndSemanal: totalPagoIndSemanal,
      pagoIndTotal: totalPagoIndTotal,
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
        scrollDirection: Axis.vertical, // Solo scroll vertical
        child: SizedBox(
          width: double
              .infinity, // Hace que la tabla ocupe todo el ancho disponible
          child: DataTable(
            columnSpacing: 0, // Espacio entre las columnas
            columns: const [
              DataColumn(
                  label: Text(
                'Integrantes',
                style: TextStyle(fontSize: 12),
              )),
              DataColumn(
                  label: Text(
                'Monto individual',
                style: TextStyle(fontSize: 12),
              )),
              DataColumn(
                  label: Text(
                'Capital Semanal',
                style: TextStyle(fontSize: 12),
              )),
              DataColumn(
                  label: Text(
                'Interés Ind. Sem.',
                style: TextStyle(fontSize: 12),
              )),
              DataColumn(
                  label: Text(
                'Total Intereses',
                style: TextStyle(fontSize: 12),
              )),
              DataColumn(
                  label: Text(
                'Pago Ind. Sem.',
                style: TextStyle(fontSize: 12),
              )),
              DataColumn(
                  label: Text(
                'Pago Ind. Total',
                style: TextStyle(fontSize: 12),
              )),
            ],
            rows: List<DataRow>.generate(listaUsuarios.length, (index) {
              final usuario = listaUsuarios[index];

              // Verifica si es la fila de totales
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

// Modelo de datos
class UsuarioPrestamo {
  final double montoIndividual;
  final double capitalSemanal;
  final double interesIndividualSemanal;
  final double totalIntereses;
  final double pagoIndSemanal;
  final double pagoIndTotal;

  UsuarioPrestamo({
    required this.montoIndividual,
    required this.capitalSemanal,
    required this.interesIndividualSemanal,
    required this.totalIntereses,
    required this.pagoIndSemanal,
    required this.pagoIndTotal,
  });
}
