import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InfoCliente extends StatefulWidget {
  final String idCliente;

  InfoCliente({required this.idCliente});

  @override
  _InfoClienteState createState() => _InfoClienteState();
}

class _InfoClienteState extends State<InfoCliente> {
  Map<String, dynamic>? clienteData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClienteData();
  }

  Future<void> fetchClienteData() async {
    final response = await http.get(Uri.parse(
        'http://192.168.0.108:3000/api/v1/clientes/${widget.idCliente}'));

    if (response.statusCode == 200) {
      setState(() {
        clienteData = json.decode(response.body)[0];
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.all(16),
        width: width,
        height: height,
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : clienteData != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda fija y centrada
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_circle,
                              size: 150,
                              color: Color(0xFFFB2056),
                            ),
                            SizedBox(height: 16),
                            _buildSectionTitle('Información General'),
                            _buildDetailRow('ID:', clienteData!['idclientes']),
                            _buildDetailRow('Nombre:',
                                '${clienteData!['nombres']} ${clienteData!['apellidoP']} ${clienteData!['apellidoM']}'),
                            _buildDetailRow(
                                'Fecha de Nac:', clienteData!['fechaNac']),
                            _buildDetailRow(
                                'Tipo Cliente:', clienteData!['tipo_cliente']),
                            _buildDetailRow('Sexo:', clienteData!['sexo']),
                            _buildDetailRow(
                                'Ocupación:', clienteData!['ocupacion']),
                            _buildDetailRow(
                                'Teléfono:', clienteData!['telefono']),
                            _buildDetailRow(
                                'Estado Civil:', clienteData!['eCivil']),
                            _buildDetailRow('Dependientes Económicos:',
                                clienteData!['dependientes_economicos']),
                            _buildDetailRow('Email:', clienteData!['email']),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),

                      // Columna derecha deslizable
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fila para Cuentas de Banco y Domicilios
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Columna para Cuentas de Banco y Domicilios
                                      Expanded(
                                        flex:
                                            2, // Mantén un tamaño mayor para esta columna
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildSectionTitle(
                                                'Cuentas de Banco'),
                                            if (clienteData!['cuentabanco']
                                                is List)
                                              for (var cuenta in clienteData![
                                                  'cuentabanco']) ...[
                                                _buildDetailRow('Banco:',
                                                    cuenta['nombreBanco']),
                                                _buildDetailRow(
                                                    'Número de Cuenta:',
                                                    cuenta['numCuenta']),
                                                _buildDetailRow(
                                                    'Número de Tarjeta:',
                                                    cuenta['numTarjeta']),
                                                SizedBox(height: 16),
                                              ],
                                            _buildSectionTitle('Domicilio'),
                                            if (clienteData!['domicilios']
                                                is List)
                                              for (var domicilio
                                                  in clienteData![
                                                      'domicilios']) ...[
                                                _buildAddresses(domicilio),
                                                SizedBox(height: 16),
                                              ],
                                          ],
                                        ),
                                      ),

                                      // Elimina el espaciado entre las columnas
                                      Expanded(
                                        flex:
                                            2, // Ajusta el tamaño según sea necesario
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildSectionTitle(
                                                'Datos Adicionales'),
                                            if (clienteData!['adicionales']
                                                is List)
                                              for (var adicional
                                                  in clienteData![
                                                      'adicionales']) ...[
                                                _buildDetailRow(
                                                    'CURP:', adicional['curp']),
                                                _buildDetailRow(
                                                    'RFC:', adicional['rfc']),
                                                _buildDetailRow(
                                                    'Fecha de Creación:',
                                                    adicional['fCreacion']),
                                                SizedBox(height: 16),
                                              ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              SizedBox(height: 16),

                              _buildSectionTitle('Ingresos y Egresos'),
                              if (clienteData!['ingresos_egresos'] is List)
                                _buildIncomeInfo(
                                    clienteData!['ingresos_egresos']),
                              _buildSectionTitle('Referencias'),
                              if (clienteData!['referencias'] is List)
                                _buildReferences(clienteData!['referencias']),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Text('Error al cargar datos del cliente'),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text('$title $value', style: TextStyle(fontSize: 14)),
    );
  }

  Widget _buildIncomeInfo(List<dynamic> ingresos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ingresos.map<Widget>((ingreso) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Tipo de Info:', ingreso['tipo_info']),
                _buildDetailRow(
                    'Años de Actividad:', ingreso['años_actividad']),
                _buildDetailRow('Descripción:', ingreso['descripcion']),
                _buildDetailRow('Monto Semanal:', ingreso['monto_semanal']),
                _buildDetailRow('Fecha Creación:', ingreso['fCreacion']),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReferences(List<dynamic> referencias) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: referencias.map<Widget>((referencia) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Nombre:',
                    '${referencia['nombres']} ${referencia['apellidoP']} ${referencia['apellidoM']}'),
                _buildDetailRow('Parentesco:', referencia['parentesco']),
                _buildDetailRow('Teléfono:', referencia['telefono']),
                _buildDetailRow(
                    'Tiempo de Conocimiento:', referencia['timepoCo']),
                _buildDetailRow('Fecha Creación:', referencia['fCreacion']),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddresses(Map<String, dynamic> domicilio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila para los detalles básicos del domicilio
        Row(
          children: [
            SizedBox(height: 8), // Espacio debajo del título
            Expanded(
                child: _buildDetailRow(
                    'Tipo Domicilio:', domicilio['tipo_domicilio'])),
            Expanded(
                child: _buildDetailRow(
                    'Propietario:', domicilio['nombre_propietario'])),
            Expanded(
                child: _buildDetailRow('Parentesco:', domicilio['parentesco'])),
          ],
        ),
        // Fila para la dirección
        Row(
          children: [
            Expanded(child: _buildDetailRow('Calle:', domicilio['calle'])),
            Expanded(child: _buildDetailRow('Número Ext:', domicilio['next'])),
            Expanded(child: _buildDetailRow('Número Int:', domicilio['nInt'])),
          ],
        ),
        // Fila para la ubicación
        Row(
          children: [
            Expanded(child: _buildDetailRow('Colonia:', domicilio['colonia'])),
            Expanded(
                child: _buildDetailRow('Municipio:', domicilio['municipio'])),
            Expanded(child: _buildDetailRow('Estado:', domicilio['estado'])),
          ],
        ),
        // Fila para el código postal y tiempo de residencia
        Row(
          children: [
            Expanded(child: _buildDetailRow('Código Postal:', domicilio['cp'])),
            Expanded(
                child: _buildDetailRow(
                    'Tiempo Viviendo:', domicilio['tiempoViviendo'])),
          ],
        ),
      ],
    );
  }
}
