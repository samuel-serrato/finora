// providers/user_data_provider.dart
import 'package:finora/ip.dart';
import 'package:finora/models/image_data.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserDataProvider extends ChangeNotifier {
  String _nombreNegocio = '';
  List<ImageData> _imagenes = []; // Cambia a List<ImageData>
  String _nombreUsuario = '';
  String _tipoUsuario = '';
  String _idnegocio = '';
  String _idusuario = '';
  double _redondeo = 0;

  // Getters
  String get nombreNegocio => _nombreNegocio;
  List<ImageData> get imagenes => _imagenes; // Cambia el tipo de retorno
  String get nombreUsuario => _nombreUsuario;
  String get tipoUsuario => _tipoUsuario;
  String get idnegocio => _idnegocio;
  String get idusuario => _idusuario;
  double get redondeo => _redondeo;

  // <<< AÑADE ESTE GETTER
  // Devuelve `true` si el _idusuario NO está vacío, `false` en caso contrario.
  bool get isLoggedIn => _idusuario.isNotEmpty;

  // Setters
  void setUserData({
    required String nombreNegocio,
    required List<ImageData> imagenes, // Cambia el tipo del parámetro
    required String nombreUsuario,
    required String tipoUsuario,
    required String idnegocio,
    required String idusuario,
    required double redondeo,
  }) {
    _nombreNegocio = nombreNegocio;
    _imagenes = imagenes;
    _nombreUsuario = nombreUsuario;
    _tipoUsuario = tipoUsuario;
    _idnegocio = idnegocio;
    _idusuario = idusuario;
    _redondeo = redondeo;
    notifyListeners(); // Notifica a los listeners que los datos han cambiado
  }

  // <<< OPCIONAL PERO RECOMENDADO: Un método para limpiar los datos al cerrar sesión
  void clearUserData() {
    _nombreNegocio = '';
    _imagenes = [];
    _nombreUsuario = '';
    _tipoUsuario = '';
    _idnegocio = '';
    _idusuario = '';
    _redondeo = 0;
    notifyListeners();
  }

  // ---  NUEVO MÉTODO DE LOGOUT CENTRALIZADO ---
  // Devuelve `true` si el logout fue exitoso, `false` si no.
  Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    // Si no hay token, no podemos hacer logout en el servidor,
    // pero sí podemos limpiar los datos locales.
    if (token.isEmpty) {
      await prefs.remove('tokenauth');
      clearUserData();
      return true;
    }

    try {
      // Llamada al API para invalidar el token en el backend
      await http.post(
        Uri.parse('$baseUrl/api/v1/auth/logout'),
        headers: {'tokenauth': token},
      );
    } catch (e) {
      // Si hay un error de conexión, lo imprimimos en la consola.
      // Aún así, procederemos a limpiar los datos locales.
      print('Error de conexión durante el logout: $e');
    } finally {
      // ESTO SE EJECUTA SIEMPRE (con éxito o con error de API).
      // Es la forma más segura de garantizar que el usuario quede deslogueado en el dispositivo.
      await prefs.remove('tokenauth');
      clearUserData(); // Limpia los datos del provider y notifica a los listeners.
      print('Datos locales y token eliminados.');
    }
    return true; // Asumimos éxito si se limpiaron los datos locales.
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
      _imagenes[index] =
          ImageData(tipoImagen: tipoImagen, rutaImagen: nuevaRuta);
    } else {
      _imagenes.add(ImageData(tipoImagen: tipoImagen, rutaImagen: nuevaRuta));
    }
    notifyListeners();
  }

  // Nuevo método para actualizar datos específicos
  void actualizarDatosUsuario({
    String? nombreCompleto,
    String? tipoUsuario,
    String? email,
  }) {
    if (nombreCompleto != null) {
      _nombreUsuario = nombreCompleto;
    }
    if (tipoUsuario != null) {
      _tipoUsuario = tipoUsuario;
    }
    // Puedes añadir más campos según sea necesario
    notifyListeners(); // Notifica a los listeners que los datos han cambiado
  }

  void actualizarRedondeo(double nuevoRedondeo) {
    _redondeo = nuevoRedondeo;
    notifyListeners();
  }
}
