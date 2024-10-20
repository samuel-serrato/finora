import 'package:flutter/material.dart';

class simuladorGrupal extends StatefulWidget {
  @override
  _simuladorGrupalState createState() => _simuladorGrupalState();
}

class _simuladorGrupalState extends State<simuladorGrupal> {
  int numeroUsuarios = 1;
  List<TextEditingController> montoPorUsuarioControllers = [];
  String frecuenciaPrestamo = 'Semanal';
  double tasaInteres = 0.0;

  @override
  void initState() {
    super.initState();
    _inicializarMontosUsuarios();
  }

  void _inicializarMontosUsuarios() {
    montoPorUsuarioControllers = List.generate(numeroUsuarios, (index) => TextEditingController());
  }

  void _actualizarNumeroUsuarios(int nuevoNumero) {
    setState(() {
      numeroUsuarios = nuevoNumero;
      _inicializarMontosUsuarios();
    });
  }

  @override
  void dispose() {
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
          Text(
            'Simulador de Préstamo Grupal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),

          // Monto Total y Tasa de Interés en columnas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Columna izquierda
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto Total del Préstamo',
                      style: TextStyle(fontSize: 14),
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Monto Total',
                        labelStyle: TextStyle(fontSize: 14.0, color: Colors.grey[700]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 2.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide(color: Color(0xFFFB2056), width: 2.0),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14.0),
                    ),
                    SizedBox(height: 20),
                    // Tasa de Interés
                    Text('Tasa de Interés (%):', style: TextStyle(fontSize: 14)),
                    TextField(
                      onChanged: (value) {
                        tasaInteres = double.tryParse(value) ?? 0.0;
                      },
                      decoration: InputDecoration(
                        labelText: 'Tasa',
                        labelStyle: TextStyle(fontSize: 14.0, color: Colors.grey[700]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 2.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide(color: Color(0xFFFB2056), width: 2.0),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14.0),
                    ),
                  ],
                ),
              ),

              // Columna derecha
              SizedBox(width: 20), // Espacio entre columnas
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Frecuencia del Préstamo
                    Text('Frecuencia:', style: TextStyle(fontSize: 14)),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              border: Border.all(color: Colors.grey[300]!, width: 2.0),
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
                                value: frecuenciaPrestamo,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    frecuenciaPrestamo = newValue!;
                                  });
                                },
                                items: <String>['Semanal', 'Quincenal']
                                    .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value, style: TextStyle(fontSize: 14.0)),
                                  );
                                }).toList(),
                                icon: Icon(Icons.arrow_drop_down, color: Color(0xFFFB2056)),
                                dropdownColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Plazo (en semanas o quincenas)
                    Text('Plazo (en semanas o quincenas):', style: TextStyle(fontSize: 14)),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Plazo',
                        labelStyle: TextStyle(fontSize: 14.0, color: Colors.grey[700]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 2.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide(color: Color(0xFFFB2056), width: 2.0),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Cantidad de usuarios y montos por usuario en la misma fila
          Row(
            children: [
              Text('Cantidad de usuarios:', style: TextStyle(fontSize: 14)),
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
                    child: Text('${index + 1}', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ),
              SizedBox(width: 20), // Espacio entre dropdown y montos
              Expanded(
                child: Row(
                  children: List.generate(numeroUsuarios, (index) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 5),
                        child: TextField(
                          controller: montoPorUsuarioControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Usuario ${index + 1}',
                            labelStyle: TextStyle(fontSize: 14.0, color: Colors.grey[700]),
                            filled: true,
                            fillColor: Colors.grey[100],
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 2.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: BorderSide(color: Color(0xFFFB2056), width: 2.0),
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                          ),
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 14.0),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Botón para Calcular
          ElevatedButton(
            onPressed: () {
              double totalPrestamo = montoPorUsuarioControllers.fold(
                0.0,
                (sum, controller) => sum + (double.tryParse(controller.text) ?? 0.0),
              );

              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Total del préstamo grupal: \$${totalPrestamo.toStringAsFixed(2)}'),
              ));
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Color(0xFFFB2056),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Calcular Total', style: TextStyle(fontSize: 14.0)),
            ),
          ),
        ],
      ),
    );
  }
}
