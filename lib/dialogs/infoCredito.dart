import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:money_facil/ip.dart';

class InfoCredito extends StatefulWidget {
  final String folio;

  InfoCredito({required this.folio});

  @override
  _InfoCreditoState createState() => _InfoCreditoState();
}

class _InfoCreditoState extends State<InfoCredito> {
  Credito? creditoData; // Ahora es de tipo Credito? (nulo permitido)
  bool isLoading = true;
  bool dialogShown = false;
  Timer? _timer;
  late ScrollController _scrollController;
  String idCredito = '';

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
        _showErrorDialog(
            'No se pudo conectar al servidor. Por favor, revisa tu conexión de red.');
      }
    });

    setState(() {
      isLoading = true;
    });

    try {
      final url = 'http://$baseUrl/api/v1/creditos/${widget.folio}';
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
            _showErrorDialog(
                'Error en la carga de datos. La respuesta no contiene créditos.');
          }
        }
        idCredito = creditoData!.idcredito;
      } else {
        setState(() {
          isLoading = false;
        });
        if (!dialogShown) {
          dialogShown = true;
          _showErrorDialog(
              'Error en la carga de datos. Código de error: ${response.statusCode}');
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
    final width = MediaQuery.of(context).size.width * 0.9;
    final height = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      backgroundColor: Color(0xFFF7F8FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 30),
        width: width,
        height: height,
        child: Column(
          children: [
            Expanded(
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
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFB2056),
                                      Color.fromARGB(255, 197, 35, 78)
                                    ],
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                  ),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(20)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    )
                                  ],
                                ),
                                padding: EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 16),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                          Icons.account_balance_wallet_rounded,
                                          size: 60,
                                          color: Color(0xFFFB2056),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Información del Crédito',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Divider(
                                          color: Colors.white.withOpacity(0.5),
                                          thickness: 1),
                                      _buildDetailRow('Folio',
                                          creditoData!.folio.toString()),
                                      _buildDetailRow(
                                          'Grupo',
                                          creditoData!.nombreGrupo ??
                                              'No disponible'),
                                      _buildDetailRow('Monto Total',
                                          "\$${formatearNumero(creditoData!.montoTotal ?? 0.0)}"),
                                      _buildDetailRow('Interés Mensual',
                                          "${creditoData!.ti_mensual ?? 0.0}%"),
                                      _buildDetailRow('Garantía',
                                          "\$${creditoData!.garantia ?? 0.0}"),
                                      _buildDetailRow(
                                        'Monto Desembolsado',
                                        "\$${formatearNumero(creditoData!.montoDesembolsado ?? 0.0)}",
                                      ),
                                      _buildDetailRow('Interés Global',
                                          "${creditoData!.interesGlobal ?? 0.0}%"),
                                      _buildDetailRow(
                                        'Día de Pago',
                                        creditoData!.diaPago ?? 'Desconocido',
                                      ),
                                      SizedBox(height: 3),
                                      Divider(
                                          color: Colors.white.withOpacity(0.5),
                                          thickness: 1),
                                      SizedBox(height: 3),
                                      _buildDetailRow(
                                          creditoData!.tipoPlazo == 'Semanal'
                                              ? 'Capital Semanal'
                                              : 'Capital Quincenal',
                                          "\$${formatearNumero(creditoData!.semanalCapital ?? 0.0)}"),
                                      _buildDetailRow('Capital Total',
                                          "\$${formatearNumero((creditoData!.semanalCapital * creditoData!.plazo) ?? 0.0)}"),
                                      _buildDetailRow(
                                          creditoData!.tipoPlazo == 'Semanal'
                                              ? 'Interés Semanal'
                                              : 'Interés Quincenal',
                                          "\$${formatearNumero(creditoData!.semanalInteres ?? 0.0)}"),
                                      _buildDetailRow('Interés Total',
                                          "\$${formatearNumero(creditoData!.interesTotal ?? 0.0)}"),
                                      SizedBox(height: 3),
                                      Divider(
                                          color: Colors.white.withOpacity(0.5),
                                          thickness: 1),
                                      SizedBox(height: 3),
                                      _buildDetailRow(
                                        creditoData!.tipoPlazo == 'Semanal'
                                            ? 'Pago Semanal'
                                            : 'Pago Quincenal',
                                        "\$${formatearNumero(creditoData!.pagoCuota ?? 0.0)}",
                                      ),
                                      _buildDetailRow(
                                        'Monto a Recuperar',
                                        "\$${formatearNumero(creditoData!.montoMasInteres ?? 0.0)}",
                                      ),
                                      _buildDetailRow(
                                        'Estado',
                                        creditoData!.estadoCredito.estado !=
                                                null
                                            ? creditoData!.estadoCredito.estado
                                                .toString()
                                            : 'No disponible',
                                      ),
                                      _buildDetailRow(
                                        'Fecha de Creación',
                                        formatearFecha(creditoData?.fCreacion ??
                                            DateTime.now()),
                                      ),
                                      SizedBox(height: 30),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            // Columna derecha con pestañas
                            Expanded(
                              flex: 75,
                              child: DefaultTabController(
                                length: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TabBar(
                                      labelColor: Color(0xFFFB2056),
                                      unselectedLabelColor: Colors.grey,
                                      indicatorColor: Color(0xFFFB2056),
                                      tabs: [
                                        Tab(text: 'Control'),
                                        Tab(text: 'Integrantes'),
                                        Tab(text: 'Otros'),
                                      ],
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildSectionTitle(
                                                    'Control de Pagos'),
                                                PaginaControl(
                                                    idCredito: idCredito),
                                              ],
                                            ),
                                          ),
                                          SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildSectionTitle(
                                                    'Integrantes'),
                                                PaginaIntegrantes(
                                                  clientesMontosInd:
                                                      creditoData!
                                                          .clientesMontosInd,
                                                  tipoPlazo:
                                                      creditoData!.tipoPlazo,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildSectionTitle('Otros'),
                                                Text(
                                                  "Aquí puedes agregar otros detalles o información adicional.",
                                                  style:
                                                      TextStyle(fontSize: 16),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(child: Text('No se ha cargado la información')),
            ),
            // Botones de acción
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cerrar el diálogo
                    },
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // guardarCredito();
                    },
                    child: Text('Guardar'),
                    style: ElevatedButton.styleFrom(
                        //backgroundColor: Color(0xFFFB2056),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Función para formatear números
  String formatearNumero(double numero) {
    final formatter = NumberFormat("#,##0.00", "en_US"); // Formato en español
    return formatter.format(numero);
  }

// Función para formatear fechas
  String formatearFecha(Object? fecha) {
    if (fecha is String) {
      // Convertir la cadena de fecha en un objeto DateTime
      final parsedDate = DateTime.parse(fecha);
      final formatter = DateFormat('dd/MM/yyyy'); // Formato de fecha
      return formatter.format(parsedDate);
    } else if (fecha is DateTime) {
      // Si ya es un objeto DateTime
      final formatter = DateFormat('dd/MM/yyyy'); // Formato de fecha
      return formatter.format(fecha);
    } else {
      return 'Fecha no válida';
    }
  }

  // Construcción del widget para mostrar detalles
// Widget para construir filas de detalle
  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
}

class ClienteMonto {
  final String idamortizacion;
  final String nombreCompleto;
  final double capitalIndividual;
  final double periodoCapital;
  final double periodoInteres;
  final double totalCapital;
  final double totalIntereses;
  final double periodoInteresPorcentaje;
  final double capitalMasInteres;
  final double total;

  ClienteMonto({
    required this.idamortizacion,
    required this.nombreCompleto,
    required this.capitalIndividual,
    required this.periodoCapital,
    required this.periodoInteres,
    required this.totalCapital,
    required this.totalIntereses,
    required this.periodoInteresPorcentaje,
    required this.capitalMasInteres,
    required this.total,
  });

  factory ClienteMonto.fromJson(Map<String, dynamic> json) {
    return ClienteMonto(
      idamortizacion: json['idamortizacion'],
      nombreCompleto: json['nombreCompleto'],
      capitalIndividual: json['capitalIndividual'].toDouble(),
      periodoCapital: json['periodoCapital'].toDouble(),
      periodoInteres: json['periodoInteres'].toDouble(),
      totalCapital: json['totalCapital'].toDouble(),
      totalIntereses: json['interesTotal'].toDouble(),
      periodoInteresPorcentaje: json['periodoInteresPorcentaje'].toDouble(),
      capitalMasInteres: json['capitalMasInteres'].toDouble(),
      total: json['total'].toDouble(),
    );
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
  final double semanalCapital; // Nuevo campo
  final double semanalInteres; // Nuevo campo
  final double montoTotal;
  final double interesTotal;
  final double montoMasInteres;
  final double pagoCuota;
  final String numPago;
  final String fechasIniciofin;
  final EstadoCredito estadoCredito;
  final String fCreacion;
  final List<ClienteMonto> clientesMontosInd;

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
    required this.semanalCapital, // Nuevo campo
    required this.semanalInteres, // Nuevo campo
    required this.montoTotal,
    required this.interesTotal,
    required this.montoMasInteres,
    required this.pagoCuota,
    required this.numPago,
    required this.fechasIniciofin,
    required this.estadoCredito,
    required this.fCreacion,
    required this.clientesMontosInd,
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
      semanalCapital: json['semanalCapital'].toDouble(), // Nuevo campo
      semanalInteres: json['semanalInteres'].toDouble(), // Nuevo campo
      montoTotal: json['montoTotal'].toDouble(),
      interesTotal: json['interesTotal'].toDouble(),
      montoMasInteres: json['montoMasInteres'].toDouble(),
      pagoCuota: json['pagoCuota'].toDouble(),
      numPago: json['numPago'],
      fechasIniciofin: json['fechasIniciofin'],
      estadoCredito: EstadoCredito.fromJson(json['estado_credito']),
      fCreacion: json['fCreacion'],
      clientesMontosInd: (json['clientesMontosInd'] as List)
          .map((e) => ClienteMonto.fromJson(e))
          .toList(),
    );
  }
}

class EstadoCredito {
  final double montoTotal;
  final double moratorios;
  final int semanasDeRetraso;
  final int diferenciaEnDias;
  final String mensaje;
  final String estado;

  EstadoCredito({
    required this.montoTotal,
    required this.moratorios,
    required this.semanasDeRetraso,
    required this.diferenciaEnDias,
    required this.mensaje,
    required this.estado,
  });

  factory EstadoCredito.fromJson(Map<String, dynamic> json) {
    return EstadoCredito(
      montoTotal: double.parse(json['montoTotal']),
      moratorios: double.parse(json['moratorios']),
      semanasDeRetraso: json['semanasDeRetraso'],
      diferenciaEnDias: json['diferenciaEnDias'],
      mensaje: json['mensaje'],
      estado: json[
          'esatado'], // Nota: el JSON tiene un error de tipografía aquí ("esatado" en lugar de "estado").
    );
  }
}

class PaginaControl extends StatefulWidget {
  final String idCredito;

  PaginaControl({required this.idCredito});

  @override
  _PaginaControlState createState() => _PaginaControlState();
}

class _PaginaControlState extends State<PaginaControl> {
  late Future<List<Pago>> _pagosFuture;
// Mapa para controlar si cada pago está siendo editado
  Map<int, bool> editingState = {}; // Usamos un mapa para el control por pago

  @override
  void initState() {
    super.initState();
    _pagosFuture = _fetchPagos().then((pagos) {
      for (var pago in pagos) {
        if (pago.capitalDeposito == null) {
          pago.capitalDeposito = 0.0; // Solo si no tiene valor
        }
      }
      return pagos;
    });
  }

  // Función para formatear fechas
  String formatearFecha(Object? fecha) {
    if (fecha is String) {
      // Convertir la cadena de fecha en un objeto DateTime
      final parsedDate = DateTime.parse(fecha);
      final formatter = DateFormat('dd/MM/yyyy'); // Formato de fecha
      return formatter.format(parsedDate);
    } else if (fecha is DateTime) {
      // Si ya es un objeto DateTime
      final formatter = DateFormat('dd/MM/yyyy'); // Formato de fecha
      return formatter.format(fecha);
    } else {
      return 'Fecha no válida';
    }
  }

  Future<List<Pago>> _fetchPagos() async {
    final response = await http.get(Uri.parse(
        'http://$baseUrl/api/v1/creditos/calendario/${widget.idCredito}'));

    print('Respuesta del servidor: ${response.body}');

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((pago) => Pago.fromJson(pago)).toList();
    } else {
      throw Exception('Failed to load pagos');
    }
  }

  String formatearNumero(double numero) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numero);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pago>>(
      future: _pagosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No se encontraron pagos.'));
        } else {
          List<Pago> pagos = snapshot.data!;

          // Inicializa los totales antes de construir la interfaz.
          double totalMonto =
              0.0; // Monto completo (suma total de capitalMasInteres)
          double totalPagoActual = 0.0; // Suma de pagos completos y parciales
          double totalSaldoFavor = 0.0; // Saldo a favor
          double totalSaldoContra = 0.0; // Saldo en contra

          // Calcular los totales excluyendo el pago 1
          for (int i = 0; i < pagos.length; i++) {
            final pago = pagos[i];
            if (i == 0) continue; // Excluir el pago 1 (índice 0)

            double capitalMasInteres = pago.capitalMasInteres ?? 0.0;
            double capitalDeposito = pago.capitalDeposito ?? 0.0;

            // Suma de los abonos realizados
            double totalAbonos = pago.abonos
                .fold(0.0, (sum, abono) => sum + (abono['monto'] ?? 0.0));

            // Total Monto Completo (suma de capitalMasInteres)
            totalMonto += capitalMasInteres;

            // Total Pago Actual (incluyendo abonos)
            if (pago.tipoPago == 'Completo') {
              totalPagoActual += capitalMasInteres;
            } else if (pago.tipoPago == 'Monto Parcial' ||
                pago.tipoPago == 'En Abonos') {
              totalPagoActual += capitalDeposito +
                  totalAbonos; // Sumar abonos al monto parcial/Abonos
            }

            // Saldo a favor y en contra ya lo tienes calculado más arriba
            double montoTotalConAbonos = capitalDeposito + totalAbonos;

            if (montoTotalConAbonos > capitalMasInteres) {
              totalSaldoFavor += montoTotalConAbonos - capitalMasInteres;
            } else if (montoTotalConAbonos < capitalMasInteres &&
                montoTotalConAbonos > 0.0) {
              totalSaldoContra += capitalMasInteres - montoTotalConAbonos;
            }
          }

// Asegúrate de que los saldos sean positivos
          totalSaldoFavor = totalSaldoFavor > 0.0 ? totalSaldoFavor : 0.0;
          totalSaldoContra = totalSaldoContra > 0.0 ? totalSaldoContra : 0.0;

          return Column(
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFFB2056),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildTableCell("No. Pago",
                        isHeader: true, textColor: Colors.white, flex: 12),
                    _buildTableCell("Fecha Pago",
                        isHeader: true, textColor: Colors.white, flex: 20),
                    _buildTableCell("Monto a Pagar",
                        isHeader: true,
                        textColor: Colors.white,
                        flex: 20), // Nueva columna
                    _buildTableCell("Pago",
                        isHeader: true, textColor: Colors.white, flex: 20),
                    _buildTableCell("Monto",
                        isHeader: true, textColor: Colors.white, flex: 20),
                    _buildTableCell("Saldo a Favor",
                        isHeader: true, textColor: Colors.white, flex: 20),
                    _buildTableCell("Saldo en Contra",
                        isHeader: true, textColor: Colors.white, flex: 20),
                  ],
                ),
              ),
              Container(
                height: 400,
                child: SingleChildScrollView(
                  child: Column(
                    children: pagos.map((pago) {
                      // Identificar si es el primer pago
                       bool esPago1 = pagos.indexOf(pago) == 0;
                      int index = pagos.indexOf(pago);

                      // Calcular saldo a favor y en contra para cada fila
                      double saldoFavor = 0.0;
                      double saldoContra = 0.0;

                      if (!esPago1) {
                        double capitalMasInteres =
                            pago.capitalMasInteres ?? 0.0;
                        double capitalDeposito = pago.capitalDeposito ?? 0.0;

                        // Suma el total de abonos realizados
                        double totalAbonos = pago.abonos.fold(
                            0.0, (sum, abono) => sum + (abono['monto'] ?? 0.0));

                        // Calcula el monto total pagado (depósito + abonos)
                        double montoPagado = capitalDeposito + totalAbonos;

                        // Calcula saldo a favor y en contra solo si hay datos válidos
                        if (montoPagado > 0.0) {
                          // Solo calcular si hay pagos realizados
                          if (montoPagado > capitalMasInteres) {
                            saldoFavor = montoPagado - capitalMasInteres;
                            saldoContra =
                                0.0; // No puede haber saldo en contra si hay saldo a favor
                          } else if (montoPagado < capitalMasInteres) {
                            saldoContra = capitalMasInteres - montoPagado;
                            saldoFavor =
                                0.0; // No puede haber saldo a favor si hay saldo en contra
                          } else {
                            saldoFavor = 0.0;
                            saldoContra = 0.0; // Si están equilibrados
                          }
                        } else {
                          // Si no hay datos, mantener ambos saldos en 0.0
                          saldoFavor = 0.0;
                          saldoContra = 0.0;
                        }
                      }

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom:
                                BorderSide(color: Color(0xFFEEEEEE), width: 1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              _buildTableCell(esPago1 ? "0" : "${pago.semana}",
                                  flex: 12),
                              _buildTableCell(formatearFecha(pago.fechaPago),
                                  flex: 20),
                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : "\$${pago.capitalMasInteres?.toStringAsFixed(2)}",
                                flex: 20,
                              ),
                              // Celda para tipo de pago
                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : DropdownButton<String?>(
                                        value: pago.tipoPago.isEmpty ? null : pago.tipoPago,
                                        hint: Text(
                                          pago.tipoPago.isEmpty ? "Seleccionar Pago" : "",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        items: <String>[
                                          'Completo',
                                          'Monto Parcial',
                                          'En Abonos',
                                        ].map((String value) {
                                          return DropdownMenuItem<String?>(
                                            value: value,
                                            child: Text(
                                              value,
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            pago.tipoPago = newValue!;
                                            if (newValue == 'Completo') {
                                              pago.capitalDeposito = pago.capitalMasInteres ?? 0.0;
                                            } else if (newValue == 'Monto Parcial') {
                                              pago.capitalDeposito = 0.0; // Resetear valor
                                            }
                                          });
                                        },
                                      ),
                                flex: 20,

                              ),
                              SizedBox(width: 20),
                              // Dos botones: uno para agregar abonos, otro para ver abonos
                              _buildTableCell(
                                pago.tipoPago == 'En Abonos'
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 5),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Botón para agregar un abono
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Color(0xFFFB2056),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 5,
                                                    offset: Offset(2, 2),
                                                  ),
                                                ],
                                              ),
                                              child: IconButton(
                                                icon: Icon(Icons.add,
                                                    color: Colors.white),
                                                onPressed: () async {
                                                  List<Map<String, dynamic>>
                                                      nuevosAbonos =
                                                      (await showDialog(
                                                            context: context,
                                                            builder: (context) =>
                                                                AbonosDialog(
                                                              montoAPagar: pago
                                                                  .capitalMasInteres,
                                                              onConfirm:
                                                                  (abonos) {
                                                                Navigator.of(
                                                                        context)
                                                                    .pop(
                                                                        abonos);
                                                              },
                                                            ),
                                                          )) ??
                                                          []; // Si es null, asigna una lista vacía

                                                  // Actualizar la lista de abonos del pago
                                                  setState(() {
                                                    if (nuevosAbonos
                                                        .isNotEmpty) {
                                                      pago.abonos
                                                          .addAll(nuevosAbonos);
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            SizedBox(
                                                width:
                                                    8), // Espacio entre los botones
                                            // Botón para ver los abonos realizados en PopUpMenu
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 5,
                                                    offset: Offset(2, 2),
                                                  ),
                                                ],
                                              ),
                                              child: PopupMenuButton<
                                                  Map<String, dynamic>>(
                                                tooltip: 'Mostrar Abonos',
                                                icon: Icon(Icons.visibility,
                                                    color: Colors.white),
                                                color: Colors.white,
                                                offset: Offset(0, 40),
                                                onSelected: (abono) {
                                                  // Aquí podrías manejar acciones con los abonos seleccionados
                                                },
                                                itemBuilder: (context) {
                                                  // Calcula el total de los abonos
                                                  double totalAbonos =
                                                      pago.abonos.fold(
                                                          0.0,
                                                          (sum, abono) =>
                                                              sum +
                                                              (abono['monto'] ??
                                                                  0.0));

                                                  return [
                                                    ...pago.abonos.map((abono) {
                                                      return PopupMenuItem(
                                                        value: abono,
                                                        child: Container(
                                                          width:
                                                              300, // Puedes ajustar este valor si quieres que el menú sea aún más ancho
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 8.0,
                                                                  horizontal:
                                                                      12.0),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                  Icons.payment,
                                                                  color: Colors
                                                                      .green,
                                                                  size:
                                                                      16), // Icono junto al texto
                                                              SizedBox(
                                                                  width:
                                                                      10), // Espacio entre el icono y el texto
                                                              Expanded(
                                                                child: Text(
                                                                  "Fecha: ${formatearFecha(abono['fecha'])}, Monto: \$${abono['monto']?.toStringAsFixed(2)}",
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                    PopupMenuItem(
                                                      enabled:
                                                          false, // Deshabilitamos este item para que no sea seleccionable
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 8.0,
                                                                horizontal:
                                                                    12.0),
                                                        child: Column(
                                                          children: [
                                                            Divider(
                                                                color: Colors
                                                                    .black26,
                                                                height:
                                                                    1), // Divider entre los abonos y el total
                                                            SizedBox(
                                                                height: 10),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .attach_money,
                                                                    color: Colors
                                                                        .black,
                                                                    size:
                                                                        16), // Icono del total
                                                                SizedBox(
                                                                    width: 10),
                                                                Expanded(
                                                                  child: Text(
                                                                    "Total Abonos: \$${totalAbonos.toStringAsFixed(2)}",
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .black87,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ];
                                                },
                                                constraints: BoxConstraints(
                                                    maxWidth:
                                                        500), // Ajusta el ancho máximo del menú
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : esPago1
    ? "-"
    : pago.tipoPago == 'Monto Parcial'
      ? (pago.capitalDeposito != null && pago.capitalDeposito! > 0 && !(editingState[index] ?? false)
          ? Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                "\$${pago.capitalDeposito!.toStringAsFixed(2)}",
                style: TextStyle(fontSize: 12, color: Colors.black),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(left: 10),
              child: TextField(
                controller: TextEditingController(
                  text: pago.capitalDeposito != null
                      ? pago.capitalDeposito!.toStringAsFixed(2)
                      : '',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    pago.capitalDeposito = double.tryParse(value) ?? 0.0;
                  });
                },
                onSubmitted: (value) {
                  // Mantén el TextField visible mientras se edita
                  setState(() {
                    editingState[index] = true; // Mantener el TextField visible
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Monto Parcial',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: BorderSide(color: Color(0xFFFB2056), width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                ),
              ),
            ))
      : "-",
  flex: 20,
                              ),

                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : saldoFavor > 0
                                        ? "\$${saldoFavor.toStringAsFixed(2)}"
                                        : "-", // Mostrar "-" si saldoFavor es 0
                                flex: 20,
                              ),
                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : saldoContra > 0
                                        ? "\$${saldoContra.toStringAsFixed(2)}"
                                        : "-", // Mostrar "-" si saldoContra es 0
                                flex: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFFB2056),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildTableCell("Totales",
                        isHeader: false, textColor: Colors.white, flex: 12),
                    _buildTableCell("", textColor: Colors.white, flex: 20),
                    _buildTableCell("\$${formatearNumero(totalMonto)}",
                        textColor: Colors.white, flex: 20),
                    _buildTableCell("", textColor: Colors.white, flex: 20),
                    _buildTableCell("\$${formatearNumero(totalPagoActual)}",
                        textColor: Colors.white, flex: 20),
                    _buildTableCell("\$${formatearNumero(totalSaldoFavor)}",
                        textColor: Colors.white, flex: 20),
                    _buildTableCell("\$${formatearNumero(totalSaldoContra)}",
                        textColor: Colors.white, flex: 20),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildTableCell(dynamic content,
      {bool isHeader = false, Color textColor = Colors.black, int flex = 1}) {
    return Flexible(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Align(
          alignment: isHeader ? Alignment.center : Alignment.center,
          child: content is Widget
              ? content
              : Text(
                  content.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
        ),
      ),
    );
  }
}

class Pago {
  int semana;
  String fechaPago;
  double capital;
  double interes;
  double capitalMasInteres;

  double? saldoFavor; // Actualizado a tipo numérico
  double? saldoEnContra; // Actualizado a tipo numérico
  double restanteTotal;
  String estado;
  double? capitalDeposito;
  String tipoPago;
  int? cantidadAbonos;
  double? montoPorCuota;
  List<Map<String, dynamic>> abonos;

  Pago({
    required this.semana,
    required this.fechaPago,
    required this.capital,
    required this.interes,
    required this.capitalMasInteres,
    this.saldoFavor,
    this.saldoEnContra,
    required this.restanteTotal,
    required this.estado,
    this.capitalDeposito,
    required this.tipoPago,
    this.cantidadAbonos,
    this.montoPorCuota,
    this.abonos = const [],
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    return Pago(
      semana: json['semana'],
      fechaPago: json['fechaPago'],
      capital: (json['capital'] is int)
          ? (json['capital'] as int).toDouble()
          : json['capital'],
      interes: (json['interes'] is int)
          ? (json['interes'] as int).toDouble()
          : json['interes'],
      capitalMasInteres: (json['capitalMasInteres'] is int)
          ? (json['capitalMasInteres'] as int).toDouble()
          : json['capitalMasInteres'],

      saldoFavor: json['saldoFavor'] != null
          ? double.tryParse(json['saldoFavor'].toString())
          : null, // Conversión de saldoFavor
      saldoEnContra: json['saldoEnContra'] != null
          ? double.tryParse(json['saldoEnContra'].toString())
          : null, // Conversión de saldoEnContra

      restanteTotal: (json['restanteTotal'] is int)
          ? (json['restanteTotal'] as int).toDouble()
          : json['restanteTotal'],
      estado: json['estado'],
      capitalDeposito:
          json['pagos'] != null && (json['pagos'] as List).isNotEmpty
              ? (json['pagos'][0]['capitalDeposito'] as num).toDouble()
              : null,

      cantidadAbonos: json['cantidadAbonos'],
      montoPorCuota: json['montoPorCuota'],
      abonos: [],
      tipoPago: json['tipoPagos'] == 'sin asignar' ? '' : json['tipoPagos'],
    );
  }
}

class AbonosDialog extends StatefulWidget {
  final double montoAPagar; // Se recibe el monto a pagar como parámetro
  final Function(List<Map<String, dynamic>>) onConfirm;

  AbonosDialog({required this.montoAPagar, required this.onConfirm});

  @override
  _AbonosDialogState createState() => _AbonosDialogState();
}

class _AbonosDialogState extends State<AbonosDialog> {
  List<Map<String, dynamic>> abonos = [];
  double montoPorAbono = 0.0;
  DateTime fechaPago = DateTime.now();
  TextEditingController montoController =
      TextEditingController(); // Controlador para el TextField

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.4;
    final height = MediaQuery.of(context).size.height * 0.52;

    // Calcular el total de los abonos
    double totalAbonos = abonos.fold(0.0, (sum, abono) => sum + abono['monto']);

    // Calcular el total pendiente
    double montoFaltante = widget.montoAPagar -
        totalAbonos; // Usar montoAPagar en lugar de montoTotal

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Registrar Abonos",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFB2056)),
              ),
              SizedBox(height: 20),

              // Fila con monto y fecha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Monto del abono
                  Container(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Monto del Abono:",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        TextField(
                          controller: montoController, // Usar el controlador
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelStyle: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w500,
                            ),
                            hintText: "Ingresa el monto",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey[300]!, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Color(0xFFFB2056), width: 2),
                            ),
                            prefixIcon: Icon(Icons.attach_money,
                                color: Color(0xFFFB2056)),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 15, horizontal: 20),
                          ),
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[800]),
                          onChanged: (value) {
                            setState(() {
                              montoPorAbono = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 30),

                  // Selector de fecha con el botón de agregar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Fecha de Pago:",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: fechaPago,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime
                                        .now(), // Limita la selección hasta hoy
                                  );
                                  if (pickedDate != null &&
                                      pickedDate != fechaPago) {
                                    setState(() {
                                      fechaPago = pickedDate;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey[600]!, width: 1.2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${fechaPago.toLocal()}".split(' ')[0],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Icon(Icons.calendar_today,
                                          color: Color(0xFFFB2056)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 30),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFFB2056),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                              child: Text(
                                "Agregar Abono",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white),
                              ),
                              onPressed: () {
                                if (montoPorAbono > 0.0) {
                                  setState(() {
                                    abonos.add({
                                      'monto': montoPorAbono,
                                      'fecha': "${fechaPago.toLocal()}"
                                          .split(' ')[0],
                                    });
                                    montoPorAbono = 0.0;
                                    montoController
                                        .clear(); // Limpiar el TextField
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Mostrar los abonos registrados
              if (abonos.isNotEmpty) ...[
                Text(
                  "Abonos registrados:",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  height: 170,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: abonos.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 5),
                        color: Colors.grey[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            "Monto: \$${abonos[index]['monto']} - Fecha: ${abonos[index]['fecha']}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Mostrar los totales, lo que falta y el monto total
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Abonado: \$${totalAbonos.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 100),
                  Text(
                    "Monto a Pagar: \$${widget.montoAPagar.toStringAsFixed(2)}", // Usar montoAPagar aquí
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "Falta: \$${montoFaltante.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Botón de Confirmar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      "Confirmar",
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    onPressed: () {
                      widget.onConfirm(abonos); // Pasar los abonos al callback
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Clase PaginaIntegrantes: Widget que muestra la tabla
class PaginaIntegrantes extends StatelessWidget {
  final List<ClienteMonto> clientesMontosInd;
  final String tipoPlazo;

  const PaginaIntegrantes({
    Key? key,
    required this.clientesMontosInd,
    required this.tipoPlazo,
  }) : super(key: key);

  String formatearNumero(double numero) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numero);
  }

  @override
  Widget build(BuildContext context) {
    // Variables para el estilo del texto
    const headerTextStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 13, // Tamaño de fuente del encabezado
    );

    const contentTextStyle = TextStyle(
      fontSize: 12, // Tamaño de fuente del contenido
      color: Colors.black87,
    );

    // Estilo para la fila de totales
    const totalRowTextStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );

    // Método para construir las celdas del encabezado
    Widget _buildHeaderCell(String text) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Text(text, style: headerTextStyle, textAlign: TextAlign.center),
        ),
      );
    }

// Método para construir las celdas de datos
    Widget _buildDataCell(String text) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Text(text, style: contentTextStyle, textAlign: TextAlign.center),
        ),
      );
    }

// Método para construir las celdas de totales
    Widget _buildTotalCell(String text) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Text(text, style: totalRowTextStyle, textAlign: TextAlign.center),
        ),
      );
    }

    const totalRowColor = Color(0xFFFB2056); // Rojo para la fila de totales

    // Verifica el tipo de plazo y ajusta el texto de los encabezados
    final pagoColumnText = tipoPlazo == 'Semanal' ? 'Pago Sem.' : 'Pago Qna.';
    final capitalColumnText =
        tipoPlazo == 'Semanal' ? 'Capital Sem.' : 'Capital Qna.';
    final interesColumnText =
        tipoPlazo == 'Semanal' ? 'Interés Sem.' : 'Interés Qna.';

    // Sumar las columnas numéricas
    double sumCapitalIndividual = 0;
    double sumPeriodoCapital = 0;
    double sumPeriodoInteres = 0;
    double sumTotalCapital = 0;
    double sumTotalIntereses = 0;
    double sumCapitalMasInteres = 0;
    double sumTotal = 0;

    for (var cliente in clientesMontosInd) {
      sumCapitalIndividual += cliente.capitalIndividual;
      sumPeriodoCapital += cliente.periodoCapital;
      sumPeriodoInteres += cliente.periodoInteres;
      sumTotalCapital += cliente.totalCapital;
      sumTotalIntereses += cliente.totalIntereses;
      sumCapitalMasInteres += cliente.capitalMasInteres;
      sumTotal += cliente.total;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double tableWidth = constraints.maxWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: tableWidth,
              child: Column(
                children: [
                  // Encabezado de la tabla (como un Row con fondo y bordes redondeados)
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Color(0xFFFB2056), // Fondo del encabezado
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell("Nombre"),
                        _buildHeaderCell("M. Individual"),
                        _buildHeaderCell(capitalColumnText),
                        _buildHeaderCell(interesColumnText),
                        _buildHeaderCell("Total Capital"),
                        _buildHeaderCell("Total Interes"),
                        _buildHeaderCell(pagoColumnText),
                        _buildHeaderCell("Pago Total"),
                      ],
                    ),
                  ),
                  // Cuerpo de la tabla: Lista de datos (Rows)
                  for (var cliente in clientesMontosInd)
                    Row(
                      children: [
                        _buildDataCell(cliente.nombreCompleto),
                        _buildDataCell(
                            "\$${formatearNumero(cliente.capitalIndividual)}"),
                        _buildDataCell(
                            "\$${formatearNumero(cliente.periodoCapital)}"),
                        _buildDataCell(
                            "\$${formatearNumero(cliente.periodoInteres)}"),
                        _buildDataCell(
                            "\$${formatearNumero(cliente.totalCapital)}"),
                        _buildDataCell(
                            "\$${formatearNumero(cliente.totalIntereses)}"),
                        _buildDataCell(
                            "\$${formatearNumero(cliente.capitalMasInteres)}"),
                        _buildDataCell("\$${formatearNumero(cliente.total)}"),
                      ],
                    ),
                  // Fila de totales (con color y bordes redondeados)
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: totalRowColor, // Fondo de la fila de totales
                      borderRadius: BorderRadius.all(
                        Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildTotalCell("Totales"),
                        _buildTotalCell(
                            "\$${formatearNumero(sumCapitalIndividual)}"),
                        _buildTotalCell(
                            "\$${formatearNumero(sumPeriodoCapital)}"),
                        _buildTotalCell(
                            "\$${formatearNumero(sumPeriodoInteres)}"),
                        _buildTotalCell(
                            "\$${formatearNumero(sumTotalCapital)}"),
                        _buildTotalCell(
                            "\$${formatearNumero(sumTotalIntereses)}"),
                        _buildTotalCell(
                            "\$${formatearNumero(sumCapitalMasInteres)}"),
                        _buildTotalCell("\$${formatearNumero(sumTotal)}"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
