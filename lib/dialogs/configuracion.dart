import 'dart:io';
import 'package:finora/main.dart';
import 'package:finora/providers/logo_provider.dart';
import 'package:flutter/material.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracionDialog extends StatefulWidget {
  @override
  _ConfiguracionDialogState createState() => _ConfiguracionDialogState();
}

class _ConfiguracionDialogState extends State<ConfiguracionDialog> {
  bool notificationsEnabled = true;
  bool dataSync = true;
  String selectedLanguage = 'Español';
  File? _logoImage;
  String? _logoImagePath;
  bool _isLoading = false;
  String? _tempLogoPath; // Ruta temporal para previsualización
  bool _hasPendingChanges = false; // Para controlar cambios no guardados

  @override
  void initState() {
    super.initState();
    _loadSavedLogo();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;

    return AlertDialog(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.12,
        vertical: size.height * 0.12,
      ),
      content: Container(
        width: size.width * 0.75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(context, title: 'Apariencia', items: [
                        _buildSwitchItem(
                          context,
                          title: 'Modo oscuro',
                          value: isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleDarkMode(value);
                          },
                          icon: Icons.dark_mode,
                          iconColor: Colors.purple,
                        ),
                      ]),
                      SizedBox(height: 15),
                      _buildSection(context,
                          title: 'Zoom',
                          items: [
                            _buildZoomSlider(context, scaleProvider),
                          ],
                          isExpandable: true),
                      SizedBox(height: 15),
                      /* _buildSection(context, title: 'Notificaciones', items: [
                        _buildSwitchItem(
                          context,
                          title: 'Activar notificaciones',
                          value: notificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              notificationsEnabled = value;
                            });
                          },
                          icon: Icons.notifications,
                          iconColor: Colors.red,
                        ),
                      ]),
                      SizedBox(height: 15), */
                      _buildSection(context,
                          title: 'Personalización',
                          items: [
                            _buildLogoUploader(context),
                          ],
                          isExpandable: true),
                      SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoUploader(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final logoProvider = Provider.of<LogoProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(0xFF5162F6),
                width: 2,
              ),
            ),
            child: _tempLogoPath != null || _logoImagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_tempLogoPath ?? _logoImagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : Icon(
                    Icons.add_photo_alternate,
                    size: 50,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
          ),
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            _logoImagePath != null
                ? "Logo de la financiera"
                : _tempLogoPath != null
                    ? "Nuevo logo (no guardado)"
                    : "Sin logo",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_tempLogoPath == null)
              ElevatedButton.icon(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5162F6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.photo_camera,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                    _logoImagePath != null ? 'Cambiar logo' : 'Subir logo',
                    style: TextStyle(fontSize: 14)),
              ),
            if (_tempLogoPath != null) ...[
              ElevatedButton.icon(
                onPressed: _saveLogo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.save,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text('Guardar', style: TextStyle(fontSize: 14)),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _tempLogoPath = null;
                  _hasPendingChanges = false;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.cancel,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text('Cancelar', style: TextStyle(fontSize: 14)),
              ),
            ],
            if (_logoImagePath != null && _tempLogoPath == null) ...[
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _deleteLogo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.delete,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text('Eliminar', style: TextStyle(fontSize: 14)),
              ),
            ],
          ],
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            "Formatos permitidos: PNG",
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            "Esta imagen se utilizará como logo de la financiera en la aplicación",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildZoomSlider(BuildContext context, ScaleProvider scaleProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentScale = scaleProvider.scaleFactor;

    // Convertir factor de escala a porcentaje para mostrar
    final scalePercent = (currentScale * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.zoom_out,
                size: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Color(0xFF5162F6),
                  inactiveTrackColor:
                      isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  thumbColor: Color(0xFF5162F6),
                  overlayColor: Color(0xFF5162F6).withOpacity(0.2),
                  trackHeight: 4.0,
                ),
                child: Slider(
                  value: currentScale,
                  min: 0.5,
                  max: 2.5,
                  divisions: 20,
                  onChanged: (value) {
                    scaleProvider.setScaleFactor(value);
                  },
                ),
              ),
            ),
            Icon(Icons.zoom_in,
                size: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
          ],
        ),
        SizedBox(height: 8),
        // Mostrar porcentaje de zoom centrado
        Center(
          child: Text(
            "$scalePercent%",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildZoomButton(context, scaleProvider,
                icon: Icons.remove,
                onPressed: () => _adjustZoom(scaleProvider, -0.1)),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => scaleProvider.setScaleFactor(1.0),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5162F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Restablecer', style: TextStyle(fontSize: 12)),
            ),
            SizedBox(width: 8),
            _buildZoomButton(context, scaleProvider,
                icon: Icons.add,
                onPressed: () => _adjustZoom(scaleProvider, 0.1)),
          ],
        ),
        // Espacio adicional debajo del botón "Restablecer"
        SizedBox(height: 16),
      ],
    );
  }

  void _adjustZoom(ScaleProvider scaleProvider, double amount) {
    double newScale = scaleProvider.scaleFactor + amount;
    // Mantener el zoom dentro de los límites
    if (newScale >= 0.5 && newScale <= 2.5) {
      scaleProvider.setScaleFactor(newScale);
    }
  }

  Widget _buildZoomButton(BuildContext context, ScaleProvider scaleProvider,
      {required IconData icon, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF5162F6),
        foregroundColor: Colors.white,
        padding: EdgeInsets.all(8),
        minimumSize: Size(36, 36),
        maximumSize: Size(36, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Center(
        child: Text(
          'Configuración',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cerrar',
              style: TextStyle(
                color: Color(0xFF5162F6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
    bool isExpandable = false,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: isExpandable
              ? ExpansionTile(
                  title: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: title == 'Zoom'
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          title == 'Zoom' ? Icons.zoom_in : Icons.image,
                          color: title == 'Zoom' ? Colors.blue : Colors.orange,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 14),
                      Text(
                        title == 'Zoom'
                            ? 'Nivel de zoom'
                            : 'Imagen de la financiera',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  children: items,
                  tilePadding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  trailing: Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items,
                ),
        ),
      ],
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required String title,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    required Color iconColor,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Color(0xFF5162F6),
            ),
          ),
        ],
      ),
    );
  }

  // Método modificado para solo seleccionar imagen
  Future<void> _pickImage() async {
    setState(() => _isLoading = true);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
        allowMultiple: false,
      );

      if (result != null) {
        final String filePath = result.files.single.path!;
        if (path.extension(filePath).toLowerCase() != '.png') {
          _showErrorSnackbar('Solo se permiten archivos PNG');
          return;
        }

        setState(() {
          _tempLogoPath = filePath;
          _hasPendingChanges = true;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error al seleccionar imagen: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Nuevo método para guardar cambios
  Future<void> _saveLogo() async {
    if (_tempLogoPath == null) return;

    setState(() => _isLoading = true);

    try {
      final String projectRoot = await _findProjectRoot();
      final Directory uploadDir =
          Directory(path.join(projectRoot, 'assets', 'uploaded'));

      if (!uploadDir.existsSync()) {
        await uploadDir.create(recursive: true);
      }

      const String fixedFileName = 'financiera_logo.png';
      final String destPath = path.join(uploadDir.path, fixedFileName);

      if (File(destPath).existsSync()) {
        await File(destPath).delete();
      }

      await File(_tempLogoPath!).copy(destPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('financiera_logo_path', destPath);

      // Actualizar Provider
      final logoProvider = Provider.of<LogoProvider>(context, listen: false);
      logoProvider.setLogoPath(destPath);

      // Limpiar caché y estado
      imageCache.clear();
      imageCache.clearLiveImages();

      setState(() {
        _logoImagePath = destPath;
        _tempLogoPath = null;
        _hasPendingChanges = false;
      });

      await _updatePubspec(destPath);
    } catch (e) {
      _showErrorSnackbar('Error al guardar: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _findProjectRoot() async {
    Directory currentDir = Directory.current;
    int maxLevels = 10;

    // Busca hacia arriba en la jerarquía de directorios
    while (maxLevels-- > 0) {
      final pubspecFile = File(path.join(currentDir.path, 'pubspec.yaml'));

      // Verifica si existe el pubspec.yaml
      if (await pubspecFile.exists()) {
        return currentDir.path;
      }

      // Sube un nivel si no se encontró
      currentDir = currentDir.parent;
    }

    throw Exception('No se encontró la raíz del proyecto con pubspec.yaml');
  }

  // Método para cargar el logo
  Future<void> _loadSavedLogo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLogoPath = prefs.getString('financiera_logo_path');

    if (savedLogoPath != null && File(savedLogoPath).existsSync()) {
      setState(() {
        _logoImagePath = savedLogoPath;
      });
    }
  }

  // Método para guardar/sobrescribir la imagen
  Future<void> _pickAndSaveImage() async {
    setState(() {
      _isLoading = true;
      _logoImagePath = null; // Forzar actualización visual
    });

    try {
      // 1. Seleccionar imagen solo PNG
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
        allowMultiple: false,
      );

      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Verificar extensión manualmente
      final String filePath = result.files.single.path!;
      if (path.extension(filePath).toLowerCase() != '.png') {
        _showErrorSnackbar('Formato no válido. Solo se permiten archivos PNG');
        setState(() => _isLoading = false);
        return;
      }

      // 3. Obtener rutas del proyecto
      final String projectRoot = await _findProjectRoot();
      final Directory uploadDir =
          Directory(path.join(projectRoot, 'assets', 'uploaded'));

      if (!uploadDir.existsSync()) {
        await uploadDir.create(recursive: true);
      }

      // 4. Generar nombre fijo .png
      const String fixedFileName = 'financiera_logo.png';
      final String destPath = path.join(uploadDir.path, fixedFileName);

      // 5. Eliminar versión anterior
      if (File(destPath).existsSync()) {
        await File(destPath).delete();
      }

      // 6. Copiar archivo
      final File file = File(filePath);
      await file.copy(destPath);

      // 7. Actualizar preferencias
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('financiera_logo_path', destPath);

      // 8. Actualizar UI y limpiar caché
      imageCache.clear();
      imageCache.clearLiveImages();

      setState(() {
        _logoImagePath = destPath;
        _isLoading = false;
      });

      // 9. Actualizar pubspec.yaml
      await _updatePubspec(destPath);
    } catch (e) {
      _showErrorSnackbar('Error al subir el logo: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

// Nuevo método para mostrar errores
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

// Modificar el método _generateFixedFileName
  String _generateFixedFileName(String originalPath) {
    const String baseName = 'financiera_logo';
    return '$baseName.png'; // Fuerza extensión .png
  }

  // Actualizar pubspec.yaml mejorado
  Future<void> _updatePubspec(String imagePath) async {
    try {
      final pubspecFile =
          File(path.join(path.dirname(imagePath), '..', 'pubspec.yaml'));

      final content = await pubspecFile.readAsString();
      final relativePath = path
          .relative(imagePath, from: path.dirname(pubspecFile.path))
          .replaceAll(r'\', r'/');

      final assetEntry = '    - $relativePath';
      final assetsSection = RegExp(r'flutter:\s*assets:');

      if (!content.contains(assetEntry)) {
        final newContent = content.replaceFirst(
            assetsSection, 'flutter:\n  assets:\n$assetEntry');

        await pubspecFile.writeAsString(newContent);
        print('pubspec.yaml actualizado correctamente');
      }
    } catch (e) {
      print('Error actualizando pubspec: $e');
    }
  }

  // Método para eliminar el logo
  Future<void> _deleteLogo() async {
    try {
      final logoProvider = Provider.of<LogoProvider>(context, listen: false);

      if (_logoImagePath != null) {
        final file = File(_logoImagePath!);
        if (await file.exists()) await file.delete();
        await _removeFromPubspec(_logoImagePath!);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('financiera_logo_path');

      logoProvider.clearLogo();

      setState(() => _logoImagePath = null);
    } catch (e) {
      _showErrorSnackbar('Error al eliminar: $e');
    }
  }

  // Nuevo método para remover del pubspec.yaml
  Future<void> _removeFromPubspec(String imagePath) async {
    try {
      final pubspecFile =
          File(path.join(path.dirname(imagePath), '..', 'pubspec.yaml'));

      final content = await pubspecFile.readAsString();
      final relativePath = path
          .relative(imagePath, from: path.dirname(pubspecFile.path))
          .replaceAll(r'\', r'/');

      final assetEntry = RegExp(r'^\s*-\s*' + relativePath, multiLine: true);

      final newContent = content.replaceAll(assetEntry, '');
      await pubspecFile.writeAsString(newContent);

      print('Entrada removida del pubspec.yaml');
    } catch (e) {
      print('Error removiendo del pubspec: $e');
    }
  }
}
