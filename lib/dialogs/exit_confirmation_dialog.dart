// lib/widgets/exit_confirmation_dialog.dart

import 'package:finora/providers/theme_provider.dart'; // Asegúrate que la ruta sea correcta
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExitConfirmationDialog extends StatelessWidget {
  /// Callback asíncrono que ejecuta la lógica de logout y cierre de la app.
  final Future<void> Function() onLogoutAndExit;

  const ExitConfirmationDialog({
    Key? key,
    required this.onLogoutAndExit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- (Tu código de estilos y tema se mantiene igual, lo omito por brevedad) ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    const primaryColor = Color(0xFF5162F6);
    final titleColor = isDarkMode ? Colors.white : Colors.black87;
    final contentColor = isDarkMode ? Colors.grey[300] : Colors.grey[700];
    final buttonTextColor = isDarkMode ? Colors.grey[300] : Colors.grey[700];
    final buttonBorderColor =
        isDarkMode ? Colors.grey[700]! : Colors.grey[400]!;
    // ---

    return AlertDialog(
      // --- (Tu código de apariencia del AlertDialog se mantiene igual) ---
      backgroundColor:
          isDarkMode ? Colors.grey[800] : Colors.white, // Color dinámico
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      contentPadding: const EdgeInsets.only(top: 25, bottom: 20),
      title: Column(
        children: [
          const Icon(Icons.logout, size: 60, color: primaryColor),
          const SizedBox(height: 15),
          Text('¿Desea Salir de Finora?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: titleColor)),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Text(
            'La sesión se cerrará automáticamente al salir de la aplicación.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: contentColor, height: 1.4)),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(25, 20, 25, 20),
      // ---

      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón de Cancelar (sin cambios)
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: buttonTextColor,
                    side: BorderSide(color: buttonBorderColor),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 15),

            // Botón de Cerrar Sesión y Salir (AQUÍ ESTÁ LA MAGIA)
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  // Captura el contexto actual para usarlo de forma segura en operaciones asíncronas
                  final currentContext = context;

                  // 1. Muestra el diálogo de carga ANTES de hacer nada.
                  showDialog(
                    context: currentContext,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: isDarkMode
                            ? Colors.grey[800]
                            : Colors.white, // Color dinámico
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        content: Container(
                          padding: const EdgeInsets.all(20),
                          child:  Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: Color(0xFF5162F6)),
                              SizedBox(height: 20),
                              Text('Cerrando sesión...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  )),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  try {
                    // 2. Ejecuta la lógica de logout y cierre que pasaste.
                    // Esto incluye la llamada a la API y el windowManager.destroy().
                    await onLogoutAndExit();

                    // Si onLogoutAndExit tiene éxito, la app se cierra y el código de aquí abajo
                    // no llega a ejecutarse, lo cual está bien.
                  } catch (e) {
                    // 3. Si OCURRE UN ERROR en onLogoutAndExit (p. ej. sin conexión),
                    // la app NO se cierra. Debemos manejarlo.
                    if (!currentContext.mounted) return;

                    // Cierra el diálogo de carga ("Cerrando sesión...")
                    Navigator.pop(currentContext);

                    // Opcional: Muestra un error al usuario.
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.redAccent,
                        content: Text('Error al cerrar sesión: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Cerrar Sesión y Salir'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
