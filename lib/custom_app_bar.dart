import 'package:flutter/material.dart';
import 'package:money_facil/constants/routes.dart';
import 'package:money_facil/ip.dart';
import 'package:money_facil/screens/login.dart';
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 20, bottom: 20),
          decoration: BoxDecoration(color: Colors.white),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Row for the image and title
              Row(
                children: [
                  // Image on the left

                  // Title text
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[900],
                      fontSize: 24,
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
                              builder: (context) => AlertDialog(
                                title: Text('Cerrar sesión'),
                                content:
                                    Text('¿Estás seguro de que quieres salir?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text('Aceptar'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm) await _logoutUser(context);
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
                                      fontSize: 16, color: Colors.grey[800]),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.exit_to_app,
                                    color: Colors.redAccent),
                                const SizedBox(width: 12),
                                Text(
                                  'Cerrar sesión',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey[800]),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    tipoUsuario,
                                    style: TextStyle(
                                      color: Colors.grey.shade900,
                                      fontSize: 12,
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
