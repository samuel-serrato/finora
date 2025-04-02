// custom_dialogs.dart
import 'package:flutter/material.dart';

// Modificar la función para que sea awaitable
Future<bool?> mostrarDialogo(
    BuildContext context, String titulo, String mensaje,
    {bool esError = false}) async {
  return showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.info_outline,
              color: esError ? Colors.red : Colors.blue,
            ),
            SizedBox(width: 10),
            Text(
              esError ? "Error" : titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: esError ? Colors.red : Colors.blue,
              ),
            ),
          ],
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.justify,
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(true); // Devuelve true al hacer clic
            },
            icon: Icon(Icons.check, color: Colors.white),
            label: Text('OK', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: esError ? Colors.red : Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
        ],
      );
    },
  );
}
