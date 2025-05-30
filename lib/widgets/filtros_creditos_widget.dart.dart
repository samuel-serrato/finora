import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class FiltrosCreditosWidget extends StatefulWidget {
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final String? tipoCreditoSeleccionado;
  final String? frecuenciaSeleccionada;
  final String? diapagoSeleccionado;
  final int? numeroPagoSeleccionado;
  final String? estadoPagoSeleccionado;
  final String? estadoCreditoSeleccionado;
  final Function(
    DateTime?,
    DateTime?,
    String?,
    String?,
    String?,
    int?,
    String?,
    String?,
  ) onAplicarFiltros;
  final VoidCallback onRestablecer;

  const FiltrosCreditosWidget({
    Key? key,
    required this.fechaDesde,
    required this.fechaHasta,
    required this.tipoCreditoSeleccionado,
    required this.frecuenciaSeleccionada,
    required this.diapagoSeleccionado,
    required this.numeroPagoSeleccionado,
    required this.estadoPagoSeleccionado,
    required this.estadoCreditoSeleccionado,
    required this.onAplicarFiltros,
    required this.onRestablecer,
  }) : super(key: key);

  @override
  _FiltrosCreditosWidgetState createState() => _FiltrosCreditosWidgetState();
}

class _FiltrosCreditosWidgetState extends State<FiltrosCreditosWidget> {
  late DateTime? _fechaDesde;
  late DateTime? _fechaHasta;
  late String? _tipoCreditoSeleccionado;
  late String? _frecuenciaSeleccionada;
  late String? _diapagoSeleccionado;
  late int? _numeroPagoSeleccionado;
  late String? _estadoPagoSeleccionado;
  late String? _estadoCreditoSeleccionado;

  @override
  void initState() {
    super.initState();
    _fechaDesde = widget.fechaDesde;
    _fechaHasta = widget.fechaHasta;
    _tipoCreditoSeleccionado = widget.tipoCreditoSeleccionado;
    _frecuenciaSeleccionada = widget.frecuenciaSeleccionada;
    _diapagoSeleccionado = widget.diapagoSeleccionado;
    _numeroPagoSeleccionado = widget.numeroPagoSeleccionado;
    _estadoPagoSeleccionado = widget.estadoPagoSeleccionado;
    _estadoCreditoSeleccionado = widget.estadoCreditoSeleccionado;
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
          // Header con título y botón cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtros de Créditos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(
                  Icons.close,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  size: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tipo de Crédito y Frecuencia en la misma fila
          Row(
            children: [
              Expanded(
                child: _buildFilterSection(
                  'Tipo de Crédito',
                  isDarkMode,
                  child: Column(
                    children: [
                      _buildCompactDropdown(
                        value: _tipoCreditoSeleccionado,
                        hint: 'Seleccionar tipo',
                        items: const ['Grupal', 'Individual'],
                        isDarkMode: isDarkMode,
                        onChanged: (value) => setState(
                            () => _tipoCreditoSeleccionado = value),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(
                              () => _tipoCreditoSeleccionado = null),
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(
                                color: Color(0xFF5162F6), fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterSection(
                  'Frecuencia',
                  isDarkMode,
                  child: Column(
                    children: [
                      _buildCompactDropdown(
                        value: _frecuenciaSeleccionada,
                        hint: 'Seleccionar frecuencia',
                        items: const ['Semanal', 'Quincenal'],
                        isDarkMode: isDarkMode,
                        onChanged: (value) => setState(
                            () => _frecuenciaSeleccionada = value),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(
                              () => _frecuenciaSeleccionada = null),
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(
                                color: Color(0xFF5162F6), fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Día de Pago y Número de Pago en la misma fila
          Row(
            children: [
              Expanded(
                child: _buildFilterSection(
                  'Día de Pago',
                  isDarkMode,
                  child: Column(
                    children: [
                      _buildCompactDropdown(
                        value: _diapagoSeleccionado,
                        hint: 'Seleccionar día',
                        items: const [
                          'Lunes',
                          'Martes',
                          'Miércoles',
                          'Jueves',
                          'Viernes',
                          'Sábado',
                          'Domingo'
                        ],
                        isDarkMode: isDarkMode,
                        onChanged: (value) =>
                            setState(() => _diapagoSeleccionado = value),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _diapagoSeleccionado = null),
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(
                                color: Color(0xFF5162F6), fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterSection(
                  'Número de Pago',
                  isDarkMode,
                  child: Column(
                    children: [
                      _buildCompactDropdown(
                        value: _numeroPagoSeleccionado?.toString(),
                        hint: 'Seleccionar número',
                        items: List.generate(21, (index) => index.toString()),
                        isDarkMode: isDarkMode,
                        onChanged: (value) => setState(() =>
                            _numeroPagoSeleccionado =
                                value != null ? int.parse(value) : null),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(
                              () => _numeroPagoSeleccionado = null),
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(
                                color: Color(0xFF5162F6), fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Estado de Pago y Estado de Crédito en la misma fila
          Row(
            children: [
              Expanded(
                child: _buildFilterSection(
                  'Estado de Pago',
                  isDarkMode,
                  child: Column(
                    children: [
                      _buildCompactDropdown(
                        value: _estadoPagoSeleccionado,
                        hint: 'Seleccionar estado',
                        items: const ['Pagado', 'Desembolso', 'Retraso'],
                        isDarkMode: isDarkMode,
                        onChanged: (value) => setState(
                            () => _estadoPagoSeleccionado = value),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(
                              () => _estadoPagoSeleccionado = null),
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(
                                color: Color(0xFF5162F6), fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterSection(
                  'Estado de Crédito',
                  isDarkMode,
                  child: Column(
                    children: [
                      _buildCompactDropdown(
                        value: _estadoCreditoSeleccionado,
                        hint: 'Seleccionar estado',
                        items: const ['Activo', 'Finalizado', 'Liquidado'],
                        isDarkMode: isDarkMode,
                        onChanged: (value) => setState(
                            () => _estadoCreditoSeleccionado = value),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(
                              () => _estadoCreditoSeleccionado = null),
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(
                                color: Color(0xFF5162F6), fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

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
                   onPressed: widget.onRestablecer,
                  child: Text(
                    'Restablecer',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 13,
                    ),
                  ),
              ),),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                    child: const Text(
                    'Aplicar Filtros',
                    style: TextStyle(fontSize: 13),
                  ),
                  onPressed: () {
                    widget.onAplicarFiltros(
                      _fechaDesde,
                      _fechaHasta,
                      _tipoCreditoSeleccionado,
                      _frecuenciaSeleccionada,
                      _diapagoSeleccionado,
                      _numeroPagoSeleccionado,
                      _estadoPagoSeleccionado,
                      _estadoCreditoSeleccionado,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5162F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                  ),
                  
                
                ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String titulo, bool isDarkMode,
      {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? fecha, bool isDarkMode,
      {required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white70 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 3),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fecha != null
                        ? '${fecha.day.toString().padLeft(2, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.year}'
                        : 'dd-mm-yyyy',
                    style: TextStyle(
                      fontSize: 12,
                      color: fecha != null
                          ? (isDarkMode ? Colors.white : Colors.black)
                          : (isDarkMode ? Colors.white54 : Colors.grey),
                    ),
                  ),
                  
                ),
                 Icon(
                  Icons.calendar_today,
                  color: isDarkMode ? Colors.white60 : Colors.grey[600],
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDropdown({
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
              fontSize: 12,
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