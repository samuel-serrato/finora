import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String version;

  const DownloadProgressDialog({
    Key? key,
    required this.downloadUrl,
    required this.version,
  }) : super(key: key);

  @override
  _DownloadProgressDialogState createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  double _progress = 0.0;
  String _status = "Iniciando descarga...";
  bool _downloadComplete = false;
  @override
  void initState() {
    super.initState();
    print("DownloadProgressDialog inicializado");
    _downloadUpdate();
  }

  Future<void> _downloadUpdate() async {
    try {
      // Añadir más logs para seguimiento
      print("Iniciando proceso de descarga...");

      // Obtener el directorio temporal y construir el path del archivo
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/instalador_v${widget.version}.exe';
      final file = File(filePath);

      setState(() {
        _status = "Conectando con el servidor...";
      });
      print("Conectando con el servidor para descargar: ${widget.downloadUrl}");

      // Realizar la solicitud HTTP para descargar el archivo
      final uri = Uri.parse(widget.downloadUrl);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();

      setState(() {
        _status = "Descargando actualización...";
      });
      print("Iniciando descarga. Tamaño: ${response.contentLength} bytes");

      final contentLength = response.contentLength;
      List<int> bytes = [];

      await for (var data in response) {
        bytes.addAll(data);
        if (mounted) {
          setState(() {
            _progress = contentLength > 0 ? bytes.length / contentLength : 0;
          });
        }
      }

      // Guardar el archivo descargado
      await file.writeAsBytes(bytes);
      print("Archivo descargado y guardado en: $filePath");

      // --- Añadir ejecución del instalador aquí ---
      print("Iniciando instalador...");
      await Process.start(filePath, [], runInShell: true);

      if (mounted) {
        setState(() {
          _status = "Descarga completada. Preparando instalación...";
          _downloadComplete = true;
        });
        await Future.delayed(const Duration(seconds: 1));
      }

      // Mostrar mensaje final
      if (mounted) {
        setState(() {
          _status = "Iniciando instalador y cerrando aplicación...";
        });
        await Future.delayed(const Duration(seconds: 1));
      }

      // Asegurarse de cerrar correctamente todos los diálogos primero
      Navigator.of(context).popUntil((route) => route.isFirst);
      print("Diálogos cerrados. Preparando cierre de aplicación...");

      // Esperar un momento para asegurar que se han cerrado correctamente
      await Future.delayed(const Duration(seconds: 1));

      print("Intentando cerrar la aplicación ahora...");

      // SIMPLIFICAR EL CIERRE - usar directamente exit(0)
      print("Cerrando aplicación con exit(0)");
      exit(0); // Esto debe cerrar la aplicación completa

      // El código a continuación nunca se ejecutará si exit(0) funciona correctamente
    } catch (e, stackTrace) {
      print("Error al descargar o ejecutar la actualización: $e");
      print("Stack trace: $stackTrace");
      if (mounted) {
        setState(() {
          _status = "Error: $e";
        });
        await Future.delayed(const Duration(seconds: 3));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      // Evitar que el usuario cierre el diálogo con el botón atrás
      onWillPop: () async => false,
      child: AlertDialog(
        title: Text('Actualizando a v${widget.version}'),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_status),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.blueAccent : Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(_progress * 100).toStringAsFixed(0)}%'),
                  if (_downloadComplete)
                    Text('Completado', style: TextStyle(color: Colors.green)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
