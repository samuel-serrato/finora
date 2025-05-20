import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finora/providers/theme_provider.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class nUsuarioDialog extends StatefulWidget {
  final VoidCallback onUsuarioAgregado;

  nUsuarioDialog({required this.onUsuarioAgregado});

  @override
  _nUsuarioDialogState createState() => _nUsuarioDialogState();
}

class _nUsuarioDialogState extends State<nUsuarioDialog> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController nombreCompletoController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? selectedTipoUsuario;
  List<String> tiposUsuario = [
    'Admin',
    'Contador',
    'Asistente',
    'Campo',
    'Invitado'
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _dialogShown = false;
  bool _errorDeConexion = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _agregarUsuario() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorDeConexion = false;
      _dialogShown = false;
    });

    _timer = Timer(Duration(seconds: 10), () {
      if (!_dialogShown) {
        setState(() {
          _isLoading = false;
          _errorDeConexion = true;
        });
        _mostrarDialogo(
          title: 'Error',
          message: 'Tiempo de espera agotado. Verifica tu conexión.',
          isSuccess: false,
        );
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // Modificación aquí: Combina el usuario con un punto y el nombre de la financiera sin espacios
      final usuarioCompleto =
          '${usuarioController.text}.${userData.nombreNegocio.toLowerCase().replaceAll(' ', '')}';

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/usuarios'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'usuario': usuarioCompleto,
          'tipoUsuario': selectedTipoUsuario,
          'nombreCompleto': nombreCompletoController.text,
          'email': emailController.text,
          'password': passwordController.text,
          'idnegocio': userData.idnegocio
        }),
      );

      if (response.statusCode == 201) {
        widget.onUsuarioAgregado();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usuario creado correctamente',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _handleResponseError(response);
      }
    } catch (e) {
      _mostrarDialogo(
        title: 'Error',
        message:
            'Error de conexión: ${e is SocketException ? 'Verifica tu red' : 'Error inesperado'}',
        isSuccess: false,
      );
    } finally {
      _timer?.cancel();
      setState(() => _isLoading = false);
    }
  }

  void _handleResponseError(http.Response response) {
    final responseBody = jsonDecode(response.body);
    final errorCode = responseBody['Error']?['Code'] ?? response.statusCode;
    final errorMessage =
        responseBody['Error']?['Message'] ?? "Error desconocido";

    if (response.statusCode == 401 && errorMessage == "jwt expired") {
      _handleTokenExpiration();
    } else {
      _mostrarDialogo(
        title: 'Error ${response.statusCode}',
        message: errorMessage,
        isSuccess: false,
      );
    }
  }

  void _handleTokenExpiration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tokenauth');

    _mostrarDialogo(
        title: 'Sesión expirada',
        message: 'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
        isSuccess: false,
        onClose: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            ));
  }

  void _mostrarDialogo({
    required String title,
    required String message,
    required bool isSuccess,
    VoidCallback? onClose,
  }) {
    if (_dialogShown) return;

    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    // Define los colores según el tema actual
    final backgroundColor =
        isDarkMode ? Color.fromARGB(255, 60, 60, 60) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final buttonTextColor = isDarkMode ? Colors.grey[300] : Colors.blue;
    final titleColor = isSuccess
        ? (isDarkMode ? Colors.green[300] : Colors.green)
        : (isDarkMode ? Colors.red[300] : Colors.red);
    final contentTextColor = isDarkMode ? Colors.grey[300] : Colors.grey[800];

    _dialogShown = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: TextStyle(color: contentTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.white70 : null,
            ),
            child: Text(
              'Aceptar',
              style: TextStyle(
                color: buttonTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).then((_) => _dialogShown = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final userData = Provider.of<UserDataProvider>(context); // Nuevo

    final width = MediaQuery.of(context).size.width * 0.6;
    final height = MediaQuery.of(context).size.height * 0.8;

    // Define theme colors based on dark mode state
    final backgroundColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey;
    final primaryColor = Color(0xFF5162F6); // Brand color stays the same
    final borderColor = isDarkMode ? Colors.grey[700] : Colors.grey[400];
    final secondaryTextColor = isDarkMode ? Colors.grey[300] : Colors.grey[600];
    final cancelButtonColor = isDarkMode ? Colors.grey[800] : Colors.grey[700];
    final fieldBgColor = isDarkMode ? Color(0xFF2A2A2A) : Colors.white;

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(20),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Agregar Usuario",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Divider(color: dividerColor, thickness: 0.5),
                    SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          // Panel lateral izquierdo (color primario)
                          Container(
                            decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20))),
                            width: 250,
                            padding: EdgeInsets.symmetric(
                                vertical: 20, horizontal: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 40),
                                Icon(Icons.person_add,
                                    size: 80, color: Colors.white),
                                SizedBox(height: 20),
                                Text(
                                  "Complete todos los campos requeridos para registrar un nuevo usuario",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 30),
                          // Área principal del formulario
                          Expanded(
                            child: Column(
                              children: [
                                // Área scrollable
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(height: 30),

                                        // Reemplaza el _buildTextField del usuarioController con este Row
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Flexible(
                                              flex: 3,
                                              child: TextFormField(
                                                controller: usuarioController,
                                                maxLength: 20,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: textColor),
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Nombre de usuario',
                                                  labelStyle: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          secondaryTextColor),
                                                  prefixIcon: Icon(
                                                      Icons.person_outline,
                                                      color:
                                                          secondaryTextColor),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    borderSide: BorderSide(
                                                        color: borderColor ??
                                                            Colors.grey),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    borderSide: BorderSide(
                                                        color: primaryColor,
                                                        width: 1.5),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    borderSide: BorderSide(
                                                        color: Colors.red),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          vertical: 14,
                                                          horizontal: 16),
                                                  fillColor: fieldBgColor,
                                                  filled: true,
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Campo obligatorio';
                                                  }
                                                  return null;
                                                },
                                                autovalidateMode:
                                                    AutovalidateMode
                                                        .onUserInteraction,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Flexible(
                                              flex: 3,
                                              child: Text(
                                                '.${userData.nombreNegocio.toLowerCase().replaceAll(' ', '')}',
                                                style: TextStyle(
                                                  color: secondaryTextColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 20),

                                        _buildTextField(
                                          controller: nombreCompletoController,
                                          label: 'Nombre completo',
                                          icon: Icons.badge_outlined,
                                          isDarkMode: isDarkMode,
                                          textColor: textColor,
                                          secondaryColor: secondaryTextColor,
                                          primaryColor: primaryColor,
                                          borderColor: borderColor,
                                          fieldBgColor: fieldBgColor,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Campo obligatorio';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: 20),

                                        _buildTextField(
                                          controller: emailController,
                                          label: 'Correo electrónico',
                                          icon: Icons.alternate_email,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          isDarkMode: isDarkMode,
                                          textColor: textColor,
                                          secondaryColor: secondaryTextColor,
                                          primaryColor: primaryColor,
                                          borderColor: borderColor,
                                          fieldBgColor: fieldBgColor,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return null;
                                            }
                                            if (!RegExp(
                                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                                .hasMatch(value)) {
                                              return 'Correo inválido';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: 20),

                                        _buildTextField(
                                          controller: passwordController,
                                          label: 'Contraseña',
                                          icon: Icons.lock_outline,
                                          obscureText: true,
                                          isDarkMode: isDarkMode,
                                          textColor: textColor,
                                          secondaryColor: secondaryTextColor,
                                          primaryColor: primaryColor,
                                          borderColor: borderColor,
                                          fieldBgColor: fieldBgColor,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Campo obligatorio';
                                            }
                                            if (value.length < 4) {
                                              return 'Mínimo 4 caracteres';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: 20),

                                        _buildDropdown(
                                          value: selectedTipoUsuario,
                                          hint: 'Tipo de usuario',
                                          items: tiposUsuario,
                                          icon: Icons.group_work_outlined,
                                          isDarkMode: isDarkMode,
                                          textColor: textColor,
                                          secondaryColor: secondaryTextColor,
                                          primaryColor: primaryColor,
                                          borderColor: borderColor,
                                          fieldBgColor: fieldBgColor,
                                          onChanged: (value) {
                                            setState(() {
                                              selectedTipoUsuario = value;
                                            });
                                          },
                                          validator: (value) {
                                            if (value == null) {
                                              return 'Seleccione un tipo';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: 30),
                                      ],
                                    ),
                                  ),
                                ),

                                // Sección fija de botones
                                Container(
                                  padding: EdgeInsets.only(top: 20),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                          color: isDarkMode
                                              ? Colors.grey[800]!
                                              : Colors.grey[300]!,
                                          width: 1.0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: TextButton.styleFrom(
                                          foregroundColor: cancelButtonColor,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 25, vertical: 12),
                                          side: BorderSide(
                                              color: isDarkMode
                                                  ? Colors.grey[600]!
                                                  : Colors.grey[400]!),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: Text('CANCELAR',
                                            style: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.grey[300]
                                                    : null)),
                                      ),
                                      SizedBox(width: 15),
                                      ElevatedButton(
                                        onPressed: _agregarUsuario,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 30, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: Text('CREAR USUARIO',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

// Widgets reutilizables con soporte para dark mode
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    required bool isDarkMode,
    required Color textColor,
    required Color? secondaryColor,
    required Color primaryColor,
    required Color? borderColor,
    required Color fieldBgColor,
    String? Function(String?)? validator,
  }) {
    // Add a state variable to control password visibility
    bool _isPasswordVisible = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return TextFormField(
          controller: controller,
          obscureText: obscureText ? !_isPasswordVisible : false,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: TextStyle(fontSize: 12, color: textColor),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(fontSize: 12, color: secondaryColor),
            hintText: label,
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
            prefixIcon: Icon(icon, color: secondaryColor),
            // Add suffix icon for password visibility toggle
            suffixIcon: obscureText
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      icon: Icon(
                        size: 20,
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: secondaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor ?? Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            fillColor: fieldBgColor,
            filled: true,
          ),
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        );
      },
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
    required bool isDarkMode,
    required Color textColor,
    required Color? secondaryColor,
    required Color primaryColor,
    required Color? borderColor,
    required Color fieldBgColor,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint, style: TextStyle(color: secondaryColor)),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: TextStyle(fontSize: 14, color: textColor)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      dropdownColor: fieldBgColor,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: secondaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor ?? Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        fillColor: fieldBgColor,
        filled: true,
      ),
      style: TextStyle(color: textColor, fontSize: 14),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}
