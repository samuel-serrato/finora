import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogoProvider extends ChangeNotifier {
  String? _logoPath;
  int _version = 0; // Nuevo contador de versión

  String? get logoPath => _logoPath;
  int get version => _version; // Getter para la versión

  void setLogoPath(String path) {
    _logoPath = path;
    _version++; // Incrementar versión al actualizar
    notifyListeners();
  }

  Future<void> loadLogoPath() async {
    final prefs = await SharedPreferences.getInstance();
    _logoPath = prefs.getString('financiera_logo_path');
    notifyListeners(); // Notificar para reconstruir la UI
  }

  void updateLogoPath(String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('financiera_logo_path', newPath);
    _logoPath = newPath;
    _version++;
    notifyListeners();
  }

  void clearLogo() {
    _logoPath = null;
    _version++; // Incrementar versión al eliminar
    notifyListeners();
  }
}
