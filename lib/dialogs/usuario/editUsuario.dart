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
import 'package:finora/widgets/cambiar_contraseña.dart';

class editUsuarioDialog extends StatefulWidget {
  final VoidCallback onUsuarioEditado;
  final String idUsuario; // Añadir esta línea

  editUsuarioDialog({required this.onUsuarioEditado, required this.idUsuario});

  @override
  _editUsuarioDialogState createState() => _editUsuarioDialogState();
}

class _editUsuarioDialogState extends State<editUsuarioDialog> {
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
    _obtenerUsuario(); // Llamar al obtener datos al iniciar
  }

  Future<void> _obtenerUsuario() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/usuarios/${widget.idUsuario}'),
        headers: {'tokenauth': token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Verifica que el arreglo no esté vacío
        if (data is List && data.isNotEmpty) {
          final usuarioData = data[0];

          // Aquí agregas el código para quitar el .nombreNegocio
          String usuario = usuarioData['usuario'];
          if (usuario.contains('.')) {
            usuario = usuario.split('.')[0];
          }
          usuarioController.text = usuario;

          nombreCompletoController.text = usuarioData['nombreCompleto'];
          emailController.text = usuarioData['email'];
          selectedTipoUsuario = usuarioData['tipoUsuario'];
        } else {
          print('El arreglo de usuarios está vacío');
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editarUsuario() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);

    print('flutter: [_editarUsuario] Iniciando edición de usuario...');

    if (!_formKey.currentState!.validate()) {
      print('flutter: [_editarUsuario] Validación de formulario fallida');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorDeConexion = false;
      _dialogShown = false;
    });

    print('flutter: [_editarUsuario] Configurando timeout de 10 segundos');
    _timer = Timer(Duration(seconds: 10), () {
      print('flutter: [_editarUsuario] Timeout alcanzado');
      if (!_dialogShown) {
        print('flutter: [_editarUsuario] Mostrando error de conexión');
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
      print(
          'flutter: [_editarUsuario] Token obtenido: ${token.isNotEmpty ? "****" : "VACÍO"}');

      // URL CORREGIDA CON IDUSUARIO
      final url = '$baseUrl/api/v1/usuarios/${widget.idUsuario}';
      print('flutter: [_editarUsuario] URL: $url');

      // Modificación aquí: Combina el usuario con un punto y el nombre de la financiera sin espacios
      final usuarioCompleto =
          '${usuarioController.text}.${userData.nombreNegocio.toLowerCase().replaceAll(' ', '')}';

      // BODY ACTUALIZADO (sin password)
      final requestBody = {
        'usuario': usuarioCompleto,
        'tipoUsuario': selectedTipoUsuario,
        'nombreCompleto': nombreCompletoController.text,
        'email': emailController.text,
        //'roles': ['user']
      };

      print('flutter: [_editarUsuario] Cuerpo de la petición:');
      print('• Usuario: ${requestBody['usuario']}');
      print('• Tipo: ${requestBody['tipoUsuario']}');
      print('• Nombre: ${requestBody['nombreCompleto']}');
      print('• Email: ${requestBody['email']}');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print(
          'flutter: [_editarUsuario] Respuesta recibida - Código: ${response.statusCode}');
      print('flutter: [_editarUsuario] Body de respuesta: ${response.body}');

      if (response.statusCode == 200) {
        // Después de una edición exitosa
        // Verificar si el usuario editado es el mismo que está en la sesión actual
        final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
        
        // Comparar el ID del usuario editado con el ID del usuario actual
        if (widget.idUsuario.toString() == userDataProvider.idusuario.toString()) {
          print('flutter: [_editarUsuario] Actualizando provider - es la sesión actual');
          userDataProvider.actualizarDatosUsuario(
            nombreCompleto: nombreCompletoController.text,
            tipoUsuario: selectedTipoUsuario,
            // Puedes añadir más campos si es necesario
          );
        } else {
          print('flutter: [_editarUsuario] No se actualiza provider - no es la sesión actual');
        }
        // Debería ser 200 en lugar de 201 para actualización
        print('flutter: [_editarUsuario] Edición exitosa');
        widget.onUsuarioEditado();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usuario actualizado correctamente',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('flutter: [_editarUsuario] Error en la respuesta');
        _handleResponseError(response);
      }
    } catch (e) {
      print('flutter: [_editarUsuario] Excepción capturada: $e');
      print(
          'flutter: [_editarUsuario] Stack trace: ${e is Error ? (e as Error).stackTrace : ""}');
      _mostrarDialogo(
        title: 'Error',
        message:
            'Error de conexión: ${e is SocketException ? 'Verifica tu red' : 'Error inesperado'}',
        isSuccess: false,
      );
    } finally {
      print('flutter: [_editarUsuario] Limpiando recursos');
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

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    _dialogShown = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Color(0xFF303030) : Colors.white,
        title: Text(
          title,
          style: TextStyle(color: isSuccess ? Colors.green : Colors.red),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose?.call();
            },
            child: Text(
              'Aceptar',
              style: TextStyle(
                color: Color(0xFF5162F6),
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
      backgroundColor: isDarkMode ? Color(0xFF212121) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(20),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Color(0xFF5162F6)))
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Editar Usuario",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Divider(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey,
                        thickness: 0.5),
                    SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          // Panel lateral izquierdo (azul)
                          Container(
                            decoration: BoxDecoration(
                                color: Color(0xFF5162F6),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20))),
                            width: 250,
                            padding: EdgeInsets.symmetric(
                                vertical: 20, horizontal: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 40),
                                Icon(Icons.person_search_rounded,
                                    size: 80, color: Colors.white),
                                SizedBox(height: 20),
                                Text(
                                  "Complete todos los campos requeridos para editar un usuario",
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

                                        // Campos del formulario
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

                                        // Botón cambiar contraseña
                                        SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (context) =>
                                                CambiarPasswordDialog(
                                              idUsuario: widget.idUsuario,
                                              isDarkMode: isDarkMode,
                                            ),
                                          ),
                                          icon: Icon(Icons.lock_reset,
                                              size: 18, color: Colors.white),
                                          label: Text('Cambiar contraseña'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF5162F6),
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 20),
                                        SizedBox(height: 20),

                                        _buildDropdown(
                                          value: selectedTipoUsuario,
                                          hint: 'Tipo de usuario',
                                          items: tiposUsuario,
                                          icon: Icons.group_work_outlined,
                                          isDarkMode: isDarkMode,
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
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: TextButton.styleFrom(
                                          foregroundColor: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 25, vertical: 12),
                                          side: BorderSide(
                                            color: isDarkMode
                                                ? Colors.grey[600]!
                                                : Colors.grey[400]!,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text('CANCELAR'),
                                      ),
                                      SizedBox(width: 15),
                                      ElevatedButton(
                                        onPressed: _editarUsuario,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF5162F6),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 30, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text('EDITAR USUARIO',
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
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: TextStyle(
        fontSize: 14,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: isDarkMode ? Colors.blue[300] : Colors.grey[600],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Color(0xFF5162F6),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
        ),
        fillColor: isDarkMode ? Color(0xFF303030) : Colors.white,
        filled: true,
      ),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required IconData icon,
    required bool isDarkMode,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(
        hint,
        style: TextStyle(
          color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      dropdownColor: isDarkMode ? Color(0xFF424242) : Colors.white,
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: isDarkMode ? Colors.blue[300] : Colors.grey[600],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Color(0xFF5162F6),
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        fillColor: isDarkMode ? Color(0xFF303030) : Colors.white,
        filled: true,
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
        fontSize: 14,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      icon: Icon(
        Icons.arrow_drop_down,
        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
      ),
    );
  }
}
