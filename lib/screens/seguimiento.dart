import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SeguimientoScreen extends StatefulWidget {
  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  List<Usuario> listausuarios = [];
  bool isLoading = true;
  bool showErrorDialog = false;

  @override
  void initState() {
    super.initState();
   // obtenerusuarios();
  }

  /* void obtenerusuarios() async {
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
                  item['id'], item['email'], item['password'], item['name']))
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
  } */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      body: content(context),
    );
  }

// Función para obtener los datos de la API y mostrarlos en la consola
/* void obtenerDatos() async {
  final response = await http.get(Uri.parse('https://api.escuelajs.co/api/v1/ids'));

  if (response.statusCode == 200) {
    // Parsear la respuesta a formato JSON
    final List<dynamic> data = json.decode(response.body);
    print('Datos obtenidos de la API:');
    print(data);
  } else {
    print('Error al obtener los datos. Código de estado: ${response.statusCode}');
  }
} */

  Widget content(BuildContext context) {
    return Column(
      children: [
        filaBienvenida(),
        filaSearch(context),
        filaTabla(context),
      ],
    );
  }

// Fila 1
  Widget filaBienvenida() {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(
            width: 200,
            padding: EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.white,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              children: [
                Icon(
                  Icons
                      .person, // Icono de usuario, puedes cambiarlo según tu preferencia
                  color: Colors.black, // Color del icono
                ),
                SizedBox(width: 10.0), // Espacio entre el icono y el texto
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

// Fila 3
  Widget filaSearch(context) {
    double maxWidth = MediaQuery.of(context).size.width * 0.35;

    return Container(
      /* color: Colors.orange, */
      padding: EdgeInsets.only(bottom: 0, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start, // Alinea el texto abajo
        children: <Widget>[
          Text(
            'Seguimiento',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Container(
            //height: 50,
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: TextField(
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0), // Ajusta el relleno interno
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
                  borderSide: BorderSide.none, // Borde transparente
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Fila 4
  Widget filaTabla(BuildContext context) {
    return Expanded(
      child: Container(
        /* color: Colors.purple, */
        padding: EdgeInsets.all(20),
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
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 16.0, left: 0, right: 0),
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
                          backgroundColor: MaterialStatePropertyAll(
                            Color(0xFF7EFF8B),
                          ),
                          foregroundColor: MaterialStatePropertyAll(
                            Color(0xFF434343),
                          ),
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  10), // Aquí puedes cambiar el valor del radio
                            ),
                          ),
                        ),
                        onPressed: () {
                        //  obtenerusuarios();
                        },
                        child: Text('Nuevo Cliente'),
                      ),
                    ],
                  ),
                ),
                // Widget "tabla" donde se muestra la DataTable
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
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: DataTable(
        headingRowColor:
            MaterialStateProperty.resolveWith((states) => Color(0xFFE8EFF9)),
        columnSpacing: 30,
        headingRowHeight: 50,
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Password')),
          DataColumn(label: Text('Nombre')),
        ],
        rows: listausuarios.map((usuario) {
          return DataRow(cells: [
            DataCell(Text(
                usuario.id.toString())), // Convertir a String si es necesario
            DataCell(Text(usuario.email)),
            DataCell(Text(usuario.password)),
            DataCell(Text(usuario.name)),
          ]);
        }).toList(),
      ),
    );
  }
}

class Usuario {
  final int id;
  final String email;
  final String password;
  final String name;

  Usuario(this.id, this.email, this.password, this.name);
}
