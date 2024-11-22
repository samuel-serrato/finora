import 'package:flutter/material.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:money_facil/dialogs/infoCredito.dart';
import 'package:money_facil/dialogs/nCredito.dart'; // Para manejar fechas

class SeguimientoScreen extends StatefulWidget {
  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  // Datos estáticos de ejemplo de créditos activos
  final List<Credito> listaCreditos = [
    Credito(
      idCredito: 1,
      nombreCredito: 'Cielito Azul',
      montoAutorizado: 50000,
      garantia: 10, // Porcentaje de la garantía
      interes: 9.28,
      tipoCredito: 'Individual',
      estadoCredito: 'Activo', // Estado del crédito
      montoDesembolsado: 40000,
      semanaDePago: '2 de 14',
      diaDePago: 'Lunes',
      fechaPago: DateTime(2024, 11, 10), // Fecha de pago
      pagoSemanal: 2500.0, // Ejemplo de pago semanal
      fechaInicio: DateTime(2024, 10, 1), // Fecha de inicio
      fechaFin: DateTime(2025, 1, 1), // Fecha de finalización
    ),
    Credito(
      idCredito: 2,
      nombreCredito: 'Las lobas',
      montoAutorizado: 10000,
      garantia: 10, // Porcentaje de la garantía
      interes: 9.28,
      tipoCredito: 'Individual',
      estadoCredito: 'Activo', // Estado del crédito
      montoDesembolsado: 10000,
      semanaDePago: '5 de 12',
      diaDePago: 'Miércoles',
      fechaPago: DateTime(2024, 11, 12), // Fecha de pago
      pagoSemanal: 2500.0, // Ejemplo de pago semanal
      fechaPagado: DateTime(2024, 11, 12), // Ejemplo de pago registrado
      fechaInicio: DateTime(2024, 9, 1), // Fecha de inicio
      fechaFin: DateTime(2024, 12, 1), // Fecha de finalización
    ),
    Credito(
      idCredito: 3,
      nombreCredito: 'Las trabajadoras',
      montoAutorizado: 80000,
      garantia: 10, // Porcentaje de la garantía
      interes: 9.28,
      tipoCredito: 'Grupal',
      estadoCredito: 'Activo', // Estado del crédito
      montoDesembolsado: 80000,
      semanaDePago: '8 de 20',
      diaDePago: 'Viernes',
      fechaPago: DateTime(2024, 11, 15), // Fecha de pago
      pagoSemanal: 2500.0, // Ejemplo de pago semanal
      fechaInicio: DateTime(2024, 8, 15), // Fecha de inicio
      fechaFin: DateTime(2025, 2, 15), // Fecha de finalización
    ),
  ];

  bool _isDarkMode = false;

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        isDarkMode: _isDarkMode,
        toggleDarkMode: _toggleDarkMode,
        title: 'Créditos Activos',
      ),
      backgroundColor: Color(0xFFF7F8FA),
      body: content(context),
    );
  }

  Widget content(BuildContext context) {
    return Column(
      children: [
        filaBuscarYAgregar(context),
        filaTabla(context),
      ],
    );
  }

  Widget filaBuscarYAgregar(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width * 0.35;
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 40,
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8.0)],
            ),
            child: TextField(
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide:
                      BorderSide(color: Color.fromARGB(255, 137, 192, 255)),
                ),
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Color(0xFFFB2056)),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            onPressed: mostrarDialogAgregarGrupo,
            child: Text('Agregar Crédito'),
          ),
        ],
      ),
    );
  }

  void mostrarDialogAgregarGrupo() {
    showDialog(
      barrierDismissible: false, // Evita que se cierre al tocar fuera
      context: context,
      builder: (context) {
        return nCreditoDialog(
          onGrupoAgregado: () {
            //obtenerGrupos(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }

  Widget filaTabla(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0.5,
                  blurRadius: 5,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(child: tabla()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget tabla() {
    const double fontSize = 11;

    // Lista para almacenar los índices de las filas seleccionadas
    List<int> selectedRows = [];

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowColor:
            MaterialStateProperty.resolveWith((states) => Color(0xFFE8EFF9)),
        columnSpacing: 15,
        headingRowHeight: 50,
        columns: const [
          DataColumn(label: Text('Tipo', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Nombre', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Autorizado', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Interés %', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('Desembolsado', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('Interés Total', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Monto a Recuperar',
                  style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Día Pago', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('Pago Semanal', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label:
                  Text('Semana de Pago', style: TextStyle(fontSize: fontSize))),
          DataColumn(
              label: Text('Duración del Crédito',
                  style: TextStyle(fontSize: fontSize))), // Nueva columna
          DataColumn(
              label:
                  Text('Estado de Pago', style: TextStyle(fontSize: fontSize))),
        ],
        rows: listaCreditos.map((credito) {
          String estadoPago = _calcularEstadoPago(credito);
          Color colorEstado;

          if (estadoPago == "A Tiempo" || estadoPago == "Pagado") {
            colorEstado = Colors.green;
          } else {
            colorEstado = Colors.red;
          }

          return DataRow(
            selected: selectedRows.contains(listaCreditos.indexOf(credito)),
            onSelectChanged: (isSelected) {
              setState(() {
                if (isSelected == true) {
                  selectedRows.add(listaCreditos.indexOf(credito));
                  showDialog(
                    context: context,
                    builder: (context) =>
                        InfoCredito(id: credito.idCredito),
                  );
                }
              });
            },
            cells: [
              DataCell(Text(credito.tipoCredito,
                  style: TextStyle(fontSize: fontSize))),
              DataCell(Text(credito.nombreCredito,
                  style: TextStyle(fontSize: fontSize))),

              DataCell(Center(
                  child: Text('\$${credito.montoAutorizado}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('${credito.interes}%',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('\$${credito.montoDesembolsado}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('\$${credito.interesTotal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('\$${credito.montoARecuperar.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text(credito.diaDePago,
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text('\$${credito.pagoSemanal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(Center(
                  child: Text(credito.semanaDePago,
                      style: TextStyle(fontSize: fontSize)))),
              DataCell(
                Center(
                  child: Text(
                    '${DateFormat('dd/MM/yyyy').format(credito.fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(credito.fechaFin)}',
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ), // Combina las fechas de inicio y fin
              DataCell(
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(radius: 8, backgroundColor: colorEstado),
                          SizedBox(width: 8),
                          Text(estadoPago,
                              style: TextStyle(fontSize: fontSize)),
                        ],
                      ),
                      if (estadoPago == "Atrasado") ...[
                        SizedBox(height: 4),
                        Text(
                            '(${_diasDeRetraso(credito.fechaPago)} días de retraso)',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                      if (credito.fechaPagado != null) ...[
                        SizedBox(height: 4),
                        Text(
                            '(Pagado: ${DateFormat('dd/MM/yyyy').format(credito.fechaPagado!)})',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ]
                    ],
                  ),
                ),
              ),
            ],
            color: MaterialStateColor.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.blue.withOpacity(0.1);
              } else if (states.contains(MaterialState.hovered)) {
                return Colors.blue.withOpacity(0.2);
              }
              return Colors.transparent;
            }),
          );
        }).toList(),
      ),
    );
  }

  // Método para calcular el estado de pago (A Tiempo, Atrasado o Pagado)
  String _calcularEstadoPago(Credito credito) {
    DateTime ahora = DateTime.now();
    if (credito.fechaPagado != null) {
      return "Pagado";
    } else if (ahora.isBefore(credito.fechaPago) ||
        ahora.isAtSameMomentAs(credito.fechaPago)) {
      return "A Tiempo";
    } else {
      return "Atrasado";
    }
  }

  // Método para calcular los días de retraso
  int _diasDeRetraso(DateTime fechaPago) {
    DateTime ahora = DateTime.now();
    return ahora.difference(fechaPago).inDays;
  }
}

class Credito {
  final int idCredito;

  final String nombreCredito;
  final int montoAutorizado;
  final int garantia;
  final double interes;
  final String tipoCredito;
  final String estadoCredito;
  final int montoDesembolsado;
  final String semanaDePago;
  final String diaDePago;
  final DateTime fechaPago;
  final double pagoSemanal;
  final DateTime? fechaPagado;
  final DateTime fechaInicio; // Nuevo campo
  final DateTime fechaFin; // Nuevo campo

  Credito({
    required this.idCredito,
    required this.nombreCredito,
    required this.montoAutorizado,
    required this.garantia,
    required this.interes,
    required this.tipoCredito,
    required this.estadoCredito,
    required this.montoDesembolsado,
    required this.semanaDePago,
    required this.diaDePago,
    required this.fechaPago,
    required this.pagoSemanal,
    this.fechaPagado,
    required this.fechaInicio, // Nuevo campo en el constructor
    required this.fechaFin, // Nuevo campo en el constructor
  });

  // Cálculo del interés total
  double get interesTotal {
    return montoDesembolsado * (interes / 100);
  }

  // Cálculo del monto a recuperar
  double get montoARecuperar {
    return montoDesembolsado + interesTotal;
  }
}
