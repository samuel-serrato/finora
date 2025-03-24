// providers/user_data_provider.dart
import 'package:finora/models/image_data.dart';
import 'package:flutter/material.dart';

class UserDataProvider extends ChangeNotifier {
  String _nombreFinanciera = '';
  List<ImageData>   _imagenes = []; // Cambia a List<ImageData>
  String _nombreUsuario = '';
  String _tipoUsuario = '';
  String _idfinanciera = '';

  // Getters
  String get nombreFinanciera => _nombreFinanciera;
  List<ImageData> get imagenes => _imagenes; // Cambia el tipo de retorno
  String get nombreUsuario => _nombreUsuario;
  String get tipoUsuario => _tipoUsuario;
  String get idfinanciera => _idfinanciera;

  // Setters
  void setUserData({
    required String nombreFinanciera,
    required List<ImageData> imagenes, // Cambia el tipo del parámetro
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

  // En el UserDataProvider, añade este método
ImageData? getLogoForTheme(bool isDarkMode) {
  final String targetType = isDarkMode ? 'logoBlanco' : 'logoColor';
  try {
    return _imagenes.firstWhere((img) => img.tipoImagen == targetType);
  } catch (e) {
    // Fallback al otro tipo si no encuentra el solicitado
    final String fallbackType = isDarkMode ? 'logoColor' : 'logoBlanco';
    try {
      return _imagenes.firstWhere((img) => img.tipoImagen == fallbackType);
    } catch (e) {
      return null;
    }
  }
}

void actualizarLogo(String tipoImagen, String nuevaRuta) {
  final index = _imagenes.indexWhere((img) => img.tipoImagen == tipoImagen);
  if (index != -1) {
    _imagenes[index] = ImageData(tipoImagen: tipoImagen, rutaImagen: nuevaRuta);
  } else {
    _imagenes.add(ImageData(tipoImagen: tipoImagen, rutaImagen: nuevaRuta));
  }
  notifyListeners();
}


}