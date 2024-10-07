import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkMode;
  final Function toggleDarkMode;
  final String title; // Nuevo parámetro para el título

  @override
  Size get preferredSize => Size.fromHeight(100);

  CustomAppBar({
    required this.isDarkMode,
    required this.toggleDarkMode,
    required this.title, // Agregar el título al constructor
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 20, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title, // Usar el título recibido en el widget
                    style: TextStyle(
                      color: Colors.grey[900],
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: GestureDetector(
                      onTap: () {
                        toggleDarkMode(!isDarkMode);
                      },
                      child: Container(
                        width: 50,
                        height: 30,
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode
                                  ? Colors.black45
                                  : Colors.grey[400]!,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: isDarkMode
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          children: [
                            AnimatedPositioned(
                              duration: Duration(milliseconds: 200),
                              left: isDarkMode ? 0 : 20,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border:
                                      Border.all(color: Colors.white, width: 1),
                                ),
                                child: Icon(
                                  isDarkMode
                                      ? Icons.wb_sunny
                                      : Icons.nights_stay,
                                  color: Colors.black,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey, width: 0.8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Acción para notificaciones
                            },
                            splashColor: Colors.grey.withOpacity(0.3),
                            highlightColor: Colors.grey.withOpacity(0.2),
                            child: Center(
                              child: Icon(
                                Icons.notifications,
                                color: Colors.grey[800],
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color.fromARGB(255, 201, 205, 209),
                        radius: 18,
                        child: Icon(
                          Icons
                              .person, // Puedes cambiar este icono por el que prefieras
                          color: Colors.grey[800], // Cambia el color del icono
                          size:
                              20, // Ajusta el tamaño del icono según el `radius` del CircleAvatar
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Nombre Usuario',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 20),
                ],
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          color: Colors.grey[300],
        ),
      ],
    );
  }
}
