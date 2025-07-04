// lib/widgets/custom_popup_menu.dart
import 'package:finora/models/menu_pago.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:flutter/material.dart';

// =============================================================================
// === WIDGET PRINCIPAL: CustomPopupMenu
// =============================================================================

class CustomPopupMenu extends StatelessWidget {
  final List<MenuItemModel> items;
  final Function(String)? onItemSelected;
  final Widget icon;
  final Color? menuColor;
  final double? elevation;
  final ShapeBorder? shape;
  final Offset offset;
  final String? tooltip;
  final double? width; // <-- AÑADE ESTA LÍNEA

  // --- 1. AÑADE ESTE NUEVO PARÁMETRO ---
  final VoidCallback? onMenuBuild;

  const CustomPopupMenu({
    Key? key,
    required this.items,
    this.onItemSelected,
    this.icon = const Icon(Icons.more_vert),
    this.menuColor,
    this.elevation,
    this.shape,
    this.offset = const Offset(0, 40),
    this.tooltip,
    this.width, // <-- AÑADE ESTA LÍNEA
      // --- 2. AÑADE AL CONSTRUCTOR ---
    this.onMenuBuild,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: icon,
      color: menuColor,
      elevation: elevation,
      shape: shape,
      offset: offset,
      tooltip: tooltip,
      // --- AÑADE ESTA LÍNEA ---
      constraints: BoxConstraints(minWidth: width ?? 0.0),
      // -------------------------
      onSelected: onItemSelected,
      itemBuilder: (BuildContext context) {
          // --- 3. EJECUTA LA FUNCIÓN AQUÍ ---
        // Si la función onMenuBuild fue proporcionada, la llamamos.
        // Esto sucede justo antes de que los items se construyan.
        onMenuBuild?.call();
        
        return items.map((item) {
          if (item is MenuActionItem) {
            return _buildActionItem(item);
          }
          if (item is SubMenuItem) {
            return _buildSubMenuItem(context, item);
          }
          if (item is MenuInfoItem) {
            return NonInteractivePopupItem(child: item.child);
          }

          // --- CORRECCIÓN APLICADA AQUÍ ---
          // Ahora los items personalizados también usan NonInteractivePopupItem
          // para evitar la opacidad y problemas de click.
          if (item is MenuCustomItem) {
            return NonInteractivePopupItem(child: item.builder(context));
          }

          if (item is MenuSeparator) {
            return const PopupMenuDivider();
          }
          return const PopupMenuItem<String>(child: SizedBox.shrink());
        }).toList();
      },
    );
  }

  // --- MÉTODOS CONSTRUCTORES PRIVADOS ---

  PopupMenuEntry<String> _buildActionItem(MenuActionItem item) {
    return PopupMenuItem<String>(
      onTap: item.onTap,
      padding: EdgeInsets.zero,
      child: item.child,
    );
  }

  PopupMenuEntry<String> _buildSubMenuItem(
      BuildContext context, SubMenuItem item) {
    return NonInteractivePopupItem(
      child: PopupMenuButton<String>(
        tooltip: '',
        onSelected: onItemSelected,
        offset: item.offset,
        color: item.backgroundColor,
        elevation: item.elevation,
        constraints: BoxConstraints(
          minWidth: item.width ?? 0.0, // Usa el width si existe, si no, 0
          maxWidth: item.maxWidth ??
              double.infinity, // Usa maxWidth si existe, si no, infinito
        ),
        // -----------------------------
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: item.child,

        itemBuilder: (BuildContext context) {
          return item.subItems.map((subItem) {
            if (subItem is MenuActionItem) {
              return _buildActionItem(subItem);
            }
            // --- INICIO DE LA MODIFICACIÓN ---
            if (subItem is MenuInfoItem) {
              // SOLUCIÓN: Usar NonInteractivePopupItem para mostrar el widget
              // sin interactividad y sin el efecto de opacidad.
              return NonInteractivePopupItem(
                child: subItem.child,
              );
            }
            // --- FIN DE LA MODIFICACIÓN ---

            if (subItem is MenuCustomItem) {
              return NonInteractivePopupItem(child: subItem.builder(context));
            }

            if (subItem is MenuSeparator) {
              return const PopupMenuDivider(height: 1);
            }
            return const PopupMenuItem<String>(child: SizedBox.shrink());
          }).toList();
        },
      ),
    );
  }
}

// =============================================================================
// === CLASES DE AYUDA (Colocadas al final del archivo)
// =============================================================================

// *** AQUÍ ESTÁ LA CORRECCIÓN PRINCIPAL ***
class NonInteractivePopupItem extends PopupMenuEntry<String> {
  const NonInteractivePopupItem({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  // CAMBIO CRÍTICO: Calculamos la altura real en lugar de devolver 0
  double get height {
    // Para elementos invisibles (como el SizedBox de ancho), devolvemos una altura mínima
    // Para elementos visibles, Flutter calculará automáticamente la altura correcta
    if (child is SizedBox && (child as SizedBox).height == 0) {
      return 1.0; // Altura mínima para que Flutter considere el ancho
    }
    return kMinInteractiveDimension; // Altura estándar para otros elementos
  }

  @override
  bool represents(String? value) => false;

  @override
  NonInteractivePopupItemState createState() => NonInteractivePopupItemState();
}

class NonInteractivePopupItemState extends State<NonInteractivePopupItem> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
