import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:finora/dialogs/configuracion_credito_widget.dart';
import 'package:finora/ip.dart';
import 'package:finora/main.dart';
import 'package:finora/models/cuenta_bancaria.dart';
import 'package:finora/providers/logo_provider.dart';
import 'package:finora/providers/user_data_provider.dart';
import 'package:finora/widgets/cambiar_contraseña.dart';
import 'package:flutter/material.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/services.dart';
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
  double? _roundingThreshold;

  // Agrega estas variables nuevas
  List<CuentaBancaria> _cuentasBancarias = [];
  bool _loadingCuentas = false;

  // NUEVO: Estado para controlar la vista del submenú
  bool _showCreditSettings = false;

  void initState() {
    super.initState();

    // Espera a que el contexto esté listo y asigna el valor inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        _roundingThreshold =
            userData.redondeo ?? 0.5; // Valor por defecto si es null
      });
    });

    _loadSavedLogos();
    _fetchCuentasBancarias();
  }

  // Cargar los logos guardados previamente
  Future<void> _loadSavedLogos() async {
    final logoProvider = Provider.of<LogoProvider>(context, listen: false);

    setState(() {
      _colorLogoImagePath = logoProvider.colorLogoPath;
      _whiteLogoImagePath = logoProvider.whiteLogoPath;
    });
  }

  // Nueva función genérica para construir items de configuración
  Widget _buildConfigItem(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData? leadingIcon,
    Widget?
        leadingWidget, // Para casos donde un IconData no es suficiente (ej. Imagen)
    Color? iconColor, // Color para el icono y su fondo
    Widget? trailing, // El widget que va al final (Switch, Button, etc.)
    VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
    bool enabled = true,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Determinar el color del ícono por defecto si no se provee
    final effectiveIconColor = iconColor ?? Color(0xFF5162F6);

    Widget leadingContent;
    if (leadingWidget != null) {
      leadingContent = leadingWidget;
    } else if (leadingIcon != null) {
      leadingContent = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? effectiveIconColor.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          leadingIcon,
          color: enabled ? effectiveIconColor : Colors.grey,
          size: 18,
        ),
      );
    } else {
      // Si no hay ícono ni widget líder, dejamos un espacio para mantener la alineación
      leadingContent = SizedBox(width: 14); // Ajusta este valor si es necesario
    }

    Widget titleWidget = Text(
      title,
      style: titleStyle ??
          TextStyle(
            color: enabled
                ? (isDarkMode ? Colors.white : Colors.black)
                : Colors.grey,
            fontSize: 16,
            //fontWeight: FontWeight.w500, // Un poco más de peso para el título
          ),
    );

    Widget? subtitleWidget = subtitle != null
        ? Text(
            subtitle,
            style: subtitleStyle ??
                TextStyle(
                  color: enabled
                      ? (isDarkMode ? Colors.grey[400] : Colors.grey[600])
                      : Colors.grey[700],
                  fontSize: 14,
                ),
          )
        : null;

    // Widget principal que contiene todo
    Widget itemContent = Row(
      children: [
        leadingContent,
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment
                .center, // Centrar verticalmente si hay subtítulo
            children: [
              titleWidget,
              if (subtitleWidget != null) ...[
                SizedBox(height: 2), // Pequeño espacio entre título y subtítulo
                subtitleWidget,
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );

    // Envolver en IgnorePointer y Opacity si no está habilitado
    // Envolver en InkWell si hay onTap
    Widget finalWidget = Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: itemContent,
    );

    if (onTap != null) {
      finalWidget = InkWell(
        onTap: enabled ? onTap : null,
        child: finalWidget,
        borderRadius: BorderRadius.circular(
            8), // Para que el ripple effect coincida con el contenedor
      );
    }

    if (!enabled) {
      return IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: 0.5, // Atenuar visualmente
          child: finalWidget,
        ),
      );
    }

    return finalWidget;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.80;
    final height = size.height * 0.85;

    return AlertDialog(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: size.height * 0.05,
      ),
      content: Container(
        width: width,
        height: height,
        child: Column(
          children: [
            // El header ahora es dinámico y muestra el botón de retroceso
            _buildHeader(
              context,
              title: _showCreditSettings
                  ? 'Configuración de Crédito'
                  : 'Configuración',
              onBack: _showCreditSettings
                  ? () {
                      setState(() {
                        _showCreditSettings = false;
                      });
                    }
                  : null, // No hay botón de retroceso en la pantalla principal
            ),
            Expanded(
              child: ClipRRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final offsetAnimation = Tween<Offset>(
                      begin: Offset(
                          child.key == const ValueKey('credit_settings')
                              ? 1.0
                              : -1.0,
                          0.0),
                      end: Offset.zero,
                    ).animate(animation);

                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: _showCreditSettings
                      ? ConfiguracionCreditoWidget(
                          key: const ValueKey('credit_settings'),
                          initialRoundingValue: _roundingThreshold!,
                          onSave: (newValue) {
                            // Actualizar el valor local y el provider
                            final userDataProvider =
                                Provider.of<UserDataProvider>(context,
                                    listen: false);
                            userDataProvider.actualizarRedondeo(newValue);
                            setState(() {
                              _roundingThreshold = newValue;
                              // Regresar a la pantalla anterior después de guardar
                              _showCreditSettings = false;
                            });
                          },
                        )
                      : _buildMainSettings(
                          key: const ValueKey('main_settings'),
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

  // NUEVO: Widget que contiene el menú principal de configuración
  Widget _buildMainSettings({Key? key}) {
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userData = Provider.of<UserDataProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return CustomScrollView(
        key: key,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildFinancialInfoBlock(context),
                  _buildUserSection(context),
                  const SizedBox(height: 15),

                  _buildSection(
                    context,
                    title: 'Apariencia',
                    items: [
                      _buildConfigItem(
                        context,
                        title: 'Modo oscuro',
                        leadingIcon: Icons.dark_mode,
                        iconColor: Colors.purple,
                        trailing: Transform.scale(
                          scale: 0.8,
                          child: Switch.adaptive(
                            value: isDarkMode,
                            onChanged: (value) {
                              themeProvider.toggleDarkMode(value);
                            },
                            activeColor: const Color(0xFF5162F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildSection(
                    context,
                    title: 'Zoom',
                    items: [_buildZoomSlider(context, scaleProvider)],
                    isExpandable: true,
                  ),
                  const SizedBox(height: 15),
                  _buildSection(
                    context,
                    title: 'Personalizar logo',
                    items: [_buildLogoUploader(context)],
                    isExpandable: true,
                    enabled: userData.tipoUsuario == 'Admin' ||
                        userData.tipoUsuario == 'Contador',
                  ),
                  const SizedBox(height: 15),
                  _buildBankAccountsSection(context),
                  const SizedBox(height: 15),

                  // ---- MODIFICACIÓN PRINCIPAL AQUÍ ----
                  // Ahora es un item de configuración que navega
                  _buildSection(
                    context,
                    title: 'Crédito', // Título de la sección general
                    items: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: _buildConfigItem(context,
                            title: 'Configuración de crédito',
                            //subtitle: 'Define el redondeo para los créditos',
                            leadingIcon: Icons.monetization_on,
                            iconColor: Colors.teal, onTap: () {
                          setState(() {
                            _showCreditSettings = true;
                          });
                        },
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            enabled: userData.tipoUsuario == 'Admin' ||
                                userData.tipoUsuario == 'Contador'),
                      ),
                    ],
                    enabled: userData.tipoUsuario == 'Admin' ||
                        userData.tipoUsuario == 'Contador',
                  ),
                ],
              ),
            ),
          ),
        ]);
  }

  Widget _buildLogoUploader(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final logoProvider = Provider.of<LogoProvider>(context);
    final userData = Provider.of<UserDataProvider>(context);

    bool isAdmin = userData.tipoUsuario == 'Admin';

// Depuración: Imprimir todas las imágenes para verificar
    print("Número de imágenes: ${userData.imagenes.length}");
    userData.imagenes.forEach((img) {
      print("Tipo de imagen: ${img.tipoImagen}, Ruta: ${img.rutaImagen}");
    });

    final colorLogo = userData.imagenes
        .where((img) => img.tipoImagen == 'logoColor')
        .firstOrNull;
    final whiteLogo = userData.imagenes
        .where((img) => img.tipoImagen == 'logoBlanco')
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color Logo (Light Mode)
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
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFF5162F6),
                        width: 2,
                      ),
                    ),
                    child: _tempColorLogoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_tempColorLogoPath!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : colorLogo != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  '$baseUrl/imagenes/subidas/${colorLogo.rutaImagen}',
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.add_photo_alternate,
                                      size: 50,
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    );
                                  },
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
                    _tempColorLogoPath != null
                        ? "Nuevo logo a color (no guardado)"
                        : colorLogo != null
                            ? "Logo a color guardado"
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
                          onPressed: isAdmin
                              ? () => _pickAndUploadLogo("logoColor")
                              : null,
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
                          label: Text(colorLogo != null ? 'Cambiar' : 'Subir',
                              style: TextStyle(fontSize: 14)),
                        ),
                      if (colorLogo != null && _tempColorLogoPath == null) ...[
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isAdmin ? () {/* ... */} : null,
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

            // Vertical Separator
            SizedBox(width: 20),
            Container(
              height: 250,
              width: 1,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            SizedBox(width: 20),

            // White Logo (Dark Mode)
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
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFF5162F6),
                        width: 2,
                      ),
                    ),
                    child: _tempWhiteLogoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_tempWhiteLogoPath!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : whiteLogo != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  '$baseUrl/imagenes/subidas/${whiteLogo.rutaImagen}',
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.add_photo_alternate,
                                      size: 50,
                                      color: Colors.grey[400],
                                    );
                                  },
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
                    _tempWhiteLogoPath != null
                        ? "Nuevo logo blanco (no guardado)"
                        : whiteLogo != null
                            ? "Logo blanco guardado"
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
                          onPressed: isAdmin
                              ? () => _pickAndUploadLogo("logoBlanco")
                              : null,
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
                          label: Text(whiteLogo != null ? 'Cambiar' : 'Subir',
                              style: TextStyle(fontSize: 14)),
                        ),
                      if (whiteLogo != null && _tempWhiteLogoPath == null) ...[
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isAdmin ? () {/* ... */} : null,
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

        // Botones para guardar ambos logos si hay cambios pendientes
        if ((_tempColorLogoPath != null || _tempWhiteLogoPath != null) &&
            isAdmin) ...[
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

  // Modificamos el header para que pueda cambiar de título

  // ---- FUNCIÓN MODIFICADA ----
  // El header ahora es más inteligente
  // ---- FUNCIÓN CORREGIDA ----
  // Se reemplaza Stack por un Row para un layout más robusto y predecible.
  Widget _buildHeader(BuildContext context,
      {required String title, VoidCallback? onBack}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      // Se mantiene el contenedor principal para el color de fondo y los bordes
      height: 60, // Una altura fija ayuda a la consistencia
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // 1. Espacio izquierdo: Contiene el botón de "atrás" o está vacío.
          //    Tiene un ancho fijo para que el título siempre se alinee igual.
          SizedBox(
            width: 60, // Ancho fijo para el área del botón
            child: onBack != null
                ? Center(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      onPressed: onBack,
                      tooltip: 'Volver',
                    ),
                  )
                : null, // Si no hay callback, no se muestra nada.
          ),

          // 2. Título: Ocupa todo el espacio restante y se centra dentro de él.
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center, // Centra el texto horizontalmente
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 3. Espacio derecho: Un espaciador invisible del mismo tamaño que el izquierdo.
          //    Esto es CRUCIAL para que el título en el Expanded quede perfectamente centrado.
          const SizedBox(width: 60),
        ],
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

  // En el método _buildSection, modifica la parte del ExpansionTile:
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
    bool isExpandable = false,
    bool enabled = true,
    EdgeInsetsGeometry?
        tilePadding, // Nuevo parámetro para controlar el padding del tile
    double?
        titleIconSize, // Nuevo parámetro para el tamaño del icono en el título
    double?
        titleIconContainerSize, // Nuevo parámetro para el tamaño del contenedor del icono
    TextStyle?
        sectionTitleTextStyle, // Nuevo para el estilo del texto del título de la sección
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final userData = Provider.of<UserDataProvider>(context);

    // Valores por defecto si no se proporcionan los nuevos parámetros
    final effectiveTilePadding = tilePadding ??
        EdgeInsets.symmetric(
            horizontal: 16.0, vertical: 0.0); // Reducir vertical
    final effectiveTitleIconSize =
        titleIconSize ?? 16.0; // Ligeramente más pequeño
    final effectiveTitleIconContainerSize =
        titleIconContainerSize ?? 28.0; // Ligeramente más pequeño
    final effectiveSectionTitleTextStyle = sectionTitleTextStyle ??
        TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 16, // Podrías querer unificar este tamaño
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        /* Padding(
          padding: const EdgeInsets.only(
              left: 8.0, bottom: 8.0, top: 4.0), // Añadí un top padding pequeño
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ), */
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
              ? IgnorePointer(
                  ignoring: !enabled,
                  child: Opacity(
                    opacity: enabled ? 1.0 : 0.6,
                    child: ExpansionTile(
                      onExpansionChanged: enabled ? (value) {} : null,
                      // Aquí aplicamos los nuevos parámetros y valores reducidos
                      tilePadding:
                          effectiveTilePadding, // Usar el padding efectivo
                      title: Row(
                        children: [
                          Container(
                            width:
                                effectiveTitleIconContainerSize, // Usar tamaño de contenedor efectivo
                            height:
                                effectiveTitleIconContainerSize, // Usar tamaño de contenedor efectivo
                            decoration: BoxDecoration(
                              color: _getIconColor(title).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getSectionIcon(title),
                              color: _getIconColor(title),
                              size:
                                  effectiveTitleIconSize, // Usar tamaño de icono efectivo
                            ),
                          ),
                          SizedBox(
                              width: 12), // Reducir un poco si es necesario
                          Text(
                            title,
                            style:
                                effectiveSectionTitleTextStyle, // Usar estilo de texto efectivo
                          ),
                        ],
                      ),
                      children: enabled ? items : [_buildDisabledMessage()],
                      trailing: Icon(
                        // El trailing también afecta la altura si es muy grande
                        Icons.arrow_drop_down,
                        size: 20, // Puedes ajustar el tamaño del trailing icon
                        color: enabled
                            ? (isDarkMode ? Colors.grey[400] : Colors.grey[600])
                            : Colors.grey,
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      items, // Para secciones no expandibles, el padding se maneja en _buildConfigItem
                ),
        ),
      ],
    );
  }

  IconData _getSectionIcon(String title) {
    switch (title) {
      case 'Zoom':
        return Icons.zoom_in;
      case 'Cuentas bancarias':
        return Icons.account_balance; // Icono nuevo
      case 'Personalizar logo':
        return Icons.image;
      default:
        return Icons.settings;
    }
  }

  Color _getIconColor(String title) {
    switch (title) {
      case 'Zoom':
        return Colors.blue;
      case 'Cuentas bancarias':
        return Colors.green; // Color nuevo
      case 'Personalizar logo':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

// Nuevo método para mensaje de deshabilitado
  Widget _buildDisabledMessage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Se requieren permisos de administrador\npara modificar esta configuración',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildFinancialInfoBlock(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userData = Provider.of<UserDataProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Buscar el logo según el modo de tema
    final logo = userData.imagenes.where((img) {
      return isDarkMode
          ? img.tipoImagen == 'logoBlanco'
          : img.tipoImagen == 'logoColor';
    }).firstOrNull;

    final logoUrl =
        logo != null ? '$baseUrl/imagenes/subidas/${logo.rutaImagen}' : null;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 0, bottom: 20, left: 0, right: 0),
        child: Row(
          children: [
            // Contenedor para la imagen del logo
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: logoUrl != null
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Si falla la carga de la imagen, mostrar ícono
                          return Icon(
                            Icons.account_balance,
                            color: isDarkMode ? Colors.white : Colors.black,
                          );
                        },
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
                    userData.nombreNegocio,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Financiera',
                    style: TextStyle(
                      fontSize: 16,
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

  Widget _buildUserSection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userData = Provider.of<UserDataProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return _buildSection(
      context,
      title: 'Usuario',
      items: [
        _buildConfigItem(
          context,
          title: userData.nombreUsuario,
          subtitle: userData.tipoUsuario,
          leadingIcon: Icons.person,
          iconColor: Colors.green,
          trailing: ElevatedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => CambiarPasswordDialog(
                idUsuario: userData.idusuario,
                isDarkMode: isDarkMode,
              ),
            ),
            icon: Icon(
              Icons.lock_reset,
              size: 18,
              color: isDarkMode ? Colors.white : Color(0xFF5162F6),
            ),
            label: Text(
              'Cambiar contraseña',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Color(0xFF5162F6),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
              foregroundColor: isDarkMode ? Colors.white : Color(0xFF5162F6),
              side: BorderSide(
                color: Color(0xFF5162F6),
                width: 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadLogo(String tipoLogo) async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    if (userData.tipoUsuario == 'Admin') {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png'],
        );

        if (result != null && result.files.isNotEmpty) {
          String tempPath = result.files.single.path!;

          setState(() {
            if (tipoLogo == "logoColor") {
              _tempColorLogoPath = tempPath;
            } else {
              _tempWhiteLogoPath = tempPath;
            }
          });

          // No llamamos a _uploadLogoToServer aquí
        }
      } catch (e) {
        print('Error al seleccionar el logo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar el archivo')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solo los administradores pueden subir logos')),
      );
    }
  }

// Función para guardar los cambios pendientes (cuando hay imagenes temporales)
  Future<void> _saveLogoChanges() async {
    try {
      setState(() => _isSaving = true);

      if (_tempColorLogoPath != null) {
        // Sube el logo a color y espera la respuesta del servidor
        await _uploadLogoToServer(_tempColorLogoPath!, "logoColor");
        setState(() => _colorLogoImagePath = _tempColorLogoPath);
      }

      if (_tempWhiteLogoPath != null) {
        // Sube el logo blanco y espera la respuesta del servidor
        await _uploadLogoToServer(_tempWhiteLogoPath!, "logoBlanco");
        setState(() => _whiteLogoImagePath = _tempWhiteLogoPath);
      }

      // Limpiar variables temporales
      setState(() {
        _tempColorLogoPath = null;
        _tempWhiteLogoPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logo guardado correctamente'),
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
      // 0. Obtener token de autenticación
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      if (token.isEmpty) {
        throw Exception(
            'Token de autenticación no encontrado. Por favor, inicia sesión.');
      }

      // 1. Crear solicitud
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/imagenes/subir/logo'),
      );

      // Agregar token al header
      request.headers['tokenauth'] = token;

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
        'idnegocio': userData.idnegocio,
      });

      // 4. Imprimir detalles de la solicitud
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parsear el JSON de la respuesta
        final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
        final nuevaRuta = jsonResponse['filename'];

        // Actualizar el provider con el nuevo logo
        userData.actualizarLogo(tipoLogo, nuevaRuta);
      } else {
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

  Future<void> _fetchCuentasBancarias() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    setState(() => _loadingCuentas = true);

    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/v1/financiera/cuentasbanco/${userData.idnegocio}'),
        headers: {'tokenauth': token},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _cuentasBancarias =
            data.map((item) => CuentaBancaria.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching cuentas: $e');
    } finally {
      setState(() => _loadingCuentas = false);
    }
  }

  void _showAddCuentaDialog() {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController numeroController = TextEditingController();
    String selectedBanco = 'Santander';

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          title: Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFF5162F6)),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Nueva Cuenta Bancaria',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5162F6),
                  ),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          content: Container(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la cuenta',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    prefixIcon: Icon(Icons.label, color: Color(0xFF5162F6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Color(0xFF5162F6), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color:
                            isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                      ),
                    ),
                    fillColor: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                    filled: true,
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: numeroController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Número de cuenta',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    prefixIcon: Icon(Icons.numbers, color: Color(0xFF5162F6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Color(0xFF5162F6), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color:
                            isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                      ),
                    ),
                    fillColor: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter
                        .digitsOnly, // Solo permite dígitos
                    LengthLimitingTextInputFormatter(
                        16), // Limita a 16 caracteres
                  ],
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor:
                          isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: selectedBanco,
                      decoration: InputDecoration(
                        labelText: 'Selecciona un banco',
                        labelStyle: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                        prefixIcon:
                            Icon(Icons.business, color: Color(0xFF5162F6)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      dropdownColor:
                          isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      items: [
                        "BBVA",
                        "Santander",
                        "Banorte",
                        "HSBC",
                        "Banamex",
                        "Scotiabank",
                        "Bancoppel",
                        "Banco Azteca"
                      ].map((String banco) {
                        return DropdownMenuItem<String>(
                          value: banco,
                          child: Text(
                            banco,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => selectedBanco = value!,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isNotEmpty &&
                    numeroController.text.isNotEmpty) {
                  await _addCuentaBancaria(
                    nombreController.text,
                    numeroController.text,
                    selectedBanco, // Solo se envía el nombre del banco
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor completa todos los campos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5162F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCuentaBancaria(
      String nombre, String numero, String banco) async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    try {
      // Crear el cuerpo del request
      final requestBody = {
        'idnegocio': userData.idnegocio,
        'nombreCuenta': nombre,
        'numeroCuenta': numero,
        'nombreBanco': banco,
      };

      // Imprimir lo que se va a enviar
      print('Datos enviados al servidor:');
      print('URL: $baseUrl/api/v1/financiera/cuentasbanco');
      print('Headers:');
      print('  tokenauth: $token');
      print('  Content-Type: application/json');
      print('Body:');
      print(jsonEncode(requestBody));

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/financiera/cuentasbanco'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Status code: ${response.statusCode}'); // Log del status
      print(
          'Response body: ${response.body}'); // Log del cuerpo de la respuesta

      if (response.statusCode == 201) {
        _fetchCuentasBancarias();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta agregada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Manejar otros códigos de estado (ej. 400, 500)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error del servidor: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error adding cuenta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCuentaItem(BuildContext context, CuentaBancaria cuenta) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final formattedDate = DateFormat('dd/MM/yyyy').format(cuenta.fCreacion);

    return ListTile(
      leading: Image.network(
        '$baseUrl/imagenes/bancos/${cuenta.rutaBanco}',
        width: 70,
        height: 40,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.account_balance),
      ),
      title: Text(cuenta.nombreCuenta),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Banco: ${cuenta.nombreBanco}'),
          Text('Número: ${cuenta.numeroCuenta}'),
          Text('Creada: ${DateFormat('dd/MM/yyyy').format(cuenta.fCreacion)}'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _showEditCuentaDialog(cuenta),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(cuenta.numeroCuenta),
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountsSection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final userData = Provider.of<UserDataProvider>(context); // Obtener userData

    return _buildSection(
      context,
      title: 'Cuentas bancarias',
      items: [
        _loadingCuentas
            ? Center(child: CircularProgressIndicator())
            : _cuentasBancarias.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No hay cuentas registradas',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  )
                : Column(
                    children: _cuentasBancarias
                        .map((cuenta) => _buildCuentaItem(context, cuenta))
                        .toList(),
                  ),
        Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: userData.tipoUsuario == 'Admin' || userData.tipoUsuario == 'Contador'
                ? _showAddCuentaDialog
                : null, // Deshabilitar si no es Admin
            icon: Icon(
              Icons.add,
              size: 20,
              color: Colors.white,
            ),
            label: Text('Agregar Nueva Cuenta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5162F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
      isExpandable: true,
      enabled: userData.tipoUsuario == 'Admin' || userData.tipoUsuario == 'Contador', // Solo habilitado para Admin
    );
  }

  void _confirmDelete(String numeroCuenta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content:
            Text('¿Estás seguro de que quieres eliminar esta cuenta bancaria?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[700])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cierra el diálogo
              _deleteCuenta(numeroCuenta); // Ejecuta la eliminación
            },
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  Future<void> _deleteCuenta(String numeroCuenta) async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    try {
      final url =
          '$baseUrl/api/v1/financiera/cuentasbanco/${userData.idnegocio}/$numeroCuenta';

      print('Enviando DELETE a: $url'); // Log de la URL
      print('Token usado: $token'); // Log del token

      final response = await http.delete(
        Uri.parse(url),
        headers: {'tokenauth': token},
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        _fetchCuentasBancarias(); // Actualizar la lista
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta eliminada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error eliminando cuenta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditCuentaDialog(CuentaBancaria cuenta) {
    _showCuentaDialog(
      isEditing: true,
      cuentaOriginal: cuenta,
      nombre: cuenta.nombreCuenta,
      numero: cuenta.numeroCuenta,
      banco: cuenta.nombreBanco,
    );
  }

  void _showCuentaDialog({
    bool isEditing = false,
    CuentaBancaria? cuentaOriginal,
    String? nombre,
    String? numero,
    String? banco,
  }) {
    final TextEditingController nombreController =
        TextEditingController(text: nombre);
    final TextEditingController numeroController =
        TextEditingController(text: numero);
    String selectedBanco = banco ?? 'Santander';

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          title: Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFF5162F6)),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  isEditing
                      ? 'Editar Cuenta Bancaria'
                      : 'Nueva Cuenta Bancaria',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5162F6),
                  ),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          content: Container(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la cuenta',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    prefixIcon: Icon(Icons.label, color: Color(0xFF5162F6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Color(0xFF5162F6), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color:
                            isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                      ),
                    ),
                    fillColor: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                    filled: true,
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: numeroController,
                  enabled: true,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Número de cuenta',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    prefixIcon: Icon(Icons.numbers, color: Color(0xFF5162F6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Color(0xFF5162F6), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color:
                            isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                      ),
                    ),
                    fillColor: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                  ],
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor:
                          isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: selectedBanco,
                      decoration: InputDecoration(
                        labelText: 'Selecciona un banco',
                        labelStyle: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                        prefixIcon:
                            Icon(Icons.business, color: Color(0xFF5162F6)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      dropdownColor:
                          isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      items: [
                        "BBVA",
                        "Santander",
                        "Banorte",
                        "HSBC",
                        "Banamex",
                        "Scotiabank",
                        "Bancoppel",
                        "Banco Azteca"
                      ].map((String banco) {
                        return DropdownMenuItem<String>(
                          value: banco,
                          child: Text(
                            banco,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => selectedBanco = value!,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isNotEmpty &&
                    numeroController.text.isNotEmpty) {
                  if (isEditing) {
                    await _editCuentaBancaria(
                      cuentaOriginal!.numeroCuenta,
                      nombreController.text,
                      numeroController.text,
                      selectedBanco,
                    );
                  } else {
                    await _addCuentaBancaria(
                      nombreController.text,
                      numeroController.text,
                      selectedBanco,
                    );
                  }
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor completa todos los campos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5162F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(isEditing ? 'Actualizar' : 'Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCuentaBancaria(
      String numeroOriginal, String nombre, String numero, String banco) async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    try {
      final requestBody = {
        'nombreCuenta': nombre,
        'cuentaNueva': numero,
        'nombreBanco': banco,
      };

      // Imprimir datos que se enviarán
      print('⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻');
      print('EDITANDO CUENTA BANCARIA');
      print(
          'URL: $baseUrl/api/v1/financiera/cuentasbanco/${userData.idnegocio}/$numeroOriginal');
      print('Headers:');
      print('  tokenauth: $token');
      print('  Content-Type: application/json');
      print('Body enviado:');
      print(jsonEncode(requestBody));
      print('Número original: $numeroOriginal');

      final response = await http.put(
        Uri.parse(
            '$baseUrl/api/v1/financiera/cuentasbanco/${userData.idnegocio}/$numeroOriginal'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Imprimir respuesta
      print('⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻');
      print('RESPUESTA DEL SERVIDOR');
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        _fetchCuentasBancarias();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta actualizada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻⎻');
      print('ERROR EN LA SOLICITUD');
      print('Error editing cuenta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
