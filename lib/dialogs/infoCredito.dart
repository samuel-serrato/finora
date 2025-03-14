import 'dart:async';
import 'dart:io';
import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:finora/ip.dart';
import 'package:finora/models/pago_seleccionado.dart';
import 'package:finora/screens/login.dart';
import 'package:process_run/process_run.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../providers/pagos_provider.dart';
import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

class InfoCredito extends StatefulWidget {
  final String folio;

  InfoCredito({required this.folio});

  @override
  _InfoCreditoState createState() => _InfoCreditoState();
}

class _InfoCreditoState extends State<InfoCredito> {
  Credito? creditoData; // Ahora es de tipo Credito? (nulo permitido)
  bool isLoading = true;
  bool errorDeConexion = false; // Para indicar si hubo un error de conexión.
  bool dialogShown = false;
  Timer? _timer;
  late ScrollController _scrollController;
  String idCredito = '';
  final GlobalKey<_PaginaControlState> paginaControlKey = GlobalKey();
  bool isSending = false; // Nuevo estado para controlar la carga

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

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    bool dialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final url = 'http://$baseUrl/api/v1/creditos/${widget.folio}';
      final response = await http.get(
        Uri.parse(url),
        headers: {'tokenauth': token},
      );

      _timer?.cancel();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          if (mounted) {
            setState(() {
              creditoData = Credito.fromJson(data[0]);
              isLoading = false;
            });
          }
        } else {
          _handleError(dialogShown, 'Error en la carga de datos...');
        }
        idCredito = creditoData!.idcredito;
      } else if (response.statusCode == 404) {
        final errorData = json.decode(response.body);
        if (errorData["Error"]["Message"] == "jwt expired") {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('tokenauth');
          _handleError(dialogShown,
              'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
              redirectToLogin: true);
        } else {
          _handleError(dialogShown, 'Error: ${response.statusCode}');
        }
      } else {
        print('Respuesta:${response.body}');
        _handleError(dialogShown, 'Error: ${response.statusCode}');
      }
    } catch (e) {
      _handleError(dialogShown, 'Error: $e');
    }
  }

  void _handleError(bool dialogShown, String mensaje,
      {bool redirectToLogin = false}) {
    _timer?.cancel();

    if (mounted) {
      setState(() {
        isLoading = false;
        errorDeConexion = true;
      });
    }

    if (!dialogShown) {
      dialogShown = true;
      _showErrorDialog(mensaje,
          onClose: redirectToLogin
              ? () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => LoginScreen()));
                }
              : null);
    }
  }

  void _showErrorDialog(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onClose != null) onClose();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> generarPagoJson(
    List<PagoSeleccionado> pagosSeleccionados,
    List<PagoSeleccionado> pagosOriginales,
  ) {
    if (pagosSeleccionados.isEmpty) return [];

    List<Map<String, dynamic>> pagosJson = [];

    for (PagoSeleccionado pagoActual in pagosSeleccionados) {
      PagoSeleccionado pagoOriginal = pagosOriginales.firstWhere(
        (p) => p.idfechaspagos == pagoActual.idfechaspagos,
        orElse: () => pagoActual,
      );

      bool tieneCambios = _compararPagos(pagoActual, pagoOriginal) ||
          pagoActual.abonos
              .any((abono) => !abono.containsKey('idpagosdetalles'));

      if (!tieneCambios) continue;

      double paidCapital = pagoOriginal.abonos
          .where((a) => a.containsKey('idpagosdetalles'))
          .fold(0.0, (sum, a) => sum + (a['deposito'] ?? 0.0));

      double paidMoratorio = pagoOriginal.abonos
          .where((a) => a.containsKey('idpagosdetalles'))
          .fold(0.0, (sum, a) => sum + (a['moratorio'] ?? 0.0));

      double totalDeuda =
          (pagoActual.capitalMasInteres ?? 0.0) + (pagoActual.moratorio ?? 0.0);

      // ===== Lógica para "Garantia" =====
      if (pagoActual.tipoPago?.toLowerCase() == 'garantia') {
        double totalDepositado = pagoActual.deposito ?? 0.0;
        double capitalPendiente = pagoActual.capitalMasInteres! - paidCapital;
        double moratorioPendiente = pagoActual.moratorio! - paidMoratorio;

        // Aplicar a capital primero
        double aplicadoCapital = totalDepositado.clamp(0.0, capitalPendiente);
        double remanente = totalDepositado - aplicadoCapital;

        // Aplicar remanente a moratorios
        double aplicadoMoratorio = remanente.clamp(0.0, moratorioPendiente);
        double saldofavor =
            (totalDepositado - (aplicadoCapital + aplicadoMoratorio))
                .clamp(0.0, double.infinity);

        pagosJson.add({
          "idfechaspagos": pagoActual.idfechaspagos,
          "fechaPago": pagoActual.fechaPago,
          "tipoPago": "Garantia",
          "montoaPagar": _redondear(pagoActual.capitalMasInteres ?? 0.0),
          "deposito": _redondear(aplicadoCapital),
          "moratorio": _redondear(aplicadoMoratorio),
          "saldofavor": _redondear(saldofavor),
        });
        continue;
      }

      // ===== Lógica para "Completo" =====
      if (pagoActual.tipoPago?.toLowerCase() == 'completo') {
        double saldoPendiente = totalDeuda - (paidCapital + paidMoratorio);
        double deposito = pagoActual.capitalMasInteres ?? 0.0;
        double saldofavor = (pagoActual.deposito ?? 0.0) - deposito;

        pagosJson.add({
          "idfechaspagos": pagoActual.idfechaspagos,
          "fechaPago": formatearFechaJSON(pagoActual.fechaPago),
          "tipoPago": "Completo",
          "montoaPagar": _redondear(pagoActual.capitalMasInteres ?? 0.0),
          "deposito": _redondear(deposito),
          "moratorio": _redondear(
              0.0), // En "Completo", el moratorio se incluye en el depósito total
          "saldofavor": _redondear(saldofavor),
        });
        continue; // Saltar al siguiente pago
      }

      // ===== Lógica para "Monto Parcial" =====
      if (pagoActual.tipoPago?.toLowerCase() == 'monto parcial') {
        double totalDepositado = pagoActual.deposito ?? 0.0;
        double capitalPendiente = pagoActual.capitalMasInteres! - paidCapital;
        double moratorioPendiente = pagoActual.moratorio! - paidMoratorio;

        // Aplicar a capital primero
        double aplicadoCapital = totalDepositado.clamp(0.0, capitalPendiente);
        double remanente = totalDepositado - aplicadoCapital;

        // Aplicar remanente a moratorios
        double aplicadoMoratorio = remanente.clamp(0.0, moratorioPendiente);
        double saldofavor =
            (totalDepositado - (aplicadoCapital + aplicadoMoratorio))
                .clamp(0.0, double.infinity);

        pagosJson.add({
          "idfechaspagos": pagoActual.idfechaspagos,
          "fechaPago": pagoActual.fechaPago,
          "tipoPago": "Monto Parcial",
          "montoaPagar": _redondear(pagoActual.capitalMasInteres ?? 0.0),
          "deposito": _redondear(aplicadoCapital),
          "moratorio": _redondear(aplicadoMoratorio),
          "saldofavor": _redondear(saldofavor),
        });
        continue; // Saltar al siguiente pago
      }

      // ===== Lógica para "En Abonos" =====
      // ===== Lógica para "En Abonos" =====
      // ===== Lógica para "En Abonos" =====
      List<Map<String, dynamic>> nuevosAbonos = pagoActual.abonos
          .where((abono) => !abono.containsKey('idpagosdetalles'))
          .toList();

      for (var abono in nuevosAbonos) {
        double montoAbono = (abono['deposito'] as num).toDouble();
        double remainingDeuda = totalDeuda - (paidCapital + paidMoratorio);

        double aplicadoCapital = 0.0;
        double aplicadoMoratorio = 0.0;
        double saldofavor = 0.0;

        // Calcular saldos pendientes, asegurando que no sean negativos
        double remainingCapital = (pagoActual.capitalMasInteres! - paidCapital)
            .clamp(0.0, double.infinity);
        double remainingMoratorio =
            (pagoActual.moratorio! - paidMoratorio).clamp(0.0, double.infinity);

        if (remainingDeuda > 0) {
          aplicadoCapital = montoAbono.clamp(0.0, remainingCapital);
          double remanente = montoAbono - aplicadoCapital;
          aplicadoMoratorio = remanente.clamp(0.0, remainingMoratorio);
          saldofavor = (montoAbono - (aplicadoCapital + aplicadoMoratorio))
              .clamp(0.0, double.infinity);
        } else {
          saldofavor = montoAbono;
        }

        // Usar la fecha de depósito del abono
        String fechaPagoAbono =
            abono['fechaDeposito']; // <-- Aquí se usa la fecha de depósito

        pagosJson.add({
          "idfechaspagos": pagoActual.idfechaspagos,
          "fechaPago": fechaPagoAbono, // <-- Fecha de depósito
          "tipoPago": "En Abonos",
          "montoaPagar": _redondear(pagoActual.capitalMasInteres ?? 0.0),
          "deposito": _redondear(aplicadoCapital),
          "moratorio": _redondear(aplicadoMoratorio),
          "saldofavor": _redondear(saldofavor),
        });

        // Actualizar acumulados
        paidCapital += aplicadoCapital;
        paidMoratorio += aplicadoMoratorio;
      }
      print('\n==== Procesando pago: ${pagoActual.idfechaspagos} ====');
      print('Tipo de pago: ${pagoActual.tipoPago}');
      print('Capital + Interés: ${pagoActual.capitalMasInteres}');
      print('Moratorios: ${pagoActual.moratorio}');
      print('Abonos previos (capital): $paidCapital');
      print('Abonos previos (moratorios): $paidMoratorio');
    }

    return pagosJson;
  }

  /// Compara si dos pagos son diferentes
  bool _compararPagos(PagoSeleccionado actual, PagoSeleccionado original) {
    return actual.deposito != original.deposito ||
        actual.capitalMasInteres != original.capitalMasInteres ||
        actual.moratorio != original.moratorio;
  }

  double _redondear(double valor, [int decimales = 2]) {
    return double.parse(valor.toStringAsFixed(decimales));
  }

// Método auxiliar para imprimir los datos de un PagoSeleccionado
  String _imprimirPago(PagoSeleccionado pago) {
    return '''
  {
    "idfechaspagos": "${pago.idfechaspagos}",
    "fechaPago": "${pago.fechaPago}",
    "tipoPago": "${pago.tipoPago}",
    "capitalMasInteres": ${pago.capitalMasInteres},
    "deposito": ${pago.deposito},
    "moratorio": ${pago.moratorio},
    "saldoFavor": ${pago.saldoFavor},
    "saldoEnContra": ${pago.saldoEnContra},
    "abonos": ${pago.abonos}
  }
  ''';
  }

  Future<void> enviarDatosAlServidor(
    BuildContext context,
    List<PagoSeleccionado> pagosSeleccionados,
  ) async {
    try {
      // Obtener los pagos originales del provider
      final pagosOriginales =
          Provider.of<PagosProvider>(context, listen: false).pagosOriginales;

      // Generar los datos JSON con la función que ya tienes
      List<Map<String, dynamic>> pagosJson =
          generarPagoJson(pagosSeleccionados, pagosOriginales);

      // URL del servidor
      final url = Uri.parse('http://$baseUrl/api/v1/pagos');

      // Obtener el token de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // Verificar que el token esté disponible
      if (token.isEmpty) {
        _handleError(false,
            'Token de autenticación no encontrado. Por favor, inicia sesión.',
            redirectToLogin: true);
        return;
      }

      // Datos a enviar
      print('Datos a enviar: $pagosJson');

      // Hacer la solicitud POST
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json', // Asegúrate de enviar como JSON
          'tokenauth': token, // Agregar el token al header
        },
        body: json.encode(pagosJson), // Convertir los datos a formato JSON
      );

      // Verificar la respuesta del servidor
      if (response.statusCode == 201) {
        print('Datos enviados exitosamente');
        mostrarDialogo(context, 'Éxito', 'Datos enviados exitosamente.');
      } else {
        // Verificar si la sesión ha expirado
        if (response.statusCode == 401) {
          // Código para sesión expirada
          _handleError(false,
              'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
              redirectToLogin: true);
          return;
        }

        // Imprimir detalles del error si la respuesta no es 201
        print('Error al enviar datos: ${response.statusCode}');
        print('Respuesta del servidor: ${response.body}');

        // Parsear la respuesta del servidor
        final Map<String, dynamic> respuesta = json.decode(response.body);
        final int codigoError = respuesta['Error']['Code'];
        final String mensajeError = respuesta['Error']['Message'];

        // Mostrar el error usando la misma función
        mostrarDialogo(
          context,
          'Error $codigoError',
          mensajeError,
          esError: true,
        );
      }
    } catch (e) {
      print('Error al hacer la solicitud: $e');
      mostrarDialogo(context, 'Error', 'Ocurrió un error: $e', esError: true);
    } finally {
      setState(() {
        isSending = false; // Asegurarse de desactivar el indicador de carga
      });
    }
  }

// Función para mostrar un diálogo genérico o de error con diseño
  void mostrarDialogo(BuildContext context, String titulo, String mensaje,
      {bool esError = false}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Row(
            children: [
              if (esError) Icon(Icons.error_outline, color: Colors.red),
              if (!esError) Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 10),
              Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: esError ? Colors.red : Colors.blue,
                ),
              ),
            ],
          ),
          content: Text(
            mensaje,
            textAlign: TextAlign.justify,
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
                Provider.of<PagosProvider>(context, listen: false)
                    .limpiarPagos();

                paginaControlKey.currentState?.recargarPagos();
              },
              icon: Icon(Icons.check, color: Colors.white),
              label: Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: esError ? Colors.red : Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    final width = MediaQuery.of(context).size.width * 0.97;
    final height = MediaQuery.of(context).size.height * 0.93;

    return Dialog(
        backgroundColor:
            isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA), // Fondo dinámico
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.all(16),
        child: Stack(
          children: [
            Container(
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
                                            Color(0xFF5162F6),
                                            Color(0xFF2D336B),
                                          ],
                                          begin: Alignment.centerRight,
                                          end: Alignment.centerLeft,
                                        ),
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(20)),
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 35,
                                              backgroundColor: Colors.white,
                                              child: Icon(
                                                Icons
                                                    .account_balance_wallet_rounded,
                                                size: 50,
                                                color: Color(0xFF5162F6),
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Información del Crédito',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Divider(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                thickness: 1),
                                            _buildDetailRow('Folio',
                                                creditoData!.folio.toString()),
                                            _buildDetailRow(
                                                'Grupo',
                                                creditoData!.nombreGrupo ??
                                                    'No disponible'),
                                            _buildDetailRow(
                                                'Tipo',
                                                creditoData!.tipoPlazo ??
                                                    'No disponible'),
                                            _buildDetailRow('Monto Total',
                                                "\$${formatearNumero(creditoData!.montoTotal ?? 0.0)}"),
                                            _buildDetailRow('Interés Mensual',
                                                "${creditoData!.ti_mensual ?? 0.0}%"),
                                            _buildDetailRow('Interés M. Monto',
                                                "\$${formatearNumero((creditoData!.montoTotal ?? 0.0) * (creditoData!.ti_mensual ?? 0.0) / 100)}"),
                                            _buildDetailRow('Garantía',
                                                "\$${creditoData!.garantia ?? 0.0}"),
                                            _buildDetailRow('Garantía Monto',
                                                "\$${creditoData!.montoGarantia ?? 0.0}"),
                                            _buildDetailRow(
                                              'Monto Desembolsado',
                                              "\$${formatearNumero(creditoData!.montoDesembolsado ?? 0.0)}",
                                            ),
                                            _buildDetailRow('Interés Global',
                                                "${creditoData!.interesGlobal ?? 0.0}%"),
                                            _buildDetailRow(
                                              'Día de Pago',
                                              creditoData!.diaPago ??
                                                  'Desconocido',
                                            ),
                                            SizedBox(height: 3),
                                            Divider(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                thickness: 1),
                                            SizedBox(height: 3),
                                            _buildDetailRow(
                                                creditoData!.tipoPlazo ==
                                                        'Semanal'
                                                    ? 'Capital Semanal'
                                                    : 'Capital Quincenal',
                                                "\$${formatearNumero(creditoData!.semanalCapital ?? 0.0)}"),
                                            _buildDetailRow('Capital Total',
                                                "\$${formatearNumero((creditoData!.semanalCapital * creditoData!.plazo) ?? 0.0)}"),
                                            _buildDetailRow(
                                                creditoData!.tipoPlazo ==
                                                        'Semanal'
                                                    ? 'Interés Semanal'
                                                    : 'Interés Quincenal',
                                                "\$${formatearNumero(creditoData!.semanalInteres ?? 0.0)}"),
                                            _buildDetailRow('Interés Total',
                                                "\$${formatearNumero(creditoData!.interesTotal ?? 0.0)}"),
                                            SizedBox(height: 3),
                                            Divider(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                thickness: 1),
                                            SizedBox(height: 3),
                                            _buildDetailRow(
                                              creditoData!.tipoPlazo ==
                                                      'Semanal'
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
                                              creditoData!.estado != null
                                                  ? creditoData!.estado
                                                      .toString()
                                                  : 'No disponible',
                                            ),
                                            _buildDetailRow(
                                              'Fecha de Creación',
                                              formatearFecha(
                                                  creditoData?.fCreacion ??
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TabBar(
                                            labelColor: Color(0xFF5162F6),
                                            unselectedLabelColor: Colors.grey,
                                            indicatorColor: Color(0xFF5162F6),
                                            tabs: [
                                              Tab(text: 'Control'),
                                              Tab(text: 'Integrantes'),
                                              Tab(text: 'Descargables'),
                                            ],
                                          ),
                                          Expanded(
                                            child: TabBarView(
                                              children: [
                                                SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      _buildSectionTitle(
                                                          'Control de Pagos'),
                                                      PaginaControl(
                                                        key: paginaControlKey,
                                                        idCredito: idCredito,
                                                        montoGarantia: creditoData!
                                                                .montoGarantia ??
                                                            0.0,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      _buildSectionTitle(
                                                          'Integrantes'),
                                                      SizedBox(height: 12),
                                                      PaginaIntegrantes(
                                                        clientesMontosInd:
                                                            creditoData!
                                                                .clientesMontosInd,
                                                        tipoPlazo: creditoData!
                                                            .tipoPlazo,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      _buildSectionTitle(
                                                          'Descargables'),
                                                      PaginaDescargables(
                                                        tipo: creditoData!.tipo,
                                                        folio:
                                                            creditoData!.folio,
                                                      )
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
                            : Center(
                                child: Text('No se ha cargado la información')),
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
                        /* ElevatedButton(
                          onPressed: () {
                            // Reinicia los datos del Provider
                            Provider.of<PagosProvider>(context, listen: false)
                                .limpiarPagos();

                            // Opcional: muestra un mensaje para confirmar el reinicio
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Los datos se han reiniciado correctamente.')),
                            );
                          },
                          child: Text('Reiniciar Datos'),
                        ), */
                        ElevatedButton(
                          onPressed: isSending
                              ? null // Deshabilita el botón si está enviando
                              : () async {
                                  setState(() {
                                    isSending =
                                        true; // Activar el indicador de carga
                                  });

                                  // Delay of 1 second
                                  await Future.delayed(
                                      Duration(milliseconds: 500));

                                  final pagosSeleccionados =
                                      Provider.of<PagosProvider>(context,
                                              listen: false)
                                          .pagosSeleccionados;
                                  final pagosOriginales =
                                      Provider.of<PagosProvider>(context,
                                              listen: false)
                                          .pagosOriginales;

                                  // Generar JSON solo con los datos modificados
                                  List<Map<String, dynamic>> pagosJson =
                                      generarPagoJson(
                                          pagosSeleccionados, pagosOriginales);

                                  // Verificar si hay datos modificados para enviar
                                  if (pagosJson.isNotEmpty) {
                                    print('Datos a enviar: $pagosJson');
                                    // Llamar a la función para enviar los datos al servidor
                                    await enviarDatosAlServidor(
                                        context, pagosSeleccionados);
                                  } else {
                                    print("No hay cambios para guardar.");
                                  }

                                  setState(() {
                                    isSending =
                                        false; // Desactivar el indicador de carga
                                  });
                                },
                          child: isSending
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('Guardar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isSending)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(
                      0.3), // Semi-transparent background works for both modes
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode ? Colors.black54 : Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Color(
                                0xFF5162F6), // Primary color stays the same
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Guardando...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ));
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

  // Función para formatear fechas
  String formatearFechaJSON(Object? fecha) {
    print("Fecha original: $fecha");
    if (fecha is String) {
      try {
        // Convertir la cadena en DateTime
        final parsedDate = DateTime.parse(fecha);
        // Convertir a formato ISO 8601
        final isoDate = parsedDate.toIso8601String();
        print("Fecha convertida a ISO 8601: $isoDate");
        return isoDate;
      } catch (e) {
        print("Error al parsear la fecha: $e");
        return 'Fecha no válida';
      }
    } else if (fecha is DateTime) {
      final isoDate = fecha.toIso8601String();
      print("Fecha DateTime convertida a ISO 8601: $isoDate");
      return isoDate;
    } else {
      print("Tipo de dato no válido para fecha: ${fecha.runtimeType}");
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
  final double montoGarantia;
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
  final String estado;
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
    required this.montoGarantia,
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
    required this.estado,
    required this.fCreacion,
    required this.clientesMontosInd,
  });

  factory Credito.fromJson(Map<String, dynamic> json) {
    //print("Procesando JSON: $json");
    //print("Campo plazo: ${json['plazo']}");
    //print("Campo numPago: ${json['numPago']}");
    return Credito(
      idcredito: json['idcredito'] ?? "",
      idgrupos: json['idgrupos'] ?? "",
      nombreGrupo: json['nombreGrupo'] ?? "",
      diaPago: json['diaPago'] ?? "",
      plazo: json['plazo'] ?? 0, // Ya es un número, no necesita conversión
      tipoPlazo: json['tipoPlazo'] ?? "",
      tipo: json['tipo'] ?? "",
      ti_mensual: (json['ti_mensual'] as num?)?.toDouble() ?? 0.0,
      folio: json['folio'] ?? "",
      garantia: json['garantia'] ?? "",
      montoGarantia: (json['montoGarantia'] as num?)?.toDouble() ?? 0.0,
      montoDesembolsado: (json['montoDesembolsado'] as num?)?.toDouble() ?? 0.0,
      interesGlobal: (json['interesGlobal'] as num?)?.toDouble() ?? 0.0,
      semanalCapital: (json['semanalCapital'] as num?)?.toDouble() ?? 0.0,
      semanalInteres: (json['semanalInteres'] as num?)?.toDouble() ?? 0.0,
      montoTotal: (json['montoTotal'] as num?)?.toDouble() ?? 0.0,
      interesTotal: (json['interesTotal'] as num?)?.toDouble() ?? 0.0,
      montoMasInteres: (json['montoMasInteres'] as num?)?.toDouble() ?? 0.0,
      pagoCuota: (json['pagoCuota'] as num?)?.toDouble() ?? 0.0,
      numPago: json['numPago'] ?? "", // Este es un texto
      fechasIniciofin: json['fechasIniciofin'] ?? "",
      estado:
          json['estado_credito']?['esatado'] ?? "", // Manejo del objeto anidado
      fCreacion: json['fCreacion'] ?? "",
      clientesMontosInd: (json['clientesMontosInd'] as List? ?? [])
          .map((e) => ClienteMonto.fromJson(e))
          .toList(),
    );
  }
}

class PaginaControl extends StatefulWidget {
  final String idCredito;
  final double montoGarantia;

  PaginaControl(
      {Key? key, required this.idCredito, required this.montoGarantia})
      : super(key: key);

  @override
  _PaginaControlState createState() => _PaginaControlState();
}

class _PaginaControlState extends State<PaginaControl> {
  late Future<List<Pago>> _pagosFuture;
  Map<int, bool> editingState = {};
  List<TextEditingController> controllers = [];
  bool isLoading = true;
  Timer? _debounce;
  bool dialogShown = false;

  @override
  void initState() {
    super.initState();
    _pagosFuture = _fetchPagos();
  }

  Future<void> recargarPagos() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    await Future.delayed(Duration(milliseconds: 500));

    try {
      List<Pago> pagos = await _fetchPagos();
      if (mounted) {
        setState(() {
          _pagosFuture = Future.value(pagos);
          isLoading = false;
        });

        // Actualizar el PagosProvider con los nuevos pagos
        _actualizarProviderConPagos(pagos);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      _mostrarDialogoError('Error al cargar los pagos: $e');
    }
  }

  Future<List<Pago>> _fetchPagos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse(
            'http://$baseUrl/api/v1/creditos/calendario/${widget.idCredito}'),
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Pago> pagos = data.map((pago) => Pago.fromJson(pago)).toList();

        // Dentro de _fetchPagos:
        // Dentro de _fetchPagos después de obtener la lista de pagos:
        for (var pago in pagos) {
          double totalDeuda = (pago.capitalMasInteres ?? 0.0) +
              (pago.moratorios?.moratorios ?? 0.0);

          // Verificar si hay garantía
          bool tieneGarantia =
              pago.abonos.any((abono) => abono['garantia'] == 'Si');

          // Calcular el monto total pagado, incluyendo garantía y abonos adicionales
          double montoPagado = 0.0;

          // Sumar todos los abonos, incluyendo los marcados como garantía
          for (var abono in pago.abonos) {
            montoPagado += double.tryParse(abono['abono'].toString()) ?? 0.0;
          }

          // Verificar si hay actividad en el pago
          bool sinActividad = pago.abonos.isEmpty;

          if (sinActividad) {
            pago.saldoEnContra = 0.0;
            pago.saldoFavor = 0.0;
          } else {
            // Verificar si el pago está liquidado
            bool estaPagado = montoPagado >= totalDeuda;

            if (estaPagado) {
              pago.saldoEnContra = 0.0;
              pago.saldoFavor =
                  tieneGarantia ? 0.0 : (montoPagado - totalDeuda);
            } else {
              pago.saldoEnContra = totalDeuda - montoPagado;
              pago.saldoFavor = 0.0;
            }
          }
        }

        // Cargar los pagos en el provider
        _actualizarProviderConPagos(pagos);

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        return pagos;
      } else {
        print('Respuesta:${response.body}');
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      _mostrarDialogoError('Error: $e');
      throw Exception(e);
    }
  }

  void _actualizarProviderConPagos(List<Pago> pagos) {
    final pagosProvider = Provider.of<PagosProvider>(context, listen: false);
    pagosProvider.cargarPagos(pagos
        .map((pago) => PagoSeleccionado(
              semana: pago.semana,
              tipoPago: pago.tipoPago,
              deposito: pago.deposito ?? 0.0,
              saldoFavor: 0.0,
              saldoEnContra: 0.0,
              abonos: pago.abonos ?? [],
              idfechaspagos: pago.idfechaspagos ?? '',
              fechaPago: pago.fechaPago ?? '',
            ))
        .toList());

    // Inicializamos los controladores para cada pago
    // En _actualizarProviderConPagos:
    controllers = List.generate(pagos.length, (index) {
      return TextEditingController(
        text: pagos[index].sumaDepositoMoratorisos != null &&
                pagos[index].sumaDepositoMoratorisos! > 0
            ? "\$${formatearNumero(pagos[index].sumaDepositoMoratorisos!)}" // Formatea aquí
            : "",
      );
    });
  }

  void _mostrarDialogoError(String mensaje) {
    if (!dialogShown && mounted) {
      dialogShown = true;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  dialogShown = false;
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  String formatearFecha(Object? fecha) {
    try {
      if (fecha is String && fecha.isNotEmpty) {
        final parsedDate = DateTime.parse(fecha);
        return DateFormat('dd/MM/yyyy').format(parsedDate);
      } else if (fecha is DateTime) {
        return DateFormat('dd/MM/yyyy').format(fecha);
      }
    } catch (e) {
      print('Error formateando la fecha: $e');
    }
    return 'Fecha no válida';
  }

  String formatearNumero(double numero) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numero);
  }

  bool _puedeEditarPago(Pago pago) {
    if (pago.moratorios != null) {
      return pago.moratorios!.montoTotal > pago.sumaDepositoMoratorisos!;
    } else {
      return (pago.capitalMasInteres ?? 0) >
          (pago.sumaDepositoMoratorisos ?? 0);
    }
  }

  String _formatFecha(String fecha) {
    if (fecha.isEmpty) return 'Sin fecha registrada';

    try {
      final DateTime parsedDate = DateTime.parse(fecha);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return FutureBuilder<List<Pago>>(
      future: _pagosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || isLoading) {
          return Padding(
            padding: const EdgeInsets.only(top: 200),
            child: Center(
                child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF5162F6)), // Cambiar a cualquier color que desees
            )),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No se encontraron pagos.'));
        } else {
          List<Pago> pagos = snapshot.data!;

          // Inicializamos los totales
          double totalMonto = 0.0; // Total de la deuda (capital + moratorios)
          double totalPagoActual = 0.0;
          double totalSaldoFavor = 0.0;
          double totalSaldoContra = 0.0;

          // Obtener la última semana (el pago más alto)
          int totalPagosDelCredito = pagos.isNotEmpty
              ? pagos.map((pago) => pago.semana).reduce((a, b) => a > b ? a : b)
              : 0; // Si hay pagos, obtenemos la semana más alta

          print('totalPagosDelCredito: $totalPagosDelCredito');

          // Calculamos el totalMonto como capitalMasInteres * totalPagosDelCredito
          if (totalPagosDelCredito > 0) {
            double capitalMasInteres =
                pagos.isNotEmpty ? pagos.last.capitalMasInteres : 0.0;
            totalMonto = capitalMasInteres * totalPagosDelCredito;
          }

          double saldoAcumuladoContra = 0.0;

          for (int i = 0; i < pagos.length; i++) {
            final pago = pagos[i];

            // Excluir semana 0 (cuando no hay pagos aún)
            if (i == 0) {
              continue; // No se hace ningún cálculo para la semana 0
            }

            double capitalMasInteres = pago.capitalMasInteres ?? 0.0;
            double deposito = pago.deposito ?? 0.0;
            double moratorios = pago.moratorios?.moratorios ?? 0.0;

            // Usar sumaDepositoMoratorios en lugar de los abonos
            double sumaDepositoMoratorios = pago.sumaDepositoMoratorisos ?? 0.0;

            if (sumaDepositoMoratorios == 0.0) {
              sumaDepositoMoratorios = pago.abonos.fold(
                    0.0,
                    (sum, abono) => sum + (abono['deposito'] ?? 0.0),
                  ) +
                  deposito;
            }

            // Total de la deuda incluye capital + interés + moratorios
            double totalDeuda = capitalMasInteres + moratorios;

            // Monto pagado es el valor de sumaDepositoMoratorios
            double montoPagado = sumaDepositoMoratorios;

            // Verificar si se usó garantía en este pago
            bool tieneGarantia =
                pago.abonos.any((abono) => abono['garantia'] == 'Si');

// Corregir el cálculo cuando hay garantía
            if (tieneGarantia) {
              // Sumar TODOS los abonos, tanto garantía como pagos adicionales
              montoPagado = pago.abonos.fold(
                0.0,
                (sum, abono) =>
                    sum +
                    (double.tryParse(abono['deposito'].toString()) ?? 0.0),
              );
            }
            // Acumular el pago actual
            totalPagoActual += montoPagado;

            // Verificar si el monto pagado excede lo que debe (capital + intereses + moratorios)
            double saldoFavor = 0.0;
            double saldoContra = 0.0;

            // Código corregido:
            if (tieneGarantia) {
              saldoFavor = 0.0;
              saldoContra =
                  totalDeuda - montoPagado; // <-- Usar el monto real pagado
            } else {
              // Si no hay garantía, calcular saldos normalmente
              if (montoPagado >= totalDeuda) {
                saldoFavor = montoPagado - totalDeuda;
              } else {
                saldoContra = totalDeuda - montoPagado;
              }
            }

            // Si el saldo en contra es igual al total de la deuda, restablecer a 0
            if (saldoContra == totalDeuda) {
              saldoContra = 0.0;
            }

            // Si hay saldo a favor, este debe restar del saldo acumulado en contra
            if (saldoFavor > 0) {
              // Restamos del saldo en contra si es posible
              if (saldoAcumuladoContra > 0) {
                if (saldoAcumuladoContra <= saldoFavor) {
                  saldoFavor -= saldoAcumuladoContra;
                  saldoAcumuladoContra = 0;
                } else {
                  saldoAcumuladoContra -= saldoFavor;
                  saldoFavor = 0;
                }
              }
              totalSaldoFavor += saldoFavor;
            }

            // Si no hay saldo a favor, simplemente acumulamos el saldo en contra
            if (saldoContra > 0) {
              saldoAcumuladoContra += saldoContra;
            }

            // Acumular totales evitando duplicaciones
            if (saldoAcumuladoContra > 0) {
              totalSaldoContra = saldoAcumuladoContra;
            }

            // Debugging: Para verificar si los valores son correctos
            print("Pago $i");
            print("  Total deuda: $totalDeuda");
            print("  Monto pagado: $montoPagado");
            print("  Saldo Favor: $saldoFavor");
            print("  Saldo Contra: $saldoContra");

            pago.saldoEnContra = saldoContra; // <-- ¡Clave!
            pago.saldoFavor = saldoFavor;

            // Debugging
            print(
                "Pago ${pago.semana}: Saldo en contra UI = ${pago.saldoEnContra}");
          }

          // Mostrar los totales correctamente
          totalSaldoFavor = totalSaldoFavor > 0.0 ? totalSaldoFavor : 0.0;
          totalSaldoContra = totalSaldoContra > 0.0 ? totalSaldoContra : 0.0;

          print("=== Totales Finales ===");
          print(
              "  Total Monto: $totalMonto"); // Total de la deuda (capital + moratorios)
          print("  Total Pagos Realizados: $totalPagoActual");
          print(
              "  Total Saldo a Favor: ${totalSaldoFavor == 0.0 ? '-' : totalSaldoFavor.toStringAsFixed(2)}");
          print(
              "  Total Saldo en Contra: ${totalSaldoContra == 0.0 ? '-' : totalSaldoContra.toStringAsFixed(2)}");

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF5162F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildTableCell("No. Pago",
                          isHeader: true, textColor: Colors.white, flex: 12),
                      _buildTableCell("Fecha Pago",
                          isHeader: true, textColor: Colors.white, flex: 15),
                      _buildTableCell("Monto a Pagar",
                          isHeader: true,
                          textColor: Colors.white,
                          flex: 20), // Nueva columna
                      _buildTableCell("Pago",
                          isHeader: true, textColor: Colors.white, flex: 22),
                      _buildTableCell("Monto",
                          isHeader: true, textColor: Colors.white, flex: 20),
                      _buildTableCell("Saldo a Favor",
                          isHeader: true, textColor: Colors.white, flex: 18),
                      _buildTableCell("Saldo en Contra",
                          isHeader: true, textColor: Colors.white, flex: 18),
                      _buildTableCell("Moratorios",
                          isHeader: true,
                          textColor: Colors.white,
                          flex: 18), // Nueva columna
                    ],
                  ),
                ),
              ),
              Container(
                height: MediaQuery.of(context).size.height *
                    0.55, // ← Ajusta el porcentaje
                child: SingleChildScrollView(
                  child: Column(
                    children: pagos.map((pago) {
                      bool esPago1 = pagos.indexOf(pago) == 0;
                      int index = pagos.indexOf(pago);

                      double saldoFavor = 0.0;
                      double saldoContra = 0.0;

                      if (!esPago1) {
                        double capitalMasInteres =
                            pago.capitalMasInteres ?? 0.0;
                        double moratorio = pago.moratorios!.moratorios ?? 0.0;

                        // Total a pagar incluyendo moratorios
                        double montoAPagarTotal = capitalMasInteres + moratorio;

                        // Total de abonos de la semana
                        double totalAbonos = pago.abonos.fold(0.0,
                            (sum, abono) => sum + (abono['deposito'] ?? 0.0));

                        // Monto total pagado (solo abonos)
                        double montoPagado = totalAbonos;

                        // Calcular saldos
                        if (montoPagado > montoAPagarTotal) {
                          saldoFavor = montoPagado - montoAPagarTotal;
                          saldoContra = 0.0;
                        } else if (montoPagado < montoAPagarTotal) {
                          saldoContra = montoAPagarTotal - montoPagado;
                          saldoFavor = 0.0;
                        } else {
                          saldoFavor = 0.0;
                          saldoContra = 0.0;
                        }

                        // Si el saldo en contra es igual al monto total a pagar, se pone a 0
                        if (saldoContra == montoAPagarTotal) {
                          saldoContra = 0.0;
                        }

                        print(
                            'Pago de la semana ${pago.semana}: Saldo a favor: $saldoFavor, Saldo en contra: $saldoContra');
                      }

                      // Convierte la fecha del pago a DateTime
                      DateTime fechaPagoDateTime =
                          DateTime.parse(pago.fechaPago);

                      return Container(
                        decoration: BoxDecoration(
                          color: _puedeEditarPago(pago)
                              ? Colors
                                  .transparent // Fondo transparente si es editable
                              : isDarkMode
                                  ? Colors.blueGrey
                                      .shade900 // Fondo oscuro para pagos no editables en dark mode
                                  : Colors.blueGrey
                                      .shade50, // Fondo claro para pagos no editables en light mode
                          border: Border(
                            bottom: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Color(0xFFEEEEEE),
                                width: 1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              _buildTableCell(esPago1 ? "0" : "${pago.semana}",
                                  flex: 12),
                              _buildTableCell(formatearFecha(pago.fechaPago),
                                  flex: 15),
                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : "\$${formatearNumero(pago.capitalMasInteres)}",
                                flex: 20,
                              ),
                              // Celda para tipo de pago
                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DropdownButton<String?>(
                                            value: pago.tipoPago.isEmpty
                                                ? null
                                                : pago.tipoPago,
                                            hint: Text(
                                              pago.tipoPago.isEmpty
                                                  ? "Seleccionar Pago"
                                                  : "",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                            ),
                                            items: <String>[
                                              'Completo',
                                              'Monto Parcial',
                                              'En Abonos',
                                              if (pago.semana >=
                                                  totalPagosDelCredito - 1)
                                                'Garantia',
                                            ].map((String value) {
                                              return DropdownMenuItem<String?>(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: _puedeEditarPago(
                                                            pago)
                                                        ? isDarkMode
                                                            ? Colors.white
                                                            : Colors.black
                                                        : isDarkMode
                                                            ? Colors.grey[400]
                                                            : Colors.grey[700],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: _puedeEditarPago(pago)
                                                ? (String? newValue) {
                                                    setState(() {
                                                      pago.tipoPago = newValue!;
                                                      print(
                                                          "Pago seleccionado: Semana ${pago.semana}, Tipo de pago: $newValue, Fecha de pago: ${pago.fechaPago}, ID Fechas Pagos: ${pago.idfechaspagos}, Monto a Pagar: ${pago.capitalMasInteres}");

                                                      // Manejar diferentes tipos de pago
                                                      // Manejar diferentes tipos de pago
                                                      if (newValue ==
                                                          'Completo') {
                                                        double montoAPagar =
                                                            pago.capitalMasInteres ??
                                                                0.0;
                                                        pago.deposito =
                                                            montoAPagar;
                                                        pago.fechaPagoCompleto =
                                                            DateTime.now()
                                                                .toString();
                                                        if (pago.fechaPago
                                                            .isEmpty) {
                                                          pago.fechaPago =
                                                              DateTime.now()
                                                                  .toString();
                                                        }
                                                      }
                                                      // Agregar manejo para 'Monto Parcial'
                                                      else if (newValue ==
                                                          'Monto Parcial') {
                                                        // Establecer fecha actual y limpiar fechaPagoCompleto
                                                        pago.fechaPagoCompleto =
                                                            DateTime.now()
                                                                .toString();
                                                        if (pago.fechaPago
                                                            .isEmpty) {
                                                          pago.fechaPago =
                                                              DateTime.now()
                                                                  .toString();
                                                        }
                                                      } else if (newValue ==
                                                          'Garantia') {
                                                        // Asignar valor de garantía desde el widget
                                                        pago.deposito = widget
                                                            .montoGarantia;

                                                        // Cambiar estas líneas para usar la fecha seleccionada
                                                        pago.fechaPagoCompleto =
                                                            pago.fechaPagoCompleto
                                                                    .isEmpty
                                                                ? DateTime.now()
                                                                    .toString()
                                                                : pago
                                                                    .fechaPagoCompleto;

                                                        if (pago.fechaPago
                                                            .isEmpty) {
                                                          pago.fechaPago =
                                                              DateTime.now()
                                                                  .toString();
                                                        }

                                                        // Calcular totalDeuda incluyendo moratorios
                                                        double totalDeuda =
                                                            (pago.capitalMasInteres ??
                                                                    0.0) +
                                                                (pago.moratorios
                                                                        ?.moratorios ??
                                                                    0.0);

                                                        // Calcular saldos basados en el monto de garantía
                                                        if (widget
                                                                .montoGarantia >=
                                                            totalDeuda) {
                                                          pago.saldoFavor =
                                                              widget.montoGarantia -
                                                                  totalDeuda;
                                                          pago.saldoEnContra =
                                                              0.0;
                                                        } else {
                                                          pago.saldoEnContra =
                                                              totalDeuda -
                                                                  widget
                                                                      .montoGarantia;
                                                          pago.saldoFavor = 0.0;
                                                        }
                                                      }

                                                      // Crear objeto PagoSeleccionado
                                                      PagoSeleccionado
                                                          pagoSeleccionado =
                                                          PagoSeleccionado(
                                                        semana: pago.semana,
                                                        tipoPago: pago.tipoPago,
                                                        deposito:
                                                            pago.deposito ??
                                                                0.00,
                                                        fechaPago: pago
                                                                .fechaPagoCompleto
                                                                .isNotEmpty
                                                            ? pago
                                                                .fechaPagoCompleto
                                                            : pago
                                                                .fechaPago, // <-- Cambio clave aquí
                                                        idfechaspagos:
                                                            pago.idfechaspagos ??
                                                                '',
                                                        capitalMasInteres: pago
                                                            .capitalMasInteres,
                                                        moratorio: pago
                                                            .moratorios
                                                            ?.moratorios,
                                                        saldoFavor:
                                                            pago.saldoFavor,
                                                        saldoEnContra:
                                                            pago.saldoEnContra,
                                                        abonos: pago.abonos,
                                                      );

                                                      // Actualizar provider
                                                      Provider.of<PagosProvider>(
                                                              context,
                                                              listen: false)
                                                          .actualizarPago(
                                                              pagoSeleccionado
                                                                  .semana,
                                                              pagoSeleccionado);

                                                      // Debug: Imprimir estado actualizado
                                                      print(
                                                          "Estado del Provider después de actualización:");
                                                      Provider.of<PagosProvider>(
                                                              context,
                                                              listen: false)
                                                          .pagosSeleccionados
                                                          .forEach((pago) {
                                                        print(
                                                            "Pago en Provider: Semana ${pago.semana}, Tipo de pago: ${pago.tipoPago}, Monto a Pagar: ${pago.capitalMasInteres}, Deposito: ${pago.deposito}");
                                                      });
                                                    });
                                                  }
                                                : null,
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              color: _puedeEditarPago(pago)
                                                  ? Color(0xFF5162F6)
                                                  : isDarkMode
                                                      ? Colors.grey[600]
                                                      : Colors.grey[400],
                                            ),
                                            dropdownColor: isDarkMode
                                                ? Colors.grey[800]
                                                : Colors.white,
                                          ),
                                          // Fila para seleccionar la fecha (se muestra tanto en "Completo" como en "Monto Parcial")
                                          // Selector de fecha
                                          // Selector de fecha (modificar esta condición)
                                          if (_puedeEditarPago(pago) &&
                                              (pago.tipoPago == 'Completo' ||
                                                  pago.tipoPago ==
                                                      'Monto Parcial' ||
                                                  pago.tipoPago ==
                                                      'Garantia')) // <- Añadir Garantia aquí
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(top: 4.0),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: _puedeEditarPago(
                                                            pago)
                                                        ? () =>
                                                            _editarFechaPago(
                                                                context, pago)
                                                        : null,
                                                    style: ButtonStyle(
                                                      backgroundColor:
                                                          MaterialStateProperty
                                                              .resolveWith<
                                                                  Color>(
                                                        (states) =>
                                                            _puedeEditarPago(
                                                                    pago)
                                                                ? Color(
                                                                    0xFF5162F6)
                                                                : Colors
                                                                    .transparent,
                                                      ),
                                                      padding:
                                                          MaterialStateProperty
                                                              .all<EdgeInsets>(
                                                        EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical:
                                                                8), // Menos espacio interno
                                                      ),
                                                      minimumSize:
                                                          MaterialStateProperty
                                                              .all<Size>(Size(
                                                                  24,
                                                                  24)), // Tamaño mínimo
                                                      shape: MaterialStateProperty
                                                          .all<
                                                              RoundedRectangleBorder>(
                                                        RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      6.0),
                                                          side: BorderSide(
                                                            color: _puedeEditarPago(
                                                                    pago)
                                                                ? Color(0xFF5162F6)
                                                                    .withOpacity(
                                                                        0.3)
                                                                : (isDarkMode
                                                                        ? Colors.grey[
                                                                            600]!
                                                                        : Colors.grey[
                                                                            400]!)
                                                                    .withOpacity(
                                                                        0.3),
                                                            width: 0.8,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .calendar_month_outlined,
                                                      size: 18,
                                                      color: _puedeEditarPago(
                                                              pago)
                                                          ? Colors.white
                                                          : isDarkMode
                                                              ? Colors.grey[500]
                                                              : Colors
                                                                  .grey[400],
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    _formatFecha(pago
                                                            .fechaPagoCompleto
                                                            .isEmpty
                                                        ? pago.fechaPago
                                                        : pago
                                                            .fechaPagoCompleto),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDarkMode
                                                          ? Colors.grey[400]
                                                          : Colors.grey[600],
                                                      fontStyle: pago
                                                              .fechaPago.isEmpty
                                                          ? FontStyle.italic
                                                          : FontStyle.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          // Indicadores de Garantía DEBAJO del selector de fecha
                                          if (pago.tipoPago == 'Completo') ...[
                                            ...pago.abonos.map((abono) {
                                              final esGarantia =
                                                  (abono['garantia'] as String)
                                                          .toLowerCase() ==
                                                      'si';
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Column(
                                                  children: [
                                                    if (esGarantia)
                                                      Container(
                                                        margin: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 12),
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Color(
                                                                  0xFFE53888)
                                                              .withOpacity(
                                                                  isDarkMode
                                                                      ? 0.3
                                                                      : 0.2),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              "Garantía",
                                                              style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color(
                                                                      0xFFE53888)),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ],
                                      ),
                                flex: 22,
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
                                                color: _puedeEditarPago(pago)
                                                    ? const Color(0xFF5162F6)
                                                    : Colors.grey,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 5,
                                                    offset: Offset(2, 2),
                                                  ),
                                                ],
                                              ),
                                              child: IconButton(
                                                icon: const Icon(Icons.add,
                                                    color: Colors.white),
                                                onPressed: _puedeEditarPago(
                                                        pago)
                                                    ? () async {
                                                        // Obtén el provider y muestra el diálogo para agregar abonos
                                                        final pagosProvider =
                                                            Provider.of<
                                                                    PagosProvider>(
                                                                context,
                                                                listen: false);
                                                        var uuid = Uuid();

                                                        List<
                                                                Map<String,
                                                                    dynamic>>
                                                            nuevosAbonos =
                                                            (await showDialog(
                                                                  barrierDismissible:
                                                                      false,
                                                                  context:
                                                                      context,
                                                                  builder:
                                                                      (context) =>
                                                                          AbonosDialog(
                                                                    montoAPagar:
                                                                        pago.capitalMasInteres,
                                                                    onConfirm:
                                                                        (abonos) {
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop(
                                                                              abonos);
                                                                    },
                                                                  ),
                                                                )) ??
                                                                [];

                                                        print(
                                                            'Nuevos abonos recibidos: $nuevosAbonos');

                                                        setState(() {
                                                          if (nuevosAbonos
                                                              .isNotEmpty) {
                                                            nuevosAbonos
                                                                .forEach(
                                                                    (abono) {
                                                              // Asigna un UID único a cada abono
                                                              abono['uid'] =
                                                                  uuid.v4();

                                                              // Evita duplicados comparando UID
                                                              bool existeAbono = pago
                                                                  .abonos
                                                                  .any((existeAbono) =>
                                                                      existeAbono[
                                                                          'uid'] ==
                                                                      abono[
                                                                          'uid']);
                                                              if (!existeAbono) {
                                                                print(
                                                                    'Agregando abono con UID: ${abono['uid']}');

                                                                // Actualizar la fecha de pago con la fecha de depósito
                                                                pago.fechaPago =
                                                                    abono[
                                                                        'fechaDeposito']; // <-- Usar la fecha del diálogo

                                                                pago.abonos
                                                                    .add(abono);
                                                              } else {
                                                                print(
                                                                    'Abono duplicado detectado con UID: ${abono['uid']}');
                                                              }
                                                            });

                                                            // Recalcular totales
                                                            double totalAbonos =
                                                                pago.abonos
                                                                    .fold(
                                                              0.0,
                                                              (sum, abono) =>
                                                                  sum +
                                                                  (abono['deposito'] ??
                                                                      0.0),
                                                            );

                                                            // Se suma el moratorio si existe (consulta en el objeto moratorios)
                                                            double totalDeuda = pago
                                                                    .capitalMasInteres! +
                                                                (pago.moratorios
                                                                        ?.moratorios ??
                                                                    0.0);

                                                            double montoPagado =
                                                                totalAbonos;

                                                            if (montoPagado <
                                                                totalDeuda) {
                                                              pago.saldoEnContra =
                                                                  totalDeuda -
                                                                      montoPagado;
                                                              pago.saldoFavor =
                                                                  0.0;
                                                            } else {
                                                              pago.saldoEnContra =
                                                                  0.0;
                                                              pago.saldoFavor =
                                                                  montoPagado -
                                                                      totalDeuda;
                                                            }

                                                            print(
                                                                'Saldos recalculados -> Saldo a favor: ${pago.saldoFavor}, Saldo en contra: ${pago.saldoEnContra}');

                                                            // Actualiza el Provider
                                                            final index = pagosProvider
                                                                .pagosSeleccionados
                                                                .indexWhere((p) =>
                                                                    p.semana ==
                                                                    pago.semana);
                                                            final pagoActualizado =
                                                                PagoSeleccionado(
                                                              semana:
                                                                  pago.semana,
                                                              tipoPago:
                                                                  pago.tipoPago,
                                                              deposito:
                                                                  pago.deposito ??
                                                                      0.0,
                                                              saldoFavor: pago
                                                                  .saldoFavor,
                                                              saldoEnContra: pago
                                                                  .saldoEnContra,
                                                              abonos:
                                                                  pago.abonos,
                                                              idfechaspagos: pago
                                                                  .idfechaspagos,
                                                              fechaPago: pago
                                                                  .fechaPago, // <-- Usar la fecha del diálogo
                                                              capitalMasInteres:
                                                                  pago.capitalMasInteres,
                                                              moratorio: pago
                                                                  .moratorios
                                                                  ?.moratorios,
                                                            );
                                                            if (index != -1) {
                                                              pagosProvider
                                                                          .pagosSeleccionados[
                                                                      index] =
                                                                  pagoActualizado;
                                                            } else {
                                                              pagosProvider
                                                                  .agregarPago(
                                                                      pagoActualizado);
                                                            }
                                                          }
                                                        });
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Botón para ver los abonos realizados (PopupMenu)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isDarkMode
                                                        ? Colors.black54
                                                        : Colors.black26,
                                                    blurRadius: 5,
                                                    offset: Offset(2, 2),
                                                  ),
                                                ],
                                              ),
                                              child: PopupMenuButton<
                                                  Map<String, dynamic>>(
                                                tooltip: 'Mostrar Abonos',
                                                icon: const Icon(
                                                    Icons.visibility,
                                                    color: Colors.white),
                                                color: isDarkMode
                                                    ? Colors.grey[850]
                                                    : Colors.white,
                                                offset: const Offset(0, 45),
                                                onSelected: (item) {
                                                  // Aquí podrías manejar acciones según el item seleccionado (abono o moratorio)
                                                },
                                                itemBuilder: (context) {
                                                  List<
                                                          PopupMenuEntry<
                                                              Map<String,
                                                                  dynamic>>>
                                                      items = [];

                                                  // Agregar los abonos existentes
                                                  for (var abono
                                                      in pago.abonos) {
                                                    final fecha =
                                                        formatearFecha(abono[
                                                            'fechaDeposito']);
                                                    final monto =
                                                        (abono['deposito']
                                                                is num)
                                                            ? (abono['deposito']
                                                                    as num)
                                                                .toDouble()
                                                            : 0.0;
                                                    final esGarantia =
                                                        abono['garantia'] ==
                                                            "Si";

                                                    items.add(
                                                      PopupMenuItem(
                                                        value: abono,
                                                        child: Container(
                                                          width: double
                                                              .infinity, // Usa todo el ancho disponible
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 6.0,
                                                                  horizontal:
                                                                      10.0),
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .monetization_on,
                                                                color: esGarantia
                                                                    ? Colors
                                                                        .orange
                                                                    : Colors
                                                                        .green,
                                                                size: 18,
                                                              ),
                                                              const SizedBox(
                                                                  width:
                                                                      10), // Espaciado más uniforme
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      fecha,
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        color: isDarkMode
                                                                            ? Colors.grey[300]
                                                                            : Colors.black54,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            2), // Espacio reducido entre fecha y monto
                                                                    Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      children: [
                                                                        Text(
                                                                          "\$${formatearNumero(monto)}",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: isDarkMode
                                                                                ? Colors.white
                                                                                : Colors.black87,
                                                                          ),
                                                                        ),
                                                                        if (esGarantia)
                                                                          Container(
                                                                            padding:
                                                                                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                            decoration:
                                                                                BoxDecoration(
                                                                              color: Color(0xFFE53888).withOpacity(isDarkMode ? 0.3 : 0.2),
                                                                              borderRadius: BorderRadius.circular(6),
                                                                            ),
                                                                            child:
                                                                                const Text(
                                                                              "Garantía",
                                                                              style: TextStyle(
                                                                                fontSize: 10,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: Color(0xFFE53888),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  // Calcular el total de abonos, sumando depósitos y los moratorios (sumaMoratorios)
                                                  double totalAbonos =
                                                      pago.abonos.fold(
                                                    0.0,
                                                    (sum, abono) =>
                                                        sum +
                                                        ((abono['deposito']
                                                                is num)
                                                            ? (abono['deposito']
                                                                    as num)
                                                                .toDouble()
                                                            : 0.0),
                                                  ); /* +
                                                          pago.pagosMoratorios
                                                              .fold(
                                                            0.0,
                                                            (sum, moratorio) =>
                                                                sum +
                                                                ((moratorio['sumaMoratorios']
                                                                        is num)
                                                                    ? (moratorio['sumaMoratorios']
                                                                            as num)
                                                                        .toDouble()
                                                                    : 0.0),
                                                          ); */
                                                  // Reemplaza la variable booleana por un texto condicional
                                                  final String? textoEstado = pago
                                                              .estado ==
                                                          "Pagado"
                                                      ? "Liquidado"
                                                      : pago.estado == "Retraso"
                                                          ? "Pagado con Retraso"
                                                          : null;

                                                  items.add(
                                                    PopupMenuItem(
                                                      enabled: false,
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Divider(
                                                            color: isDarkMode
                                                                ? Colors
                                                                    .grey[700]
                                                                : Colors.grey,
                                                            thickness: 0.8,
                                                            height: 10,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        8.0,
                                                                    horizontal:
                                                                        12.0),
                                                            child: Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .calculate_rounded,
                                                                  color: isDarkMode
                                                                      ? Colors.blue[
                                                                          400]
                                                                      : Colors.blue[
                                                                          700],
                                                                  size: 20,
                                                                ),
                                                                const SizedBox(
                                                                    width: 12),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        'TOTAL ABONOS',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              10,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color: isDarkMode
                                                                              ? Colors.grey[400]
                                                                              : Colors.grey[600],
                                                                          letterSpacing:
                                                                              0.5,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              4),
                                                                      Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Text(
                                                                            '\$${formatearNumero(totalAbonos)}',
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 16,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: isDarkMode ? Colors.blue[300] : Colors.blue[800],
                                                                            ),
                                                                          ),
                                                                          if (textoEstado !=
                                                                              null) // Muestra badge si hay texto
                                                                            Container(
                                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                                              decoration: BoxDecoration(
                                                                                color: isDarkMode ? Colors.blue[900] : Colors.blue[100],
                                                                                borderRadius: BorderRadius.circular(8),
                                                                                border: Border.all(
                                                                                  color: isDarkMode ? Colors.blue[700]! : Colors.blue[300]!,
                                                                                  width: 0.5,
                                                                                ),
                                                                              ),
                                                                              child: Text(
                                                                                textoEstado!, // Texto dinámico según estado
                                                                                style: TextStyle(
                                                                                  fontSize: 10,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: isDarkMode ? Colors.blue[300] : Colors.blue[800],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                        ],
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
                                                  );

                                                  return items;
                                                },
                                                constraints:
                                                    const BoxConstraints(
                                                  maxWidth: 500,
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      )
                                    : esPago1
                                        ? "-"
                                        : pago.tipoPago == 'Monto Parcial'
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 10),
                                                child: (editingState[index] ??
                                                        true) // Inicialmente será true
                                                    ? Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center, // <-- Añade esta línea

                                                        children: [
                                                          TextField(
                                                            controller:
                                                                controllers[
                                                                    index],
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: _puedeEditarPago(
                                                                      pago)
                                                                  ? isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black
                                                                  : isDarkMode
                                                                      ? Colors.grey[
                                                                          300]
                                                                      : Colors.grey[
                                                                          700],
                                                            ),
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            enabled:
                                                                _puedeEditarPago(
                                                                    pago), // Usamos la lógica de edición aquí

                                                            onChanged: (value) {
                                                              // Cancelar el Timer anterior si existe
                                                              if (_debounce
                                                                      ?.isActive ??
                                                                  false) {
                                                                _debounce
                                                                    ?.cancel();
                                                              }

                                                              // Crear un nuevo Timer para esperar a que el usuario termine de escribir
                                                              _debounce = Timer(
                                                                  const Duration(
                                                                      milliseconds:
                                                                          500),
                                                                  () {
                                                                setState(() {
                                                                  // Convertir el valor ingresado a double y asignar 0.0 si está vacío o es inválido
                                                                  double
                                                                      nuevoDeposito =
                                                                      value.isEmpty
                                                                          ? 0.0
                                                                          : double.tryParse(value) ??
                                                                              0.0;

                                                                  // Actualizar el depósito en el objeto `pago`
                                                                  pago.deposito =
                                                                      nuevoDeposito;

                                                                  // Actualizar la propiedad `sumaDepositoMoratorisos`
                                                                  pago.sumaDepositoMoratorisos =
                                                                      nuevoDeposito;

                                                                  // Calcular los saldos (a favor y en contra)
                                                                  if (nuevoDeposito >
                                                                      0) {
                                                                    // Si hay depósito, recalcular los abonos y los saldos
                                                                    double
                                                                        totalMoratorios =
                                                                        pago.moratorios?.moratorios ??
                                                                            0.0;
                                                                    double
                                                                        totalPagarConMoratorio =
                                                                        (pago.capitalMasInteres ??
                                                                                0.0) +
                                                                            totalMoratorios;

                                                                    // Asignar el depósito primero al monto total a pagar (capital + intereses)
                                                                    double
                                                                        depositoParaCapital =
                                                                        pago.capitalMasInteres ??
                                                                            0.0;
                                                                    double
                                                                        depositoParaMoratorio =
                                                                        totalMoratorios;

                                                                    // Si el depósito cubre más de lo que se debe por capital, el resto va al moratorio
                                                                    if (nuevoDeposito >
                                                                        depositoParaCapital) {
                                                                      depositoParaCapital =
                                                                          pago.capitalMasInteres ??
                                                                              0.0;
                                                                      double
                                                                          saldoRestante =
                                                                          nuevoDeposito -
                                                                              depositoParaCapital;
                                                                      depositoParaMoratorio = (saldoRestante >
                                                                              totalMoratorios)
                                                                          ? totalMoratorios
                                                                          : saldoRestante;
                                                                    }

                                                                    // Calcular saldo a favor (lo que sobra después de cubrir el total con moratorios)
                                                                    double
                                                                        saldoFavor =
                                                                        nuevoDeposito -
                                                                            totalPagarConMoratorio;
                                                                    if (saldoFavor <
                                                                        0)
                                                                      saldoFavor =
                                                                          0.0;

                                                                    // Asignar los valores calculados
                                                                    pago.deposito =
                                                                        nuevoDeposito;
                                                                    pago.saldoFavor =
                                                                        saldoFavor;
                                                                    pago.saldoEnContra =
                                                                        totalPagarConMoratorio -
                                                                            nuevoDeposito;

                                                                    // Debugging: Imprimir los resultados de los cálculos
                                                                    print(
                                                                        "Deposito actualizado: \$${pago.deposito}");
                                                                    print(
                                                                        "Monto total a pagar (con moratorio): \$${totalPagarConMoratorio}");
                                                                    print(
                                                                        "Saldo en Contra: \$${pago.saldoEnContra}");
                                                                    print(
                                                                        "Saldo a Favor: \$${pago.saldoFavor}");

                                                                    // Actualizar el Provider
                                                                    final pagosProvider = Provider.of<
                                                                            PagosProvider>(
                                                                        context,
                                                                        listen:
                                                                            false);

                                                                    // Buscar si ya existe un pago con la misma semana
                                                                    final index = pagosProvider
                                                                        .pagosSeleccionados
                                                                        .indexWhere((p) =>
                                                                            p.semana ==
                                                                            pago.semana);

                                                                    if (index !=
                                                                        -1) {
                                                                      // Actualizar el pago existente
                                                                      pagosProvider
                                                                              .pagosSeleccionados[index] =
                                                                          PagoSeleccionado(
                                                                        semana:
                                                                            pago.semana,
                                                                        tipoPago:
                                                                            pago.tipoPago,
                                                                        deposito:
                                                                            nuevoDeposito,
                                                                        saldoFavor:
                                                                            pago.saldoFavor,
                                                                        saldoEnContra:
                                                                            pago.saldoEnContra,
                                                                        idfechaspagos:
                                                                            pago.idfechaspagos,
                                                                        fechaPago: pago.fechaPagoCompleto.isNotEmpty
                                                                            ? pago.fechaPagoCompleto
                                                                            : pago.fechaPago, // <-- Cambio clave aquí
                                                                        capitalMasInteres:
                                                                            pago.capitalMasInteres,
                                                                        moratorio: pago
                                                                            .moratorios
                                                                            ?.moratorios,
                                                                      );
                                                                    } else {
                                                                      // Agregar un nuevo pago si no existe
                                                                      pagosProvider
                                                                          .agregarPago(
                                                                        PagoSeleccionado(
                                                                          semana:
                                                                              pago.semana,
                                                                          tipoPago:
                                                                              pago.tipoPago,
                                                                          deposito:
                                                                              nuevoDeposito,
                                                                          saldoFavor:
                                                                              pago.saldoFavor,
                                                                          saldoEnContra:
                                                                              pago.saldoEnContra,
                                                                          idfechaspagos:
                                                                              pago.idfechaspagos,
                                                                          fechaPago: pago.fechaPagoCompleto.isNotEmpty
                                                                              ? pago.fechaPagoCompleto
                                                                              : pago.fechaPago, // <-- Cambio clave aquí
                                                                          capitalMasInteres:
                                                                              pago.capitalMasInteres,
                                                                          moratorio: pago
                                                                              .moratorios
                                                                              ?.moratorios,
                                                                        ),
                                                                      );
                                                                    }
                                                                  } else {
                                                                    // Si el valor está vacío, establecer el saldo en contra a 0
                                                                    pago.saldoEnContra =
                                                                        0.0;
                                                                    pago.saldoFavor =
                                                                        0.0;
                                                                  }
                                                                });
                                                              });
                                                            },

                                                            decoration:
                                                                InputDecoration(
                                                              hintText:
                                                                  'Monto Parcial',
                                                              hintStyle:
                                                                  TextStyle(
                                                                fontSize: 12,
                                                                color: isDarkMode
                                                                    ? Colors.grey[
                                                                        300]
                                                                    : Colors.grey[
                                                                        700],
                                                              ),
                                                              prefixText:
                                                                  '\$', // Mostrar el símbolo "$" dentro del campo
                                                              prefixStyle:
                                                                  TextStyle(
                                                                fontSize: 14,
                                                                color: _puedeEditarPago(
                                                                        pago)
                                                                    ? isDarkMode
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .black
                                                                    : isDarkMode
                                                                        ? Colors.grey[
                                                                            300]
                                                                        : Colors
                                                                            .grey[700],
                                                              ),
                                                              enabledBorder:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            15.0),
                                                                borderSide: BorderSide(
                                                                    color: Colors
                                                                            .grey[
                                                                        400]!,
                                                                    width: 1.5),
                                                              ),
                                                              focusedBorder:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            15.0),
                                                                borderSide: BorderSide(
                                                                    color: Color(
                                                                        0xFF5162F6),
                                                                    width: 1.5),
                                                              ),
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      vertical:
                                                                          10,
                                                                      horizontal:
                                                                          10),
                                                            ),
                                                          ),

                                                          if (pago.abonos
                                                              .isNotEmpty)
                                                            ...pago.abonos
                                                                .map((abono) {
                                                              final esGarantia =
                                                                  (abono['garantia']
                                                                              as String)
                                                                          .toLowerCase() ==
                                                                      'si'; // Solo verifica el campo

                                                              return Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        top:
                                                                            4.0),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Text(
                                                                      'Pagado: ${formatearFecha(abono["fechaDeposito"])}',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: isDarkMode
                                                                            ? Colors.grey[300]
                                                                            : Colors.grey[600],
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                        height:
                                                                            6),
                                                                    if (esGarantia) // ← Condición simplificada
                                                                      Container(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                6,
                                                                            vertical:
                                                                                2),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color:
                                                                              Color(0xFFE53888).withOpacity(0.2),
                                                                          borderRadius:
                                                                              BorderRadius.circular(6),
                                                                        ),
                                                                        child:
                                                                            const Text(
                                                                          "Garantía",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                10,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color:
                                                                                Color(0xFFE53888),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              );
                                                            }).toList(),
                                                          // Mostrar mensaje del total pagado de Garantía
                                                          if (pago.abonos.any(
                                                              (abono) =>
                                                                  abono[
                                                                      'garantia'] ==
                                                                  'Si'))
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      top: 4.0),
                                                              child: Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .green
                                                                      .shade50,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  border: Border.all(
                                                                      color: Colors
                                                                          .green
                                                                          .shade100,
                                                                      width: 1),
                                                                ),
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    //Icon(Icons.verified_outlined, size: 14, color: Colors.green.shade800),
                                                                    SizedBox(
                                                                        width:
                                                                            4),
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          vertical:
                                                                              4),
                                                                      child:
                                                                          RichText(
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        text:
                                                                            TextSpan(
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                10,
                                                                            color:
                                                                                Colors.grey.shade800,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                          children: [
                                                                            TextSpan(text: 'Se pagó '),
                                                                            TextSpan(
                                                                              text: '\$${formatearNumero(pago.capitalMasInteres) ?? '0.00'}',
                                                                              style: TextStyle(
                                                                                fontSize: 10,
                                                                                color: Colors.green.shade800,
                                                                                fontWeight: FontWeight.bold,
                                                                              ),
                                                                            ),
                                                                            TextSpan(text: ' de '),
                                                                            TextSpan(
                                                                              text: '\$${formatearNumero(widget.montoGarantia)}',
                                                                              style: TextStyle(
                                                                                fontSize: 10,
                                                                                color: Colors.green.shade800,
                                                                                fontWeight: FontWeight.bold,
                                                                              ),
                                                                            ),
                                                                            TextSpan(text: ' de Garantía'),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      )
                                                    : Text(
                                                        "\$${pago.deposito ?? '0.00'}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black),
                                                      ),
                                              )
                                            : Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 10),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .center, // Alineación a la izquierda
                                                  children: [
                                                    // Mostrar el monto depositado
                                                    Text(
                                                      "\$${formatearNumero(pago.deposito ?? 0.00)}",
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDarkMode
                                                              ? Colors.white
                                                              : Colors.black),
                                                    ),
                                                    SizedBox(
                                                        height:
                                                            4), // Espacio entre el monto y la fecha

                                                    // Verificar si hay pagos y mostrar la fecha de depósito de cada uno
                                                    if (pago.abonos.isNotEmpty)
                                                      ...pago.abonos
                                                          .map((abono) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 4.0),
                                                          child: Text(
                                                            'Pagado: ${formatearFecha(abono["fechaDeposito"])}',
                                                            // Mostrar la fecha de depósito
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: isDarkMode
                                                                  ? Colors
                                                                      .grey[300]
                                                                  : Colors.grey[
                                                                      700],
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    if (pago.abonos.any(
                                                        (abono) =>
                                                            abono['garantia'] ==
                                                            'Si'))
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 12),
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .green.shade50,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .green
                                                                    .shade100),
                                                          ),
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          child: RichText(
                                                            textAlign: TextAlign
                                                                .center,
                                                            text: TextSpan(
                                                              style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade800,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500),
                                                              children: [
                                                                TextSpan(
                                                                    text:
                                                                        'Se pagó '),
                                                                TextSpan(
                                                                  text:
                                                                      '\$${formatearNumero(pago.capitalMasInteres)}',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .green
                                                                          .shade800,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold),
                                                                ),
                                                                TextSpan(
                                                                    text:
                                                                        ' de '),
                                                                TextSpan(
                                                                  text:
                                                                      '\$${formatearNumero(widget.montoGarantia)}',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .green
                                                                          .shade800,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold),
                                                                ),
                                                                TextSpan(
                                                                    text:
                                                                        ' de Garantía'),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                flex: 20,
                              ),

                              // Para "Saldo a Favor":
                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : (pago.abonos.isEmpty &&
                                            pago.deposito == 0.0)
                                        ? "-"
                                        : (pago.saldoFavor != null &&
                                                pago.saldoFavor! > 0.0)
                                            ? "\$${formatearNumero(pago.saldoFavor!)}"
                                            : "-",
                                flex: 18,
                              ),

                              // En la clase _PaginaControlState (dentro del método build):
// Código corregido (mostrar saldo aunque haya abonos/depósitos):
                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : (pago.saldoEnContra != null &&
                                            pago.saldoEnContra! >
                                                0.0) // ← Mostrar siempre si hay saldo
                                        ? "\$${formatearNumero(pago.saldoEnContra!)}"
                                        : "-",
                                flex: 18,
                              ),
                              // Mostrar los moratorios con la misma lógica, solo si existen
                              _buildTableCell(
                                esPago1
                                    ? "-"
                                    : (pago.moratorios == null)
                                        ? "-" // Mostrar "-" si los moratorios son nulos
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment
                                                .center, // Distribuir uniformemente
                                            children: [
                                              Text(
                                                pago.moratorios!.moratorios ==
                                                        0.0
                                                    ? "-" // Mostrar "-" si el monto de moratorios es 0.0
                                                    : "\$${formatearNumero(pago.moratorios!.moratorios)}",
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal),
                                              ),
                                              if (pago.moratorios!
                                                          .semanasDeRetraso >
                                                      0 ||
                                                  pago.moratorios!
                                                          .diferenciaEnDias >
                                                      0)
                                                PopupMenuButton<int>(
                                                  tooltip:
                                                      'Mostrar información',
                                                  color: Colors.white,
                                                  icon: Icon(Icons.info_outline,
                                                      size: 16,
                                                      color: Colors.grey),
                                                  offset: Offset(0,
                                                      40), // Ajusta la posición del menú
                                                  itemBuilder:
                                                      (BuildContext context) =>
                                                          [
                                                    PopupMenuItem(
                                                      enabled:
                                                          false, // Desactivado, solo para mostrar información
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          if (pago.moratorios!
                                                                  .semanasDeRetraso >
                                                              0)
                                                            Text(
                                                              "Semanas de Retraso: ${pago.moratorios!.semanasDeRetraso}",
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                          .grey[
                                                                      800]),
                                                            ),
                                                          if (pago.moratorios!
                                                                  .semanasDeRetraso >
                                                              0)
                                                            SizedBox(
                                                                height:
                                                                    8), // Espacio entre los elementos

                                                          if (pago.moratorios!
                                                                  .diferenciaEnDias >
                                                              0)
                                                            Text(
                                                              "Días de Retraso: ${pago.moratorios!.diferenciaEnDias}",
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                          .grey[
                                                                      800]),
                                                            ),
                                                          SizedBox(
                                                              height:
                                                                  8), // Espacio entre los elementos

                                                          if (pago.moratorios!
                                                                  .diferenciaEnDias >
                                                              0)
                                                            Text(
                                                              "Monto Total a Pagar: ${formatearNumero(pago.moratorios!.montoTotal)}",
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                          .grey[
                                                                      800]),
                                                            ),
                                                          if (pago.moratorios!
                                                                  .diferenciaEnDias >
                                                              0)
                                                            SizedBox(
                                                                height:
                                                                    8), // Espacio entre los elementos

                                                          if (pago
                                                              .moratorios!
                                                              .mensaje
                                                              .isNotEmpty)
                                                            Text(
                                                              "${pago.moratorios!.mensaje}",
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                          .grey[
                                                                      800]),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                flex: 18,
                              ),

                              // Nueva columna para los moratorios
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Después, pasas esos totales al _buildTableCell como lo haces normalmente
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF5162F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildTableCell("Totales",
                        isHeader: false, textColor: Colors.white, flex: 10),
                    _buildTableCell("", textColor: Colors.white, flex: 6),
                    _buildTableCell("\$${formatearNumero(totalMonto)}",
                        textColor: Colors.white, flex: 10),
                    _buildTableCell("", textColor: Colors.white, flex: 15),
                    _buildTableCell("\$${formatearNumero(totalPagoActual)}",
                        textColor: Colors.white, flex: 10),
                    _buildTableCell("\$${formatearNumero(totalSaldoFavor)}",
                        textColor: Colors.white, flex: 10),
                    _buildTableCell("\$${formatearNumero(totalSaldoContra)}",
                        textColor: Colors.white, flex: 10),
                    _buildTableCell("0.00", textColor: Colors.white, flex: 10),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  // 1. Este es el método para editar la fecha
  void _editarFechaPago(BuildContext context, Pago pago) async {
    DateTime initialDate = DateTime.now();
    DateTime lastDate = DateTime.now();

    // Priorizar fechaPagoCompleto si existe
    String? fechaAUsar = pago.fechaPagoCompleto.isNotEmpty
        ? pago.fechaPagoCompleto
        : pago.fechaPago;

    if (fechaAUsar.isNotEmpty) {
      try {
        final DateTime parsedDate = DateTime.parse(fechaAUsar);

        if (!parsedDate.isAfter(DateTime.now())) {
          initialDate = parsedDate;
        }
      } catch (e) {
        print("Fecha inválida: $fechaAUsar");
      }
    }

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
            child: child!,
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Color(0xFF5162F6),
              ),
            ));
      },
    );

    if (fechaSeleccionada != null) {
      setState(() {
        // Actualizar SOLO la fecha de pago completo
        // Actualizar SOLO la fecha de pago completo (solo fecha)
        pago.fechaPagoCompleto =
            fechaSeleccionada.toIso8601String().split('T')[0];

        // Mantener fechaPago original intacta
        if (pago.fechaPago.isEmpty) {
          pago.fechaPago = DateTime.now().toString();
        }

        Provider.of<PagosProvider>(context, listen: false)
            .actualizarPago(pago.semana, pago.toPagoSeleccionado());
      });
    }
  }

  Widget _buildTableCell(dynamic content,
      {bool isHeader = false, Color? textColor, int flex = 1}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Si no se proporciona un color de texto específico, usar el color basado en el tema
    final Color actualTextColor =
        textColor ?? (isDarkMode ? Colors.white : Colors.black);

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
                    color: actualTextColor,
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
  String fechaPagoCompleto = '';
  double capital;
  double interes;
  double capitalMasInteres;
  double? saldoFavor;
  double? saldoEnContra;
  double restanteTotal;
  String estado;
  double? deposito;
  String tipoPago;
  int? cantidadAbonos;
  double? montoPorCuota;
  List<Map<String, dynamic>> abonos;
  List<String?> fechasDepositos;
  String? idfechaspagos; // Campo idfechaspagos
  double? sumaDepositosFavor;
  double? sumaDepositoMoratorisos;
  Moratorios? moratorios; // Campo de moratorios
  // Nuevo: pagosMoratorios
  List<Map<String, dynamic>> pagosMoratorios;

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
    this.deposito,
    required this.tipoPago,
    this.cantidadAbonos,
    this.montoPorCuota,
    this.abonos = const [],
    this.fechasDepositos = const [],
    this.idfechaspagos, // Incluir en el constructor
    this.sumaDepositosFavor,
    this.sumaDepositoMoratorisos,
    this.moratorios, // Incluir en el constructor
    this.pagosMoratorios = const [], // Valor por defecto vacío
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    List<String?> fechasDepositos = [];
    var pagos = json['pagos'] as List?;
    if (pagos != null) {
      for (var pago in pagos) {
        fechasDepositos.add(pago['fechaDeposito']);
      }
    }

    // Parsear pagosMoratorios si existen, de lo contrario asigna una lista vacía
    List<Map<String, dynamic>> pagosMoratorios =
        (json['pagosMoratorios'] as List?)
                ?.map((moratorio) => Map<String, dynamic>.from(moratorio))
                .toList() ??
            [];

    return Pago(
      semana: json['semana'] ?? 0,
      fechaPago: json['fechaPago'] ?? '',
      capital: (json['capital'] is int)
          ? (json['capital'] as int).toDouble()
          : (json['capital'] as num?)?.toDouble() ?? 0.0,
      interes: (json['interes'] is int)
          ? (json['interes'] as int).toDouble()
          : (json['interes'] as num?)?.toDouble() ?? 0.0,
      capitalMasInteres: (json['capitalMasInteres'] is int)
          ? (json['capitalMasInteres'] as int).toDouble()
          : (json['capitalMasInteres'] as num?)?.toDouble() ?? 0.0,
      saldoFavor: json['saldoFavor'] != null
          ? double.tryParse(json['saldoFavor'].toString())
          : null,
      sumaDepositosFavor: json['sumaDepositosFavor'] != null
          ? double.tryParse(json['sumaDepositosFavor'].toString())
          : null,
      sumaDepositoMoratorisos: json['sumaDepositoMoratorisos'] != null
          ? double.tryParse(json['sumaDepositoMoratorisos'].toString())
          : null,
      saldoEnContra: json['saldoEnContra'] != null
          ? double.tryParse(json['saldoEnContra'].toString())
          : null,
      restanteTotal: (json['restanteTotal'] is int)
          ? (json['restanteTotal'] as int).toDouble()
          : (json['restanteTotal'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado'] ?? '',
      deposito: json['pagos'] != null && (json['pagos'] as List).isNotEmpty
          ? ((json['pagos'][0]['deposito'] as num?)?.toDouble() ?? 0.0)
          : null,
      tipoPago:
          json['tipoPagos'] == 'sin asignar' ? '' : json['tipoPagos'] ?? '',
      cantidadAbonos: (json['cantidadAbonos'] as num?)?.toInt(),
      montoPorCuota: (json['montoPorCuota'] is String)
          ? double.tryParse(json['montoPorCuota'])
          : (json['montoPorCuota'] as num?)?.toDouble(),
      abonos: (json['pagos'] as List<dynamic>? ?? [])
          .map((pago) => Map<String, dynamic>.from(pago))
          .toList(),
      fechasDepositos: fechasDepositos,
      idfechaspagos: json['idfechaspagos'], // Parsear el idfechaspagos
      moratorios: json['moratorios'] is Map<String, dynamic>
          ? Moratorios.fromJson(Map<String, dynamic>.from(json['moratorios']))
          : null,
      pagosMoratorios: pagosMoratorios, // Asigna los pagosMoratorios parseados
    );
  }

  PagoSeleccionado toPagoSeleccionado() {
    return PagoSeleccionado(
      semana: semana,
      tipoPago: tipoPago,
      deposito: deposito ?? 0.00,
      fechaPago: this.fechaPagoCompleto.isNotEmpty
          ? this.fechaPagoCompleto
          : this.fechaPago, // <-- Prioriza fechaPagoCompleto
      idfechaspagos: idfechaspagos ?? '',
      capitalMasInteres: capitalMasInteres,
      moratorio: moratorios?.moratorios,
      saldoFavor: saldoFavor,
      saldoEnContra: saldoEnContra,
      abonos: abonos,
    );
  }
}

class Moratorios {
  double montoTotal;
  double moratorios;
  int semanasDeRetraso;
  int diferenciaEnDias;
  String mensaje;

  Moratorios({
    required this.montoTotal,
    required this.moratorios,
    required this.semanasDeRetraso,
    required this.diferenciaEnDias,
    required this.mensaje,
  });

  factory Moratorios.fromJson(Map<String, dynamic> json) {
    return Moratorios(
      montoTotal: (json['montoTotal'] as num).toDouble(),
      moratorios: (json['moratorios'] as num).toDouble(),
      semanasDeRetraso: json['semanasDeRetraso'] ?? 0,
      diferenciaEnDias: json['diferenciaEnDias'] ?? 0,
      mensaje: json['mensaje'] ?? '',
    );
  }
}

// 2. Crear la función imprimirPagos
void imprimirPagos(List<Pago> pagos) {
  for (var pago in pagos) {
    print('Semana: ${pago.semana}');
    print('Fecha de Pago: ${pago.fechaPago}');
    print('Pagos:');
    for (var abono in pago.abonos) {
      print('  ID Pago: ${abono["idpagos"]}');
      print('  ID Detalle: ${abono["idpagosdetalles"]}');
      print('  Fecha de Depósito: ${abono["fechaDeposito"]}');
      print('  Monto Depositado: ${abono["deposito"]}');
    }
    print(''); // Línea en blanco para separar los pagos
  }
}

class AbonosDialog extends StatefulWidget {
  final double montoAPagar;
  final Function(List<Map<String, dynamic>>) onConfirm;

  AbonosDialog({
    required this.montoAPagar,
    required this.onConfirm,
  });

  @override
  _AbonosDialogState createState() => _AbonosDialogState();
}

class _AbonosDialogState extends State<AbonosDialog> {
  List<Map<String, dynamic>> abonos = [];
  double montoPorAbono = 0.0;
  DateTime fechaPago = DateTime.now();
  TextEditingController montoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final width = MediaQuery.of(context).size.width * 0.4;
    final height = MediaQuery.of(context).size.height * 0.52;

    // Colores adaptados según el modo
    final Color primaryColor = Color(0xFF5162F6);
    final Color backgroundColor = isDarkMode ? Color(0xFF121212) : Colors.white;
    final Color cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.grey[50]!;
    final Color textColor = isDarkMode ? Colors.white : Colors.grey[800]!;
    final Color labelColor = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;
    final Color inputBackground =
        isDarkMode ? Color(0xFF2C2C2C) : Colors.grey[100]!;
    final Color inputBorderColor =
        isDarkMode ? Colors.grey[600]! : Colors.grey[300]!;

    double totalAbonos =
        abonos.fold(0.0, (sum, abono) => sum + abono['deposito']);
    double montoFaltante = widget.montoAPagar - totalAbonos;

    return Dialog(
      backgroundColor: backgroundColor,
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
                    color: primaryColor),
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
                            color: labelColor,
                          ),
                        ),
                        TextField(
                          controller: montoController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelStyle: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            hintText: "Ingresa el monto",
                            hintStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[400]),
                            filled: true,
                            fillColor: inputBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: inputBorderColor, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: primaryColor, width: 2),
                            ),
                            prefixIcon:
                                Icon(Icons.attach_money, color: primaryColor),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 15, horizontal: 20),
                          ),
                          style: TextStyle(fontSize: 14, color: textColor),
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
                            color: labelColor,
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
                                    lastDate: DateTime.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: primaryColor,
                                            onPrimary: Colors.white,
                                            surface: isDarkMode
                                                ? Color(0xFF2C2C2C)
                                                : Colors.white,
                                            onSurface: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                          dialogBackgroundColor: isDarkMode
                                              ? Color(0xFF1E1E1E)
                                              : Colors.white,
                                        ),
                                        child: child!,
                                      );
                                    },
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
                                    color: inputBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      // Color del borde mejorado para modo claro
                                      color: isDarkMode
                                          ? inputBorderColor
                                          : Color(0xFFAAAAAA),
                                      // Ancho del borde mayor en modo claro
                                      width: isDarkMode ? 1.2 : 1.5,
                                    ),
                                    // Añadir sombra sutil en modo claro para mejor profundidad
                                    boxShadow: isDarkMode
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            )
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${fechaPago.toLocal()}".split(' ')[0],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: textColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Icon(Icons.calendar_today,
                                          color: primaryColor),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 30),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
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
                                      'deposito': montoPorAbono,
                                      'fechaDeposito': "${fechaPago.toLocal()}"
                                          .split(' ')[0],
                                    });
                                    montoPorAbono = 0.0;
                                    montoController.clear();
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
                    color: labelColor,
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
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            "Monto: \$${abonos[index]['deposito']} - Fecha: ${abonos[index]['fechaDeposito']}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textColor,
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
                      color: textColor,
                    ),
                  ),
                  SizedBox(width: 100),
                  /* Text(
                    "Monto a Pagar: \$${widget.montoAPagar.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    "Falta: \$${montoFaltante.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ), */
                ],
              ),
              SizedBox(height: 20),

              // Botón de Confirmar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDarkMode ? Color(0xFF444444) : Color(0xFF5162F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDarkMode ? Color(0xFF2E7D32) : Colors.green,
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
                      for (var abono in abonos) {
                        print(
                            'Monto: \$${abono['deposito']} - Fecha: ${abono['fechaDeposito']}');
                      }
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
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    // Variables para el estilo del texto
    const headerTextStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 13, // Tamaño de fuente del encabezado
    );

    final contentTextStyle = TextStyle(
      fontSize: 12, // Tamaño de fuente del contenido
      color: isDarkMode ? Colors.white : Colors.black87,
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

    const totalRowColor = Color(0xFF5162F6); // Rojo para la fila de totales

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
                      color: Color(0xFF5162F6), // Fondo del encabezado
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

// Clase PaginaIntegrantes: Widget que muestra la tabla
// Clase PaginaDescargables
class PaginaDescargables extends StatefulWidget {
  final String tipo;
  final String folio;
  final bool descargando; // Nuevo parámetro para controlar el estado

  const PaginaDescargables({
    Key? key,
    required this.tipo,
    required this.folio,
    this.descargando = false,
  }) : super(key: key);

  @override
  State<PaginaDescargables> createState() => _PaginaDescargablesState();
}

class _PaginaDescargablesState extends State<PaginaDescargables> {
  String? _documentoDescargando; // null, 'contrato' o 'pagare'
  bool dialogShown = false; // Controlar diálogos mostrados

  Future<void> _descargarDocumento(String documento) async {
    setState(() => _documentoDescargando = documento);

    bool dialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse(
          'http://$baseUrl/api/v1/formato/'
          '${documento.toLowerCase()}/'
          '${widget.tipo.toLowerCase()}/'
          '${widget.folio.toUpperCase()}',
        ),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final String? savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar documento',
          fileName: '${documento}_${widget.folio}.docx',
          allowedExtensions: ['docx'],
          type: FileType.custom,
        );

        if (!mounted) return;

        if (savePath != null) {
          final file = File(savePath);
          await file.writeAsBytes(response.bodyBytes);
          if (!mounted) return;
          await _abrirArchivoGuardado(savePath);
        }
      } else if (response.statusCode == 404) {
        final errorData = json.decode(response.body);
        if (errorData["Error"]["Message"] == "jwt expired") {
          await prefs.remove('tokenauth');

          if (!dialogShown) {
            dialogShown = true;
            _handleError(
              dialogShown,
              'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
              redirectToLogin: true,
            );
          }
        } else {
          _handleError(dialogShown, 'Error 404: Documento no encontrado.');
        }
      } else {
        _handleError(dialogShown, 'Error de servidor: ${response.statusCode}');
      }
    } catch (e) {
      _handleError(dialogShown, 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _documentoDescargando = null);
      }
    }
  }

  void _handleError(bool dialogShown, String message,
      {bool redirectToLogin = false}) {
    if (!dialogShown) {
      dialogShown = true;
      _mostrarDialogoError(
        message,
        onClose: redirectToLogin
            ? () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              }
            : null,
      );
    }
  }

  void _mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    if (!mounted || dialogShown) return; // Evitar múltiples diálogos

    dialogShown = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose?.call();
            },
            child: Text('Aceptar'),
          ),
        ],
      ),
    ).then((_) => dialogShown = false);
  }

  void _mostrarError(String mensaje) {
    if (!mounted || dialogShown) return; // Evitar múltiples diálogos

    dialogShown = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Aceptar'),
          ),
        ],
      ),
    ).then((_) => dialogShown = false);
  }

  Future<void> _abrirArchivoGuardado(String path) async {
    try {
      final openResult = await OpenFile.open(path); // Abre el archivo

      if (openResult.type == ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento abierto en:\n${path.split('/').last}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _mostrarError('No se pudo abrir el archivo: ${openResult.message}');
      }
    } catch (e) {
      _mostrarError(
          'Error al abrir el archivo: ${e.toString().split(':').first}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /*  _buildInfoRow('Tipo:', widget.tipo),
          const SizedBox(height: 4),
          _buildInfoRow('Folio:', widget.folio),
          const SizedBox(height: 20), */
          _buildBotonesDescarga(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String titulo, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$titulo ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            )),
        Expanded(
          child: Text(valor,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
        ),
      ],
    );
  }

  _buildBotonesDescarga() {
    return Column(
      children: [
        _buildBotonDescarga(
          titulo: 'Descargar Contrato',
          icono: Icons.description,
          color: Colors.blue[800]!,
          documento: 'contrato', // Nuevo parámetro
          onTap: () => _descargarDocumento('contrato'),
        ),
        const SizedBox(height: 15),
        _buildBotonDescarga(
          titulo: 'Descargar Pagaré',
          icono: Icons.monetization_on_rounded,
          color: Colors.green[700]!,
          documento: 'pagare', // Nuevo parámetro
          onTap: () => _descargarDocumento('pagare'),
        ),
      ],
    );
  }

  Widget _buildBotonDescarga({
    required String titulo,
    required IconData icono,
    required Color color,
    required String documento, // Nuevo parámetro
    required VoidCallback onTap,
  }) {
    final estaDescargando = _documentoDescargando == documento;

    return Material(
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        onTap: estaDescargando ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: estaDescargando
              ? _buildLoadingIndicator()
              : _buildButtonContent(titulo, icono),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildButtonContent(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, color: Colors.white, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
        ),
        const Icon(Icons.download_rounded, color: Colors.white, size: 24),
      ],
    );
  }
}
