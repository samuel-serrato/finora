import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String version; // Nueva variable para la versión

  const DownloadProgressDialog({
    Key? key,
    required this.downloadUrl,
    required this.version, // Requerir la versión
  }) : super(key: key);

  @override
  _DownloadProgressDialogState createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  double progress = 0.0;

  @override
  void initState() {
    super.initState();
    _downloadUpdate();
  }

  Future<void> _downloadUpdate() async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      final response = await client.send(request);
      final total = response.contentLength;

      // Obtener la carpeta de Descargas
      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception("No se pudo acceder a Descargas");

      final fileName = widget.downloadUrl.split('/').last;
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      var sink = file.openWrite();

      int bytesReceived = 0;

      response.stream.listen(
        (List<int> chunk) {
          bytesReceived += chunk.length;
          sink.add(chunk);
          if (total != null) {
            setState(() {
              progress = bytesReceived / total;
            });
          }
        },
        onDone: () async {
          await sink.close();
          final result = await OpenFile.open(filePath);
          print(
              "Resultado al abrir el archivo: ${result.type} - ${result.message}");
          if (mounted) Navigator.of(context).pop();
        },
        onError: (error) {
          print('Error en la descarga: $error');
          if (mounted) Navigator.of(context).pop();
        },
      );
    } catch (e) {
      print('Error en la descarga: $e');
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Descargando actualización"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress),
          const SizedBox(height: 20),
          Text('${(progress * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}
