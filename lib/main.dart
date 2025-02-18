import 'package:flutter/material.dart';
import 'package:finora/navigation_rail.dart';
import 'package:finora/providers/pagos_provider.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'constants/routes.dart'; // Añade esta importación

void main() async {
  await initializeDateFormatting('es');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PagosProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      initialRoute: AppRoutes.login, // Ruta inicial
      routes: {
        AppRoutes.login: (context) => LoginScreen(),
      },
      onGenerateRoute: (settings) {
  // Manejo seguro del tipo
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
      ),
    );
  }
  return _errorRoute();
},
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff6750a4),
        useMaterial3: true,
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