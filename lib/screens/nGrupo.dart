import 'package:flutter/material.dart';

class AddGroupDialog extends StatefulWidget {
  @override
  _AddGroupDialogState createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends State<AddGroupDialog> {
  String selectedMember = 'Seleccionar Integrante 1';
  String selectedGroup = 'Seleccionar Grupo';
  final TextEditingController loanNameController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      title: Text('Agregar Grupo'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estructura de dos columnas
            Row(
              children: [
                // Primera columna
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Campo desplegable para seleccionar integrante
                      DropdownButtonFormField<String>(
                        value: selectedMember,
                        items: [
                          'Seleccionar Integrante 1',
                          'Integrante 2',
                          'Integrante 3'
                        ].map((String member) {
                          return DropdownMenuItem<String>(
                            value: member,
                            child: Text(member),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedMember = value!;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Integrante 1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Campo para agregar detalles
                      TextField(
                        controller: detailsController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Detalles',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20),

                // Segunda columna
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Campo desplegable para seleccionar grupo
                      DropdownButtonFormField<String>(
                        value: selectedGroup,
                        items: [
                          'Seleccionar Grupo',
                          'Grupo 1',
                          'Grupo 2',
                          'Grupo 3'
                        ].map((String group) {
                          return DropdownMenuItem<String>(
                            value: group,
                            child: Text(group),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedGroup = value!;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Grupo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Campo de texto para el nombre del préstamo
                      TextField(
                        controller: loanNameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre del Préstamo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            // Lógica para aceptar
            Navigator.of(context).pop();
          },
          child: Text('Aceptar'),
        ),
        ElevatedButton(
          onPressed: () {
            // Lógica para cancelar
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
          ),
          child: Text('Cancelar'),
        ),
      ],
    );
  }
}

// Función para mostrar el diálogo
void showAddGroupDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AddGroupDialog();
    },
  );
}
