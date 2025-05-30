import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

enum TipoFiltro {
  dropdown,
  rangoFechas,
  // Agregar más tipos según necesidad
}

class ConfiguracionFiltro {
  final String clave;
  final String titulo;
  final TipoFiltro tipo;
  List<String>? opciones; // Para dropdowns
  final DateTime? fechaInicial; // Para rangos de fechas
  final DateTime? fechaFinal; // Para rangos de fechas

  ConfiguracionFiltro({
    required this.clave,
    required this.titulo,
    required this.tipo,
    this.opciones,
    this.fechaInicial,
    this.fechaFinal,
  });
}

// 3. WIDGET GENÉRICO MODIFICADO para usar dentro de PopupMenu (SIN Navigator.pop interno):
class FiltrosGenericosWidgetInline extends StatefulWidget {
  final List<ConfiguracionFiltro> configuraciones;
  final Map<String, dynamic> valoresIniciales;
  final Function(Map<String, dynamic>) onAplicar;
  final VoidCallback onRestablecer;
  final String titulo;

  const FiltrosGenericosWidgetInline({
    Key? key,
    required this.configuraciones,
    required this.valoresIniciales,
    required this.onAplicar,
    required this.onRestablecer,
    this.titulo = 'Filtros',
  }) : super(key: key);

  @override
  _FiltrosGenericosWidgetInlineState createState() => _FiltrosGenericosWidgetInlineState();
}

class _FiltrosGenericosWidgetInlineState extends State<FiltrosGenericosWidgetInline> {
  late Map<String, dynamic> _valores;

  @override
  void initState() {
    super.initState();
    _valores = Map<String, dynamic>.from(widget.valoresIniciales);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header con título (SIN botón cerrar porque está en PopupMenu)
          Text(
            widget.titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),

          const SizedBox(height: 12),

          // Lista de filtros configurados EN FILAS (como tu diseño original)
          ..._construirFiltrosEnFilas(isDarkMode),

          const SizedBox(height: 16),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: isDarkMode
                          ? Colors.grey[600]!
                          : Colors.grey[400]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    widget.onRestablecer();
                  },
                  child: Text(
                    'Restablecer',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5162F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    widget.onAplicar(_valores);
                  },
                  child: const Text(
                    'Aplicar Filtros',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Construir filtros en filas (como tu diseño original)
  List<Widget> _construirFiltrosEnFilas(bool isDarkMode) {
    List<Widget> widgets = [];
    
    // Organizar filtros en pares para mostrar en filas
    for (int i = 0; i < widget.configuraciones.length; i += 2) {
      widgets.add(
        Row(
          children: [
            Expanded(
              child: _construirDropdownFiltroCompacto(
                widget.configuraciones[i], 
                isDarkMode
              ),
            ),
            if (i + 1 < widget.configuraciones.length) ...[
              SizedBox(width: 16),
              Expanded(
                child: _construirDropdownFiltroCompacto(
                  widget.configuraciones[i + 1], 
                  isDarkMode
                ),
              ),
            ] else
              Expanded(child: Container()), // Espacio vacío si es impar
          ],
        ),
      );
      
      if (i + 2 < widget.configuraciones.length) {
        widgets.add(SizedBox(height: 12));
      }
    }
    
    return widgets;
  }

  Widget _construirDropdownFiltroCompacto(ConfiguracionFiltro config, bool isDarkMode) {
    final currentValue = _valores[config.clave] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          config.titulo,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _construirDropdownCompacto(
          value: currentValue,
          //hint: 'Seleccionar ${config.titulo.toLowerCase()}',
          hint: 'Seleccionar',
          items: config.opciones ?? [],
          isDarkMode: isDarkMode,
          onChanged: (value) {
            setState(() {
              _valores[config.clave] = value;
            });
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _valores[config.clave] = null;
              });
            },
            child: const Text(
              'Limpiar',
              style: TextStyle(color: Color(0xFF5162F6), fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirDropdownCompacto({
    required String? value,
    required String hint,
    required List<String> items,
    required bool isDarkMode,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 36,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
              fontSize: 11,
            ),
          ),
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          iconStyleData: IconStyleData(
            icon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: isDarkMode ? Colors.white60 : Colors.grey[600],
                size: 16,
              ),
            ),
          ),
          dropdownStyleData: DropdownStyleData(
            maxHeight: 200,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}