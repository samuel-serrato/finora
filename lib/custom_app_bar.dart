import 'dart:io';
import 'package:finora/dialogs/configuracion.dart';
import 'package:finora/providers/logo_provider.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:finora/constants/routes.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
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
        await prefs.remove('tokenauth');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.green,
              content: Text('Sesión cerrada correctamente')),
        );
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

  Future<String?> _getLogoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('financiera_logo_path');
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: 120,
      height: 40,
      alignment: Alignment.center,
      child: Text(
        'Logo financiera',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final logoProvider = Provider.of<LogoProvider>(context);

    // Make sure we've loaded the logo path
    if (logoProvider.logoPath == null) {
      // Try to load it if it's not loaded yet
      logoProvider.loadLogoPath();
    }

    final isDarkMode = themeProvider.isDarkMode;

    return Column(children: [
      Container(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 10, bottom: 15),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Theme.of(context).colorScheme.surface
                : Colors.white,
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            // Row for the image and title
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.white
                        : Colors.grey[900], // Color dinámico
                    fontSize: 22,
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
                      themeProvider.toggleDarkMode(!isDarkMode);
                    },
                    child: Container(
                      width: 50,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color:
                                isDarkMode ? Colors.grey[600]! : Colors.white,
                            width: 1),
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
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.surface
                          : Colors.white, // Color dinámico
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDarkMode ? Colors.grey[600]! : Colors.grey,
                          width: 0.8),
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
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.grey[800], // Color dinámico
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
                      color: isDarkMode ? Colors.grey[900] : Colors.white,
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
                    child: Consumer<LogoProvider>(
                      builder: (context, logoProvider, _) {
                        // Check if we have a path and if the file exists
                        final hasLogo = logoProvider.logoPath != null;
                        final fileExists = hasLogo
                            ? File(logoProvider.logoPath!).existsSync()
                            : false;

                        return Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: (hasLogo && fileExists)
                              ? Image.file(
                                  File(logoProvider.logoPath!),
                                  width: 120,
                                  height: 40,
                                  fit: BoxFit.contain,
                                  key: ValueKey(logoProvider.version),
                                  errorBuilder: (context, error, stackTrace) {
                                    print(
                                        "Error loading image: $error"); // Debug output
                                    return _buildDefaultPlaceholder();
                                  },
                                )
                              : _buildDefaultPlaceholder(),
                        );
                      },
                    )),
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
                      color: isDarkMode
                          ? Colors.grey[800]
                          : Colors.white, // Color dinámico
                      elevation: 10,
                      onSelected: (value) async {
                        if (value == 'logout') {
                          bool confirm = await showDialog(
                                context: context,
                                builder: (context) => Theme(
                                  data: Theme.of(context).copyWith(
                                    dialogBackgroundColor: isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.white, // Color dinámico
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Color(0xFF5162F6),
                                      ),
                                    ),
                                  ),
                                  child: AlertDialog(
                                    backgroundColor: isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.white, // Color dinámico
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
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors
                                                    .black87, // Color dinámico
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
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors
                                                  .grey[700], // Color dinámico
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
                                                foregroundColor: isDarkMode
                                                    ? Colors.white
                                                    : Colors.grey[
                                                        700], // Color dinámico
                                                side: BorderSide(
                                                    color: isDarkMode
                                                        ? Colors.grey[600]!
                                                        : Colors.grey[400]!),
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
                              false;

                          if (confirm) await _logoutUser(context);
                        } else if (value == 'acerca_de') {
                          _showAboutDialog(context);
                        }
                        if (value == 'configuracion') {
                          showDialog(
                            context: context,
                            barrierColor:
                                Colors.black38, // Fondo semi-transparente
                            builder: (context) => ConfiguracionDialog(),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'configuracion',
                          child: Row(
                            children: [
                              Icon(Icons.settings,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                              const SizedBox(width: 12),
                              Text(
                                'Configuración',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'acerca_de',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: isDarkMode
                                      ? Colors.blue[200]
                                      : Colors.blue),
                              const SizedBox(width: 12),
                              Text(
                                'Acerca de',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app,
                                  color: isDarkMode
                                      ? Colors.redAccent[200]
                                      : Colors.redAccent),
                              const SizedBox(width: 12),
                              Text(
                                'Cerrar sesión',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey[800]),
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
                          color: isDarkMode
                              ? Colors.grey[900]
                              : Colors.white, // Color dinámico
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
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black, // Color dinámico
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  tipoUsuario,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors
                                            .grey.shade900, // Color dinámico
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black), // Color dinámico
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
        color:
            isDarkMode ? Colors.grey[700] : Colors.grey[300], // Color dinámico
      ),
    ]);
  }
}

void _showAboutDialog(BuildContext context) {
  final width = MediaQuery.of(context).size.width * 0.30;
  final height = MediaQuery.of(context).size.height * 0.32;
  final isDarkMode =
      Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

  showDialog(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isDarkMode ? Colors.grey[800] : Colors.white, // Color dinámico
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                isDarkMode
                    ? 'assets/finora_blanco.png'
                    : 'assets/finora_hzt.png',
                width: 150,
                height: 50,
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    Text(
                      'Desarrollado por CODX',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white
                            : Colors.grey[700], // Color dinámico
                      ),
                    ),
                    SizedBox(height: 18),
                    Divider(
                      color: isDarkMode
                          ? Colors.grey[600]
                          : Colors.grey[300], // Color dinámico
                      height: 1,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Versión 1.0.0',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5162F6)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Cerrar',
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.white
                        : Colors.grey[700], // Color dinámico
                    fontSize: 14,
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
