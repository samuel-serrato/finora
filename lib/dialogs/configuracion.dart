import 'package:finora/main.dart';
import 'package:flutter/material.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class ConfiguracionDialog extends StatefulWidget {
  @override
  _ConfiguracionDialogState createState() => _ConfiguracionDialogState();
}

class _ConfiguracionDialogState extends State<ConfiguracionDialog> {
  bool notificationsEnabled = true;
  bool dataSync = true;
  String selectedLanguage = 'Español';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider =
        Provider.of<ScaleProvider>(context); // Obtén el ScaleProvider
    final isDarkMode = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;

    // Usamos AlertDialog en lugar de Dialog para tener mejor control sobre el fondo
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
                          isExpandable:
                              true), // Indicar que esta sección es expandible
                      SizedBox(height: 15),
                      _buildSection(context, title: 'Notificaciones', items: [
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
                      SizedBox(height: 15),
                      /* _buildSection(context, title: 'Datos', items: [
                        _buildSwitchItem(
                          context,
                          title: 'Sincronización automática',
                          value: dataSync,
                          onChanged: (value) {
                            setState(() {
                              dataSync = value;
                            });
                          },
                          icon: Icons.sync,
                          iconColor: Colors.green,
                        ),
                      ]), */
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
    bool isExpandable =
        false, // Nuevo parámetro para indicar si la sección es expandible
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
                          color: Colors.blue
                              .withOpacity(0.1), // Color de fondo del ícono
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.zoom_in, // Ícono de zoom
                          color: Colors.blue, // Color del ícono
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 14), // Espacio entre el ícono y el texto
                      Text(
                        'Nivel de zoom',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  children: items,
                  initiallyExpanded: false, // Inicialmente contraído
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
}
