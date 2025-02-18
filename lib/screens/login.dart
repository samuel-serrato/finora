import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:finora/constants/routes.dart';
import 'package:finora/ip.dart';
import 'package:finora/navigation_rail.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    print('=== INICIANDO LOGIN ===');
    print('Usuario: ${_usernameController.text}');
    print('Contraseña: ${_passwordController.text}');

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      print('Error: Campos vacíos');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
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

          print('Navegando a HomeScreen');
          // En el método de login exitoso:
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.navigation,
            (route) => false,
            arguments: {
              'username': responseBody['usuario'][0]['nombreCompleto'],
              'rol': responseBody['usuario'][0]['roles'].isNotEmpty
                  ? responseBody['usuario'][0]['roles'][0]
                  : 'sin_rol',
              'userId': responseBody['usuario'][0]['idusuarios'],
              'userType': responseBody['usuario'][0]['tipoUsuario']
            },
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
                content: Text(
                    'Bienvenido ${responseBody['usuario'][0]['nombreCompleto']}')),
          );
        } else {
          print('Error: Token no encontrado en headers');
          throw Exception('Token no encontrado en los headers');
        }
      } else {
        // Modificación aquí para extraer el mensaje correctamente
        final errorMessage = responseBody['Error']?['Message'] ??
            responseBody['message'] ??
            'Error desconocido';
        print('Error en respuesta del servidor: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Excepción capturada: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
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
      'image': 'assets/finance.png',
      'color': const Color(0xFF5162F6),
    },
    {
      'title': 'Crea Grupos Personalizados\nde Créditos',
      //'subtitle': 'Organiza por tasa de interés, garantías\no perfil de riesgo',
      'image': 'assets/custom_groups.png', // Ej: Diagrama de nodos o tags
      'color': const Color(0xFF009688), // Verde-azul profesional
    },
      {
      'title': 'Historial Completo\nde Transacciones',
      //'subtitle': 'Accede al registro de pagos,\nabonos y ajustes',
      'image': 'assets/transaction_history.png', // Ej: Tabla con fechas y montos
      'color': const Color(0xFF9C27B0), // Morado para datos históricos
    },
    {
      'title': 'Reportes Detallados\ny en Tiempo Real',
      'image': 'assets/reports.png',
      'color': const Color(0xFF3F51B5), // Azul corporativo
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color(0xFFF0EFFF),
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
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
                  child: LoginForm(
                    usernameController: _usernameController,
                    passwordController: _passwordController,
                    onLogin: _handleLogin,
                  ),
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
      ]),
    );
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
                      image: DecorationImage(
                        image: AssetImage(slide['image']),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.2),
                          BlendMode.darken,
                        ),
                      ),
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

  const LoginForm({
    Key? key,
    required this.usernameController,
    required this.passwordController,
    required this.onLogin,
  }) : super(key: key);

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 500,
                    height: 100,
                      child: Image.asset('assets/finora_hzt.png',
                          fit: BoxFit.contain),
                    ),
              ],
            ),
           /*  const SizedBox(height: 20),
            Text(
              'Iniciar Sesión',
              style: TextStyle(
                fontSize: 24.0,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ), */
          ],
        ),
        const SizedBox(height: 50.0),
        _buildTextField(
          label: 'Usuario',
          icon: Icons.person_outline,
          controller: widget.usernameController,
        ),
        const SizedBox(height: 30.0),
        _buildTextField(
          label: 'Contraseña',
          icon: Icons.lock_outline,
          isPassword: true,
          controller: widget.passwordController,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(color: Color(0xFF5162F6)),
            ),
          ),
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
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('¿No tienes cuenta? ',
                style: TextStyle(color: Colors.grey[700])),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Regístrate',
                style: TextStyle(
                  color: Color(0xFF5162F6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: TextStyle(color: Colors.grey[800]),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[500]),
            suffixIcon: isPassword
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey[500],
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
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFF5162F6), width: 2),
            ),
            hintText: 'Ingrese su ${label.toLowerCase()}',
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }
}

