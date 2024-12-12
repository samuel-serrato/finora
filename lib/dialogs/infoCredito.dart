import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InfoCredito extends StatefulWidget {
  final String folio;

  InfoCredito({required this.folio});

  @override
  _InfoCreditoState createState() => _InfoCreditoState();
}

class _InfoCreditoState extends State<InfoCredito> {
  Credito? creditoData;  // Ahora es de tipo Credito? (nulo permitido)
  bool isLoading = true;
  bool dialogShown = false;
  Timer? _timer;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fetchCreditoData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCreditoData() async {
    _timer = Timer(Duration(seconds: 10), () {
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
        _showErrorDialog('No se pudo conectar al servidor. Por favor, revisa tu conexión de red.');
      }
    });

    setState(() {
      isLoading = true;
    });

    try {
      final url = 'http://192.168.0.109:3000/api/v1/creditos/${widget.folio}';
      final response = await http.get(Uri.parse(url));

      _timer?.cancel();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List && data.isNotEmpty) {
          setState(() {
            creditoData = Credito.fromJson(data[0]);
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          if (!dialogShown) {
            dialogShown = true;
            _showErrorDialog('Error en la carga de datos. La respuesta no contiene créditos.');
          }
        }
      } else {
        setState(() {
          isLoading = false;
        });
        if (!dialogShown) {
          dialogShown = true;
          _showErrorDialog('Error en la carga de datos. Código de error: ${response.statusCode}');
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!dialogShown) {
        dialogShown = true;
        _showErrorDialog('Error de conexión o inesperado: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
  final width = MediaQuery.of(context).size.width * 0.8;
  final height = MediaQuery.of(context).size.height * 0.8;

  return Dialog(
    backgroundColor: Color(0xFFF7F8FA),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    insetPadding: EdgeInsets.all(16),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 50),
      width: width,
      height: height,
      child: isLoading
          ? Center(child: CircularProgressIndicator())
          : creditoData != null
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna izquierda con la información del crédito
                    Expanded(
                      flex: 25,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFFB2056),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 70, // Tamaño del avatar
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.credit_card,
                                size: 100,
                                color: Color(0xFFFB2056), // Color que combine con el fondo
                              ),
                            ),
                            SizedBox(height: 16),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Información del Crédito',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 8), // Espacio entre el título y los detalles
                            _buildDetailRow('Folio', creditoData!.folio),
                            _buildDetailRow('Grupo', creditoData!.nombreGrupo),
                            _buildDetailRow('Monto Desembolsado', "\$${creditoData!.montoDesembolsado}"),
                            _buildDetailRow('Interés Total', "\$${creditoData!.interesTotal}"),
                            _buildDetailRow('Monto Total', "\$${creditoData!.montoTotal}"),
                            _buildDetailRow('Pago por Cuota', "\$${creditoData!.pagoCuota}"),
                            _buildDetailRow('Estado', creditoData!.estadoCredito),
                            _buildDetailRow('Fecha de Creación', _formatDate(creditoData!.fCreacion)),
                            SizedBox(height: 30),
                            
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Columna derecha con otros detalles o contenido adicional
                    Expanded(
                      flex: 75,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Aquí puedes agregar más contenido o detalles adicionales
                            _buildSectionTitle('Detalles Adicionales'),
                            Text(
                              "Aquí puedes agregar más detalles o contenido adicional del crédito.",
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(child: Text('No se ha cargado la información')),
    ),
  );
}

Widget _buildDetailRow(String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(
          "$title: ",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}

String _formatDate(String date) {
  // Aquí puedes aplicar cualquier formato necesario
  return date;
}
}


class Credito {
  final String idcredito;
  final String idgrupos;
  final String nombreGrupo;
  final String diaPago;
  final int plazo;
  final String tipoPlazo;
  final String tipo;
  final double ti_mensual;
  final String folio;
  final String garantia;
  final double montoDesembolsado;
  final double interesGlobal;
  final double montoTotal;
  final double interesTotal;
  final double montoMasInteres;
  final double pagoCuota;
  final String numPago;
  final String fechasIniciofin;
  final String estadoCredito;
  final String fCreacion;

  Credito({
    required this.idcredito,
    required this.idgrupos,
    required this.nombreGrupo,
    required this.diaPago,
    required this.plazo,
    required this.tipoPlazo,
    required this.tipo,
    required this.ti_mensual,
    required this.folio,
    required this.garantia,
    required this.montoDesembolsado,
    required this.interesGlobal,
    required this.montoTotal,
    required this.interesTotal,
    required this.montoMasInteres,
    required this.pagoCuota,
    required this.numPago,
    required this.fechasIniciofin,
    required this.estadoCredito,
    required this.fCreacion,
  });

  factory Credito.fromJson(Map<String, dynamic> json) {
    return Credito(
      idcredito: json['idcredito'],
      idgrupos: json['idgrupos'],
      nombreGrupo: json['nombreGrupo'],
      diaPago: json['diaPago'] ?? "",
      plazo: json['plazo'],
      tipoPlazo: json['tipoPlazo'],
      tipo: json['tipo'],
      ti_mensual: json['ti_mensual'].toDouble(),
      folio: json['folio'],
      garantia: json['garantia'],
      montoDesembolsado: json['montoDesembolsado'].toDouble(),
      interesGlobal: json['interesGlobal'].toDouble(),
      montoTotal: json['montoTotal'].toDouble(),
      interesTotal: json['interesTotal'].toDouble(),
      montoMasInteres: json['montoMasInteres'].toDouble(),
      pagoCuota: json['pagoCuota'].toDouble(),
      numPago: json['numPago'],
      fechasIniciofin: json['fechasIniciofin'],
      estadoCredito: json['estado_credito'],
      fCreacion: json['fCreacion'],
    );
  }
}
