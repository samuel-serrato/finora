import 'dart:convert';
import 'dart:io';

import 'package:finora/ip.dart';
import 'package:finora/providers/logo_provider.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:finora/utils/localVersion.dart';
import 'package:finora/widgets/DownloadProgressDialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finora/navigation_rail.dart';
import 'package:finora/providers/pagos_provider.dart';
import 'package:finora/screens/login.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'constants/routes.dart';
import 'package:http/http.dart' as http;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ScaleProvider extends ChangeNotifier {
  double _scaleFactor;
  static const String _scaleFactorKey = 'scale_factor';

  ScaleProvider(this._scaleFactor);

  double get scaleFactor => _scaleFactor;

  Future<void> loadSavedScale() async {
    // Aquí sigue usando SharedPreferences si quieres mantener el scale guardado
    // pero la versión ya no se guarda ahí.
    final prefs = await SharedPreferences.getInstance();
    _scaleFactor = prefs.getDouble(_scaleFactorKey) ?? _scaleFactor;
    notifyListeners();
  }

  void setScaleFactor(double newScale) async {
    _scaleFactor = newScale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scaleFactorKey, newScale);
  }
}

/// Compara versiones (se asume formato X.Y.Z)
bool isNewVersionAvailable(String localVersion, String remoteVersion) {
  List<int> local = localVersion.split('.').map((e) => int.parse(e)).toList();
  List<int> remote = remoteVersion.split('.').map((e) => int.parse(e)).toList();

  for (int i = 0; i < remote.length; i++) {
    int remotePart = remote[i];
    int localPart = i < local.length ? local[i] : 0;

    if (remotePart > localPart) return true;
    if (remotePart < localPart) return false;
  }
  return false;
}

/// Muestra el diálogo de actualización
void showUpdateDialog(
    BuildContext context, String newVersion, String downloadUrl) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
      final width = MediaQuery.of(context).size.width * 0.3;
      final height = MediaQuery.of(context).size.height * 0.35;

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(24),
          constraints:
              BoxConstraints(maxHeight: height, minHeight: 150, minWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_download_outlined,
                color: isDarkMode ? Colors.blueAccent : Colors.blueAccent,
                size: 70,
              ),
              const SizedBox(height: 10),
              Text(
                'Nueva actualización disponible',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.blueAccent.withOpacity(0.1)
                      : Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Versión $newVersion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.blueAccent.shade200
                        : Colors.blueAccent.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    ),
                    child: const Text('Más tarde'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => DownloadProgressDialog(
                          downloadUrl:
                              'http://$baseUrl/descargar' + downloadUrl,
                          version: newVersion,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDarkMode ? Colors.blueAccent : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Actualizar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Verifica la versión de la app consultando el API y compara con la versión local
Future<void> checkAppVersion() async {
  try {
    final response = await http.get(
      Uri.parse('http://$baseUrl/api/v1/buscar/version'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final remoteVersion = data['version'] as String;
      final downloadUrl = data['downloadUrl'] as String;
      final localVersion = await getLocalVersion();

      if (isNewVersionAvailable(localVersion, remoteVersion)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showUpdateDialog(
            navigatorKey.currentContext!,
            remoteVersion,
            downloadUrl,
          );
        });
      }
    }
  } catch (e) {
    print('Error al verificar versión: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logoProvider = LogoProvider();

  await initializeDateFormatting('es_ES', null);
  Intl.defaultLocale = 'es_ES';
  await windowManager.ensureInitialized();

  // Configuración de escala
  double systemScale = await windowManager.getDevicePixelRatio();
  // Ya no se usa SharedPreferences para guardar la versión,
  // pero seguimos usándolo para la escala
  final prefs = await SharedPreferences.getInstance();

  double savedScale = prefs.getDouble('scale_factor') ?? 0.0;
  double initialScale = savedScale > 0.0
      ? savedScale
      : (systemScale < 1.4 ? 1.4 / systemScale : 1.0);

  if (initialScale > 1.0) {
    Size screenSize = await windowManager.getSize();
    await windowManager.setSize(Size(
        screenSize.width * initialScale, screenSize.height * initialScale));
  }

  // Verificar versión antes de iniciar la app
  await checkAppVersion();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PagosProvider()),
        ChangeNotifierProvider(create: (_) => ScaleProvider(initialScale)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => logoProvider),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          final bool isControlPressed = event.isControlPressed;
          double currentScale = scaleProvider.scaleFactor;

          if (isControlPressed) {
            if (event.logicalKey == LogicalKeyboardKey.equal ||
                event.logicalKey == LogicalKeyboardKey.add ||
                event.logicalKey == LogicalKeyboardKey.numpadAdd) {
              double newScale = currentScale + 0.1;
              if (newScale <= 2.5) scaleProvider.setScaleFactor(newScale);
            } else if (event.logicalKey == LogicalKeyboardKey.minus ||
                event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
              double newScale = currentScale - 0.1;
              if (newScale >= 0.5) scaleProvider.setScaleFactor(newScale);
            } else if (event.logicalKey == LogicalKeyboardKey.digit0 ||
                event.logicalKey == LogicalKeyboardKey.numpad0) {
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
          navigatorKey: navigatorKey,
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
              return MaterialPageRoute(
                builder: (context) =>
                    NavigationScreen(scaleFactor: scaleProvider.scaleFactor),
              );
            }
            return _errorRoute();
          },
          debugShowCheckedModeBanner: false,
          theme:
              themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
        ),
      ),
    );
  }
}

Route<dynamic> _errorRoute() {
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      body: Center(child: Text('Error de navegación')),
    ),
  );
}
