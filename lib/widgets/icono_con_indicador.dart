// En tu archivo: lib/widgets/icono_con_indicador.dart

import 'package:flutter/material.dart';

class IconoConIndicador extends StatelessWidget {
  final Widget child; // El ícono principal (p. ej. Icon(Icons.more_vert))
  final bool mostrarIndicador;
  final int count; // <-- NUEVO: El número a mostrar
  final Color colorIndicador;
  final double right;
  final double top;

  const IconoConIndicador({
    Key? key,
    required this.child,
    this.mostrarIndicador = false,
    this.count = 0, // <-- NUEVO: Valor por defecto es 0
    this.colorIndicador = const Color(0xFFE53888),
    this.right = -2, // Ajustamos la posición para dar espacio al número
    this.top = -2,   // Ajustamos la posición
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!mostrarIndicador) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: top,
          right: right,
          child: Container(
            // --- LÓGICA DE TAMAÑO MODIFICADA ---
            // Hacemos el contenedor un poco más grande para que quepa el número.
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(
              minWidth: 12, // Ancho mínimo para el círculo
              minHeight: 12, // Altura mínima
            ),
            decoration: BoxDecoration(
              color: colorIndicador,
              borderRadius: BorderRadius.circular(10), // Hacemos el radio más grande
              //border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            // --- WIDGET DE TEXTO AÑADIDO ---
            // Usamos un Center para alinear el número perfectamente.
            child: Center(
              child: Text(
                // Mostramos el número. Si es mayor a 9, mostramos "9+" para no saturar.
                count > 9 ? '9+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1, // Ayuda a centrar verticalmente el texto
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}