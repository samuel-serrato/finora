import 'package:flutter/material.dart';

class nAnalisisScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: content(context),
    );
  }
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

// Fila 1
Widget filaBienvenida() {
  return Container(
    /* color: Colors.blue, */
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
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person, // Icono de usuario, puedes cambiarlo según tu preferencia
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


// Fila 2
Widget filaCards() {
  return Container(
    /* color: Colors.green, */
    color: Color(0xFFEFF5FD),
    height: 150.0,
    padding: EdgeInsets.all(16.0),
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: <Widget>[
        Card(
          child: Container(width: 200.0, height: 200.0),
        ),
        Card(
          child: Container(width: 200.0, height: 200.0),
        ),
        Card(
          child: Container(width: 200.0, height: 200.0),
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
    color: Color(0xFFEFF5FD),
    padding: EdgeInsets.only(bottom: 0, left: 20, right: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end, // Alinea el texto abajo
      children: <Widget>[
        Text(
          'Nuevo Análisis',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Container(
          height: 50,
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: TextField(
            decoration: InputDecoration(
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.0),
                borderSide: BorderSide(color: Color.fromARGB(255, 137, 192, 255))
              ),
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
Widget filaTabla(context) {
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
          child: Column(
            children: [
              // Row de botones
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Últimos Análisis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),),
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
                        // Acción para el primer botón
                      },
                      child: Text('Nuevo Análisis'),
                    ),
                  ],
                ),
              ),
              // Tabla de datos
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.resolveWith(
                        (states) => Color(0xFFE8EFF9)
                      ),
                    columnSpacing: 30,
/*                     dataRowHeight: 50.0, */
                    headingRowHeight: 50,
                    columns: const[
                      DataColumn(label: Text('Columna 1')),
                      DataColumn(label: Text('Columna 2')),
                      DataColumn(label: Text('Columna 3')),
                      // Agrega más columnas según sea necesario
                    ],
                    rows: const[
                      DataRow(cells: [
                        DataCell(Text('Dato 1')),
                        DataCell(Text('Dato 2')),
                        DataCell(Text('Dato 3')),
                        // Agrega más celdas según sea necesario
                      ]),
                      // Agrega más filas según sea necesario
                      DataRow(cells: [
                        DataCell(Text('Dato 1')),
                        DataCell(Text('Dato 2')),
                        DataCell(Text('Dato 3')),
                        // Agrega más celdas según sea necesario
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
