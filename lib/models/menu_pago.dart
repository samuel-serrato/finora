// lib/widgets/menu_models.dart
import 'package:flutter/material.dart';

// Clase base abstracta para todos los tipos de elementos del menú.
abstract class MenuItemModel {}

// 1. Para una acción simple que se puede clickear (Editar, Eliminar)
// 1. VERSIÓN MEJORADA para una acción que dispara un evento
class MenuActionItem extends MenuItemModel {
  final Widget child; // El widget que se mostrará (un Row con icono y texto)
  final VoidCallback onTap; // La función EXACTA a ejecutar cuando se toque

  MenuActionItem({
    required this.child,
    required this.onTap,
  });
}

// 2. Para un separador visual
class MenuSeparator extends MenuItemModel {}

// 3. Para un submenú que contiene su propia lista de items
class SubMenuItem extends MenuItemModel {
  // Cómo se ve este item en el menú principal
  final Widget child;
  // Los items que aparecerán cuando se abra el submenú
  final List<MenuItemModel> subItems;
  // Propiedades del PopupMenuButton del submenú
  final Color? backgroundColor;
  final double? elevation;
  final Offset offset;
  final double? width; // <-- AÑADIR ESTA LÍNEA
  final double? maxWidth; // <-- Añade esta línea para el ancho máximo

  SubMenuItem({
    required this.child,
    required this.subItems,
    this.backgroundColor,
    this.elevation,
    this.offset = const Offset(-160, 0),
    this.width, // <-- AÑADIR ESTE PARÁMETRO
    this.maxWidth, // <-- Añade este parámetro
  });
}

// 4. Para un item que solo muestra información (no es clickeable)
class MenuInfoItem extends MenuItemModel {
  final Widget child;

  MenuInfoItem({required this.child});
}

// 5. Para un item completamente personalizado que necesita su propio builder
// Perfecto para el Checkbox con su propio estado.
class MenuCustomItem extends MenuItemModel {
  final WidgetBuilder builder;

  MenuCustomItem({required this.builder});
}
