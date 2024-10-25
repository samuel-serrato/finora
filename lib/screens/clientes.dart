import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/screens/nCliente.dart';

class ClientesScreen extends StatefulWidget {
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> listaClientes = [];
  bool isLoading = true;
  bool showErrorDialog = false;

  @override
  void initState() {
    super.initState();
    obtenerClientes();
  }

  Future<void> obtenerClientes() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.0.108:3000/api/v1/clientes'));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          listaClientes = data.map((item) => Cliente.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          showErrorDialog = true;
        });
      }
    } catch (e) {
      setState(() {
        showErrorDialog = true;
      });
    }
  }

  String formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: content(context),
    );
  }

  Widget content(BuildContext context) {
    return Column(
      children: [
        filaBienvenida(),
        filaSearch(context),
        filaTabla(context),
      ],
    );
  }

  Widget filaBienvenida() {
    return Container(
      color: Color(0xFFEFF5FD),
      padding: EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(
            width: 200,
            padding: EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 2.0),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.black),
                SizedBox(width: 10.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nombre del usuario'),
                    Text('Tipo de usuario'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget filaSearch(context) {
    double maxWidth = MediaQuery.of(context).size.width * 0.35;
    return Container(
      color: Color(0xFFEFF5FD),
      padding: EdgeInsets.only(bottom: 0, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Clientes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: TextField(
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    borderSide:
                        BorderSide(color: Color.fromARGB(255, 137, 192, 255))),
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
            width: double.infinity,
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Últimos Clientes',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Color(0xFF7EFF8B)),
                          foregroundColor:
                              MaterialStatePropertyAll(Color(0xFF434343)),
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        onPressed: () {
                          mostrarDialogoAgregarCliente(); // Llama a la función para mostrar el diálogo
                        },
                        child: Text('Agregar Clientes'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tabla(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void mostrarDialogoAgregarCliente() {
    showDialog(
      context: context,
      builder: (context) {
        return nClienteDialog(
          onClienteAgregado: () {
            obtenerClientes(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }

  Widget tabla() {
    return DataTable(
      showCheckboxColumn: false,
      headingRowColor:
          MaterialStateProperty.resolveWith((states) => Color(0xFFDFE7F5)),
      dataRowHeight: 50,
      columnSpacing: 30,
      headingTextStyle:
          TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Tipo')),
        DataColumn(label: Text('Nombres')),
        DataColumn(label: Text('Apellido P')),
        DataColumn(label: Text('Apellido M')),
        DataColumn(label: Text('F. Nac')),
        DataColumn(label: Text('Sexo')),
        DataColumn(label: Text('Teléfono')),
        DataColumn(label: Text('E. Civil')),
        DataColumn(label: Text('F. Creación')),
        DataColumn(label: Text('Tipo Cliente')),
      ],
      rows: listaClientes.map((cliente) {
        return DataRow(
          cells: [
            DataCell(Text(cliente.idclientes)),
            DataCell(Text(cliente.idtipoclientes.toString())),
            DataCell(Text(cliente.nombres)),
            DataCell(Text(cliente.apellidoP)),
            DataCell(Text(cliente.apellidoM)),
            DataCell(Text(formatDate(cliente.fechaNac))),
            DataCell(Text(cliente.sexo)),
            DataCell(Text(cliente.telefono)),
            DataCell(Text(cliente.eCilvi)),
            DataCell(Text(formatDate(cliente.fCreacion))),
            DataCell(Text(cliente.nombre)),
          ],
          onSelectChanged: (isSelected) {
            // Acción al seleccionar la fila
            setState(() {
              // Puedes agregar lógica aquí para manejar la fila seleccionada
              // Por ejemplo, guardar el cliente seleccionado o realizar otra acción
            });
          },
          color: MaterialStateColor.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.withOpacity(
                  0.1); // Color azul bajito cuando está seleccionada la fila
            } else if (states.contains(MaterialState.hovered)) {
              return Colors.blue.withOpacity(
                  0.2); // Color azul bajito cuando el mouse está encima
            }
            return Colors
                .transparent; // Color transparente cuando no se cumple ninguna condición
          }),
        );
      }).toList(),
    );
  }
}

class Cliente {
  final String idclientes;
  final int idtipoclientes;
  final String nombres;
  final String apellidoP;
  final String apellidoM;
  final String fechaNac;
  final String sexo;
  final String telefono;
  final String eCilvi;
  final String fCreacion;
  final String nombre;

  Cliente({
    required this.idclientes,
    required this.idtipoclientes,
    required this.nombres,
    required this.apellidoP,
    required this.apellidoM,
    required this.fechaNac,
    required this.sexo,
    required this.telefono,
    required this.eCilvi,
    required this.fCreacion,
    required this.nombre,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      idclientes: json['idclientes'],
      idtipoclientes: json['idtipoclientes'],
      nombres: json['nombres'],
      apellidoP: json['apellidoP'],
      apellidoM: json['apellidoM'],
      fechaNac: json['fechaNac'],
      sexo: json['sexo'],
      telefono: json['telefono'],
      eCilvi: json['eCilvi'],
      fCreacion: json['fCreacion'],
      nombre: json['nombre'],
    );
  }
}
