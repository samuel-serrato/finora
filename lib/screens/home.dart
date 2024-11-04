import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/CardUserWidget.dart';
//import 'nusuario.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController _notaController = TextEditingController();
  Set<int> selectedItems = Set<int>();
  int hoveredItemIndex = -1;

  late Timer timer;
  List<Usuario> listausuarios = []; // Lista vacía de usuarios
  List<Nota> listaNotas = []; // Lista vacía de notas
  bool isLoading = false; // Establecer como falso ya que no se carga nada
  //bool showErrorDialog = false;
  String username = '';
  String nombre = '';
  String formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
  String formattedDateTime = DateFormat('h:mm:ss a').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    username = widget.username;

    // Actualizar la fecha y la hora cada segundo
    timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      setState(() {
        formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
        formattedDateTime = DateFormat('h:mm:ss a').format(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    // Cancelar el temporizador en el método dispose()
    timer.cancel();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;

    return Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      body: content(),
      appBar: isMobile
          ? AppBar(
              automaticallyImplyLeading: false,
              title: Text(''),
              toolbarHeight: 0,
            )
          : null,
    );
  }

  Widget content() {
      bool isMobile = MediaQuery.of(context).size.width < 600;

      return Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        child: Column(
          children: [
            Expanded(
              flex: 22,
              child: Container(
                //color: Colors.purple,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      //color: Colors.amber,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fechayHora(),
                        ],
                      ),
                    ),
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
            Expanded(
              flex: 25,
              child: Container(
                child: cards(),
              ),
            ),
            Expanded(
              flex: 10,
              child: Container(
                child: textoyBoton(),
              ),
            ),
            if (!isMobile)
              Expanded(
                flex: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 16, left: 16, top: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Descripción',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(right: 80),
                              child: Text(
                                'Fecha de Creación',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: listaTareas(),
                      ),
                    ],
                  ),
                ),
              ),
            if (isMobile)
              Expanded(
                flex: 40,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: listaTareas(),
                ),
              ),
            Expanded(
              flex: 10,
              child: Container(
                child: campoAgregarNota(),
              ),
            ),
          ],
        ),
      );
    }
  

  Widget campoAgregarNota() {
    return Container(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _notaController,
              decoration: InputDecoration(
                fillColor: Colors.white,
                filled: true,
                hintText: 'Ingrese una nota',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
          SizedBox(width: 16.0),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(
                Color(0xFFFB2056),
              ),
              overlayColor: MaterialStateProperty.all(
                Color.fromARGB(255, 190, 15, 59),
              ), // Color al pasar el mouse
            ),
            onPressed: () {
              if (_notaController.text.isNotEmpty) {
                // Lógica para agregar la nota (simulada)
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('El campo está vacío'),
                    backgroundColor: Colors.red,
                    duration: Duration(milliseconds: 700), // Duración
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Agregar nota',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  Widget fechayHora() {
    return FittedBox(
      fit: BoxFit.contain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDate,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 10),
          Text(
            formattedDateTime,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }

  Widget cards() {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth;
              final double cardHeight = constraints.maxHeight;

              bool isMobileSize = MediaQuery.of(context).size.width < 600;

              return _buildCard(
                cardWidth,
                cardHeight,
                isMobileSize,
                Icons.hourglass_empty,
                'Grupos Activos',
                '15',
              );
            },
          ),
        ),
        SizedBox(width: 20),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth;
              final double cardHeight = constraints.maxHeight;

              bool isMobileSize = MediaQuery.of(context).size.width < 600;

              return _buildCard(
                cardWidth,
                cardHeight,
                isMobileSize,
                Icons.hourglass_empty,
                'Grupos Atrasados',
                '3',
              );
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildCard(double cardWidth, double cardHeight, bool isMobileSize, IconData icon, String title, String value) {
  return Card(
    color: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 5,
    shape: RoundedRectangleBorder(
      /* side: const BorderSide(
        color: Color.fromARGB(255, 245, 144, 169),
        width: 2.0,
      ), */
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Center(
        child: isMobileSize
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: cardHeight * 0.4,
                    color: Color(0xFFFB2056),
                  ),
                  SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: cardWidth * 0.08,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: cardWidth * 0.1,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Icon(
                      icon,
                      size: cardHeight * 0.4,
                      color: Color(0xFFFB2056),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: cardWidth * 0.05,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: cardWidth * 0.07,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}



  Widget listaTareas() {
    return ListView.builder(
      itemCount: listaNotas.length,
      itemBuilder: (context, index) {
        final nota = listaNotas[index];
        final isSelected = selectedItems.contains(index);

        return InkWell(
          onTap: () {
            // Lógica de selección de elemento
          },
          onLongPress: () {
            // Lógica de largo clic (selección de múltiples elementos)
          },
          onTapCancel: () {
            // Lógica de cancelación de clic
          },
          child: Column(
            children: <Widget>[
              SizedBox(height: 15),
              new ListTile(
                title: new Text(
                  '${nota.nota}',
                  style: new TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                subtitle: new Text('${nota.descripcion}'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget textoyBoton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Notas',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        /* TextButton(
          onPressed: () {},
          child: Row(
            children: [
              Icon(
                Icons.add,
                color: Color.fromARGB(255, 0, 104, 190),
              ),
              Text(
                'Agregar nota',
                style: TextStyle(
                  color: Color.fromARGB(255, 0, 104, 190),
                ),
              ),
            ],
          ),
        ), */
      ],
    );
  }
}

// Clase Usuario
class Usuario {
  final String id;
  final String nombre;
  final String email;

  Usuario({
    required this.id,
    required this.nombre,
    required this.email,
  });
}

// Clase Nota
class Nota {
  final String id;
  final String nota;
  final String descripcion;

  Nota({
    required this.id,
    required this.nota,
    required this.descripcion,
  });
}
