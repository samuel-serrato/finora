import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
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

      final response = await http.post(
        Uri.parse('http://$baseUrl/api/v1/usuarios'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'usuario': usuarioController.text,
          'tipoUsuario': selectedTipoUsuario,
          'nombreCompleto': nombreCompletoController.text,
          'email': emailController.text,
          'password': passwordController.text,
        }),
      );

      if (response.statusCode == 201) {
        widget.onUsuarioAgregado();
        Navigator.of(context).pop();
        _mostrarDialogo(
          title: 'Éxito',
          message: 'Usuario creado correctamente',
          isSuccess: true,
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

    _dialogShown = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose?.call();
            },
            child: Text('Aceptar'),
          ),
        ],
      ),
    ).then((_) => _dialogShown = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.6;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
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
                        "Agregar Usuario",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Divider(color: Colors.grey, thickness: 0.5),
                    SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          
                          // Panel lateral izquierdo (rojo)
                          Container(
                            decoration: BoxDecoration(
                                color: Color(0xFF5162F6),
                                borderRadius: BorderRadius.all(Radius.circular(20))),
                            width: 250,
                            padding:
                                EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 40),
                                Icon(Icons.person_add, size: 80, color: Colors.white),
                                SizedBox(height: 20),
                                Text(
                                  "Complete todos los campos requeridos para registrar un nuevo usuario",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14, height: 1.4),
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
                                        _buildTextField(
                                          controller: usuarioController,
                                          label: 'Nombre de usuario',
                                          icon: Icons.person_outline,
                                          maxLength: 20,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Campo obligatorio';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: 20),
                      
                                        _buildTextField(
                                          controller: nombreCompletoController,
                                          label: 'Nombre completo',
                                          icon: Icons.badge_outlined,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
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
                                          keyboardType: TextInputType.emailAddress,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Campo obligatorio';
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
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
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
                                          color: Colors.grey.shade300, width: 1.0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.grey[700],
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 25, vertical: 12),
                                          side:
                                              BorderSide(color: Colors.grey.shade400),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text('CANCELAR'),
                                      ),
                                      SizedBox(width: 15),
                                      ElevatedButton(
                                        onPressed: _agregarUsuario,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF5162F6),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 30, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text('CREAR USUARIO',
                                            style: TextStyle(color: Colors.white)),
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

// Widgets reutilizables con el estilo original
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
      style: TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF5162F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        labelStyle: TextStyle(color: Colors.grey[600]),
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
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint, style: TextStyle(color: Colors.grey[600])),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF5162F6), width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      style: TextStyle(color: Colors.black, fontSize: 14),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}
