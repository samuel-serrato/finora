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
    return Scaffold(
      appBar: AppBar(
        title: Text('Formulario'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agregar Grupo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

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
                        items: ['Seleccionar Integrante 1', 'Integrante 2', 'Integrante 3']
                            .map((String member) {
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
                        items: ['Seleccionar Grupo', 'Grupo 1', 'Grupo 2', 'Grupo 3']
                            .map((String group) {
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

            Spacer(),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Lógica para aceptar
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    backgroundColor: Colors.blue,
                  ),
                  child: Text('Aceptar'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    // Lógica para cancelar
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    backgroundColor: Colors.grey,
                  ),
                  child: Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: AddGroupDialog(),
  ));
}
