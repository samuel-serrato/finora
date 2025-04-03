import 'dart:async';
import 'dart:convert';
import 'package:finora/models/image_data.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:finora/constants/routes.dart';
import 'package:finora/ip.dart';
import 'package:finora/navigation_rail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MaterialApp(
    home: LoginScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _rememberMe = false; // Variable para el checkbox
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('rememberedUser');
    if (savedUser != null) {
      setState(() {
        _usernameController.text = savedUser;
        _rememberMe = true;
      });
    }
  }

  Future<void> _handleLogin() async {
    print('=== INICIANDO LOGIN ===');
    print('Usuario: ${_usernameController.text}');
    print('Contraseña: ${_passwordController.text}');

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      print('Error: Campos vacíos');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Por favor completa todos los campos'),
        ),
      );
      return;
    }

    // Validación de longitud mínima del usuario
    if (_usernameController.text.length < 4) {
      print('Error: Usuario debe tener al menos 4 caracteres');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('El usuario debe tener al menos 4 caracteres'),
        ),
      );
      return;
    }

    // Validación de longitud mínima de la contraseña
    if (_passwordController.text.length < 4) {
      print('Error: Contraseña debe tener al menos 4 caracteres');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('La contraseña debe tener al menos 4 caracteres'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('Realizando petición a: http://$baseUrl/api/v1/auth/login');
      final response = await http.post(
        Uri.parse('http://$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usuario': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      print('Respuesta recibida - Código: ${response.statusCode}');
      print('Headers: ${response.headers}');
      print('Body: ${response.body}');

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['code'] == 200) {
        final token = response.headers['tokenauth'];
        print('Token recibido: $token');

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('tokenauth', token);
          print('Token almacenado en SharedPreferences');

          // Guardar o eliminar el usuario según el checkbox "Recuérdame"
          if (_rememberMe) {
            await prefs.setString('rememberedUser', _usernameController.text);
          } else {
            await prefs.remove('rememberedUser');
          }

          final usuario = responseBody['usuario'][0];

          // Conversión de imágenes a objetos ImageData
          List<ImageData> imagenes = (usuario['imagenes'] as List)
              .map((img) => ImageData.fromJson(img))
              .toList();

          // Guardar datos en el Provider
          final userDataProvider =
              Provider.of<UserDataProvider>(context, listen: false);
          userDataProvider.setUserData(
              nombreFinanciera: usuario['nombreFinanciera'],
              imagenes: imagenes,
              nombreUsuario: usuario['nombreCompleto'],
              tipoUsuario: usuario['tipoUsuario'],
              idfinanciera: usuario['idfinanciera'],
              idusuario: usuario['idusuarios']);

          print('Navegando a HomeScreen');
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.navigation,
            (route) => false,
            arguments: {
              'userId': usuario['idusuarios'],
            },
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text('Bienvenido ${usuario['nombreCompleto']}'),
            ),
          );
        } else {
          print('Error: Token no encontrado en headers');
          throw Exception('Token no encontrado en los headers');
        }
      } else {
        final errorMessage = responseBody['Error']?['Message'] ??
            responseBody['message'] ??
            'Error desconocido';
        print('Error en respuesta del servidor: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Excepción capturada: $e');

      String errorMessage;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('tiempo de espera')) {
        errorMessage =
            'No se pudo conectar al servidor. Por favor verifica tu conexión a internet e intenta nuevamente.';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        if (errorMessage.contains('http://') ||
            errorMessage.contains('address =')) {
          errorMessage = 'Error de conexión. Por favor intenta más tarde.';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('=== FIN DEL PROCESO DE LOGIN ===');
    }
  }

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Control Financiero\nen un Solo Lugar',
      //'image': 'assets/finance.png',
      'color': const Color(0xFF5162F6),
    },
    {
      'title': 'Crea Grupos Personalizados\nde Créditos',
      //'subtitle': 'Organiza por tasa de interés, garantías\no perfil de riesgo',
      //'image': 'assets/custom_groups.png', // Ej: Diagrama de nodos o tags
      'color': const Color(0xFF009688), // Verde-azul profesional
    },
    {
      'title': 'Historial Completo\nde Transacciones',
      //'subtitle': 'Accede al registro de pagos,\nabonos y ajustes',
      //'image':
      //  'assets/transaction_history.png', // Ej: Tabla con fechas y montos
      'color': const Color(0xFF9C27B0), // Morado para datos históricos
    },
    {
      'title': 'Reportes Detallados\ny en Tiempo Real',
      // 'image': 'assets/reports.png',
      'color': const Color(0xFF3F51B5), // Azul corporativo
    },
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isDarkMode
                    ? [
                        const Color(0xFF1A1A2E),
                        const Color(0xFF121212),
                      ]
                    : [
                        const Color(0xFFF0EFFF),
                        Colors.white,
                      ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width / 2.5,
                  child: SliderWidget(slides: _slides),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 100, vertical: 120),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 100),
                          child: LoginForm(
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            onLogin: _handleLogin,
                            rememberMe: _rememberMe,
                            onRememberMeChanged: (value) {
                              setState(() {
                                _rememberMe = value;
                              });
                            },
                          ),
                        ),
                      ),
                      // Texto pegado abajo, centrado en el contenedor derecho.
                      Positioned(
                        bottom: 20, // Ajuste del margen inferior
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Finora  |  Desarrollado por ',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'CODX',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _launchURL,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                  height: 4), // Espaciado entre líneas
                              Text(
                                '© ${DateTime.now().year} Todos los derechos reservados.', // Derechos de autor en una línea aparte
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5162F6)),
                  strokeWidth: 6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://codxtech.com');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'No se pudo abrir el enlace: $url';
    }
  }
}

class SliderWidget extends StatefulWidget {
  final List<Map<String, dynamic>> slides;

  const SliderWidget({Key? key, required this.slides}) : super(key: key);

  @override
  _SliderWidgetState createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final nextPage = (_currentPage + 1) % widget.slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    });
  }

  void _goToPage(int index) {
    _timer?.cancel();
    _pageController
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        )
        .then((_) => _startAutoSlide());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: widget.slides.length,
                itemBuilder: (context, index) {
                  final slide = widget.slides[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: slide['color'],
                      /* image: DecorationImage(
                        image: AssetImage(slide['image']),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.2),
                          BlendMode.darken,
                        ),
                      ), */
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          slide['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(2, 2),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 20,
                child: Row(
                  children: List.generate(
                    widget.slides.length,
                    (index) => MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _goToPage(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _currentPage == index ? 25 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;

  const LoginForm({
    Key? key,
    required this.usernameController,
    required this.passwordController,
    required this.onLogin,
    required this.rememberMe,
    required this.onRememberMeChanged,
  }) : super(key: key);

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    var isDarkMode = themeProvider.isDarkMode;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 500,
              height: 100,
              child: Image.asset(
                isDarkMode
                    ? 'assets/finora_blanco.png'
                    : 'assets/finora_hzt.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 50.0),
        _buildTextField(
          context: context,
          label: 'Usuario',
          icon: Icons.person_outline,
          controller: widget.usernameController,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 30.0),
        _buildTextField(
          context: context,
          label: 'Contraseña',
          icon: Icons.lock_outline,
          isPassword: true,
          controller: widget.passwordController,
          onFieldSubmitted: widget.onLogin,
          textInputAction: TextInputAction.go,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment
              .spaceBetween, // Separa los elementos en los extremos
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxTheme(
                  data: CheckboxThemeData(
                    fillColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return const Color(
                              0xFF5162F6); // Color cuando está seleccionado
                        }
                        return isDarkMode
                            ? Colors.grey[800]
                            : Colors.white; // Check blanco en dark mode
                      },
                    ),
                    checkColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return isDarkMode
                              ? Colors.white
                              : Colors.white; // Check blanco en dark mode
                        }
                        return null; // Usa el color por defecto en otros estados
                      },
                    ),
                    side: BorderSide(color: Colors.grey[600]!, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Checkbox(
                    value: widget.rememberMe,
                    onChanged: (bool? value) {
                      if (value != null) {
                        widget.onRememberMeChanged(value);
                      }
                    },
                    side: BorderSide(color: Colors.grey[600]!, width: 2),
                  ),
                ),
                Text(
                  "Recuérdame",
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 15),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                isDarkMode ? Icons.dark_mode : Icons.dark_mode,
                color: isDarkMode ? Colors.white : const Color(0xFF5162F6),
              ),
              onPressed: () {
                themeProvider.toggleDarkMode(!isDarkMode);
              },
            ),
          ],
        ),
        const SizedBox(height: 40.0),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5162F6),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 5,
            shadowColor: const Color(0xFF5162F6).withOpacity(0.3),
          ),
          onPressed: widget.onLogin,
          child: const Text(
            'Ingresar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool isDarkMode,
    bool isPassword = false,
    VoidCallback? onFieldSubmitted,
    TextInputAction? textInputAction,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.grey[800],
          ),
          onFieldSubmitted: (value) => onFieldSubmitted?.call(),
          textInputAction: textInputAction,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
            ),
            suffixIcon: isPassword
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFF5162F6), width: 2),
            ),
            hintText: 'Ingrese su ${label.toLowerCase()}',
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }
}
