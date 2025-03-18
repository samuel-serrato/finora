import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class ImageSaver {
  static Future<String?> _getProjectAssetsPath() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Intentar obtener ruta guardada
    final savedPath = prefs.getString('assets_path');
    if (savedPath != null && Directory(savedPath).existsSync()) {
      return savedPath;
    }

    // 2. Pedir al usuario que seleccione la carpeta assets
    final String? newPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecciona la carpeta "assets" de tu proyecto',
    );

    if (newPath != null) {
      await prefs.setString('assets_path', newPath);
      return newPath;
    }

    return null;
  }

  static Future<String?> saveImageToProjectAssets() async {
    try {
      // Seleccionar imagen
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null) return null;

      // Obtener ruta de assets
      final assetsPath = await _getProjectAssetsPath();
      if (assetsPath == null) throw Exception('Ruta no seleccionada');

      // Crear directorio si no existe
      final uploadDir = Directory(path.join(assetsPath, 'uploaded'));
      if (!uploadDir.existsSync()) {
        await uploadDir.create(recursive: true);
      }

      // Copiar archivo
      final File file = File(result.files.single.path!);
      final String fileName = path.basename(file.path);
      final String destPath = path.join(uploadDir.path, fileName);

      await file.copy(destPath);

      return destPath;
    } catch (e) {
      print('Error al guardar: $e');
      return null;
    }
  }
}
