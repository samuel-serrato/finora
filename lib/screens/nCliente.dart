import 'package:flutter/material.dart';

class nClienteDialog extends StatefulWidget {
  final VoidCallback onClienteAgregado;

  nClienteDialog({required this.onClienteAgregado});

  @override
  _nClienteDialogState createState() => _nClienteDialogState();
}

class _nClienteDialogState extends State<nClienteDialog> {
  final TextEditingController nombresController = TextEditingController();
  final TextEditingController apellidoPController = TextEditingController();
  final TextEditingController apellidoMController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  String? selectedSexo;
  String? selectedECivil;
  DateTime? selectedDate;

  final List<String> sexos = ['Masculino', 'Femenino'];
  final List<String> estadosCiviles = [
    'Soltero',
    'Casado',
    'Divorciado',
    'Viudo'
  ];

  bool isNombresEmpty = false;
  bool isApellidoPEmpty = false;
  bool isApellidoMEmpty = false;
  bool isTelefonoEmpty = false;
  bool isSexoEmpty = false;
  bool isECivilEmpty = false;
  bool isDateEmpty = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.6;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Agregar Cliente',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: nombresController,
              label: 'Nombres',
              icon: Icons.person,
              isEmpty: isNombresEmpty,
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: apellidoPController,
                    label: 'Apellido Paterno',
                    icon: Icons.person_outline,
                    isEmpty: isApellidoPEmpty,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: apellidoMController,
                    label: 'Apellido Materno',
                    icon: Icons.person_outline,
                    isEmpty: isApellidoMEmpty,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: telefonoController,
                    label: 'Teléfono',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    isEmpty: isTelefonoEmpty,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildDropdown(
                    value: selectedSexo,
                    hint: 'Selecciona Sexo',
                    items: sexos,
                    onChanged: (value) {
                      setState(() {
                        selectedSexo = value;
                        isSexoEmpty = false;
                      });
                    },
                    isEmpty: isSexoEmpty,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: selectedECivil,
                    hint: 'Estado Civil',
                    items: estadosCiviles,
                    onChanged: (value) {
                      setState(() {
                        selectedECivil = value;
                        isECivilEmpty = false;
                      });
                    },
                    isEmpty: isECivilEmpty,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 50,
                        child: TextButton(
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                selectedDate = pickedDate;
                                isDateEmpty = false;
                              });
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                            side: BorderSide(
                              color: isDateEmpty ? Colors.red : Colors.grey,
                              width: 1.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.grey[100],
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              selectedDate != null
                                  ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                                  : 'Selecciona una fecha',
                              style: TextStyle(
                                color: selectedDate != null
                                    ? Colors.black
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isDateEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            'Campo requerido',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Cancelar'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _agregarCliente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isEmpty = false,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        errorText: isEmpty ? 'Campo requerido' : null,
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    bool isEmpty = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        errorText: isEmpty ? 'Campo requerido' : null,
      ),
    );
  }

  void _agregarCliente() {
    setState(() {
      isNombresEmpty = nombresController.text.isEmpty;
      isApellidoPEmpty = apellidoPController.text.isEmpty;
      isApellidoMEmpty = apellidoMController.text.isEmpty;
      isTelefonoEmpty = telefonoController.text.isEmpty;
      isSexoEmpty = selectedSexo == null;
      isECivilEmpty = selectedECivil == null;
      isDateEmpty = selectedDate == null;
    });

    if (!isNombresEmpty &&
        !isApellidoPEmpty &&
        !isApellidoMEmpty &&
        !isTelefonoEmpty &&
        !isSexoEmpty &&
        !isECivilEmpty &&
        !isDateEmpty) {
      final nuevoCliente = {
        "idtipoclientes": 1,
        "nombres": nombresController.text,
        "apellidoP": apellidoPController.text,
        "apellidoM": apellidoMController.text,
        "fechaNac":
            "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
        "sexo": selectedSexo,
        "telefono": telefonoController.text,
        "eCilvi": selectedECivil,
      };

      widget.onClienteAgregado();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
    }
  }
}
