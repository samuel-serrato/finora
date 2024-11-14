import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:money_facil/custom_app_bar.dart';

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
        title: 'Créditos',
      ),
      backgroundColor: Color(0xFFF7F8FA),
      body: content(context),
    );
  }


  Widget content(BuildContext context) {
    return Column(
      children: [
      //  filaBienvenida(),
        filaBuscarYAgregar(context),
        filaTabla(context)
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
            onPressed: null,
            child: Text('Agregar Crédito'),
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
