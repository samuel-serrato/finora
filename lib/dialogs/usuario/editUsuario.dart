import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:money_facil/ip.dart';
import 'package:money_facil/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        Uri.parse('http://$baseUrl/api/v1/usuarios/${widget.idUsuario}'),
        headers: {'tokenauth': token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Verifica que el arreglo no esté vacío
        if (data is List && data.isNotEmpty) {
          final usuarioData =
              data[0]; // <- Accede al primer elemento del arreglo

          usuarioController.text = usuarioData['usuario'];
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
      print('flutter: [_editarUsuario] Token obtenido: ${token.isNotEmpty ? "****" : "VACÍO"}');

      // URL CORREGIDA CON IDUSUARIO
      final url = 'http://$baseUrl/api/v1/usuarios/${widget.idUsuario}';
      print('flutter: [_editarUsuario] URL: $url');
      
      // BODY ACTUALIZADO (sin password)
      final requestBody = {
        'usuario': usuarioController.text,
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

      print('flutter: [_editarUsuario] Respuesta recibida - Código: ${response.statusCode}');
      print('flutter: [_editarUsuario] Body de respuesta: ${response.body}');

      if (response.statusCode == 200) { // Debería ser 200 en lugar de 201 para actualización
        print('flutter: [_editarUsuario] Edición exitosa');
        widget.onUsuarioEditado();
        Navigator.of(context).pop();
        _mostrarDialogo(
          title: 'Éxito',
          message: 'Usuario actualizado correctamente',
          isSuccess: true,
        );
      } else {
        print('flutter: [_editarUsuario] Error en la respuesta');
        _handleResponseError(response);
      }
    } catch (e) {
      print('flutter: [_editarUsuario] Excepción capturada: $e');
      print('flutter: [_editarUsuario] Stack trace: ${e is Error ? (e as Error).stackTrace : ""}');
      _mostrarDialogo(
        title: 'Error',
        message: 'Error de conexión: ${e is SocketException ? 'Verifica tu red' : 'Error inesperado'}',
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
                        "Editar Usuario",
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
                                        _buildTextField(
                                          controller: usuarioController,
                                          label: 'Nombre de usuario',
                                          icon: Icons.person_outline,
                                          maxLength: 20,
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
                                          controller: nombreCompletoController,
                                          label: 'Nombre completo',
                                          icon: Icons.badge_outlined,
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
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
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

                                        // Dentro de tu formulario principal, reemplaza el campo de contraseña por:
                                        SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (context) =>
                                                _CambiarPasswordDialog(
                                                    idUsuario:
                                                        widget.idUsuario),
                                          ),
                                          icon:
                                              Icon(Icons.lock_reset, size: 18),
                                          label: Text('CAMBIAR CONTRASEÑA'),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFF5162F6),
                                              foregroundColor: Colors.white),
                                        ),
                                        SizedBox(height: 20),
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
                                          color: Colors.grey.shade300,
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
                                          foregroundColor: Colors.grey[700],
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 25, vertical: 12),
                                          side: BorderSide(
                                              color: Colors.grey.shade400),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
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
                                                  BorderRadius.circular(8)),
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

class _CambiarPasswordDialog extends StatefulWidget {
  final String idUsuario;

  const _CambiarPasswordDialog({required this.idUsuario});

  @override
  __CambiarPasswordDialogState createState() => __CambiarPasswordDialogState();
}

class __CambiarPasswordDialogState extends State<_CambiarPasswordDialog> {
  final TextEditingController _nuevaPasswordController =
      TextEditingController();
  final TextEditingController _confirmarPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _cambiarPassword() async {
    print('flutter: Iniciando cambio de contraseña...');

    if (!_formKey.currentState!.validate()) {
      print('flutter: Validación de formulario fallida');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      print('flutter: Token obtenido: ${token.isNotEmpty ? "****" : "VACÍO"}');

      final url =
          'http://$baseUrl/api/v1/usuarios/recuperar/password/${widget.idUsuario}';
      print('flutter: URL de petición: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'password': _nuevaPasswordController.text,
        }),
      );

      print('flutter: Respuesta del servidor - Código: ${response.statusCode}');
      print('flutter: Body de respuesta: ${response.body}');

      if (response.statusCode == 200) {
        print('flutter: Contraseña cambiada exitosamente');
        Navigator.of(context).pop();
        _mostrarMensajeExito();
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['Error']['Message'] ?? 'Error al cambiar contraseña';
        print('flutter: Error del servidor: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('flutter: Excepción capturada: $e');
      print(
          'flutter: Stack trace: ${e is Error ? (e as Error).stackTrace : ""}');
      _mostrarError(e.toString());
    } finally {
      print('flutter: Finalizando proceso de cambio de contraseña');
      setState(() => _isLoading = false);
    }
  }

  void _mostrarMensajeExito() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contraseña actualizada correctamente'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
  return AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20.0),
      side: BorderSide(color: Colors.blue.shade100, width: 2),
    ),
    title: Column(
      children: [
        Icon(Icons.lock_reset, size: 40, color: Colors.blue.shade800),
        SizedBox(height: 10),
        Text('Cambiar Contraseña', 
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900
          ),
        ),
        Divider(color: Colors.grey.shade300, height: 20),
      ],
    ),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nuevaPasswordController,
            obscureText: true,
            style: TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              labelStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.blue.shade200),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return '⚠️ Campo obligatorio';
              if (value.length < 4) return '⚠️ Mínimo 4 caracteres';
              return null;
            },
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _confirmarPasswordController,
            obscureText: true,
            style: TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              labelStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.lock_reset, color: Colors.blue.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.blue.shade200),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            validator: (value) {
              if (value != _nuevaPasswordController.text) {
                return '⚠️ Las contraseñas no coinciden';
              }
              return null;
            },
          ),
        ],
      ),
    ),
    actions: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Cancelar', 
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500
                ),
              ),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _cambiarPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                elevation: 2,
              ),
              child: _isLoading 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Guardar', 
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ],
  );
}
}
