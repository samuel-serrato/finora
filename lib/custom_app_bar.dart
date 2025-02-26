import 'package:flutter/material.dart';
import 'package:finora/constants/routes.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkMode;
  final Function toggleDarkMode;
  final String title;
  final String nombre;
  final String tipoUsuario;

  @override
  Size get preferredSize => Size.fromHeight(90);

  CustomAppBar({
    required this.isDarkMode,
    required this.toggleDarkMode,
    required this.title,
    required this.nombre,
    required this.tipoUsuario,
  });

  Future<void> _logoutUser(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    print('token antes de cerrar sesión: $token');

    try {
      final response = await http.post(
        Uri.parse('http://$baseUrl/api/v1/auth/logout'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Eliminar el token
        await prefs.remove('tokenauth');

        // Mostrar SnackBar indicando que la sesión se ha cerrado correctamente
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sesión cerrada correctamente')),
        );

        // Navegar a la pantalla de login
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 10, bottom: 15),
          decoration: BoxDecoration(color: Colors.white),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            // Row for the image and title
            Row(
              children: [
                // Image on the left

                // Title text
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // The rest of your row remains unchanged
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
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isDarkMode ? Colors.black45 : Colors.grey[400]!,
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
                                isDarkMode ? Icons.wb_sunny : Icons.nights_stay,
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
                SizedBox(width: 10),
                Container(
                  height: 50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        spreadRadius: 2,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/mf_logo_hzt.png', // Replace with your image path
                        width: 120, // Adjust size as needed
                        height: 40,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Row(
                  children: [
                    PopupMenuButton<String>(
                      constraints: BoxConstraints(minWidth: 220),
                      tooltip: '',
                      offset: const Offset(0, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      elevation: 10,
                      onSelected: (value) async {
                        if (value == 'logout') {
                          bool confirm = await showDialog(
                                context: context,
                                builder: (context) => Theme(
                                  data: Theme.of(context).copyWith(
                                    dialogBackgroundColor: Colors.white,
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Color(0xFF5162F6),
                                      ),
                                    ),
                                  ),
                                  child: AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                    contentPadding:
                                        EdgeInsets.only(top: 25, bottom: 10),
                                    title: Column(
                                      children: [
                                        Icon(
                                          Icons.exit_to_app_rounded,
                                          size: 60,
                                          color: Color(0xFF5162F6),
                                        ),
                                        SizedBox(height: 15),
                                        Text(
                                          'Cerrar Sesión',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 15),
                                      child: Text(
                                        '¿Estás seguro de que quieres salir de tu cuenta?',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                    actionsPadding: EdgeInsets.only(
                                        bottom: 20, right: 25, left: 25),
                                    actions: [
                                      SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text('Cancelar'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    Colors.grey[700],
                                                side: BorderSide(
                                                    color: Colors.grey[400]!),
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 15),
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Color(0xFF5162F6),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text('Cerrar Sesión'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ) ??
                              false; // Si el diálogo se cierra sin valor, asigna false

                          if (confirm) await _logoutUser(context);
                        } else if (value == 'acerca_de') {
                          _showAboutDialog(context); // Llamada a la función
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'configuracion',
                          child: Row(
                            children: [
                              Icon(Icons.settings, color: Colors.black),
                              const SizedBox(width: 12),
                              Text(
                                'Configuración',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'acerca_de',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              const SizedBox(width: 12),
                              Text(
                                'Acerca de',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app, color: Colors.redAccent),
                              const SizedBox(width: 12),
                              Text(
                                'Cerrar sesión',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              spreadRadius: 2,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Color(0xFF5162F6),
                              radius: 18,
                              child: Icon(_getIconForUserType(tipoUsuario),
                                  color: Colors.white, size: 22),
                            ),
                            SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  tipoUsuario,
                                  style: TextStyle(
                                    color: Colors.grey.shade900,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 10),
              ],
            ),
          ])),
      Container(
        height: 1,
        color: Colors.grey[300],
      ),
    ]);
  }

  void _showAboutDialog(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.30;
    final height = MediaQuery.of(context).size.height * 0.32;

    showDialog(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Bordes redondeados
          ),
          elevation: 8,
          child: Container(
            width: width,
            height: height,
            padding: EdgeInsets.all(16), // Padding general
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.max, // Ocupa todo el espacio vertical
              mainAxisAlignment:
                  MainAxisAlignment.center, // Centra verticalmente los
              children: [
                // Logo del software
                Image.asset(
                  'assets/finora_hzt.png', // Ruta de la imagen
                  width: 150, // Ancho de la imagen
                  height: 50, // Alto de la imagen
                ),
                SizedBox(height: 8), // Espacio reducido
                /* Text(
                  'Acerca de Finora',
                  style: TextStyle(
                    fontSize: 18, // Título más pequeño
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5162F6),
                  ),
                ), */

                // Contenido compacto
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 2), // Menos espacio
                  child: Column(
                    children: [
                      Text(
                        'Desarrollado por CODX', // Texto combinado
                        style: TextStyle(
                          fontSize: 14, // Texto más pequeño
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 18),
                      Divider(
                        color: Colors.grey[300],
                        height: 1, // Divider más fino
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Versión 1.0.0', // Texto combinado
                        style: TextStyle(
                            fontSize: 16, // Tamaño reducido
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5162F6)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                // Botón minimalista
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8), // Botón más pequeño
                    minimumSize: Size(0, 0), // Eliminar tamaño mínimo
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Cerrar',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14, // Texto más pequeño
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

  IconData _getIconForUserType(String userType) {
    switch (userType) {
      case 'Admin':
        return Icons.admin_panel_settings;
      case 'Contador':
        return Icons.calculate;
      case 'Asistente':
        return Icons.assignment_ind;
      case 'Campo':
        return Icons.directions_walk;
      case 'Invitado':
        return Icons.person_outline;
      default:
        return Icons.person;
    }
  }
}
