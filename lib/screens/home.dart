import 'dart:async';
import 'dart:convert';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:finora/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:finora/ip.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {


  const HomeScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer timer;
  String formattedDate =
      DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now());
  String formattedDateTime =
      DateFormat('h:mm:ss a', 'es_ES').format(DateTime.now());

  bool _isDarkMode = false;
  HomeData? homeData;
  bool isLoading = true;
  String errorMessage = '';
  bool dialogShown = false; // Controlar diálogos mostrados

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
        formattedDateTime = DateFormat('h:mm:ss a').format(DateTime.now());
      });
    });
    _fetchHomeData();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  /*  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }
 */
  Future<void> _fetchHomeData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    bool dialogShown = false;

    try {
      // Obtener el token de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // Verificar si el token está disponible
      if (token.isEmpty) {
        setState(() => isLoading = false);
        _handleError(
          dialogShown,
          'Token de autenticación no encontrado. Por favor, inicia sesión.',
          redirectToLogin: true,
        );
        return;
      }

      final Uri url = Uri.parse('http://$baseUrl/api/v1/home');

      print('🔄 Iniciando solicitud a: ${url.toString()}');
      print(
          '🔑 Usando token: ${token.isNotEmpty ? 'Disponible' : 'No disponible'}');

      final response = await http.get(
        url,
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('✅ Respuesta recibida - Código: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);
          final HomeData parsedData = HomeData.fromJson(responseData);

          print('📦 Datos parseados correctamente:');
          print(
              ' - Créditos activos: ${parsedData.creditosActFin.first.creditos_activos}');
          print(
              ' - Grupos activos: ${parsedData.gruposIndGrupos.first.grupos_activos}');
          print(
              ' - Total depósitos: ${parsedData.sumaPagos.first.sumaDepositos}');

          setState(() {
            homeData = parsedData;
            isLoading = false;
          });
        } catch (e) {
          print('❌ Error parseando respuesta: $e');
          setState(() {
            errorMessage = 'Error en formato de datos';
            isLoading = false;
          });
        }
      } else {
        try {
          final errorData = json.decode(response.body);

          if (errorData["Error"] != null) {
            final mensajeError = errorData["Error"]["Message"];

            if (mensajeError == "La sesión ha cambiado. Cerrando sesión...") {
              await prefs.remove('tokenauth');

              if (!dialogShown) {
                dialogShown = true;
                mostrarDialogoCierreSesion(
                  'La sesión ha cambiado. Cerrando sesión...',
                  onClose: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false,
                    );
                  },
                );
              }
              return;
            } else if (mensajeError == "jwt expired") {
              await prefs.remove('tokenauth');

              if (!dialogShown) {
                dialogShown = true;
                _handleError(
                  dialogShown,
                  'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
                  redirectToLogin: true,
                );
              }
              return;
            }
          }
        } catch (e) {
          print('Error al procesar la respuesta: $e');
        }

        print('⚠️ Respuesta no exitosa - Código: ${response.statusCode}');
        setErrorState(
            'Error del servidor: ${response.statusCode}', dialogShown);
      }
    } on http.ClientException catch (e) {
      print('❌ Error de conexión: $e');
      setErrorState('Error de conexión: ${e.message}', dialogShown);
    } on TimeoutException {
      print('⌛ Tiempo de espera agotado');
      setErrorState('Tiempo de espera agotado', dialogShown);
    } catch (e) {
      print('❌ Error inesperado: $e');
      setErrorState('Error inesperado: ${e.toString()}', dialogShown);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }

    // Manejar timeout si la carga sigue activa después de 10 segundos
    Timer(Duration(seconds: 10), () {
      if (mounted && !dialogShown && isLoading) {
        setState(() {
          isLoading = false;
          errorMessage = 'No se pudo conectar al servidor';
        });
        dialogShown = true;
        mostrarDialogoError(
            'No se pudo conectar al servidor. Verifica tu red.');
      }
    });
  }

  void _handleError(bool dialogShown, String message,
      {bool redirectToLogin = false}) {
    if (!dialogShown) {
      dialogShown = true;
      _mostrarDialogoError(
        message,
        onClose: redirectToLogin
            ? () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              }
            : null,
      );
    }
  }

  void _mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    if (!mounted || dialogShown) return; // Evitar múltiples diálogos

    dialogShown = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(mensaje),
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
    ).then((_) => dialogShown = false);
  }

  void mostrarDialogoCierreSesion(String mensaje,
      {required Function() onClose}) {
    // Detectar si estamos en modo oscuro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          contentPadding: EdgeInsets.only(top: 25, bottom: 10),
          title: Column(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 60,
                color: Colors.red[700],
              ),
              SizedBox(height: 15),
              Text(
                'Sesión Finalizada',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          actionsPadding: EdgeInsets.only(bottom: 20, right: 25, left: 25),
          actions: [
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(double.infinity, 48), // Ancho completo
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onClose();
              },
              child: Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

// Helper method to set error state
  void setErrorState(String message, bool dialogShown) {
    setState(() {
      errorMessage = message;
      isLoading = false;
    });

    if (!dialogShown) {
      mostrarDialogoError('Error: $message');
    }
  }

// Dialog to show errors
  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(mensaje),
          actions: <Widget>[
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop();
                if (onClose != null) {
                  onClose();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Scaffold(
      backgroundColor: isDarkMode
          ? Colors.grey[900]
          : const Color(0xFFF7F8FA), // Fondo dinámico
      body: content(),
      appBar: CustomAppBar(
        isDarkMode: isDarkMode,
        toggleDarkMode: (value) {
          themeProvider.toggleDarkMode(value); // Cambia el tema
        },
        title: 'Home'
      ),
    );
  }

  Widget content() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          welcomeCard(),
          const SizedBox(height: 50),
          Expanded(child: cardsList()),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget welcomeCard() {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema
        final userData = Provider.of<UserDataProvider>(context, listen: false);


    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDarkMode ? Colors.blueGrey[800]! : Color(0xFF6A88F7),
              isDarkMode ? Colors.blueGrey[900]! : Color(0xFF5162F6),
            ],
          ),
        ),
        padding: EdgeInsets.all(25),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.waving_hand_rounded,
                        color: Colors.white.withOpacity(0.9), size: 28),
                    SizedBox(width: 10),
                    Text(
                      "Hola, ${userData.nombreUsuario}!",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _buildWelcomeInfoRow(
                  icon: Icons.calendar_today_rounded,
                  title: "Hoy es",
                  value: DateFormat('EEEE, d MMM').format(DateTime.now()),
                ),
                SizedBox(height: 12),
                _buildWelcomeInfoRow(
                  icon: Icons.access_time_rounded,
                  title: "Hora actual",
                  value: DateFormat('hh:mm a').format(DateTime.now()),
                ),
                SizedBox(height: 12),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.account_balance_wallet_rounded,
                    size: 120, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget headerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formattedDate,
          style: TextStyle(
            fontSize: 16,
            color: _isDarkMode ? Colors.white70 : Colors.grey[600],
          ),
        ),
        Text(
          formattedDateTime,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget cardsList() {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage));
    }

    return GridView.count(
      padding: const EdgeInsets.symmetric(vertical: 10),
      crossAxisCount: 5,
      childAspectRatio: 1.3,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _buildStatCard(
          title: 'Créditos Activos',
          value: homeData!.creditosActFin.first.creditos_activos ?? '0',
          icon: Icons.group_work_rounded,
          color: const Color(0xFF5162F6),
        ),
        _buildStatCard(
          title: 'Créditos Finalizados',
          value: homeData!.creditosActFin.first.creditos_finalizados ?? '0',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF6BC950),
        ),
        _buildStatCard(
          title: 'Grupos Individuales',
          value: homeData!.gruposIndGrupos.first.grupos_individuales ?? '0',
          icon: Icons.person,
          color: const Color(0xFF4ECDC4),
        ),
        _buildStatCard(
          title: 'Grupos Grupales',
          value: homeData!.gruposIndGrupos.first.grupos_grupales ?? '0',
          icon: Icons.group,
          color: const Color(0xFF4ECDC4),
        ),
        _buildStatCard(
          title: 'Acumulado Semanal',
          value: NumberFormat.currency(
            symbol: '\$',
            decimalDigits: 2,
            locale: 'en_US',
          ).format(double.tryParse(
                  (homeData!.sumaPagos.first.sumaDepositos ?? '0')
                      .replaceAll(',', '.')) ??
              0),
          icon: Icons.payments,
          color: const Color(0xFFFF6B6B),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Añade estos modelos al final de tu archivo o en uno separado
class HomeData {
  final List<CreditosActFin> creditosActFin;
  final List<GruposIndGrupos> gruposIndGrupos;
  final List<SumaPagos> sumaPagos;

  HomeData({
    required this.creditosActFin,
    required this.gruposIndGrupos,
    required this.sumaPagos,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      creditosActFin: (json['creditosActFin'] as List)
          .map((e) => CreditosActFin.fromJson(e))
          .toList(),
      gruposIndGrupos: (json['gruposIndGrupos'] as List)
          .map((e) => GruposIndGrupos.fromJson(e))
          .toList(),
      sumaPagos: (json['sumaPagos'] as List)
          .map((e) => SumaPagos.fromJson(e))
          .toList(),
    );
  }
}

class CreditosActFin {
  final String? creditos_activos;
  final String? creditos_finalizados;

  CreditosActFin({
    required this.creditos_activos,
    required this.creditos_finalizados,
  });

  factory CreditosActFin.fromJson(Map<String, dynamic> json) {
    return CreditosActFin(
      creditos_activos: json['creditos_activos']?.toString() ?? '0',
      creditos_finalizados: json['creditos_finalizados']?.toString() ?? '0',
    );
  }
}

class GruposIndGrupos {
  final int total_grupos;
  final String? grupos_individuales;
  final String? grupos_grupales;
  final String? grupos_activos;
  final String? grupos_finalizados;

  GruposIndGrupos({
    required this.total_grupos,
    required this.grupos_individuales,
    required this.grupos_grupales,
    required this.grupos_activos,
    required this.grupos_finalizados,
  });

  factory GruposIndGrupos.fromJson(Map<String, dynamic> json) {
    return GruposIndGrupos(
      total_grupos: json['total_grupos'] ?? 0,
      grupos_individuales: json['grupos_individuales']?.toString() ?? '0',
      grupos_grupales: json['grupos_grupales']?.toString() ?? '0',
      grupos_activos: json['grupos_activos']?.toString() ?? '0',
      grupos_finalizados: json['grupos_finalizados']?.toString() ?? '0',
    );
  }
}

class SumaPagos {
  final String? sumaDepositos;

  SumaPagos({
    required this.sumaDepositos,
  });

  factory SumaPagos.fromJson(Map<String, dynamic> json) {
    return SumaPagos(
      sumaDepositos: json['sumaDepositos']?.toString() ?? '0',
    );
  }
}
