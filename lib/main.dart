import 'package:flutter/material.dart';
import 'package:money_facil/navigation_rail.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // Inicializa los datos de localización para formato de fechas
  await initializeDateFormatting('es'); // 'es' para español

  // Lanza la aplicación Flutter
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NavigationScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff6750a4),
        useMaterial3: true,
      ),
    );
  }
}
