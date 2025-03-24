import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:finora/ip.dart';
import 'package:finora/main.dart';
import 'package:finora/providers/logo_provider.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Para MediaType

class ConfiguracionDialog extends StatefulWidget {
  @override
  _ConfiguracionDialogState createState() => _ConfiguracionDialogState();
}

class _ConfiguracionDialogState extends State<ConfiguracionDialog> {
  bool notificationsEnabled = true;
  bool dataSync = true;
  String selectedLanguage = 'Español';

  // Variables para el manejo de imágenes
  String? _tempColorLogoPath;
  String? _colorLogoImagePath;
  String? _tempWhiteLogoPath;
  String? _whiteLogoImagePath;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLogos();
  }

  // Cargar los logos guardados previamente
  Future<void> _loadSavedLogos() async {
    final logoProvider = Provider.of<LogoProvider>(context, listen: false);

    setState(() {
      _colorLogoImagePath = logoProvider.colorLogoPath;
      _whiteLogoImagePath = logoProvider.whiteLogoPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final userData = Provider.of<UserDataProvider>(context); // Nuevo
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
                      _buildFinancialInfoBlock(
                          context), // Nuevo bloque agregado aquí

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

        // Fila que contiene ambos logos
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo a color (modo claro) - Columna izquierda
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Logo a color (modo claro)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Container(
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
                    child: _tempColorLogoPath != null ||
                            _colorLogoImagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_tempColorLogoPath ?? _colorLogoImagePath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _colorLogoImagePath != null
                        ? "Logo a color guardado"
                        : _tempColorLogoPath != null
                            ? "Nuevo logo a color (no guardado)"
                            : "Sin logo a color",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploading && _tempColorLogoPath != null)
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF5162F6)),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () => _pickAndUploadLogo("logoColor"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF5162F6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
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
                              _colorLogoImagePath != null ? 'Cambiar' : 'Subir',
                              style: TextStyle(fontSize: 14)),
                        ),
                      if (_colorLogoImagePath != null &&
                          _tempColorLogoPath == null) ...[
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _colorLogoImagePath = null;
                            });
                            // Eliminar el logo en el provider
                            logoProvider.setColorLogoPath(null);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            Icons.delete,
                            size: 16,
                            color: Colors.white,
                          ),
                          label:
                              Text('Eliminar', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Separador vertical
            SizedBox(width: 20),
            Container(
              height: 250,
              width: 1,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            SizedBox(width: 20),

            // Logo blanco (modo oscuro) - Columna derecha
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Logo blanco (modo oscuro)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      // Fondo oscuro para visualizar mejor el logo blanco
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFF5162F6),
                        width: 2,
                      ),
                    ),
                    child: _tempWhiteLogoPath != null ||
                            _whiteLogoImagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_tempWhiteLogoPath ?? _whiteLogoImagePath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _whiteLogoImagePath != null
                        ? "Logo blanco guardado"
                        : _tempWhiteLogoPath != null
                            ? "Nuevo logo blanco (no guardado)"
                            : "Sin logo blanco",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploading && _tempWhiteLogoPath != null)
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF5162F6)),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () => _pickAndUploadLogo("logoBlanco"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF5162F6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
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
                              _whiteLogoImagePath != null ? 'Cambiar' : 'Subir',
                              style: TextStyle(fontSize: 14)),
                        ),
                      if (_whiteLogoImagePath != null &&
                          _tempWhiteLogoPath == null) ...[
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _whiteLogoImagePath = null;
                            });
                            // Eliminar el logo en el provider
                            logoProvider.setWhiteLogoPath(null);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            Icons.delete,
                            size: 16,
                            color: Colors.white,
                          ),
                          label:
                              Text('Eliminar', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 24),

        // Botones para guardar ambos logos si hay cambios pendientes
        if (_tempColorLogoPath != null || _tempWhiteLogoPath != null) ...[
          Divider(),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSaving)
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                )
              else
                ElevatedButton.icon(
                  onPressed: _saveLogoChanges,
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
                  label:
                      Text('Guardar cambios', style: TextStyle(fontSize: 14)),
                ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _cancelLogoChanges,
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
          ),
        ],

        SizedBox(height: 16),
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
            "Estas imágenes se utilizarán como logos de la financiera en la aplicación según el modo de visualización",
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

  Widget _buildFinancialInfoBlock(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userData = Provider.of<UserDataProvider>(context); // Nuevo
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 20, bottom: 30, left: 0, right: 0),
        child: Row(
          children: [
            // Contenedor para la imagen del logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: null != null
                    ? Image.file(
                        null!,
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        Icons.account_balance,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData.nombreFinanciera,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Financiera',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadLogo(String tipoLogo) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (result != null && result.files.isNotEmpty) {
        // Solo guarda la ruta temporal para previsualización
        String tempPath = result.files.single.path!;

        setState(() {
          if (tipoLogo == "logoColor") {
            _tempColorLogoPath = tempPath; // Vista previa modo claro
          } else {
            _tempWhiteLogoPath = tempPath; // Vista previa modo oscuro
          }
        });
      }
    } catch (e) {
      print('Error al seleccionar el logo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar el archivo')),
      );
    }
  }

// Función para guardar los cambios pendientes (cuando hay imagenes temporales)
  Future<void> _saveLogoChanges() async {
    try {
      setState(() => _isSaving = true);

      if (_tempColorLogoPath != null) {
        await _uploadLogoToServer(_tempColorLogoPath!, "logoColor");
        setState(() => _colorLogoImagePath = _tempColorLogoPath);
      }

      if (_tempWhiteLogoPath != null) {
        await _uploadLogoToServer(_tempWhiteLogoPath!, "logoBlanco");
        setState(() => _whiteLogoImagePath = _tempWhiteLogoPath);
      }

      // Limpiar temporales
      setState(() {
        _tempColorLogoPath = null;
        _tempWhiteLogoPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo guardado correctamente'), 
        backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

// Función para subir un logo ya seleccionado
  Future<void> _uploadLogoToServer(
    String filePath,
    String tipoLogo,
  ) async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);

    try {
      // 1. Crear solicitud
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://$baseUrl/api/v1/imagenes/subir/logo'),
      );

      // 2. Adjuntar archivo
      File file = File(filePath);
      String fileName = path.basename(file.path);
      request.files.add(
        await http.MultipartFile.fromPath(
          'imagen',
          file.path,
          filename: fileName,
          contentType: MediaType('image', 'png'),
        ),
      );

      // 3. Adjuntar campos
      request.fields.addAll({
        'tipoImagen': tipoLogo,
        'idfinanciera': userData.idfinanciera,
      });

      // 4. Imprimir detalles de la solicitud ANTES de enviar
      print('\n=== PETICIÓN ===');
      print('URL: ${request.url}');
      print('Método: ${request.method}');
      print('Headers: ${request.headers}');
      print('Campos: ${request.fields}');
      print('Archivos: ${request.files.map((f) => f.filename).toList()}');

      // 5. Enviar y capturar respuesta
      http.StreamedResponse response =
          await request.send().timeout(Duration(seconds: 30));

      // 6. Leer cuerpo de la respuesta
      String responseBody = await response.stream.bytesToString();

      // 7. Imprimir detalles de la respuesta
      print('\n=== RESPUESTA ===');
      print('Status: ${response.statusCode}');
      print('Headers: ${response.headers}');
      print('Body: $responseBody');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('Error de red: $e');
      throw Exception('Verifica tu conexión a internet');
    } on TimeoutException {
      print('Tiempo de espera agotado');
      throw Exception('El servidor no respondió a tiempo');
    } catch (e) {
      print('Error inesperado: $e');
      rethrow;
    }
  }

// Función para cancelar los cambios
  void _cancelLogoChanges() {
    setState(() {
      _tempColorLogoPath = null;
      _tempWhiteLogoPath = null;
    });
  }
}
