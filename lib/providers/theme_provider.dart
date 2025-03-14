import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  static const String _darkModeKey =
      'dark_mode'; // Clave para SharedPreferences

  ThemeProvider() {
    // Cargamos el tema guardado al inicializar
    _loadSavedTheme();
  }

  bool get isDarkMode => _isDarkMode;

  // Método para cargar el tema guardado
  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    notifyListeners();
  }

  // Mantenemos tu método original pero añadimos la persistencia
  void toggleDarkMode(bool isDarkMode) async {
    _isDarkMode = isDarkMode;
    notifyListeners();

    // Guardar en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _isDarkMode);
  }
}
