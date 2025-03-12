import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importamos para eventos de teclado
import 'package:finora/navigation_rail.dart';
import 'package:finora/providers/pagos_provider.dart';
import 'package:finora/screens/login.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart'; // Para manejar la ventana
import 'constants/routes.dart';

// Provider para gestionar el factor de escala dinámicamente
class ScaleProvider extends ChangeNotifier {
  double _scaleFactor;

  ScaleProvider(this._scaleFactor);

  double get scaleFactor => _scaleFactor;

  void setScaleFactor(double newScale) {
    _scaleFactor = newScale;
    notifyListeners();
  }
}

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
        ChangeNotifierProvider(create: (_) => ScaleProvider(scaleFactor)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // Añade esto
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Obtener el provider de escala
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider

    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          // Verificar si Control está presionado
          final bool isControlPressed = event.isControlPressed;

          if (isControlPressed) {
            double currentScale = scaleProvider.scaleFactor;

            // Teclas normales
            if (event.logicalKey == LogicalKeyboardKey.equal ||
                event.logicalKey == LogicalKeyboardKey.add) {
              // Control + Plus: Aumentar zoom
              double newScale = currentScale + 0.1;
              if (newScale <= 2.5) {
                // Límite superior
                scaleProvider.setScaleFactor(newScale);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.minus) {
              // Control + Minus: Disminuir zoom
              double newScale = currentScale - 0.1;
              if (newScale >= 0.5) {
                // Límite inferior
                scaleProvider.setScaleFactor(newScale);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
              // Control + 0: Resetear zoom a 1.4 (valor original)
              scaleProvider.setScaleFactor(1.4);
            }

            // Teclas numéricas
            else if (event.logicalKey == LogicalKeyboardKey.numpadAdd) {
              // Control + NumpadPlus
              double newScale = currentScale + 0.1;
              if (newScale <= 2.5) {
                scaleProvider.setScaleFactor(newScale);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
              // Control + NumpadMinus
              double newScale = currentScale - 0.1;
              if (newScale >= 0.5) {
                scaleProvider.setScaleFactor(newScale);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.numpad0) {
              // Control + Numpad0
              scaleProvider.setScaleFactor(1.4);
            }
          }
        }
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaleFactor: scaleProvider.scaleFactor,
          devicePixelRatio: scaleProvider.scaleFactor,
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
                  scaleFactor: scaleProvider.scaleFactor,
                ),
              );
            }
            return _errorRoute();
          },
          debugShowCheckedModeBanner: false,
          theme: themeProvider.isDarkMode
              ? ThemeData.dark()
              : ThemeData.light(), // Cambia el tema dinámicamente
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
