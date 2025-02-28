import 'package:flutter/material.dart';
import 'package:finora/navigation_rail.dart';
import 'package:finora/providers/pagos_provider.dart';
import 'package:finora/screens/login.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart'; // Para manejar la ventana
import 'constants/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa la configuración de fechas en español.
  await initializeDateFormatting('es_ES', null);
  Intl.defaultLocale = 'es_ES';

  // Inicializa window_manager
  await windowManager.ensureInitialized();

  // Obtener la escala del sistema
  double systemScale = await windowManager.getDevicePixelRatio();

  double targetScale = 1.4; // Queremos que la app se vea como 125%
  double scaleFactor = systemScale < 1.4 ? targetScale / systemScale : 1.0;
  // Solo ajustamos si la escala es menor a 125%

  // Si hay que escalar, ajustamos la ventana
  if (scaleFactor > 1.0) {
    Size screenSize = await windowManager.getSize();
    await windowManager.setSize(
        Size(screenSize.width * scaleFactor, screenSize.height * scaleFactor));
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PagosProvider()),
      ],
      child: MyApp(scaleFactor),
    ),
  );
}

class MyApp extends StatelessWidget {
  final double scaleFactor;

  const MyApp(this.scaleFactor, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: scaleFactor, // Escalar solo si es necesario
        devicePixelRatio: scaleFactor,
      ),
      child: MaterialApp(
        locale: const Locale('es', 'ES'),
        supportedLocales: const [
          Locale('es', 'ES'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        initialRoute: AppRoutes.login,
        routes: {
          AppRoutes.login: (context) => LoginScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.navigation) {
            if (settings.arguments is! Map<String, dynamic>) {
              return _errorRoute();
            }
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => NavigationScreen(
                username: args['username'] ?? 'Usuario',
                rol: args['rol'] ?? 'sin_rol',
                userId: args['userId'] ?? '',
                userType: args['userType'] ?? 'standard',
                scaleFactor: scaleFactor,
              ),
            );
          }
          return _errorRoute();
        },
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.white,
          useMaterial3: true,
        ),
      ),
    );
  }
}

// Ruta de error genérica
Route<dynamic> _errorRoute() {
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      body: Center(
        child: Text('Error de navegación'),
      ),
    ),
  );
}
