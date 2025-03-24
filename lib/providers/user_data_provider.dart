// providers/user_data_provider.dart
import 'package:flutter/material.dart';

class UserDataProvider extends ChangeNotifier {
  String _nombreFinanciera = '';
  List<dynamic> _imagenes = [];
  String _nombreUsuario = '';
  String _tipoUsuario = '';
  String _idfinanciera = '';

  // Getters
  String get nombreFinanciera => _nombreFinanciera;
  List<dynamic> get imagenes => _imagenes;
  String get nombreUsuario => _nombreUsuario;
  String get tipoUsuario => _tipoUsuario;
  String get idfinanciera => _idfinanciera;

  // Setters
  void setUserData({
    required String nombreFinanciera,
    required List<dynamic> imagenes,
    required String nombreUsuario,
    required String tipoUsuario,
    required String idfinanciera,
  }) {
    _nombreFinanciera = nombreFinanciera;
    _imagenes = imagenes;
    _nombreUsuario = nombreUsuario;
    _tipoUsuario = tipoUsuario;
    _idfinanciera = idfinanciera;
    notifyListeners(); // Notifica a los listeners que los datos han cambiado
  }
}