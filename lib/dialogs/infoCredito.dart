import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:finora/helpers/pdf_exporter_controlpago.dart';
import 'package:finora/helpers/pdf_exporter_cuentaspago.dart';
import 'package:finora/helpers/pdf_resumen_credito.dart';
import 'package:finora/models/cliente_monto.dart';
import 'package:finora/models/credito.dart';
import 'package:finora/models/menu_pago.dart';
import 'package:finora/models/renovacion_pendiente.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/utils/rounding_utils.dart';
import 'package:finora/widgets/icono_con_indicador.dart';
import 'package:finora/widgets/menu_pago.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  final String tipoUsuario;

  InfoCredito({required this.folio, required this.tipoUsuario});

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
  late String tipoUsuario; // Declaración sin inicialización directa

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    tipoUsuario = widget.tipoUsuario; // Inicialización dentro de initState
    _fetchCreditoData();
  }

  // --- NUEVO ---
  // 1. Creamos una función específica para recargar toda la información del crédito.
  //    Esto nos da un nombre claro para la acción que queremos realizar.
  Future<void> _refrescarDatosCredito() async {
    // Al llamar a _fetchCreditoData, se volverá a pedir la información
    // del crédito al servidor y se reconstruirá el widget con los nuevos datos.
    if (mounted) {
      print("REFRESCANDO TODA LA INFORMACIÓN DEL CRÉDITO...");
      await _fetchCreditoData();
    }
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

      final url = '$baseUrl/api/v1/creditos/${widget.folio}';
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
      } else {
        try {
          final errorData = json.decode(response.body);

          // Verificar si es el mensaje específico de sesión cambiada
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');
            _timer?.cancel(); // Cancela el temporizador antes de navegar

            // Mostrar diálogo y redirigir al login
            mostrarDialogoCierreSesion(
                'La sesión ha cambiado. Cerrando sesión...', onClose: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false, // Elimina todas las rutas anteriores
              );
            });
            return;
          }
          // Manejar error JWT expirado
          else if (response.statusCode == 404 &&
              errorData["Error"] != null &&
              errorData["Error"]["Message"] == "jwt expired") {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('tokenauth');
            _timer?.cancel(); // Cancela el temporizador antes de navegar

            mostrarDialogoError(
                'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                onClose: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            });
            return;
          }
          // Otros errores
          else {
            print('Respuesta:${response.body}');
            //_handleError(dialogShown, 'Error: ${response.statusCode}');
            _handleError(dialogShown,
                'Ocurrió un error al obtener los datos. Intenta nuevamente más tarde.');
          }
        } catch (parseError) {
          // Si no podemos parsear la respuesta, delegamos al manejador de errores existente
          _handleError(
              dialogShown, 'Error al procesar la respuesta del servidor');
        }
      }
    } catch (e) {
      //_handleError(dialogShown, 'Error: $e');
      _handleError(dialogShown,
          'Ocurrió un error al obtener los datos. Intenta nuevamente más tarde.');
    }
  }

  void mostrarDialogoCierreSesion(String mensaje,
      {required Function() onClose}) {
    // Detectar si estamos en modo oscuro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          contentPadding: EdgeInsets.only(top: 25, bottom: 10),
          title: Column(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 60,
                color: Colors.red[700],
              ),
              SizedBox(height: 15),
              Text(
                'Sesión Finalizada',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          actionsPadding: EdgeInsets.only(bottom: 20, right: 25, left: 25),
          actions: [
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(double.infinity, 48), // Ancho completo
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onClose();
              },
              child: Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Función para mostrar el diálogo de error
  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    if (mounted) {
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
    print('=== INICIO generarPagoJson ===');
    print('Pagos seleccionados recibidos: ${pagosSeleccionados.length}');
    print('Pagos originales recibidos: ${pagosOriginales.length}');

    if (pagosSeleccionados.isEmpty) {
      print('Lista vacía, retornando []');
      return [];
    }

    List<Map<String, dynamic>> pagosJson = [];

    for (PagoSeleccionado pagoActual in pagosSeleccionados) {
      print('\n\n=== PROCESANDO PAGO ACTUAL ===');
      print(
          'ID: ${pagoActual.idfechaspagos} | Semana: ${pagoActual.semana} | Tipo: ${pagoActual.tipoPago}');
      print(
          'Depósito actual: ${pagoActual.deposito} | Capital+Interés: ${pagoActual.capitalMasInteres} | Moratorio: ${pagoActual.moratorio}');

      // Buscar pago original
      PagoSeleccionado pagoOriginal;
      try {
        pagoOriginal = pagosOriginales
            .firstWhere((p) => p.idfechaspagos == pagoActual.idfechaspagos);
        print('PAGO ORIGINAL ENCONTRADO');
        print(
            'Depósito original: ${pagoOriginal.deposito} | Capital+Interés: ${pagoOriginal.capitalMasInteres} | Moratorio: ${pagoOriginal.moratorio}');
      } catch (e) {
        print('NO SE ENCONTRÓ PAGO ORIGINAL, USANDO ACTUAL COMO ORIGINAL');
        pagoOriginal = pagoActual;
      }

      // Verificar cambios
      bool tieneCambios = _compararPagos(pagoActual, pagoOriginal) ||
          pagoActual.abonos
              .any((abono) => !abono.containsKey('idpagosdetalles'));

      print('¿Tiene cambios? $tieneCambios');
      if (!tieneCambios) {
        print('SIN CAMBIOS - OMITIENDO');
        continue;
      }

      // Calcular pagos previos
      double paidCapital = pagoOriginal.abonos
          .where((a) => a.containsKey('idpagosdetalles'))
          .fold(0.0, (sum, a) => sum + (a['deposito'] ?? 0.0));

      double paidMoratorio = pagoOriginal.abonos
          .where((a) => a.containsKey('idpagosdetalles'))
          .fold(0.0, (sum, a) => sum + (a['moratorio'] ?? 0.0));

      print('Capital ya pagado: $paidCapital');
      print('Moratorio ya pagado: $paidMoratorio');

      double totalDeuda =
          (pagoActual.capitalMasInteres ?? 0.0) + (pagoActual.moratorio ?? 0.0);
      print('Total deuda: $totalDeuda');

      // Lógica para cada tipo de pago
      String tipoLower = pagoActual.tipoPago?.toLowerCase() ?? '';
      print('Tipo de pago detectado: $tipoLower');

      if (tipoLower == 'garantia') {
        print('PROCESANDO COMO GARANTÍA');
        // ... [resto de la lógica de garantía con prints]
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
          "montoaPagar": (pagoActual.capitalMasInteres ?? 0.0),
          "deposito": (aplicadoCapital),
          "moratorio": (aplicadoMoratorio),
          "saldofavor": (saldofavor),
        });
        continue;
      } else if (tipoLower == 'completo') {
        print('PROCESANDO COMO COMPLETO');
        // ... [resto de la lógica de completo con prints]
        double saldoPendiente = totalDeuda - (paidCapital + paidMoratorio);
        double deposito = pagoActual.capitalMasInteres ?? 0.0;
        double saldofavor = (pagoActual.deposito ?? 0.0) - deposito;

        pagosJson.add({
          "idfechaspagos": pagoActual.idfechaspagos,
          "fechaPago": formatearFechaJSON(pagoActual.fechaPago),
          "tipoPago": "Completo",
          "montoaPagar": (pagoActual.capitalMasInteres ?? 0.0),
          "deposito": (deposito),
          "moratorio":
              (0.0), // En "Completo", el moratorio se incluye en el depósito total
          "saldofavor": (saldofavor),
        });
        continue; // Saltar al siguiente pago
      } else if (tipoLower == 'monto parcial') {
        print('PROCESANDO COMO MONTO PARCIAL');
        // ... [resto de la lógica de monto parcial con prints]
        double totalDepositado = pagoActual.deposito ?? 0.0;

        // Calcular moratorio permitido (0 si está deshabilitado)
        double moratorioPermitido = pagoActual.moratorioDesabilitado == "Si"
            ? 0.0
            : (pagoActual.moratorio ?? 0.0);

        double capitalPendiente = pagoActual.capitalMasInteres! - paidCapital;
        double moratorioPendiente =
            moratorioPermitido - paidMoratorio; // Usar moratorioPermitido

        // Aplicar a capital primero
        double aplicadoCapital = totalDepositado.clamp(0.0, capitalPendiente);
        double remanente = totalDepositado - aplicadoCapital;

        double aplicadoMoratorio = 0.0;

        // Solo aplicar moratorios si están habilitados
        if (pagoActual.moratorioDesabilitado != "Si") {
          double remanente = totalDepositado - aplicadoCapital;
          aplicadoMoratorio = remanente.clamp(0.0, moratorioPendiente);
        }

        double saldofavor =
            (totalDepositado - (aplicadoCapital + aplicadoMoratorio))
                .clamp(0.0, double.infinity);

        pagosJson.add({
          "idfechaspagos": pagoActual.idfechaspagos,
          "fechaPago": pagoActual.fechaPago,
          "tipoPago": "Monto Parcial",
          "montoaPagar": (pagoActual.capitalMasInteres ?? 0.0),
          "deposito": (aplicadoCapital),
          "moratorio": (aplicadoMoratorio),
          "saldofavor": (saldofavor),
        });
        continue;
      } else if (tipoLower == 'en abonos') {
        print('PROCESANDO COMO EN ABONOS');

        List<Map<String, dynamic>> nuevosAbonos = pagoActual.abonos
            .where((abono) => !abono.containsKey('idpagosdetalles'))
            .toList();

        print('Nuevos abonos a procesar: ${nuevosAbonos.length}');

        // 1. IMPRIMIR DATOS DE pagosMoratorios para verificar
        print('=== DATOS DE pagosMoratorios ===');
        print('pagoOriginal.pagosMoratorios: ${pagoOriginal.pagosMoratorios}');
        for (var moratorio in pagoOriginal.pagosMoratorios) {
          print(' - num: ${moratorio['num']}');
          print(' - idfechaspagos: ${moratorio['idfechaspagos']}');
          print(' - sumaMoratorios: ${moratorio['sumaMoratorios']}');
          print(' - moratorioAPagar: ${moratorio['moratorioAPagar']}');
          print(
              ' - moratorioDesabilitado: ${moratorio['moratorioDesabilitado']}');
          print(' - fCreacion: ${moratorio['fCreacion']}');
        }

        // 2. Usar sumaMoratorios del servidor como moratorio ya pagado
        double moratorioPagadoServidor = pagoOriginal.pagosMoratorios.fold(0.0,
            (sum, moratorio) => sum + (moratorio['sumaMoratorios'] ?? 0.0));

        print('=== CÁLCULO DE MORATORIO PAGADO ===');
        print(
            'Moratorio pagado según servidor (sumaMoratorios): $moratorioPagadoServidor');
        print(
            'Moratorio total a pagar según servidor: ${pagoOriginal.pagosMoratorios.isNotEmpty ? pagoOriginal.pagosMoratorios.first['moratorioAPagar'] : 'N/A'}');
        print('Moratorio actual del pago: ${pagoActual.moratorio}');

        // Variables acumuladoras - USANDO DATOS DEL SERVIDOR
        double capitalAcumulado = paidCapital;
        double moratorioAcumulado = paidMoratorio + moratorioPagadoServidor;

        print('=== ESTADO INICIAL BASADO EN SERVIDOR ===');
        print(' - Capital original pagado (paidCapital): $paidCapital');
        print(' - Capital acumulado total: $capitalAcumulado');
        print(' - Moratorio original pagado (paidMoratorio): $paidMoratorio');
        print(' - Moratorio pagado según servidor: $moratorioPagadoServidor');
        print(' - Moratorio acumulado total: $moratorioAcumulado');

        for (var abono in nuevosAbonos) {
          print('\n--- Procesando nuevo abono ---');
          print('Abono: $abono');

          double montoAbono = (abono['deposito'] as num).toDouble();
          String fechaPagoAbono = abono['fechaDeposito'];

          // Calcular pendientes BASÁNDOSE EN EL ACUMULADO ACTUAL
          double capitalPendiente =
              max(0, (pagoActual.capitalMasInteres! - capitalAcumulado));
          double moratorioPendiente =
              max(0, (pagoActual.moratorio! - moratorioAcumulado));

          print('Pendientes calculados:');
          print(
              ' - Capital pendiente: $capitalPendiente (${pagoActual.capitalMasInteres} - $capitalAcumulado)');
          print(
              ' - Moratorio pendiente: $moratorioPendiente (${pagoActual.moratorio} - $moratorioAcumulado)');

          // Inicializar aplicación
          double aplicadoCapital = 0.0;
          double aplicadoMoratorio = 0.0;
          double nuevoSaldoFavor = 0.0;

          // Lógica CORREGIDA: PRIORIZAR CAPITAL COMPLETO
          // 1. Aplicar todo el abono al capital mientras haya pendiente
          if (capitalPendiente > 0) {
            aplicadoCapital = min(capitalPendiente, montoAbono);
            montoAbono -= aplicadoCapital;
            capitalAcumulado += aplicadoCapital; // ACTUALIZAR ACUMULADO
          }

          // 2. Solo si sobra dinero y hay moratorio pendiente
          if (montoAbono > 0 && moratorioPendiente > 0) {
            aplicadoMoratorio = min(moratorioPendiente, montoAbono);
            montoAbono -= aplicadoMoratorio;
            moratorioAcumulado += aplicadoMoratorio; // ACTUALIZAR ACUMULADO
          }

          // 3. El remanente es saldo a favor
          nuevoSaldoFavor = montoAbono;

          print('RESULTADO ABONO (CAPITAL PRIMERO):');
          print(' - Aplicado a capital: $aplicadoCapital');
          print(' - Aplicado a moratorio: $aplicadoMoratorio');
          print(' - Saldo a favor: $nuevoSaldoFavor');
          print(' - Nuevo capital acumulado: $capitalAcumulado');
          print(' - Nuevo moratorio acumulado: $moratorioAcumulado');

          // Agregar a pagosJson
          pagosJson.add({
            "idfechaspagos": pagoActual.idfechaspagos,
            "fechaPago": fechaPagoAbono,
            "tipoPago": "En Abonos",
            "montoaPagar": pagoActual.capitalMasInteres ?? 0.0,
            "deposito": aplicadoCapital, // Solo capital
            "moratorio": aplicadoMoratorio,
            "saldofavor": nuevoSaldoFavor,
          });
        }
      }
    }

    print('\n=== FIN generarPagoJson ===');
    print('Total de pagos generados: ${pagosJson.length}');
    return pagosJson;
  }

  /// Función de comparación con prints
  bool _compararPagos(PagoSeleccionado actual, PagoSeleccionado original) {
    print('COMPARANDO PAGOS:');

    bool depositoDiferente = actual.deposito != original.deposito;
    bool capitalDiferente =
        actual.capitalMasInteres != original.capitalMasInteres;
    bool moratorioDiferente = actual.moratorio != original.moratorio;
    bool moratorioDesabilitadoDiferente =
        actual.moratorioDesabilitado != original.moratorioDesabilitado;

    print(
        ' - Depósito diferente: $depositoDiferente (${actual.deposito} vs ${original.deposito})');
    print(
        ' - Capital diferente: $capitalDiferente (${actual.capitalMasInteres} vs ${original.capitalMasInteres})');
    print(
        ' - Moratorio diferente: $moratorioDiferente (${actual.moratorio} vs ${original.moratorio})');
    print(
        ' - MoratorioDesabilitado diferente: $moratorioDesabilitadoDiferente (${actual.moratorioDesabilitado} vs ${original.moratorioDesabilitado})');

    return depositoDiferente ||
        capitalDiferente ||
        moratorioDiferente ||
        moratorioDesabilitadoDiferente;
  }

  double _redondear(double valor, [int decimales = 2]) {
    return double.parse(valor.toStringAsFixed(decimales));
  }

  // ESTA ES LA NUEVA FUNCIÓN MAESTRA. REEMPLAZA LA ANTERIOR COMPLETAMENTE.
  Future<void> enviarDatosAlServidor(
    BuildContext context,
    // Esta lista contiene el ESTADO ACTUAL de TODOS los pagos.
    List<PagoSeleccionado> estadoActualDePagos,
  ) async {
    // Verificamos que el widget siga montado para evitar errores.
    if (!mounted) return;

    // Activamos el indicador de carga.
    setState(() => isSending = true);

    try {
      // Obtenemos el token y los datos originales para comparar.
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final pagosProvider = Provider.of<PagosProvider>(context, listen: false);
      final pagosOriginales = pagosProvider.pagosOriginales;

      // ================== INICIO DE LA LÓGICA CLAVE ==================

      // 1. FILTRAMOS PARA OBTENER SÓLO LOS PAGOS REALMENTE MODIFICADOS
      // Comparamos el estado actual de cada pago con su estado original.
      final List<PagoSeleccionado> pagosRealmenteModificados = [];
      final List<Map<String, dynamic>> cambiosMoratorio = [];

      for (final pagoActual in estadoActualDePagos) {
        // Buscamos el pago original por su ID único.
        final pagoOriginal = pagosOriginales.firstWhere(
          (p) => p.idfechaspagos == pagoActual.idfechaspagos,
          orElse: () => pagoActual, // Fallback si no lo encuentra.
        );

        // Comparamos si el objeto ha cambiado. ¡Es crucial que tu clase PagoSeleccionado use Equatable o tengas un método de comparación!
        // Si no usas Equatable, la comparación sería manual:
        // === CÓDIGO CORREGIDO Y MEJORADO ===

// Comparamos los cambios básicos primero.
        bool haCambiado = (pagoActual.deposito != pagoOriginal.deposito ||
            pagoActual.tipoPago != pagoOriginal.tipoPago ||
            pagoActual.moratorioDesabilitado !=
                pagoOriginal.moratorioDesabilitado);

// Si no hay cambios básicos, revisamos específicamente la lógica de abonos.
// Esta es la parte clave para tu problema.
        if (!haCambiado && pagoActual.tipoPago?.toLowerCase() == 'en abonos') {
          // Un cambio en "Abonos" significa que hay al menos un abono en la lista `pagoActual`
          // que todavía no tiene un `idpagosdetalles`. Esto indica que es nuevo y no ha sido guardado.
          final hayNuevosAbonos = pagoActual.abonos
              .any((abono) => !abono.containsKey('idpagosdetalles'));

          if (hayNuevosAbonos) {
            haCambiado = true;
          }
        }
// Si después de la lógica de abonos, sigue sin haber cambios, pero las longitudes son diferentes
// (caso para otros tipos de pago que usan la lista de abonos, como Garantía), también lo contamos como cambio.
        else if (!haCambiado &&
            (pagoActual.abonos.length != pagoOriginal.abonos.length)) {
          haCambiado = true;
        }

        if (haCambiado) {
          pagosRealmenteModificados.add(pagoActual);

          // Si específicamente el moratorio cambió, lo añadimos a su lista.
          if (pagoActual.moratorioDesabilitado !=
              pagoOriginal.moratorioDesabilitado) {
            cambiosMoratorio.add({
              "idfechaspagos": pagoActual.idfechaspagos,
              "moratorioDesabilitado": pagoActual.moratorioDesabilitado,
            });
          }
        }
      }

      // Si no hay ninguna modificación en absoluto, informamos al usuario y salimos.
      if (pagosRealmenteModificados.isEmpty) {
        print('✅ No hay cambios para guardar');
        if (mounted) {
          mostrarDialogo(
              context, 'Aviso', 'No se ha realizado ninguna modificación.');
        }
        return; // Salimos de la función aquí.
      }

      // =================== FIN DE LA LÓGICA DE FILTRADO ====================

      // 2. GENERAR Y ENVIAR DATOS PRINCIPALES DE PAGOS (si hay cambios de pago)
      // Usamos la lista filtrada `pagosRealmenteModificados`.
      List<Map<String, dynamic>> pagosJson =
          generarPagoJson(pagosRealmenteModificados, pagosOriginales);

      // Solo enviamos si `pagosJson` no está vacío.
      if (pagosJson.isNotEmpty) {
        print('Enviando datos de pagos...');
        final response = await http.post(
          Uri.parse('$baseUrl/api/v1/pagos'),
          headers: {'Content-Type': 'application/json', 'tokenauth': token},
          body: json.encode(pagosJson),
        );

        if (response.statusCode != 201) {
          final errorData = json.decode(response.body);
          final mensajeError =
              errorData['Error']['Message'] ?? 'Error al guardar pagos';
          throw HttpException(mensajeError);
        }
      }

      // 3. ACTUALIZAR PERMISOS DE MORATORIOS (si hay cambios de moratorio)
      // Ya no usamos `enviarCambiosMoratorio`. La lógica está aquí.
      if (cambiosMoratorio.isNotEmpty) {
        print('Enviando cambios de moratorios...');
        // Usamos Future.wait para enviar todas las actualizaciones en paralelo, es más eficiente.
        await Future.wait(cambiosMoratorio.map((cambio) {
          return _actualizarMoratorioServidor(
            cambio['idfechaspagos'],
            cambio['moratorioDesabilitado'],
            token,
          );
        }));
      }

      // 4. --- LÓGICA CLAVE PARA DECIDIR LA ACCIÓN DE REFRESCO ---
      // Esta lógica ahora se ejecuta SIEMPRE que haya habido CUALQUIER cambio.
      print('✅ Proceso de envío completado exitosamente.');

      // Decidimos si recargar toda la página o solo la tabla.
      final int totalPlazos = creditoData?.plazo ?? 0;
      final bool seModificoPagoFinal = pagosRealmenteModificados.any((pago) {
        return pago.semana >= totalPlazos - 1;
      });

      VoidCallback accionAlPresionarOk;

      if (seModificoPagoFinal) {
        print(
            "Se detectó un cambio relevante. La acción será recargar toda la información del crédito.");
        accionAlPresionarOk = () {
          if (!mounted) return;
          pagosProvider.limpiarPagos();
          // Esta es la función que creaste para recargar todo. ¡Perfecto!
          _refrescarDatosCredito();
        };
      } else {
        print(
            "Cambio intermedio detectado. La acción será recargar solo la tabla de pagos.");
        accionAlPresionarOk = () {
          if (!mounted) return;
          pagosProvider.limpiarPagos();
          paginaControlKey.currentState?.recargarPagos();
        };
      }

      // 5. MOSTRAMOS EL ÚNICO DIÁLOGO DE ÉXITO.
      // Le pasamos la acción de refresco que acabamos de determinar.
      if (mounted) {
        mostrarDialogo(
          context,
          'Éxito',
          'Datos guardados correctamente',
          onOkPressed: accionAlPresionarOk, // ¡Aquí está la magia!
        );
      }
    } on HttpException catch (e) {
      if (mounted) _handleHttpError(context, e);
    } on SocketException {
      if (mounted) _handleNetworkError(context);
    } on Exception catch (e) {
      if (mounted) _handleGenericError(context, e);
    } finally {
      // Pase lo que pase, desactivamos el indicador de carga.
      if (mounted) setState(() => isSending = false);
      print('🏁 Finalizando enviarDatosAlServidor - isSending: false');
    }
  }

  void _handleHttpError(BuildContext context, HttpException e) {
    final mensaje = _traducirMensajeError(e.message);
    mostrarDialogo(context, 'Error HTTP ${e.uri}', mensaje, esError: true);
  }

  void _handleNetworkError(BuildContext context) {
    mostrarDialogo(context, 'Error de Red',
        'No se pudo conectar al servidor. Verifica tu conexión a internet.',
        esError: true);
  }

  void _handleGenericError(BuildContext context, Exception e) {
    mostrarDialogo(context, 'Error Inesperado',
        'Ocurrió un error no esperado: ${e.toString()}',
        esError: true);
  }

  String _traducirMensajeError(String mensajeOriginal) {
    const traducciones = {
      'jwt expired': 'Sesión expirada. Vuelve a iniciar sesión.',
      'invalid token': 'Token inválido. Vuelve a iniciar sesión.',
      'session changed': 'Sesión modificada. Vuelve a iniciar sesión.',
    };

    return traducciones[mensajeOriginal] ?? mensajeOriginal;
  }

  // Método helper para actualizar moratorios
  Future<bool> _actualizarMoratorioServidor(
      String idfechaspagos, String estado, String token) async {
    try {
      final url = '$baseUrl/api/v1/pagos/permiso/moratorio/$idfechaspagos';
      final body = json.encode({'moratorioDesabilitado': estado});

      // Debug: Imprimir datos a enviar
      print('╔═══════════════════════════════════════════════════');
      print('╟[MORATORIO] URL: $url');
      print('╟[MORATORIO] Body: $body');
      print('╚═══════════════════════════════════════════════════');

      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'tokenauth': token},
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error actualizando moratorio $idfechaspagos: $e');
      return false;
    }
  }

  Future<void> enviarCambiosMoratorio(
    BuildContext context,
    List<Map<String, dynamic>> cambiosMoratorio,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      // Iterar cada cambio de moratorio y enviarlos individualmente
      for (final cambio in cambiosMoratorio) {
        final idfechaspagos = cambio["idfechaspagos"];
        final moratorioDesabilitado = cambio["moratorioDesabilitado"];
        // Enviar a endpoint específico con ID en la URL
        final response = await http.put(
          Uri.parse('$baseUrl/api/v1/pagos/permiso/moratorio/$idfechaspagos'),
          headers: {'Content-Type': 'application/json', 'tokenauth': token},
          body: json.encode({"moratorioDesabilitado": moratorioDesabilitado}),
        );

        // Imprimir la respuesta literal del servidor
        print(
            'Respuesta del servidor para ID $idfechaspagos: ${response.body}');

        // Manejar respuesta del servidor
        if (response.statusCode != 200 && response.statusCode != 201) {
          final errorData = json.decode(response.body);
          final mensajeError =
              errorData['Error']?['Message'] ?? 'Error desconocido';
          throw HttpException(mensajeError, uri: response.request?.url);
        }
      }

      // Mostrar mensaje de éxito después de que todos los cambios se envíen correctamente
      mostrarDialogo(context, 'Éxito', 'Datos guardados correctamente');
    } on HttpException catch (e) {
      print('Error HTTP: $e');
      mostrarDialogo(context, 'Error',
          'No se pudieron actualizar los permisos de moratorio: ${e.message}',
          esError: true);
    } on SocketException {
      print('Error de conexión');
      mostrarDialogo(
          context, 'Error de conexión', 'Verifique su conexión a internet',
          esError: true);
    } catch (e) {
      print('Error general: $e');
      mostrarDialogo(context, 'Error', 'Ocurrió un error inesperado: $e',
          esError: true);
    }
  }

// Función para mostrar un diálogo genérico o de error con diseño
  // --- MÉTODO COMPLETO Y MODIFICADO ---
  void mostrarDialogo(BuildContext context, String titulo, String mensaje,
      {bool esError = false, VoidCallback? onOkPressed}) {
    // El parámetro `onOkPressed` es opcional.
    // Es la función que se ejecutará cuando el usuario presione el botón 'OK'.

    mensaje = mensaje.replaceAll(
        RegExp(r'\d+\.\d+\.\d+\.\d+:\d+/\S*'), '[URL Oculta]');

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
                esError ? "Error" : titulo,
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
                // 1. Siempre cerramos el diálogo primero.
                Navigator.of(context).pop();

                // 2. --- LÓGICA CLAVE ---
                //    Si se nos proporcionó una función `onOkPressed`, la ejecutamos.
                if (onOkPressed != null) {
                  onOkPressed();
                }
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

    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;

    String formatearRangoFechasDdMmYyyy(String rango) {
      try {
        final partes = rango.split(' - ');
        if (partes.length != 2) return rango;

        final inicio = DateTime.parse(partes[0].replaceAll('/', '-'));
        final fin = DateTime.parse(partes[1].replaceAll('/', '-'));

        String formato(DateTime fecha) =>
            '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

        return '${formato(inicio)} - ${formato(fin)}';
      } catch (e) {
        return rango; // Devuelve el string original si hay error
      }
    }

    return Dialog(
        backgroundColor:
            isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA), // Fondo dinámico
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.all(8),
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
                        ? Center(
                            child: CircularProgressIndicator(
                            color: Colors.transparent,
                          ))
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
                                      child: LayoutBuilder(
                                          builder: (context, constraints) {
                                        return SingleChildScrollView(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                                minHeight:
                                                    constraints.maxHeight),
                                            child: IntrinsicHeight(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 35,
                                                    backgroundColor:
                                                        Colors.white,
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
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Divider(
                                                      color: Colors.white
                                                          .withOpacity(0.5),
                                                      thickness: 1),
                                                  _buildDetailRow(
                                                      'Folio',
                                                      creditoData!.folio
                                                          .toString()),
                                                  _buildDetailRow(
                                                      'Grupo',
                                                      creditoData!
                                                              .nombreGrupo ??
                                                          'No disponible'),
                                                  _buildDetailRow(
                                                      'Detalles:',
                                                      creditoData!.detalles ??
                                                          'No disponible'),
                                                  _buildDetailRow(
                                                      'Tipo',
                                                      creditoData!.tipoPlazo ??
                                                          'No disponible'),
                                                  _buildDetailRow(
                                                      'Monto Autorizado',
                                                      "\$${formatearNumero(creditoData!.montoTotal ?? 0.0)}"),
                                                  _buildDetailRow(
                                                      'Interés Mensual',
                                                      "${creditoData!.ti_mensual ?? 0.0}%"),
                                                  _buildDetailRow(
                                                      'Interés M. Monto',
                                                      "\$${formatearNumero((creditoData!.montoTotal ?? 0.0) * (creditoData!.ti_mensual ?? 0.0) / 100)}"),
                                                  _buildDetailRow(
                                                      'Garantía',
                                                      (creditoData!.garantia ==
                                                                  0 ||
                                                              creditoData!
                                                                      .garantia ==
                                                                  "0%" ||
                                                              creditoData!
                                                                      .garantia ==
                                                                  "0.0")
                                                          ? "Sin garantía"
                                                          : "${creditoData!.garantia}"),
                                                  _buildDetailRow(
                                                      'Garantía Monto',
                                                      "\$${creditoData!.montoGarantia ?? 0.0}"),
                                                  _buildDetailRow(
                                                    'Monto Desembolsado',
                                                    "\$${formatearNumero(creditoData!.montoDesembolsado ?? 0.0)}",
                                                  ),
                                                  _buildDetailRow(
                                                      'Interés Global',
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
                                                  _buildDetailRow(
                                                      'Capital Total',
                                                      "\$${formatearNumero((creditoData!.semanalCapital * creditoData!.plazo) ?? 0.0)}"),
                                                  _buildDetailRow(
                                                      creditoData!.tipoPlazo ==
                                                              'Semanal'
                                                          ? 'Interés Semanal'
                                                          : 'Interés Quincenal',
                                                      "\$${formatearNumero(creditoData!.semanalInteres ?? 0.0)}"),
                                                  _buildDetailRow(
                                                      creditoData!.tipoPlazo ==
                                                              'Semanal'
                                                          ? 'Interés Semanal %'
                                                          : 'Interés Quincenal %',
                                                      "\$${creditoData!.ti_semanal ?? ''}"),
                                                  _buildDetailRow(
                                                      'Interés Total',
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
                                                    creditoData!.fCreacion
                                                            .split(' ')[
                                                        0], // Solo la fecha
                                                    tooltip: creditoData!
                                                        .fCreacion, // Fecha completa en tooltip
                                                  ),
                                                  _buildDetailRow(
                                                    'Duración',
                                                    formatearRangoFechasDdMmYyyy(
                                                        creditoData!
                                                            .fechasIniciofin),
                                                  ),
                                                  SizedBox(height: 30),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
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
                                                      /*   _buildSectionTitle(
                                                          'Control de Pagos'), */
                                                      PaginaControl(
                                                        key: paginaControlKey,
                                                        idCredito: idCredito,
                                                        montoGarantia: creditoData!
                                                                .montoGarantia ??
                                                            0.0,
                                                        tipoUsuario:
                                                            tipoUsuario,
                                                        clientesParaRenovar:
                                                            creditoData!
                                                                .clientesMontosInd,
                                                        // ▼▼▼ AÑADE ESTA LÍNEA ▼▼▼
                                                        pagoCuotaTotal:
                                                            creditoData!
                                                                    .pagoCuota ??
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
                                                      /*  _buildSectionTitle(
                                                          'Integrantes'), */
                                                      SizedBox(height: 0),
                                                      PaginaIntegrantes(
                                                        clientesMontosInd:
                                                            creditoData!
                                                                .clientesMontosInd,
                                                        tipoPlazo: creditoData!
                                                            .tipoPlazo,
                                                        pagoCuota: creditoData!
                                                            .pagoCuota,
                                                        plazo:
                                                            creditoData!.plazo,
                                                        garantia: creditoData!
                                                            .garantia,
                                                        idgrupo: creditoData!
                                                            .idgrupos,
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
                                                      /* _buildSectionTitle(
                                                          'Descargables'), */
                                                      PaginaDescargables(
                                                        tipo: creditoData!.tipo,
                                                        folio:
                                                            creditoData!.folio,
                                                        credito: creditoData!,
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
                        // UBICACIÓN: Dentro del widget _InfoCreditoState, en el ElevatedButton 'Guardar'

                        ElevatedButton(
                          onPressed: isSending
                              ? null
                              : () async {
                                  // Ya no hay lógica compleja aquí.
                                  // Simplemente llamamos a nuestra nueva función maestra.
                                  await enviarDatosAlServidor(
                                    context,
                                    // Le pasamos el estado actual de TODOS los pagos desde el provider.
                                    Provider.of<PagosProvider>(context,
                                            listen: false)
                                        .pagosSeleccionados,
                                  );
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
  Widget _buildDetailRow(String title, String value, {String? tooltip}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          tooltip != null
              ? Tooltip(
                  message: tooltip,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              : SelectableRegion(
                  focusNode: FocusNode(),
                  selectionControls: materialTextSelectionControls,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        selectionColor: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    child: SelectableText(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
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

class PaginaControl extends StatefulWidget {
  final String idCredito;
  final double montoGarantia;
  final String tipoUsuario;
  // Aceptamos la lista de clientes aquí. Asegúrate de que el tipo sea el correcto.
  final List<ClienteMonto> clientesParaRenovar;
  final double pagoCuotaTotal; // <-- AÑADE ESTA LÍNEA

  PaginaControl({
    Key? key,
    required this.idCredito,
    required this.montoGarantia,
    required this.tipoUsuario,
    required this.clientesParaRenovar, // --- CAMBIADO ---
    required this.pagoCuotaTotal, // <-- AÑADE ESTA LÍNEA
  }) : super(key: key);

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
  late String tipoUsuario; // Declaración sin inicialización directa
  final ValueNotifier<Map<String, bool>> _clientesSeleccionadosNotifier =
      ValueNotifier<Map<String, bool>>({});

  // =========================================================================
  // <<< NUEVA VARIABLE DE ESTADO PARA CÁLCULOS EN TIEMPO REAL >>>
  // =========================================================================
  final Map<String, double> _saldosFavorEnTiempoReal = {};
  // =========================================================================

  final Set<String> _pagosConInteraccionRealTime = {};

  // --- MODIFICADO ---
  // Ahora usaremos esta variable para el estado de carga del botón de guardar del submenú.
  bool _isSaving = false;
  bool _isDeleting = false; // <-- NUEVA VARIABLE DE ESTADO

  // --- Referencia a la función de refresco del widget padre ---
  // La obtenemos a través del GlobalKey que ya tenías.
  late final _InfoCreditoState? _infoCreditoState;

  @override
  void initState() {
    super.initState();
    // Obtenemos la referencia al estado del widget padre.
    _infoCreditoState = (context.findAncestorStateOfType<_InfoCreditoState>());
    _pagosFuture = _fetchPagos();
    tipoUsuario = widget.tipoUsuario; // Inicialización dentro de initState
    // --- CAMBIADO ---
    final initialSelection = {
      for (var cliente in widget.clientesParaRenovar)
        cliente.idamortizacion:
            false, // O true si quieres que empiecen seleccionados
    };
    // Asigna este mapa como el valor inicial del notificador.
    _clientesSeleccionadosNotifier.value = initialSelection;
  }

  // EN LA CLASE: _PaginaControlState

Future<void> recargarPagos() async {
  // Aseguramos que el widget todavía esté en el árbol.
  if (mounted) {
    setState(() {
      isLoading = true;
      
      // <<< LA SOLUCIÓN DEFINITIVA >>>
      // Limpiamos los mapas de estado en tiempo real ANTES de recargar.
      // Esto elimina cualquier valor "fantasma" de interacciones previas.
      _saldosFavorEnTiempoReal.clear();
      _pagosConInteraccionRealTime.clear();
      print("Mapas de estado en tiempo real reseteados.");
    });
  }

  // Pequeña demora para que el indicador de carga sea visible.
  await Future.delayed(Duration(milliseconds: 100));

  try {
    // Obtenemos los pagos frescos, que se calcularán correctamente.
    List<Pago> pagos = await _fetchPagos();
    
    if (mounted) {
      // Actualizamos el Future para que el FutureBuilder se reconstruya.
      _pagosFuture = Future.value(pagos); 
      // Desactivamos el indicador de carga.
      setState(() => isLoading = false);
    }
  } catch (e) {
    if (mounted) {
      setState(() => isLoading = false);
    }
    _mostrarDialogoError('Error al recargar los pagos: $e');
  }
}

 // =========================================================================
// <<< FUNCIÓN _fetchPagos COMPLETA Y CORREGIDA >>>
// Esta versión calcula correctamente el total pagado incluyendo las renovaciones.
// =========================================================================

// =========================================================================
// <<< FUNCIÓN _fetchPagos VERSIÓN FINAL Y DEFINITIVA >>>
// Esta versión considera Abonos, Renovaciones y Saldo a Favor Utilizado.
// =========================================================================
Future<List<Pago>> _fetchPagos() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';
    if (token.isEmpty) {
      if (!mounted) return [];
      _mostrarDialogoError('Tu sesión ha expirado. Por favor, inicia sesión de nuevo.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
      return [];
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/creditos/calendario/${widget.idCredito}'),
      headers: {'tokenauth': token, 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      List<Pago> pagos = data.map((pagoJson) => Pago.fromJson(pagoJson)).toList();
      pagos.sort((a, b) => a.semana.compareTo(b.semana));

      for (var pago in pagos) {
        // Sumar los abonos en efectivo.
        double montoPagadoEnAbonos = pago.abonos.fold(0.0, (sum, abono) {
          final deposito = abono['deposito'];
          return sum + (deposito is num ? deposito.toDouble() : 0.0);
        });

        // Sumar el monto cubierto por las renovaciones pendientes.
        double montoCubiertoPorRenovacion = pago.renovacionesPendientes.fold(
          0.0,
          (sum, renovacion) => sum + (renovacion.descuento ?? 0.0),
        );
        
        // <<< CORRECCIÓN FINAL >>>
        // Incluimos el saldo a favor que el servidor indica que ya fue utilizado.
        double favorYaUtilizado = pago.favorUtilizado;
        
        // ¡Este es el total pagado REALMENTE COMPLETO!
        double montoTotalPagado = montoPagadoEnAbonos + montoCubiertoPorRenovacion + favorYaUtilizado;

        // Asignamos el monto en efectivo a las propiedades que usa la UI para mostrar los abonos.
        pago.sumaDepositoMoratorisos = montoPagadoEnAbonos;
        pago.deposito = montoPagadoEnAbonos; 

        // El resto del cálculo ahora usará el 'montoTotalPagado' completo y correcto.
        double totalDeudaSemana = (pago.capitalMasInteres ?? 0.0) +
            (pago.moratorioDesabilitado == "Si"
                ? 0.0
                : (pago.moratorios?.moratorios ?? 0.0));
        
        double diferencia = montoTotalPagado - totalDeudaSemana;

        if (diferencia >= -0.01) { // Usamos umbral para errores de punto flotante
          pago.saldoFavor = diferencia > 0 ? diferencia : 0.0;
          pago.saldoEnContra = 0.0;
        } else {
          pago.saldoFavor = 0.0;
          pago.saldoEnContra = -diferencia;
        }
        
        // El estado finalizado ahora será 100% consistente con todos los tipos de pago.
        pago.estaFinalizado = (pago.saldoEnContra ?? 0.0) <= 0.01;
      }
      
      _actualizarProviderConPagos(pagos);

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return pagos;
    } else {
      // Tu manejo de errores (sin cambios)
      final errorData = json.decode(response.body);
      // ...
      throw Exception('Error: ${response.statusCode}');
    }
  } catch (e) {
    if (mounted) {
      setState(() => isLoading = false);
    }
    _mostrarDialogoError('Error de conexión: $e');
    throw Exception(e);
  }
}

  // <<< NUEVO: FUNCIÓN COMPLETA PARA VALIDAR Y APLICAR SALDO A FAVOR >>>
  // <<< REEMPLAZA ESTA FUNCIÓN COMPLETA EN TU CÓDIGO >>>
  // =========================================================================
  // <<< REEMPLAZA ESTA FUNCIÓN COMPLETA EN TU CÓDIGO >>>
  // Esta versión corregida se asegura de poner en CERO el saldo a favor
  // de la fila original una vez que ha sido utilizado.
  // =========================================================================
  // <<< MODIFICADO: FUNCIÓN AHORA VACÍA >>>
  // Esta función realizaba una lógica similar a la que eliminamos.
  // La vaciamos para asegurarnos de que no interfiera.
  void _validarYFinalizarUltimoPago(List<Pago> pagos) {
    // No hacer nada. La lógica de liquidación automática ha sido eliminada.
    return;
  }

  // Modifica _actualizarProviderConPagos para que quede así de simple:
  void _actualizarProviderConPagos(List<Pago> pagos) {
    final pagosProvider = Provider.of<PagosProvider>(context, listen: false);

    pagosProvider.cargarPagos(pagos.map((pago) {
      // Simplemente mapeamos los valores ya calculados y definitivos.
      return PagoSeleccionado(
        moratorioDesabilitado: pago.moratorioDesabilitado,
        semana: pago.semana,
        tipoPago: pago.tipoPago,
        deposito: pago.deposito ?? 0.0,
        moratorio: pago.moratorioDesabilitado == "Si"
            ? 0.0
            : pago.moratorios?.moratorios ?? 0.0,
        saldoFavor: pago.saldoFavor ?? 0.0,
        saldoEnContra:
            pago.saldoEnContra ?? 0.0, // <-- Usará el valor ya corregido (0.0)
        abonos: pago.abonos ?? [],
        idfechaspagos: pago.idfechaspagos ?? '',
        fechaPago: pago.fechaPago ?? '',
        pagosMoratorios: pago.pagosMoratorios,
      );
    }).toList());

    controllers = List.generate(pagos.length, (index) {
      return TextEditingController(
        text: pagos[index].sumaDepositoMoratorisos != null &&
                pagos[index].sumaDepositoMoratorisos! > 0
            ? "\$${formatearNumero(pagos[index].sumaDepositoMoratorisos!)}"
            : "",
      );
    });
  }

  void mostrarDialogoCierreSesion(String mensaje,
      {required Function() onClose}) {
    // Detectar si estamos en modo oscuro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          contentPadding: EdgeInsets.only(top: 25, bottom: 10),
          title: Column(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 60,
                color: Colors.red[700],
              ),
              SizedBox(height: 15),
              Text(
                'Sesión Finalizada',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          actionsPadding: EdgeInsets.only(bottom: 20, right: 25, left: 25),
          actions: [
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(double.infinity, 48), // Ancho completo
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onClose();
              },
              child: Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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
    double montoTotal = pago.capitalMasInteres ?? 0.0;
    if (pago.moratorioDesabilitado != "Si") {
      montoTotal += pago.moratorios?.moratorios ?? 0.0;
    }
    return montoTotal > (pago.sumaDepositoMoratorisos ?? 0.0);
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

  // EN LA CLASE: _PaginaControlState

Future<void> _eliminarPago(
    BuildContext context, Pago pago, Map<String, dynamic> abono) async {
  // Obtenemos las dependencias necesarias
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('tokenauth') ?? '';
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final isDarkMode = themeProvider.isDarkMode;

  // Mostramos el diálogo de confirmación (sin cambios)
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
      title: Text('Confirmar eliminación'),
      content: Text('¿Estás seguro de que deseas eliminar este pago?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Cierra el diálogo de confirmación

            // <<< INICIO DE LA CORRECCIÓN >>>

            // 1. Obtenemos el ID del abono.
            final idAbono = abono['idpagos'];

            // 2. Verificamos si es un abono guardado en el servidor o uno local.
            // Un abono local no tendrá 'idpagos' o será una cadena vacía.
            if (idAbono == null || idAbono.toString().isEmpty) {
              // CASO 1: Es un abono local.
              print('Detectado abono local. Eliminando de la lista interna...');
              
              if (mounted) {
                setState(() {
                  // Eliminamos el abono de la lista local del objeto 'pago'.
                  // Para mayor seguridad, si asignas un UID temporal al crear el abono, úsalo aquí.
                  // Si no, la comparación directa del mapa puede funcionar si es el mismo objeto.
                  pago.abonos.remove(abono);
                });
              }

              // CRÍTICO: Recargamos los pagos para forzar el recálculo de los totales.
              // Esto simula el efecto de "cerrar y abrir" el diálogo.
              await recargarPagos();
              print('Abono local eliminado y UI recargada.');

            } else {
              // CASO 2: Es un abono que ya existe en el servidor.
              // Procedemos con la lógica original de llamada a la API.
              print('Detectado abono del servidor (ID: $idAbono). Enviando petición DELETE...');
              try {
                final url = '$baseUrl/api/v1/pagos/$idAbono/${pago.idfechaspagos}';
                
                final response = await http.delete(
                  Uri.parse(url),
                  headers: {'tokenauth': token},
                );

                if (response.statusCode == 200) {
                  // Si se borró del servidor, recargamos los datos para reflejar el cambio.
                  print('Abono del servidor eliminado correctamente. Recargando pagos...');
                  await recargarPagos();
                } else {
                  // Manejo de error si la API falla
                  final errorMsg = 'Error al eliminar: ${response.body}';
                  print(errorMsg);
                  if (mounted) _mostrarDialogoError(errorMsg);
                }
              } catch (e) {
                final errorMsg = 'Error de conexión al eliminar: $e';
                print(errorMsg);
                if (mounted) _mostrarDialogoError(errorMsg);
              }
            }
            // <<< FIN DE LA CORRECCIÓN >>>
          },
          child: Text('Eliminar', style: TextStyle(color: Colors.red)),
        )
      ],
    ),
  );
}

  // =========================================================================
  // --- NUEVO ---: FUNCIÓN COMPLETA PARA GUARDAR LA SELECCIÓN DE RENOVACIÓN
  // =========================================================================
  // En tu clase _PaginaControlState

// =========================================================================
// FUNCIÓN COMPLETA Y CORREGIDA PARA GUARDAR LA SELECCIÓN DE RENOVACIÓN
// Devuelve 'true' en caso de éxito para que se pueda recargar la UI.
// =========================================================================
  // =========================================================================
// FUNCIÓN COMPLETA Y CORREGIDA PARA GUARDAR LA SELECCIÓN DE RENOVACIÓN
// Devuelve 'true' en caso de éxito para que se pueda recargar la UI.
// =========================================================================
// =========================================================================
// FUNCIÓN 3: _guardarSeleccionRenovacion (MODIFICADA PARA ENVIAR EL DESCUENTO CORRECTO) - VERSIÓN COMPLETA
// =========================================================================
  // Por esto:
  // =========================================================================
// FUNCIÓN COMPLETA Y CORREGIDA PARA GUARDAR LA SELECCIÓN DE RENOVACIÓN
// Utiliza una lógica dinámica para identificar los últimos pagos del crédito.
// Devuelve 'true' en caso de éxito para que la UI pueda recargarse.
// =========================================================================
  // EN TU CLASE _PaginaControlState, REEMPLAZA ESTA FUNCIÓN COMPLETA:

  Future<bool> _guardarSeleccionRenovacion(
    BuildContext popupContext,
    StateSetter setStateInPopup,
    Pago pago,
    List<Pago> allPagos,
    Map<String, double> montosFinales,
  ) async {
    if (_isSaving) return false;

    final mainContext = context;
    final String idFechasPago = pago.idfechaspagos ?? '';

    setStateInPopup(() {
      _isSaving = true;
    });

    try {
      // (La lógica de validación para los últimos dos pagos no cambia y se mantiene)
      if (allPagos.isNotEmpty) {
        final int totalSemanas =
            allPagos.map((p) => p.semana).reduce((a, b) => a > b ? a : b);
        final bool esDeLosUltimosDosPagos =
            pago.semana >= totalSemanas - 1 && totalSemanas > 1;
        if (esDeLosUltimosDosPagos) {
          if (widget.clientesParaRenovar.length > 1) {
            final List<ClienteMonto> clientesSeleccionados = widget
                .clientesParaRenovar
                .where((cliente) =>
                    _clientesSeleccionadosNotifier
                        .value[cliente.idamortizacion] ==
                    true)
                .toList();
            final Set<String> idsClientesSeleccionados =
                clientesSeleccionados.map((c) => c.idclientes).toSet();
            final bool hayClientesSinRenovar = widget.clientesParaRenovar
                .any((c) => !idsClientesSeleccionados.contains(c.idclientes));
            final bool sinAbonosDeEfectivo =
                !pago.abonos.any((abono) => abono['garantia'] != 'Si');

            if (hayClientesSinRenovar && sinAbonosDeEfectivo) {
              if (mounted) {
                showDialog(
                  context: mainContext,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0)),
                    title: Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700),
                      SizedBox(width: 10),
                      Text('Acción Requerida'),
                    ]),
                    content: Text(
                        'Para continuar, por favor, primero registre los abonos de los integrantes que no van a renovar en este pago.'),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Entendido',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800),
                      ),
                    ],
                  ),
                );
              }
              return false;
            }
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      if (token.isEmpty) {
        if (!mounted) return false;
        _mostrarDialogoError(
            'No se encontró sesión activa. Por favor, inicia sesión.');
        Navigator.pushAndRemoveUntil(
            mainContext,
            MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false);
        return false;
      }

      // =========================================================================
      // --- INICIO DE LA CORRECCIÓN ---
      // =========================================================================

      // 1. Obtenemos los IDs de los clientes que YA FUERON GUARDADOS para este pago.
      final Set<String> idsYaGuardados =
          pago.renovacionesPendientes.map((r) => r.idclientes ?? '').toSet();

      // 2. Filtramos la lista de seleccionados para enviar SOLO LOS NUEVOS.
      final List<ClienteMonto> clientesNuevosParaGuardar = widget
          .clientesParaRenovar
          .where((cliente) =>
              // Condición 1: El cliente debe estar seleccionado en la UI.
              _clientesSeleccionadosNotifier.value[cliente.idamortizacion] ==
                  true &&
              // Condición 2: El cliente NO debe estar en la lista de los ya guardados.
              !idsYaGuardados.contains(cliente.idclientes))
          .toList();

      // 3. Si no hay clientes NUEVOS seleccionados, no hacemos nada.
      if (clientesNuevosParaGuardar.isEmpty) {
        ScaffoldMessenger.of(mainContext).showSnackBar(
          const SnackBar(
            content: Text("No hay nuevas selecciones para guardar."),
            backgroundColor: Colors.orange,
          ),
        );
        return false; // Detenemos la ejecución.
      }

      // =========================================================================
      // --- FIN DE LA CORRECCIÓN ---
      // =========================================================================

      // Ahora, el cuerpo de la solicitud se construye con la lista filtrada.
      final body = {
        "pagadoParaRenovacion": idFechasPago,
        "clientes": clientesNuevosParaGuardar.map((cliente) {
          // <-- USAMOS LA LISTA CORREGIDA
          final double montoADescontar =
              montosFinales[cliente.idamortizacion] ??
                  cliente.capitalMasInteres;
          return {
            "iddetallegrupos": cliente.iddetallegrupos,
            "idgrupos": cliente.idgrupos,
            "idclientes": cliente.idclientes,
            "descuento": montoADescontar,
          };
        }).toList(),
      };

      final url =
          Uri.parse('$baseUrl/api/v1/pagos/permiso/renovacion/pendientes');
      final response = await http.post(
        url,
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(mainContext).showSnackBar(
          const SnackBar(
            content: Text("Selección para renovación guardada exitosamente."),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        try {
          final errorData = json.decode(response.body);
          String mensajeError = "Ocurrió un error desconocido.";
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] != null) {
            mensajeError = errorData["Error"]["Message"];
            if (mensajeError == "La sesión ha cambiado. Cerrando sesión..." ||
                mensajeError == "jwt expired") {
              await prefs.remove('tokenauth');
              mostrarDialogoCierreSesion(
                  mensajeError == "jwt expired"
                      ? 'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.'
                      : 'La sesión ha cambiado. Se cerrará la sesión actual.',
                  onClose: () {
                Navigator.pushAndRemoveUntil(
                    mainContext,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false);
              });
              return false;
            }
          }
          ScaffoldMessenger.of(mainContext).showSnackBar(SnackBar(
              content: Text("Error al guardar: $mensajeError"),
              backgroundColor: Colors.red));
        } catch (e) {
          ScaffoldMessenger.of(mainContext).showSnackBar(SnackBar(
              content: Text("Error del servidor: ${response.statusCode}"),
              backgroundColor: Colors.red));
        }
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(mainContext).showSnackBar(SnackBar(
          content: Text("Error de conexión: $e"), backgroundColor: Colors.red));
      return false;
    } finally {
      if (mounted) {
        setStateInPopup(() {
          _isSaving = false;
        });
      }
    }
  }

// FUNCIÓN PARA ELIMINAR TODAS LAS SELECCIONES DE RENOVACIÓN DE UN PAGO
// =========================================================================
  // DENTRO DE LA CLASE _PaginaControlState

  Future<bool> _eliminarSeleccionRenovacion(BuildContext popupContext,
      StateSetter setStateInPopup, String idFechasPago) async {
    // Evita múltiples clics si ya se está eliminando o guardando
    if (_isDeleting || _isSaving) return false;

    final mainContext = context;

    // Muestra el indicador de carga en el botón de eliminar
    setStateInPopup(() {
      _isDeleting = true;
    });

    try {
      // 1. OBTENER TOKEN
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // ▼▼▼ BLOQUE RESTAURADO (MANEJO DE SESIÓN) ▼▼▼
      if (token.isEmpty) {
        if (!mounted) return false;
        _mostrarDialogoError(
            'No se encontró sesión activa. Por favor, inicia sesión.');
        Navigator.pushAndRemoveUntil(
          mainContext,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
        return false;
      }
      // ▲▲▲ FIN DEL BLOQUE RESTAURADO ▲▲▲

      // 2. REALIZAR LA LLAMADA HTTP DELETE
      final url = Uri.parse(
          '$baseUrl/api/v1/pagos/permiso/renovacion/pendientes/$idFechasPago');

      final response = await http.delete(
        url,
        headers: {'tokenauth': token},
      );

      if (!mounted) return false;

      // 3. MANEJAR LA RESPUESTA
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(mainContext).showSnackBar(
          const SnackBar(
            content: Text("Selección de renovación eliminada exitosamente."),
            backgroundColor: Colors.green,
          ),
        );
        // Devuelve 'true' para indicar éxito
        return true;
      } else {
        // ▼▼▼ BLOQUE RESTAURADO (MANEJO DE ERRORES DE API) ▼▼▼
        try {
          final errorData = json.decode(response.body);
          String mensajeError = "Ocurrió un error desconocido.";

          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] != null) {
            mensajeError = errorData["Error"]["Message"];

            if (mensajeError == "La sesión ha cambiado. Cerrando sesión...") {
              await prefs.remove('tokenauth');
              mostrarDialogoCierreSesion(
                  'La sesión ha cambiado. Se cerrará la sesión actual.',
                  onClose: () {
                Navigator.pushAndRemoveUntil(
                  mainContext,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              });
              return false;
            } else if (mensajeError == "jwt expired") {
              await prefs.remove('tokenauth');
              mostrarDialogoCierreSesion(
                  'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
                  onClose: () {
                Navigator.pushAndRemoveUntil(
                  mainContext,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              });
              return false;
            }
          }
          ScaffoldMessenger.of(mainContext).showSnackBar(SnackBar(
              content: Text("Error al eliminar: $mensajeError"),
              backgroundColor: Colors.red));
        } catch (e) {
          ScaffoldMessenger.of(mainContext).showSnackBar(SnackBar(
              content: Text("Error del servidor: ${response.statusCode}"),
              backgroundColor: Colors.red));
        }
        return false;
        // ▲▲▲ FIN DEL BLOQUE RESTAURADO ▲▲▲
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(mainContext).showSnackBar(SnackBar(
          content: Text("Error de conexión: $e"), backgroundColor: Colors.red));
      return false;
    } finally {
      if (mounted) {
        // Reinicia el estado de carga
        setStateInPopup(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return FutureBuilder<List<Pago>>(
      future: _pagosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || isLoading) {
          return Padding(
            padding: const EdgeInsets.only(top: 200),
            child: Center(
                child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5162F6)),
            )),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No se encontraron pagos.'));
        } else {
          List<Pago> pagos = snapshot.data!;

          // DESPUÉS (Cálculo correcto)
          final double saldoFavorTotalAcumulado =
              pagos.fold(0.0, (sum, pago) => sum + (pago.saldoRestante ?? 0.0));

          int totalPagosDelCredito = pagos.isNotEmpty
              ? pagos.map((pago) => pago.semana).reduce((a, b) => a > b ? a : b)
              : 0;

// ▼▼▼ REEMPLAZA TU BLOQUE DE CÁLCULO DE TOTALES POR ESTE ▼▼▼

          double totalMonto = 0.0;
          double totalPagoActual = 0.0;
          double totalSaldoFavor = 0.0; // <-- Simplificado
          double totalSaldoContra = 0.0;
          double totalMoratorios = 0.0;
          double totalRealIngresado = 0.0;
          bool hayGarantiaAplicada = false;

          // ▼▼▼ NUEVAS VARIABLES PARA LOS DOS TIPOS DE SALDO EN CONTRA ▼▼▼
          double totalSaldoContraActivo =
              0.0; // El que solo suma deudas con actividad.
          double totalSaldoContraPotencial =
              0.0; // El que suma TODAS las deudas pendientes.

          for (final pago in pagos) {
            if (pago.semana == 0) continue;

            // Cálculos que ya tenías
            totalMonto += pago.capitalMasInteres ?? 0.0;
            totalMoratorios += (pago.moratorioDesabilitado != "Si"
                ? pago.moratorios?.moratorios ?? 0.0
                : 0.0);

          // ==========================================================
// <<< INICIO DEL CÓDIGO FINAL Y CORRECTO >>>
// ==========================================================

// 1. Obtenemos el monto total que se ingresó en la fila (que ya es $10,000).
double montoIngresadoEnFila = pago.sumaDepositoMoratorisos ?? 0.0;

// 2. Obtenemos lo cubierto por renovación (que es otro tipo de ingreso).
double cubiertoPorRenovacion = pago.renovacionesPendientes.fold(0.0, (total, renovacion) => total + (renovacion.descuento ?? 0.0));

// 3. Simplemente sumamos el monto total ingresado y lo de la renovación.
//    NO sumamos 'saldoFavorOriginalGenerado' porque ya está contenido dentro de 'montoIngresadoEnFila'.
totalPagoActual += montoIngresadoEnFila + cubiertoPorRenovacion;

// ==========================================================
// <<< FIN DEL CÓDIGO FINAL Y CORRECTO >>>
// ==========================================================

            for (var abono in pago.abonos) {
              if (abono['garantia'] == 'Si') {
                hayGarantiaAplicada = true;
              } else {
                totalRealIngresado += (abono['deposito'] ?? 0.0);
              }
            }

            // --- LÓGICA DE TOTALES CORREGIDA ---
            // Sumamos el saldo que realmente queda disponible de cada fila
            totalSaldoFavor += pago.saldoRestante ?? 0.0;
            // ▼▼▼ CÁLCULO DE AMBOS TOTALES ▼▼▼

            // 1. Calculamos el "Saldo Potencial" (el de antes)
            //    Suma la deuda si es mayor a cero, sin importar si hay actividad.
            if ((pago.saldoEnContra ?? 0.0) > 0.0) {
              totalSaldoContraPotencial += pago.saldoEnContra!;
            }

            // 2. Calculamos el "Saldo Activo" (el que se mostrará)
            //    Aplicamos la misma lógica que en la celda para decidir si se suma.
            final bool tieneActividadGuardada =
                (pago.sumaDepositoMoratorisos ?? 0.0) > 0.0 ||
                    pago.abonos.isNotEmpty ||
                    pago.renovacionesPendientes.isNotEmpty;

            final bool tieneInteraccionRealTime =
                _pagosConInteraccionRealTime.contains(pago.idfechaspagos ?? '');

            if (tieneActividadGuardada || tieneInteraccionRealTime) {
              if ((pago.saldoEnContra ?? 0.0) > 0.0) {
                totalSaldoContraActivo += pago.saldoEnContra!;
              }
            }
          }

          /*      // Asegurarnos que no sean negativos por algún error de cálculo
          totalSaldoContra = totalSaldoContra > 0.0 ? totalSaldoContra : 0.0;
          totalSaldoFavor = totalSaldoFavor > 0.0 ? totalSaldoFavor : 0.0; */

// ▼▼▼ AÑADE ESTE NUEVO CÁLCULO ▼▼▼
// Sumamos el saldo original generado por TODAS las filas.
          final double saldoFavorHistoricoTotal = pagos.fold(
              0.0, (sum, pago) => sum + pago.saldoFavorOriginalGenerado);
// ▲▲▲ FIN DE LA ADICIÓN ▲▲▲

// ▲▲▲ FIN DEL BLOQUE DE REEMPLAZO ▲▲▲

          return LayoutBuilder(builder: (context, constraints) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 50),
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
                        // PASO 1: Agregar un espacio en el encabezado para la nueva columna de acciones
                        Flexible(
                            flex: 7,
                            child: Container()), // Espacio para el ícono
                      ],
                    ),
                  ),
                ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: SingleChildScrollView(
                    child: Column(
                      children: pagos.map((pago) {
                        bool esPago1 = pagos.indexOf(pago) == 0;
                        int index = pagos.indexOf(pago);

                        // ▼▼▼ AÑADE ESTA LÍNEA ▼▼▼
// Esta variable comprueba si se ha realizado algún tipo de pago o cobertura en la fila.
                        final bool tieneActividadDePago =
                            (pago.sumaDepositoMoratorisos ?? 0.0) > 0.0 ||
                                pago.abonos.isNotEmpty ||
                                pago.renovacionesPendientes.isNotEmpty;

                        // ▼▼▼ ¡ESTA ES LA LÓGICA CORREGIDA! ▼▼▼
                        final double deudaOriginalSemana =
                            (pago.capitalMasInteres ?? 0.0) +
                                (pago.moratorioDesabilitado == "Si"
                                    ? 0.0
                                    : (pago.moratorios?.moratorios ?? 0.0));

                        // ¡AQUÍ ESTÁ LA MAGIA! Restamos el descuento de garantía para obtener la deuda real.
                        final double deudaRealDeLaSemana = deudaOriginalSemana -
                            (pago.descuentoGarantiaAplicado ?? 0.0);

                        // Redondeamos el total cubierto por renovación para evitar errores de céntimos.
                        final double montoCubiertoPorRenovacion = pago
                            .renovacionesPendientes
                            .fold(
                                0.0,
                                (total, renovacion) =>
                                    total + (renovacion.descuento ?? 0.0))
                            .roundToDouble();

                        final double montoPagadoEnEfectivo =
                            pago.sumaDepositoMoratorisos ?? 0.0;

                        final double montoTotalPagadoCombinado =
                            montoPagadoEnEfectivo + montoCubiertoPorRenovacion;

                        /*    // La fila se considera finalizada si lo pagado es >= a la DEUDA REAL.
                        pago.estaFinalizado =
                            montoTotalPagadoCombinado >= deudaRealDeLaSemana;
                        // ▲▲▲ FIN DE LA LÓGICA CORREGIDA ▲▲▲ */

                        bool isDateButtonEnabled =
                            (pago.moratorioDesabilitado == "Si" ||
                                    (pago.moratorios?.moratorios ?? 0) == 0) &&
                                _puedeEditarPago(pago);

                        DateTime fechaPagoDateTime =
                            DateTime.parse(pago.fechaPago);

                        int indicadorCount = 0;
                        final bool tieneMoratorios =
                            (pago.moratorios?.moratorios ?? 0) > 0;
                        if (tieneMoratorios) {
                          indicadorCount++;
                        }

                        final bool tieneRenovaciones =
                            pago.renovacionesPendientes.isNotEmpty;
                        if (tieneRenovaciones) {
                          indicadorCount++;
                        }

// ▼▼▼ AÑADE ESTA NUEVA CONDICIÓN ▼▼▼
// Si se ha utilizado saldo a favor en este pago, también contamos como un "estado especial".
                        final bool tieneFavorUtilizado =
                            pago.favorUtilizado > 0;
                        if (tieneFavorUtilizado) {
                          indicadorCount++;
                        }
// ▲▲▲ FIN DE LA ADICIÓN ▲▲▲

                        final bool mostrarIndicador = indicadorCount > 0;

                        return Container(
                          decoration: BoxDecoration(
                            // ▼▼▼ CAMBIADO ▼▼▼
                            // Usamos `!estaFinalizado` en lugar de `_puedeEditarPago(pago)`
                            color: !pago
                                    .estaFinalizado // <-- USA LA PROPIEDAD DEL OBJETO

                                ? Colors.transparent
                                : isDarkMode
                                    ? Colors.blueGrey.shade900
                                    : Colors.blueGrey.shade50,
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
                                _buildTableCell(
                                    esPago1 ? "0" : "${pago.semana}",
                                    flex: 10),
                                _buildTableCell(formatearFecha(pago.fechaPago),
                                    flex: 15),
                                _buildTableCell(
                                  esPago1
                                      ? "-"
                                      : "\$${formatearNumero(pago.capitalMasInteres)}",
                                  flex: 18,
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
                                                  fontSize: 11,
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
                                                return DropdownMenuItem<
                                                    String?>(
                                                  value: value,
                                                  child: Text(
                                                    value,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      // ▼▼▼ CAMBIADO ▼▼▼
                                                      color: !pago
                                                              .estaFinalizado
                                                          ? (isDarkMode
                                                              ? Colors.white
                                                              : Colors.black)
                                                          : (isDarkMode
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                  .grey[700]),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              // ▼▼▼ CAMBIADO ▼▼▼
                                              onChanged: !pago.estaFinalizado
                                                  ? (String? newValue) {
                                                      // Tu lógica de `onChanged` no necesita cambiar.
                                                      // Simplemente se activará o no basado en `!estaFinalizado`.
                                                      setState(() {
                                                        pago.tipoPago =
                                                            newValue!;
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
                                                          pago.fechaPagoCompleto = pago
                                                                  .fechaPagoCompleto
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
                                                            pago.saldoFavor =
                                                                0.0;
                                                          }
                                                        }

                                                        // Crear objeto PagoSeleccionado
                                                        PagoSeleccionado
                                                            pagoSeleccionado =
                                                            PagoSeleccionado(
                                                                moratorioDesabilitado: pago
                                                                    .moratorioDesabilitado,
                                                                semana:
                                                                    pago.semana,
                                                                tipoPago: pago
                                                                    .tipoPago,
                                                                deposito: pago.deposito ??
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
                                                                saldoFavor: pago
                                                                    .saldoFavor,
                                                                saldoEnContra: pago
                                                                    .saldoEnContra,
                                                                abonos:
                                                                    pago.abonos,
                                                                pagosMoratorios:
                                                                    pago.pagosMoratorios);

                                                        // Actualizar provider
                                                        Provider.of<PagosProvider>(
                                                                context,
                                                                listen: false)
                                                            .actualizarPago(
                                                                pagoSeleccionado);

                                                        // Debug: Imprimir estado actualizado
                                                        print(
                                                            "Estado del Provider después de actualización:");
                                                        Provider.of<PagosProvider>(
                                                                context,
                                                                listen: false)
                                                            .pagosSeleccionados
                                                            .forEach((pago) {
                                                          /*  print(
                                                              "Pago en Provider: Semana ${pago.semana}, Tipo de pago: ${pago.tipoPago}, Monto a Pagar: ${pago.capitalMasInteres}, Deposito: ${pago.deposito}"); */
                                                        });
                                                      });
                                                    }
                                                  : null,
                                              icon: Icon(
                                                Icons.arrow_drop_down,
                                                // ▼▼▼ CAMBIADO ▼▼▼
                                                color: !pago.estaFinalizado
                                                    ? Color(0xFF5162F6)
                                                    : (isDarkMode
                                                        ? Colors.grey[600]
                                                        : Colors.grey[400]),
                                              ),
                                              dropdownColor: isDarkMode
                                                  ? Colors.grey[800]
                                                  : Colors.white,
                                            ),
                                            // Fila para seleccionar la fecha (se muestra tanto en "Completo" como en "Monto Parcial")
                                            // Selector de fecha
                                            // Selector de fecha (modificar esta condición)
                                            // Ejemplo para el selector de fecha
                                            if (!pago.estaFinalizado &&
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
                                                    // Widget ElevatedButton modificado
                                                    ElevatedButton(
                                                      onPressed:
                                                          isDateButtonEnabled
                                                              ? () =>
                                                                  _editarFechaPago(
                                                                      context,
                                                                      pago)
                                                              : null,
                                                      style: ButtonStyle(
                                                        backgroundColor:
                                                            MaterialStateProperty
                                                                .resolveWith<
                                                                    Color>(
                                                          (states) =>
                                                              isDateButtonEnabled
                                                                  ? Color(
                                                                      0xFF5162F6)
                                                                  : Colors
                                                                      .transparent,
                                                        ),
                                                        padding:
                                                            MaterialStateProperty
                                                                .all<
                                                                    EdgeInsets>(
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 8),
                                                        ),
                                                        minimumSize:
                                                            MaterialStateProperty
                                                                .all<Size>(Size(
                                                                    24, 24)),
                                                        shape: MaterialStateProperty
                                                            .all<
                                                                RoundedRectangleBorder>(
                                                          RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6.0),
                                                            side: BorderSide(
                                                              color: isDateButtonEnabled
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
                                                        color: isDateButtonEnabled
                                                            ? Colors.white
                                                            : (isDarkMode
                                                                ? Colors
                                                                    .grey[500]
                                                                : Colors
                                                                    .grey[400]),
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
                                                        fontSize: 11,
                                                        color: isDarkMode
                                                            ? Colors.grey[400]
                                                            : Colors.grey[600],
                                                        fontStyle: pago
                                                                .fechaPago
                                                                .isEmpty
                                                            ? FontStyle.italic
                                                            : FontStyle.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                            // Indicadores de Garantía DEBAJO del selector de fecha
                                            if (pago.tipoPago ==
                                                'Completo') ...[
                                              ...pago.abonos.map((abono) {
                                                final esGarantia =
                                                    (abono['garantia']
                                                                as String)
                                                            .toLowerCase() ==
                                                        'si';
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4.0),
                                                  child: Column(
                                                    children: [
                                                      if (esGarantia)
                                                        Container(
                                                          margin: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      12),
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
                                                                    .circular(
                                                                        6),
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
                                                                    fontSize:
                                                                        10,
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
                                  flex: 20,
                                ),

                                SizedBox(width: 20),
                                // Dos botones: uno para agregar abonos, otro para ver abonos
                                _buildTableCell(
                                  pago.tipoPago == 'En Abonos'
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(left: 5),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              // Botón para agregar un abono
                                              Container(
                                                decoration: BoxDecoration(
                                                  // ▼▼▼ CAMBIADO ▼▼▼
                                                  color: !pago.estaFinalizado
                                                      ? const Color(0xFF5162F6)
                                                      : Colors.grey,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                        color: Colors.black26,
                                                        blurRadius: 5,
                                                        offset: Offset(2, 2))
                                                  ],
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.add,
                                                      color: Colors.white),
                                                  // ▼▼▼ CAMBIADO ▼▼▼
                                                  onPressed: !pago
                                                          .estaFinalizado
                                                      ? () async {
                                                          // Obtén el provider y muestra el diálogo para agregar abonos
                                                          final pagosProvider =
                                                              Provider.of<
                                                                      PagosProvider>(
                                                                  context,
                                                                  listen:
                                                                      false);
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
                                                                        Navigator.of(context)
                                                                            .pop(abonos);
                                                                      },
                                                                      moratorioDesabilitado:
                                                                          pago.moratorioDesabilitado, // <-- Pasa el valor
                                                                      moratorios: pago
                                                                          .moratorios
                                                                          ?.moratorios, // <-- Pasa el valor
                                                                    ),
                                                                  )) ??
                                                                  [];

                                                          print(
                                                              'Nuevos abonos recibidos: $nuevosAbonos');

                                                          setState(() {
                                                            if (nuevosAbonos
                                                                .isNotEmpty) {
                                                              // Agregar los nuevos abonos a la lista del pago (esto no cambia)
                                                              pago.abonos.addAll(
                                                                  nuevosAbonos.map(
                                                                      (abono) {
                                                                abono['uid'] =
                                                                    Uuid().v4();
                                                                pago.fechaPago =
                                                                    abono[
                                                                        'fechaDeposito'];
                                                                return abono;
                                                              }));

                                                              // =========================================================================
                                                              // <<< INICIO DE LA MODIFICACIÓN: LÓGICA DE CÁLCULO PARA ABONOS >>>
                                                              // =========================================================================

                                                              // 1. Calcular el total de todos los abonos para esta fila.
                                                              final double
                                                                  totalAbonado =
                                                                  pago.abonos
                                                                      .fold(
                                                                0.0,
                                                                (sum, abono) =>
                                                                    sum +
                                                                    (abono['deposito'] ??
                                                                        0.0),
                                                              );

                                                              // 2. Calcular la deuda total de la semana.
                                                              final double
                                                                  deudaTotalSemana =
                                                                  (pago.capitalMasInteres ??
                                                                          0.0) +
                                                                      (pago.moratorioDesabilitado ==
                                                                              "Si"
                                                                          ? 0.0
                                                                          : (pago.moratorios?.moratorios ??
                                                                              0.0));

                                                              // 3. Calcular la diferencia.
                                                              final double
                                                                  diferencia =
                                                                  totalAbonado -
                                                                      deudaTotalSemana;

                                                              // 4. Identificar el pago por su ID único.
                                                              final String
                                                                  pagoId =
                                                                  pago.idfechaspagos ??
                                                                      '';

                                                              // 5. Actualizar el mapa de tiempo real y el saldo en contra del pago.
                                                              if (diferencia >
                                                                  0) {
                                                                // Guardamos el saldo a favor en nuestro mapa temporal.
                                                                _saldosFavorEnTiempoReal[
                                                                        pagoId] =
                                                                    diferencia;
                                                                pago.saldoEnContra =
                                                                    0.0;
                                                              } else {
                                                                // Si no hay saldo a favor, nos aseguramos de que no haya una entrada en el mapa.
                                                                _saldosFavorEnTiempoReal
                                                                    .remove(
                                                                        pagoId);
                                                                pago.saldoEnContra =
                                                                    -diferencia;
                                                              }

                                                              print(
                                                                  "Cálculo tras abono: Total Abonado: $totalAbonado, Deuda: $deudaTotalSemana, Saldo a Favor en mapa: ${_saldosFavorEnTiempoReal[pagoId]}, Saldo en Contra: ${pago.saldoEnContra}");

                                                              // Actualizar el Provider (esto no cambia).
                                                              Provider.of<PagosProvider>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .actualizarPago(
                                                                      pago.toPagoSeleccionado());

                                                              // =========================================================================
                                                              // <<< FIN DE LA MODIFICACIÓN >>>
                                                              // =========================================================================
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
                                                      final monto = (abono[
                                                                  'deposito']
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
                                                                    vertical:
                                                                        6.0,
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
                                                                            MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Text(
                                                                            "\$${formatearNumero(monto)}",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 13,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: isDarkMode ? Colors.white : Colors.black87,
                                                                            ),
                                                                          ),
                                                                          if (esGarantia)
                                                                            Container(
                                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                              decoration: BoxDecoration(
                                                                                color: Color(0xFFE53888).withOpacity(isDarkMode ? 0.3 : 0.2),
                                                                                borderRadius: BorderRadius.circular(6),
                                                                              ),
                                                                              child: const Text(
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
                                                                if (widget
                                                                        .tipoUsuario ==
                                                                    'Admin')
                                                                  IconButton(
                                                                    icon: Icon(
                                                                        Icons
                                                                            .delete_outline,
                                                                        size:
                                                                            16),
                                                                    color: Colors
                                                                        .red,
                                                                    onPressed:
                                                                        () {
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop();
                                                                      _eliminarPago(
                                                                          context,
                                                                          pago,
                                                                          abono);
                                                                    },
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
                                                    final String? textoEstado =
                                                        pago.estado == "Pagado"
                                                            ? "Liquidado"
                                                            : pago.estado ==
                                                                    "Retraso"
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
                                                                        : Colors
                                                                            .blue[700],
                                                                    size: 20,
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          12),
                                                                  Expanded(
                                                                    child:
                                                                        Column(
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
                                                                              style: TextStyle(
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
                                                  padding:
                                                      const EdgeInsets.only(
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
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: !pago.estaFinalizado
                                                                    ? (isDarkMode
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .black)
                                                                    : (isDarkMode
                                                                        ? Colors.grey[
                                                                            300]
                                                                        : Colors
                                                                            .grey[700]),
                                                              ),
                                                              keyboardType:
                                                                  TextInputType
                                                                      .number,
                                                              enabled: !pago
                                                                  .estaFinalizado,

                                                              // =========================================================================
                                                              // <<< INICIO DE LA MODIFICACIÓN: LÓGICA DE CÁLCULO EN TIEMPO REAL >>>
                                                              // =========================================================================
                                                              onChanged:
                                                                  (value) {
                                                                if (_debounce
                                                                        ?.isActive ??
                                                                    false) {
                                                                  _debounce
                                                                      ?.cancel();
                                                                }

                                                                _debounce = Timer(
                                                                    const Duration(
                                                                        milliseconds:
                                                                            400),
                                                                    () {
                                                                  setState(() {
                                                                    final String
                                                                        pagoId =
                                                                        pago.idfechaspagos ??
                                                                            '';

                                                                    // =========================================================================
                                                                    // <<< BLOQUE AÑADIDO PARA REGISTRAR LA INTERACCIÓN >>>
                                                                    // =========================================================================
                                                                    if (value
                                                                        .isNotEmpty) {
                                                                      _pagosConInteraccionRealTime
                                                                          .add(
                                                                              pagoId);
                                                                    } else {
                                                                      // Si el campo está vacío, la interacción "termina"
                                                                      _pagosConInteraccionRealTime
                                                                          .remove(
                                                                              pagoId);
                                                                    }
                                                                    // =========================================================================

                                                                    // Tu lógica de cálculo existente (no cambia)
                                                                    final double
                                                                        montoIngresado =
                                                                        double.tryParse(value.replaceAll(",",
                                                                                "")) ??
                                                                            0.0;
                                                                    pago.deposito =
                                                                        montoIngresado;

                                                                    final double
                                                                        deudaTotalSemana =
                                                                        (pago.capitalMasInteres ??
                                                                                0.0) +
                                                                            (pago.moratorioDesabilitado == "Si"
                                                                                ? 0.0
                                                                                : (pago.moratorios?.moratorios ?? 0.0));

                                                                    final double
                                                                        diferencia =
                                                                        montoIngresado -
                                                                            deudaTotalSemana;

                                                                    if (diferencia >
                                                                        0) {
                                                                      _saldosFavorEnTiempoReal[
                                                                              pagoId] =
                                                                          diferencia;
                                                                      pago.saldoEnContra =
                                                                          0.0;
                                                                    } else {
                                                                      _saldosFavorEnTiempoReal
                                                                          .remove(
                                                                              pagoId);
                                                                      pago.saldoEnContra =
                                                                          -diferencia;
                                                                    }

                                                                    Provider.of<PagosProvider>(
                                                                            context,
                                                                            listen:
                                                                                false)
                                                                        .actualizarPago(
                                                                            pago.toPagoSeleccionado());
                                                                  });
                                                                });
                                                              },

                                                              decoration:
                                                                  InputDecoration(
                                                                hintText:
                                                                    'Monto Parcial',
                                                                hintStyle:
                                                                    TextStyle(
                                                                  fontSize: 11,
                                                                  color: isDarkMode
                                                                      ? Colors.grey[
                                                                          300]
                                                                      : Colors.grey[
                                                                          700],
                                                                ),
                                                                /*     prefixText:
                                                                    '\$', // Mostrar el símbolo "$" dentro del campo */
                                                                prefixStyle:
                                                                    TextStyle(
                                                                  fontSize: 13,
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
                                                                      width:
                                                                          1.5),
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
                                                                      width:
                                                                          1.5),
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
                                                                      if (widget
                                                                              .tipoUsuario ==
                                                                          'Admin')
                                                                        IconButton(
                                                                          icon: Icon(
                                                                              Icons.delete_outline,
                                                                              size: 16),
                                                                          color:
                                                                              Colors.red,
                                                                          onPressed: () => _eliminarPago(
                                                                              context,
                                                                              pago,
                                                                              abono),
                                                                        ),
                                                                      SizedBox(
                                                                          height:
                                                                              6),
                                                                      if (esGarantia) // ← Condición simplificada
                                                                        Container(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              horizontal: 6,
                                                                              vertical: 2),
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
                                                                              fontSize: 10,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Color(0xFFE53888),
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
                                                                        top:
                                                                            4.0),
                                                                child:
                                                                    Container(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .green
                                                                        .shade50,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .green
                                                                            .shade100,
                                                                        width:
                                                                            1),
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
                                                                              fontSize: 10,
                                                                              color: Colors.grey.shade800,
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                            children: [
                                                                              TextSpan(text: 'Se usó '),
                                                                              TextSpan(
                                                                                text: '\$${formatearNumero(pago.capitalMasInteres) ?? '0.00'}',
                                                                                style: TextStyle(
                                                                                  fontSize: 10,
                                                                                  color: Color(0xFFE53888),
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              ),
                                                                              TextSpan(text: ' de '),
                                                                              TextSpan(
                                                                                text: '\$${formatearNumero(widget.montoGarantia)}',
                                                                                style: TextStyle(
                                                                                  fontSize: 10,
                                                                                  color: Color(0xFFE53888),
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
                                                              fontSize: 11,
                                                              color:
                                                                  Colors.black),
                                                        ),
                                                )
                                              : Padding(
                                                  padding:
                                                      const EdgeInsets.only(
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
                                                            fontSize: 13,
                                                            color: isDarkMode
                                                                ? Colors.white
                                                                : Colors.black),
                                                      ),
                                                      SizedBox(
                                                          height:
                                                              4), // Espacio entre el monto y la fecha

                                                      // Verificar si hay pagos y mostrar la fecha de depósito de cada uno
                                                      if (pago
                                                          .abonos.isNotEmpty)
                                                        ...pago.abonos
                                                            .map((abono) {
                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 4.0),
                                                            child: Column(
                                                              children: [
                                                                //PAGADO DE COMPLETO
                                                                Text(
                                                                  'Pagado: ${formatearFecha(abono["fechaDeposito"])}',
                                                                  // Mostrar la fecha de depósito
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: isDarkMode
                                                                        ? Colors.grey[
                                                                            300]
                                                                        : Colors
                                                                            .grey[700],
                                                                  ),
                                                                ),
                                                                // Botón de eliminar para Admin
                                                                if (widget
                                                                        .tipoUsuario ==
                                                                    'Admin')
                                                                  Padding(
                                                                    padding: EdgeInsets
                                                                        .only(
                                                                            top:
                                                                                4),
                                                                    child: Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        IconButton(
                                                                          icon: Icon(
                                                                              Icons.delete_outline,
                                                                              size: 16),
                                                                          color:
                                                                              Colors.red,
                                                                          onPressed: () => _eliminarPago(
                                                                              context,
                                                                              pago,
                                                                              abono),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
                                                      if (pago.abonos.any(
                                                          (abono) =>
                                                              abono[
                                                                  'garantia'] ==
                                                              'Si'))
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 12),
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Color(
                                                                      0xFFE53888)
                                                                  .withOpacity(
                                                                      0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              /*  border: Border.all(
                                                                  color: Color(0xFFE53888).withOpacity(0.2)), */
                                                            ),
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4),
                                                            child: RichText(
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              text: TextSpan(
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: isDarkMode
                                                                        ? Colors.pink[
                                                                            100]
                                                                        : Colors
                                                                            .grey
                                                                            .shade800,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500),
                                                                children: [
                                                                  TextSpan(
                                                                      text:
                                                                          'Se usó '),
                                                                  TextSpan(
                                                                    text:
                                                                        '\$${formatearNumero(pago.capitalMasInteres)}',
                                                                    style: TextStyle(
                                                                        color: Color(
                                                                            0xFFE53888),
                                                                        fontWeight:
                                                                            FontWeight.bold),
                                                                  ),
                                                                  TextSpan(
                                                                      text:
                                                                          ' de '),
                                                                  TextSpan(
                                                                    text:
                                                                        '\$${formatearNumero(widget.montoGarantia)}',
                                                                    style: TextStyle(
                                                                        color: Color(
                                                                            0xFFE53888),
                                                                        fontWeight:
                                                                            FontWeight.bold),
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
                                  flex: 18,
                                ),

                                // =========================================================================
// <<< INICIO: CELDA MEJORADA PARA "SALDO A FAVOR" >>>
// =========================================================================
                                // EN TU MÉTODO build, DENTRO DEL .map((pago) {...})
// REEMPLAZA LA CELDA "SALDO A FAVOR" CON ESTA VERSIÓN FINAL-FINAL:

// =========================================================================
// <<< INICIO: CELDA "SALDO A FAVOR" - LÓGICA FUSIONADA Y CORRECTA >>>
// =========================================================================
// EN TU MÉTODO build, USA TU CÓDIGO ORIGINAL PARA LA CELDA Y AÑADE ESTO:
                                _buildTableCell(
                                  Builder(builder: (context) {
                                    // Usamos un Builder para tener contexto

                                    // =========================================================================
                                    // <<< NUEVA LÓGICA DE PRIORIDAD MÁXIMA >>>
                                    // =========================================================================
                                    final String pagoId =
                                        pago.idfechaspagos ?? '';
                                    if (_saldosFavorEnTiempoReal
                                        .containsKey(pagoId)) {
                                      // Si nuestro mapa de tiempo real tiene un valor para este pago, lo mostramos.
                                      final double saldoRealTime =
                                          _saldosFavorEnTiempoReal[pagoId]!;
                                      return Text(
                                        "\$${formatearNumero(saldoRealTime)}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          /*  color: isDarkMode ? Colors.green[300] : Colors.green[800],
          fontWeight: FontWeight.bold, */
                                        ),
                                      );
                                    }
                                    // =========================================================================

                                    // <<< TU CÓDIGO ORIGINAL, SIN CAMBIOS, VA AQUÍ ABAJO >>>
                                    // Si no hay nada en el mapa de tiempo real, se ejecuta tu lógica probada.

                                    if ((pago.saldoFavorOriginalGenerado ??
                                            0.0) <=
                                        0.01) {
                                      return Text("-",
                                          style: TextStyle(color: textColor));
                                    }

                                    // --- Si se generó saldo a favor, evaluamos su estado ---
                                    final double restante =
                                        pago.saldoRestante ?? 0.0;
                                    final double original =
                                        pago.saldoFavorOriginalGenerado;
                                    final bool fueConsumidoTotalmente =
                                        pago.fueUtilizadoPorServidor;

                                    // --- CASO 2: El saldo se usó por completo ---
                                    if (fueConsumidoTotalmente) {
                                      return Tooltip(
                                        message:
                                            'Saldo de \$${formatearNumero(original)} utilizado completamente',
                                        child: Text(
                                          "\$${formatearNumero(original)}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: (isDarkMode
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withOpacity(0.5),
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      );
                                    }

                                    // --- CASO 3: Queda saldo (parcial o total) ---
                                    else if (restante > 0) {
                                      if (restante >= original) {
                                        return Text(
                                          "\$${formatearNumero(restante)}",
                                          style: TextStyle(fontSize: 13),
                                        );
                                      } else {
                                        final double usado =
                                            original - restante;
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Tooltip(
                                              message:
                                                  'Se utilizaron \$${formatearNumero(usado)} de saldo a favor',
                                              child: Text(
                                                "\$${formatearNumero(restante)}",
                                                style: TextStyle(fontSize: 13),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 2.0),
                                              child: Text(
                                                "(de \$${formatearNumero(original)})",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDarkMode
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    }

                                    // --- CASO 4: Fallback ---
                                    else {
                                      return Text("-",
                                          style: TextStyle(color: textColor));
                                    }
                                  }),
                                  flex: 18,
                                ),
// =========================================================================
// <<< FIN: CELDA "SALDO A FAVOR" - LÓGICA FUSIONADA Y CORRECTA >>>
// =========================================================================
                                // =========================================================================
// =========================================================================
// <<< FIN: CELDA MEJORADA PARA "SALDO A FAVOR" >>>
// =========================================================================

                                // En la clase _PaginaControlState (dentro del método build):
                                /*  _buildTableCell(
                                  esPago1
                                      ? "-"
                                      : (pago.saldoEnContra != null &&
                                              pago.saldoEnContra! > 0.0)
                                          ? pago.moratorioDesabilitado == "Si"
                                              ? "-" // Mostrar "-" si están deshabilitados
                                              : "\$${formatearNumero(pago.saldoEnContra!)}"
                                          : "-",
                                  flex: 18,
                                ), */

                                // ▼▼▼ PEGA ESTE CÓDIGO EN SU LUGAR ▼▼▼
                                // EN TU MÉTODO build, DENTRO DEL .map((pago) {...})
// REEMPLAZA TU CELDA DE "SALDO EN CONTRA" CON ESTA VERSIÓN SIMPLIFICADA:

// =========================================================================
// <<< INICIO: CELDA "SALDO EN CONTRA" CORREGIDA PARA TIEMPO REAL >>>
// =========================================================================
                                _buildTableCell(
                                  esPago1 // Mantenemos la lógica para el pago 1, que es especial.
                                      ? "-"
                                      : Builder(
                                          builder: (context) {
                                            final String pagoId =
                                                pago.idfechaspagos ?? '';

                                            // Condición 1: ¿Hay pagos ya guardados en el servidor?
                                            // (Esta era tu variable 'tieneActividadDePago')
                                            final bool tieneActividadGuardada =
                                                (pago.sumaDepositoMoratorisos ??
                                                            0.0) >
                                                        0.0 ||
                                                    pago.abonos.isNotEmpty ||
                                                    pago.renovacionesPendientes
                                                        .isNotEmpty;

                                            // Condición 2: ¿Está el usuario interactuando con esta fila AHORA?
                                            final bool
                                                tieneInteraccionRealTime =
                                                _pagosConInteraccionRealTime
                                                    .contains(pagoId);

                                            // Condición 3: ¿El saldo en contra calculado es mayor a cero?
                                            final bool haySaldoEnContra =
                                                (pago.saldoEnContra ?? 0.0) >
                                                    0.01;

                                            // Muestra el valor SOLO si (hay actividad guardada O hay interacción ahora) Y hay un saldo en contra que mostrar.
                                            if ((tieneActividadGuardada ||
                                                    tieneInteraccionRealTime) &&
                                                haySaldoEnContra) {
                                              return Text(
                                                "\$${formatearNumero(pago.saldoEnContra!)}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  /* color: isDarkMode ? Colors.orange[300] : Colors.red[800],
                  fontWeight: FontWeight.bold, */
                                                ),
                                              );
                                            } else {
                                              // En cualquier otro caso, muestra el guion.
                                              return Text(
                                                "-",
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: textColor),
                                              );
                                            }
                                          },
                                        ),
                                  flex: 18,
                                ),
// =========================================================================
// <<< FIN: CELDA "SALDO EN CONTRA" CORREGIDA >>>
// =========================================================================
                                // Mostrar los moratorios con la misma lógica, solo si existen
                                // DESPUÉS (CÓDIGO MODIFICADO)
                                _buildTableCell(
                                  esPago1
                                      ? "-"
                                      : (pago.moratorios == null ||
                                              pago.moratorios!.moratorios ==
                                                  0.0)
                                          ? Container(
                                              alignment: Alignment.center,
                                              child: Text(
                                                "-",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                            )
                                          // Ahora solo mostramos el texto, sin el Row ni el PopupMenuButton
                                          : Text(
                                              pago.moratorioDesabilitado == "Si"
                                                  ? "-"
                                                  : "\$${formatearNumero(pago.moratorios!.moratorios)}",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.normal,
                                                color:
                                                    pago.moratorioDesabilitado ==
                                                            "Si"
                                                        ? Colors.grey
                                                        : isDarkMode
                                                            ? Colors.white
                                                            : Colors.black,
                                              ),
                                            ),
                                  flex: 18,
                                ),

                                // =================================================================
                                // PASO 2: AÑADIR EL MENÚ DE OPCIONES AL FINAL DE LA FILA
                                // =================================================================
                                // DESPUÉS (CÓDIGO MODIFICADO)
                                // REEMPLAZA todo el bloque Flexible con este código

                                // PASO 3: Reemplaza tu PopupMenuButton principal con este código mejorado
                                // ---- CÓDIGO A REEMPLAZAR ----
                                // --- El bloque del CustomPopupMenu que vas a reemplazar ---
                                Flexible(
                                  flex: 7,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: esPago1
                                        ? SizedBox.shrink()
                                        : CustomPopupMenu(
                                            // --- USA EL ICONO CON INDICADOR ---
                                            icon: IconoConIndicador(
                                              mostrarIndicador:
                                                  mostrarIndicador,
                                              count:
                                                  indicadorCount, // <-- Pasamos el número calculado
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: isDarkMode
                                                      ? Colors.grey[800]
                                                      : null,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.more_vert,
                                                  color: isDarkMode
                                                      ? Colors.white70
                                                      : Colors.black54,
                                                  size: 18,
                                                ),
                                              ),
                                            ),

                                            // El resto de tus propiedades para CustomPopupMenu...
                                            width: 220.0,
                                            menuColor: isDarkMode
                                                ? Colors.grey[850]
                                                : Colors.white,
                                            elevation: 12,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              side: BorderSide(
                                                color: isDarkMode
                                                    ? Colors.grey[700]!
                                                    : Colors.grey[200]!,
                                                width: 1,
                                              ),
                                            ),
                                            tooltip: "Opciones del pago",
                                            onMenuBuild: () {
                                              final Set<String> idsGuardados =
                                                  pago.renovacionesPendientes
                                                      .map((r) => r.idclientes)
                                                      .toSet();

                                              final initialSelection = {
                                                for (var cliente in widget
                                                    .clientesParaRenovar)
                                                  cliente.idamortizacion:
                                                      idsGuardados.contains(
                                                          cliente.idclientes),
                                              };
                                              _clientesSeleccionadosNotifier
                                                  .value = initialSelection;
                                            },
                                            // LÍNEA MODIFICADA (AÑADE `pagos`)
                                            items: _buildPagoMenuItems(
                                              context,
                                              pago,
                                              pagos, // <-- AÑADIDO: Pasamos la lista completa de pagos
                                              isDarkMode,
                                              index,
                                              totalPagosDelCredito,
                                              saldoFavorTotalAcumulado, // <-- NUEVO PARÁMETRO
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Después, pasas esos totales al _buildTableCell como lo haces normalmente
                // Fila de Totales
                // Reemplaza este bloque completo en tu widget build
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

                      // <<< CAMBIO PRINCIPAL: INICIO >>>
                      // Ahora pasamos un widget Row anidado a _buildTableCell
                      // para agrupar el texto y el icono.
                      _buildTableCell(
                        Row(
                          mainAxisSize: MainAxisSize
                              .min, // Clave: para que la Row no se expanda
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. El texto del monto
                            Text(
                              "\$${formatearNumero(totalPagoActual)}",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ),
                            ),

                            // 2. El icono condicional con su Tooltip
                            if (hayGarantiaAplicada) ...[
                              SizedBox(
                                  width:
                                      4), // Controlamos el espacio exacto aquí
                              Tooltip(
                                waitDuration: Duration.zero,
                                showDuration: Duration(seconds: 5),
                                richMessage: WidgetSpan(
                                  child: Transform.translate(
                                    offset: Offset(0, -10),
                                    child: Container(
                                      padding: EdgeInsets.all(10),
                                      constraints:
                                          BoxConstraints(maxWidth: 220),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? Colors.grey[800]
                                            : Color(0xFFF7F8FA),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Total real ingresado:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '\$${formatearNumero(totalRealIngresado)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87,
                                            ),
                                          ),
                                          Divider(
                                            height: 12,
                                            thickness: 0.5,
                                            color: isDarkMode
                                                ? Colors.grey[600]
                                                : Colors.grey[300],
                                          ),
                                          Text(
                                            'Este valor no considera garantías ni montos de renovación para la suma.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              //fontStyle: FontStyle.italic,
                                              color: isDarkMode
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                decoration: BoxDecoration(),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors
                                      .help, // Más semántico que 'click'
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        textColor: Colors.white,
                        flex: 10, // Mantenemos el mismo flex para la celda
                      ),
                      // <<< CAMBIO PRINCIPAL: FIN >>>

                      // <<< MODIFICADO: Celda del Total de "Saldo a Favor" >>>
                      // En tu fila de totales, busca la celda de "Saldo a Favor"

                      // =========================================================================
// <<< REEMPLAZA ESTE WIDGET _buildTableCell COMPLETO >>>
// =========================================================================
                      // Celda de Saldo a Favor (simplificada)
                      // ▼▼▼ REEMPLAZA LA CELDA DE "SALDO A FAVOR" DE TOTALES POR ESTO ▼▼▼
                      // =========================================================================
// <<< INICIO: CELDA DE TOTALES DE SALDO A FAVOR MEJORADA >>>
// =========================================================================
                      _buildTableCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. El texto del monto restante total
                            Text(
                              "\$${formatearNumero(totalSaldoFavor)}",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ),
                            ),

                            // 2. Un icono informativo que muestra el total histórico generado
                            if (saldoFavorHistoricoTotal >
                                totalSaldoFavor + 0.01) ...[
                              SizedBox(width: 4),
                              Tooltip(
                                message:
                                    'Total generado históricamente: \$${formatearNumero(saldoFavorHistoricoTotal)}',
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                        textColor: Colors.white,
                        flex: 10,
                      ),
// =========================================================================
// <<< FIN: CELDA DE TOTALES DE SALDO A FAVOR MEJORADA >>>
// =========================================================================

                      // ▲▲▲ FIN DEL REEMPLAZO ▲▲▲
                      // Busca el Row que muestra el "Total Saldo en Contra" y reemplázalo por esto:

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // El valor con el tooltip en el lado derecho
                          Tooltip(
                            // --- El mensaje que aparece al pasar el cursor o hacer tap largo ---
                            message:
                                "Deuda Potencial Total: \$${formatearNumero(totalSaldoContraPotencial)}\n\n(Suma de todas las deudas pendientes,\nincluyendo pagos futuros y moratorios generados)",

                            // --- Estilos opcionales para que se vea bien ---
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            margin: EdgeInsets.symmetric(horizontal: 20),

                            
                            waitDuration: Duration(
                                milliseconds:
                                    300), // Tiempo de espera antes de mostrar

                            // --- El widget visible que activa el tooltip ---
                            child: Row(
                              mainAxisSize: MainAxisSize
                                  .min, // Para que el Row no ocupe todo el espacio
                              children: [
                                Text(
                                  // Muestra el total ACTIVO por defecto
                                  '\$${formatearNumero(totalSaldoContraActivo)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _buildTableCell("\$${formatearNumero(totalMoratorios)}",
                          textColor: Colors.white, flex: 10),
                      Flexible(flex: 7, child: Container()), // Espacio final
                    ],
                  ),
                ),
              ],
            );
          });
        }
      },
    );
  }

  // =========================================================================
// <<< AÑADE ESTA FUNCIÓN DE AYUDA DENTRO DE _PaginaControlState >>>
// =========================================================================
  Widget _buildTooltipRow(String label, String value, bool isDarkMode,
      {bool isTotal = false}) {
    final labelColor = isDarkMode ? Colors.white70 : Colors.black87;
    final valueColor = isTotal
        ? (isDarkMode ? Colors.green.shade300 : Colors.green.shade800)
        : (isDarkMode ? Colors.white : Colors.black);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: labelColor,
          ),
        ),
        SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // DENTRO DE LA CLASE _PaginaControlState

  /// Distribuye un monto total de forma proporcional, lo redondea al entero más cercano
  /// y ajusta la suma final distribuyendo las diferencias en incrementos de 0.50.
  ///
  /// [totalADistribuir] El monto total que se va a dividir.
  /// [clientes] La lista de clientes entre los que se va a repartir el monto.
  /// [montoOriginalTotal] La suma de los montos originales, para calcular la proporción.
  ///
  /// Devuelve un Map<String, double> con montos finales.
  Map<String, double> _distribuirYRedondearMontos(
    double totalADistribuir,
    List<ClienteMonto> clientes,
    double montoOriginalTotal,
  ) {
    if (montoOriginalTotal <= 0 || clientes.isEmpty) {
      return {};
    }

    final double totalObjetivo = totalADistribuir.roundToDouble();
    List<Map<String, dynamic>> calculos = [];
    double sumaRedondeada = 0;

    // 1. Calcular la parte proporcional y redondearla para cada cliente.
    for (var cliente in clientes) {
      final double parteProporcional =
          (cliente.capitalMasInteres / montoOriginalTotal) * totalADistribuir;
      final double montoRedondeado = parteProporcional.roundToDouble();
      final double errorDeRedondeo = montoRedondeado - parteProporcional;

      calculos.add({
        'id': cliente.idamortizacion,
        'montoFinal': montoRedondeado,
        'error': errorDeRedondeo,
      });
      sumaRedondeada += montoRedondeado;
    }

    // 2. Calcular la diferencia entre la suma de lo redondeado y el objetivo total.
    double diferencia = totalObjetivo - sumaRedondeada;

    // ▼▼▼ LÓGICA DE AJUSTE MODIFICADA ▼▼▼
    // 3. Corregir la diferencia sumando o restando incrementos de 0.50.
    if (diferencia.abs() >= 1.0) {
      // Convertimos la diferencia en "pasos de 50 centavos".
      // Si falta $1, necesitamos 2 pasos. Si faltan $2, necesitamos 4 pasos.
      int pasosDeAjuste = (diferencia * 2).round().abs();

      // Si la suma es muy BAJA (diferencia > 0), AÑADIMOS 0.50.
      if (diferencia > 0) {
        // Damos los 50 centavos a quienes más "perdieron" al redondear.
        calculos.sort(
            (a, b) => (a['error'] as double).compareTo(b['error'] as double));
        for (int i = 0; i < pasosDeAjuste; i++) {
          // Usamos el módulo para repartir de forma cíclica si hay más pasos que clientes.
          calculos[i % calculos.length]['montoFinal'] += 0.50;
        }
      }
      // Si la suma es muy ALTA (diferencia < 0), QUITAMOS 0.50.
      else {
        // Quitamos los 50 centavos a quienes más "ganaron" al redondear.
        calculos.sort(
            (a, b) => (b['error'] as double).compareTo(a['error'] as double));
        for (int i = 0; i < pasosDeAjuste; i++) {
          calculos[i % calculos.length]['montoFinal'] -= 0.50;
        }
      }
    }
    // ▲▲▲ FIN DE LA LÓGICA MODIFICADA ▲▲▲

    // 4. Crear el mapa final con los montos corregidos.
    final Map<String, double> montosFinales = {};
    for (var item in calculos) {
      montosFinales[item['id']] = item['montoFinal'];
    }

    return montosFinales;
  }

  // Dentro de la clase State de tu pantalla
// EN LA CLASE STATE DE TU PANTALLA

  Widget _buildTriggerItem({
    required IconData icon,
    required String title,
    String?
        subtitle, // Parámetro opcional para el subtítulo (como el monto en Moratorios)
    required Color iconColor,
    required Color iconBackgroundColor,
    bool isDarkMode = false,
  }) {
    return Container(
      // Añadimos el padding que tenías para que se vea igual
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- LA FLECHA QUE INDICA ACCIÓN ---
          // La añadimos a TODOS los items que usan este builder.
          Icon(
            Icons.chevron_left, // O Icons.chevron_right si prefieres
            color: isDarkMode ? Colors.white54 : Colors.black45,
            size: 20.0,
          ),

          // --- EL ÍCONO CON FONDO REDONDEADO ---
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          SizedBox(width: 12),

          // --- TEXTO PRINCIPAL Y SUBTÍTULO (OPCIONAL) ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) // Solo muestra el subtítulo si existe
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Coloca este método en tu State class
// =========================================================================
// FUNCIÓN PRINCIPAL QUE CONSTRUYE LA ESTRUCTURA DEL MENÚ USANDO MODELOS
// =========================================================================
  // EN LA CLASE STATE DE TU PANTALLA

  // =========================================================================
// FUNCIÓN 1: _buildPagoMenuItems (MODIFICADA PARA PASAR 'allPagos')
// =========================================================================
// =========================================================================
// FUNCIÓN 1: _buildPagoMenuItems (LÓGICA DE MORATORIOS CORREGIDA) - VERSIÓN COMPLETA
// =========================================================================
// =========================================================================
// FUNCIÓN 1: _buildPagoMenuItems (LÓGICA DE MORATORIOS CORREGIDA SEGÚN TU ORIGINAL) - VERSIÓN COMPLETA
// =========================================================================
  // EN TU CLASE _PaginaControlState, REEMPLAZA ESTA FUNCIÓN COMPLETA:

  List<MenuItemModel> _buildPagoMenuItems(
    BuildContext context,
    Pago pago,
    List<Pago> allPagos,
    bool isDarkMode,
    int indicePagoActual,
    int totalPagos,
    double saldoFavorTotalAcumulado,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isRightSide = screenWidth > 600;

    final List<MenuItemModel> menuDefinition = [];

    // --- 1. Submenú de Moratorios (sin cambios) ---
    if (pago.moratorios != null) {
      menuDefinition.add(
        SubMenuItem(
          maxWidth: 280.0,
          offset: isSmallScreen
              ? Offset(-250, 0)
              : isRightSide
                  ? Offset(-230, 0)
                  : Offset(-0, 0),
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          elevation: 12,
          child: _buildTriggerItem(
            icon: Icons.info_outline,
            title: 'Moratorios',
            subtitle: (pago.moratorios!.moratorios > 0)
                ? '\$${formatearNumero(pago.moratorios!.moratorios)}'
                : 'Sin moratorios',
            iconColor: isDarkMode ? Color(0xFF7E92FF) : Color(0xFF3D5AFE),
            iconBackgroundColor:
                isDarkMode ? Colors.grey.shade800 : Color(0xFFE8EAF6),
            isDarkMode: isDarkMode,
          ),
          subItems: _buildMoratoriosSubMenuItems(context, pago, isDarkMode),
        ),
      );
    }

    // --- 2. ACCIÓN "CLIENTES A RENOVAR" (sin cambios) ---
    menuDefinition.add(
      SubMenuItem(
        maxWidth: 350.0,
        offset: isSmallScreen
            ? Offset(-250, 0)
            : isRightSide
                ? Offset(-230, 0)
                : Offset(-0, 0),
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        elevation: 12,
        child: ValueListenableBuilder<Map<String, bool>>(
          valueListenable: _clientesSeleccionadosNotifier,
          builder: (context, selectionMap, child) {
            final count = selectionMap.values.where((v) => v).length;
            final subtitle =
                '$count de ${widget.clientesParaRenovar.length} seleccionados';

            return _buildTriggerItem(
              icon: Icons.person_add_outlined,
              title: 'Clientes a renovar',
              subtitle: subtitle,
              iconColor: isDarkMode ? Color(0xFF7E92FF) : Color(0xFF3D5AFE),
              iconBackgroundColor:
                  isDarkMode ? Colors.grey.shade800 : Color(0xFFE8EAF6),
              isDarkMode: isDarkMode,
            );
          },
        ),
        subItems: _buildRenovacionSubMenuItems(
          context,
          isDarkMode,
          pago,
          allPagos,
          pago.renovacionesPendientes,
          //pago.estaFinalizado,
        ),
      ),
    );

    // =========================================================================
    // ===== SUBMENÚ "UTILIZAR SALDO A FAVOR" - LÓGICA MODIFICADA ============
    // =========================================================================

    // --- INICIO DE LA LÓGICA SOLICITADA ---
    String subtituloSaldo;
    final double favorUtilizadoEnEstePago = pago.favorUtilizado;

    // PRIORIDAD 1: Mostrar cuánto se utilizó en ESTE pago específico.
    if (favorUtilizadoEnEstePago > 0.01) {
      subtituloSaldo =
          '\$${formatearNumero(favorUtilizadoEnEstePago)} utilizado aquí';
    }
    // PRIORIDAD 2: Si no se usó aquí, mostrar el saldo total disponible del crédito.
    else if (saldoFavorTotalAcumulado > 0.01) {
      subtituloSaldo =
          '\$${formatearNumero(saldoFavorTotalAcumulado)} disponible';
    }
    // PRIORIDAD 3: Si no hay nada utilizado ni disponible, mostrar un mensaje por defecto.
    else {
      subtituloSaldo = 'Sin saldo a favor';
    }
    // --- FIN DE LA LÓGICA SOLICITADA ---

    menuDefinition.add(
      SubMenuItem(
        maxWidth: 280.0,
        offset: isSmallScreen
            ? Offset(-250, 0)
            : isRightSide
                ? Offset(-230, 0)
                : Offset(-0, 0),
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        elevation: 12,
        child: _buildTriggerItem(
          icon: Icons.savings_outlined,
          title: 'Utilizar Saldo a favor',
          subtitle: subtituloSaldo, // <-- Usamos el subtítulo recién calculado
          iconColor: isDarkMode ? Color(0xFF69F0AE) : Color(0xFF00C853),
          iconBackgroundColor:
              isDarkMode ? Colors.green.shade900 : Color(0xFFE8F5E9),
          isDarkMode: isDarkMode,
        ),
        subItems: _buildSaldoAFavorSubMenuItems(
          context,
          pago,
          allPagos,
          isDarkMode,
          saldoFavorTotalAcumulado,
        ),
      ),
    );

    return menuDefinition;
  }

// =========================================================================
// FUNCIÓN AUXILIAR QUE CONSTRUYE LA LISTA DE MODELOS PARA EL SUBMENÚ
// =========================================================================
  List<MenuItemModel> _buildMoratoriosSubMenuItems(
      BuildContext context, Pago pago, bool isDarkMode) {
    final List<MenuItemModel> items = [];

    // --- Header con gradiente (usando MenuInfoItem) ---
    items.add(MenuInfoItem(
      child: Transform.translate(
        offset: const Offset(0, -8.0),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C6BC0), Color(0xFF3F51B5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF5162F6).withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.schedule, color: Colors.white, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Información de Moratorios",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    // --- Filas de información (usando MenuInfoItem) ---
    if (pago.moratorios!.semanasDeRetraso > 0) {
      items.add(MenuInfoItem(
        child: _buildInfoRowInteligente(
            Icons.date_range_outlined,
            "Semanas de retraso",
            "${pago.moratorios!.semanasDeRetraso}",
            isDarkMode),
      ));
    }
    if (pago.moratorios!.diferenciaEnDias > 0) {
      items.add(MenuInfoItem(
        child: _buildInfoRowInteligente(Icons.today_outlined, "Días de retraso",
            "${pago.moratorios!.diferenciaEnDias}", isDarkMode),
      ));
    }
    items.add(MenuInfoItem(
      child: _buildInfoRowInteligente(
          Icons.attach_money_outlined,
          "Monto calculado",
          "\$${formatearNumero(pago.moratorios!.moratorios)}",
          isDarkMode,
          isAmount: true),
    ));

    // ❌ FALTA: Monto Total
    items.add(MenuInfoItem(
      child: _buildInfoRowInteligente(
          Icons.account_balance_wallet_outlined,
          "Monto Total",
          "\$${formatearNumero(pago.moratorios!.montoTotal)}",
          isDarkMode,
          isAmount: true),
    ));

    // ❌ FALTA: Mensaje de moratorios
    if (pago.moratorios!.mensaje.isNotEmpty) {
      items.add(MenuInfoItem(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          margin: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8, // ⬅️ Aumentar a 8 para separar del mensaje
            bottom: 0,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.grey[800]?.withOpacity(0.3)
                : Colors.grey[100]?.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode
                  ? Colors.grey[600]?.withOpacity(0.3) ?? Colors.grey
                  : Colors.grey[300] ?? Colors.grey,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mensaje:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      pago.moratorios!.mensaje,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                        //fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }

    // --- Checkbox personalizado (usando MenuCustomItem) ---
    // Checkbox mejorado con animaciones usando MenuCustomItem
    if (widget.tipoUsuario == 'Admin' && _puedeEditarPago(pago)) {
      items.add(
        MenuCustomItem(
          builder: (popupContext) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateInPopup) {
                final isDisabled = pago.moratorioDesabilitado == "Si";

                return AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: 8, // ⬅️ Aumentar a 8 para separar del mensaje
                    bottom: 0,
                  ),
                  decoration: BoxDecoration(
                    color: isDisabled ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDisabled
                          ? Color(0xFF5162F6).withOpacity(0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: isDisabled
                        ? [
                            BoxShadow(
                              color: Color(0xFF5162F6).withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Checkbox personalizado
                      GestureDetector(
                        onTap: () {
                          setStateInPopup(() {
                            pago.moratorioDesabilitado =
                                isDisabled ? "No" : "Si";
                          });
                          setState(() {
                            _recalcularSaldos(pago);
                            Provider.of<PagosProvider>(context, listen: false)
                                .actualizarPago(pago.toPagoSeleccionado());
                          });
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click, // <--- AÑADE ESTO

                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: isDisabled
                                  ? LinearGradient(
                                      colors: [
                                        Color(0xFF5162F6),
                                        Color(0xFF7B68EE)
                                      ],
                                    )
                                  : null,
                              color: isDisabled ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDisabled
                                    ? Colors.transparent
                                    : Color(0xFF5162F6).withOpacity(0.6),
                                width: 2,
                              ),
                              boxShadow: isDisabled
                                  ? [
                                      BoxShadow(
                                        color:
                                            Color(0xFF5162F6).withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isDisabled
                                ? Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),

                      // Icono descriptivo
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.block_rounded,
                          size: 16,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                      SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Deshabilitar moratorios",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            AnimatedOpacity(
                              duration: Duration(milliseconds: 200),
                              opacity: isDisabled ? 1.0 : 0.6,
                              child: Text(
                                isDisabled
                                    ? "✓ Moratorios deshabilitados"
                                    : "Toca para deshabilitar",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDisabled
                                      ? Color(0xFF10B981)
                                      : Color(0xFF5162F6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
    }

    return items;
  }

  List<MenuItemModel> _buildRenovacionSubMenuItems(
    BuildContext context,
    bool isDarkMode,
    Pago pago,
    List<Pago> allPagos,
    List<RenovacionPendiente> renovacionesGuardadas,
  ) {
    final List<MenuItemModel> items = [];
    final String idfechaspagos = pago.idfechaspagos ?? '';
    final ValueNotifier<Map<String, double>> montosFinalesNotifier =
        ValueNotifier({});

    // --- Lógica de cálculo de montos iniciales ---
    final double totalOriginal = widget.clientesParaRenovar
        .fold(0.0, (sum, cliente) => sum + cliente.capitalMasInteres);

    double totalObjetivoFinal =
        (redondearDecimales(totalOriginal, context) as num).toDouble();

    Map<String, double> montosParaMostrar = {};

    bool vistaConDescuento = false;
    if (allPagos.isNotEmpty) {
      final int totalSemanas =
          allPagos.map((p) => p.semana).reduce((a, b) => a > b ? a : b);

      if (pago.semana == totalSemanas && totalSemanas > 1) {
        double garantiaRestante = 0;
        try {
          final pagoPenultimo =
              allPagos.firstWhere((p) => p.semana == totalSemanas - 1);
          final bool garantiaUsadaEnPenultimo =
              pagoPenultimo.abonos.any((abono) => abono['garantia'] == 'Si');

          if (garantiaUsadaEnPenultimo) {
            final double montoGarantiaUsadaEnPenultimo = pagoPenultimo.abonos
                .where((abono) => abono['garantia'] == 'Si')
                .fold(
                    0.0,
                    (sum, abono) =>
                        sum +
                        (double.tryParse(abono['deposito'].toString()) ?? 0.0));

            garantiaRestante =
                widget.montoGarantia - montoGarantiaUsadaEnPenultimo;
            if (garantiaRestante < 0.01) garantiaRestante = 0;
          }
        } catch (e) {
          garantiaRestante = 0;
        }

        if (garantiaRestante > 0 && widget.pagoCuotaTotal > 0) {
          vistaConDescuento = true;
          final double nuevoMontoFichaTotal =
              widget.pagoCuotaTotal - garantiaRestante;

          totalObjetivoFinal =
              (redondearDecimales(nuevoMontoFichaTotal, context) as num)
                  .toDouble();

          montosParaMostrar = _distribuirYRedondearMontos(
            totalObjetivoFinal,
            widget.clientesParaRenovar,
            widget.pagoCuotaTotal,
          );
        }
      }
    }

    if (!vistaConDescuento) {
      for (final cliente in widget.clientesParaRenovar) {
        montosParaMostrar[cliente.idamortizacion] = cliente.capitalMasInteres;
      }
    }

    if (renovacionesGuardadas.isNotEmpty) {
      final Map<String, double> savedDiscounts = {
        for (var r in renovacionesGuardadas) r.idclientes!: r.descuento ?? 0.0
      };
      for (final cliente in widget.clientesParaRenovar) {
        if (savedDiscounts.containsKey(cliente.idclientes)) {
          montosParaMostrar[cliente.idamortizacion] =
              savedDiscounts[cliente.idclientes]!;
        }
      }
    }
    montosFinalesNotifier.value = montosParaMostrar;

    // --- Header ---
    items.add(MenuInfoItem(
      child: Transform.translate(
        offset: const Offset(0, -8.0),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C6BC0), Color(0xFF3F51B5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.group_add_outlined,
                    color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Seleccionar Clientes a Renovar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    // =========================================================================
    // --- INICIO DE LA LÓGICA DE VALIDACIÓN CORREGIDA Y MEJORADA ---
    // =========================================================================
    final bool tieneActividadGuardadaEnServidor =
        renovacionesGuardadas.isNotEmpty ||
            (pago.sumaDepositoMoratorisos ?? 0.0) > 0.0;
    final bool hayClientesRenovados = renovacionesGuardadas.isNotEmpty;

    // CASO 1: El pago está finalizado y NO tiene clientes renovados.
    // Este es el único caso donde mostramos un mensaje simple y terminamos.
    if (pago.estaFinalizado && !hayClientesRenovados) {
      items.add(MenuInfoItem(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.green.withOpacity(0.1)
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkMode
                  ? Colors.green.withOpacity(0.3)
                  : Colors.green.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_outlined,
                  color: isDarkMode
                      ? Colors.green.shade300
                      : Colors.green.shade700,
                  size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Este pago ya está liquidado.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.green.shade200
                        : Colors.green.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            ],
          ),
        ),
      ));
      return items; // Salida temprana
    }

    // Si llegamos aquí, es porque:
    // A) El pago NO está finalizado.
    // B) El pago SÍ está finalizado, PERO tiene clientes renovados.
    // En ambos casos, mostramos la lista interactiva.

    // Añadimos un banner informativo si el pago está finalizado para dar contexto.
    if (pago.estaFinalizado) {
      items.add(MenuInfoItem(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.orange.withOpacity(0.15)
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkMode
                  ? Colors.orange.withOpacity(0.4)
                  : Colors.orange.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_clock_outlined,
                  color: isDarkMode
                      ? Colors.orange.shade300
                      : Colors.orange.shade700,
                  size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Pago liquidado. No se pueden guardar cambios, pero sí eliminar la renovación existente.",
                  style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.orange.shade200
                          : Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                      height: 1.3),
                ),
              )
            ],
          ),
        ),
      ));
    }

    // Siempre mostramos la lista interactiva en este punto
    items.add(
      MenuCustomItem(builder: (popupContext) {
        final ValueNotifier<String?> _currentlyEditingIdNotifier =
            ValueNotifier(null);
        final Map<String, TextEditingController> _textControllers = {};

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateInPopup) {
            final Set<String> idsGuardados =
                renovacionesGuardadas.map((r) => r.idclientes!).toSet();
            final Map<String, String> amortizacionToClienteIdMap = {
              for (var c in widget.clientesParaRenovar)
                c.idamortizacion: c.idclientes!
            };

            void _toggleCliente(String idamortizacion, bool? value) {
              final newSelection =
                  Map<String, bool>.from(_clientesSeleccionadosNotifier.value);
              final estadoActual = newSelection[idamortizacion] ?? false;
              newSelection[idamortizacion] = value ?? !estadoActual;
              _clientesSeleccionadosNotifier.value = newSelection;
              setStateInPopup(() {});
            }

            void _toggleSeleccionarTodos(bool? value) {
              final hayClientes =
                  _clientesSeleccionadosNotifier.value.isNotEmpty;
              final todosSeleccionados = hayClientes &&
                  !_clientesSeleccionadosNotifier.value.containsValue(false);
              final nuevoEstado = value ?? !todosSeleccionados;
              final newSelection = {
                for (var key in _clientesSeleccionadosNotifier.value.keys)
                  key: idsGuardados.contains(amortizacionToClienteIdMap[key])
                      ? true
                      : nuevoEstado
              };
              _clientesSeleccionadosNotifier.value = newSelection;
              setStateInPopup(() {});
            }

            void _ajustarMonto(String idClienteAjustado, double ajuste) {
              final nuevosMontos =
                  Map<String, double>.from(montosFinalesNotifier.value);
              final montoActual = nuevosMontos[idClienteAjustado] ?? 0;
              nuevosMontos[idClienteAjustado] = (montoActual + ajuste);
              montosFinalesNotifier.value = nuevosMontos;
            }

            final bool hayClientes =
                _clientesSeleccionadosNotifier.value.isNotEmpty;
            final bool todosSeleccionados = hayClientes &&
                !_clientesSeleccionadosNotifier.value.containsValue(false);

            return ValueListenableBuilder<Map<String, double>>(
              valueListenable: montosFinalesNotifier,
              builder: (context, montosActuales, child) {
                final double totalAPagar = totalObjetivoFinal;
                double totalSeleccionado = 0.0;
                for (var cliente in widget.clientesParaRenovar) {
                  if (_clientesSeleccionadosNotifier
                          .value[cliente.idamortizacion] ==
                      true) {
                    totalSeleccionado +=
                        montosActuales[cliente.idamortizacion] ?? 0.0;
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: pago.estaFinalizado
                          ? null
                          : () => _toggleSeleccionarTodos(null),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: todosSeleccionados,
                              onChanged: pago.estaFinalizado
                                  ? null
                                  : _toggleSeleccionarTodos,
                              activeColor: Color(0xFF3F51B5),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Seleccionar Todos",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                        height: 1, indent: 16, endIndent: 16, thickness: 0.5),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(50.0, 8.0, 16.0, 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Nombre",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.black54)),
                          Text("Monto a Pagar",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.black54)),
                        ],
                      ),
                    ),
                    ...widget.clientesParaRenovar.map((cliente) {
                      final String clientId = cliente.idamortizacion;
                      final bool yaEstaGuardado = renovacionesGuardadas
                          .any((r) => r.idclientes == cliente.idclientes);
                      final double montoFinal =
                          montosActuales[clientId] ?? cliente.capitalMasInteres;
                      final double montoOriginal = cliente.capitalMasInteres;
                      final double descuentoAplicado =
                          montoOriginal - montoFinal;

                      return InkWell(
                        onTap: pago.estaFinalizado || yaEstaGuardado
                            ? null
                            : () => _toggleCliente(clientId, null),
                        child: Opacity(
                          opacity:
                              pago.estaFinalizado || yaEstaGuardado ? 0.6 : 1.0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 2.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: yaEstaGuardado
                                      ? true
                                      : _clientesSeleccionadosNotifier
                                              .value[clientId] ??
                                          false,
                                  onChanged:
                                      pago.estaFinalizado || yaEstaGuardado
                                          ? null
                                          : (value) =>
                                              _toggleCliente(clientId, value),
                                  activeColor: Color(0xFF3F51B5),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                cliente.nombreCompleto,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (yaEstaGuardado)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    left: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)),
                                                child: Text(
                                                  "GUARDADO",
                                                  style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors
                                                          .green.shade700),
                                                ),
                                              )
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: ValueListenableBuilder<
                                                  String?>(
                                                valueListenable:
                                                    _currentlyEditingIdNotifier,
                                                builder:
                                                    (context, editingId, _) {
                                                  final bool isEditing =
                                                      editingId == clientId;

                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    height: 38,
                                                    child: isEditing &&
                                                            !pago.estaFinalizado
                                                        ? _buildEditableField(
                                                            context,
                                                            clientId,
                                                            montoFinal,
                                                            _textControllers,
                                                            _currentlyEditingIdNotifier,
                                                            montosFinalesNotifier,
                                                            isDarkMode,
                                                          )
                                                        : _buildStaticText(
                                                            clientId,
                                                            montoFinal,
                                                            montoOriginal,
                                                            descuentoAplicado,
                                                            _currentlyEditingIdNotifier,
                                                            pago.estaFinalizado ||
                                                                yaEstaGuardado,
                                                            isDarkMode,
                                                          ),
                                                  );
                                                },
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    iconSize: 16,
                                                    icon: Icon(
                                                        Icons.arrow_drop_up),
                                                    onPressed:
                                                        pago.estaFinalizado ||
                                                                yaEstaGuardado
                                                            ? null
                                                            : () =>
                                                                _ajustarMonto(
                                                                    clientId,
                                                                    0.10),
                                                    color: isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    iconSize: 16,
                                                    icon: Icon(
                                                        Icons.arrow_drop_down),
                                                    onPressed:
                                                        pago.estaFinalizado ||
                                                                yaEstaGuardado ||
                                                                montoFinal <
                                                                    0.10
                                                            ? null
                                                            : () =>
                                                                _ajustarMonto(
                                                                    clientId,
                                                                    -0.10),
                                                    color: isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                )
                                              ],
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
                      );
                    }).toList(),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Divider(
                          height: 1, indent: 16, endIndent: 16, thickness: 0.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.08),
                              width: 1,
                            )),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total Seleccionado:",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                Text(
                                  '\$${formatearNumero(totalSeleccionado)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total a Pagar (Objetivo):",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                Text(
                                  '\$${formatearNumero(totalAPagar)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3F51B5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.tipoUsuario == 'Admin' || !pago.estaFinalizado)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          children: [
                            if (!tieneActividadGuardadaEnServidor)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.blue.withOpacity(0.1)
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: isDarkMode
                                            ? Colors.blue.withOpacity(0.3)
                                            : Colors.blue.shade200,
                                        width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: isDarkMode
                                              ? Colors.blue.shade300
                                              : Colors.blue.shade700,
                                          size: 20),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Guarde primero un abono para poder gestionar la renovación.",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode
                                                  ? Colors.blue.shade200
                                                  : Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                              height: 1.3),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            if (hayClientesRenovados)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: _isDeleting
                                        ? Container()
                                        : Icon(Icons.delete_forever_outlined,
                                            size: 18, color: Colors.white),
                                    label: _isDeleting
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white))
                                        : Text("Eliminar Selección"),
                                    onPressed: _isSaving || _isDeleting
                                        ? null
                                        : () async {
                                            final bool eliminadoExitoso =
                                                await _eliminarSeleccionRenovacion(
                                                    popupContext,
                                                    setStateInPopup,
                                                    idfechaspagos);
                                            if (eliminadoExitoso && mounted) {
                                              Navigator.of(context).pop();
                                              Navigator.of(context).pop();
                                              await recargarPagos();
                                              _infoCreditoState
                                                  ?._refrescarDatosCredito();
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      disabledBackgroundColor:
                                          Colors.red.shade700.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: _isSaving
                                    ? Container()
                                    : Icon(Icons.save_alt_outlined,
                                        size: 18, color: Colors.white),
                                label: _isSaving
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white))
                                    : Text(
                                        "Guardar Selección",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                onPressed: pago.estaFinalizado ||
                                        !tieneActividadGuardadaEnServidor ||
                                        _isSaving ||
                                        _isDeleting
                                    ? null
                                    : () async {
                                        final bool guardadoExitoso =
                                            await _guardarSeleccionRenovacion(
                                                popupContext,
                                                setStateInPopup,
                                                pago,
                                                allPagos,
                                                montosActuales);

                                        if (guardadoExitoso && mounted) {
                                          Navigator.of(context).pop();
                                          Navigator.of(context).pop();
                                          await recargarPagos();
                                          _infoCreditoState
                                              ?._refrescarDatosCredito();
                                        } else if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text(
                                                "No se pudo guardar la selección. Intenta de nuevo."),
                                            backgroundColor: Colors.orange,
                                          ));
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF3F51B5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  disabledBackgroundColor:
                                      Color(0xFF3F51B5).withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      }),
    );

    return items;
  }

  // =========================================================================
// <<< NUEVA FUNCIÓN: LÓGICA PARA APLICAR SALDO A FAVOR >>>
// Añade esta función completa dentro de tu clase _PaginaControlState
// =========================================================================
// =========================================================================
// <<< FUNCIÓN CORREGIDA PARA APLICAR SALDO A FAVOR (SEGÚN NUEVO FORMATO) >>>
// Reemplaza la versión anterior de esta función con esta.
// =========================================================================
// =========================================================================
// <<< FUNCIÓN CON IMPRESIONES PARA DEPURACIÓN >>>
// Reemplaza la función existente con esta versión que incluye prints detallados.
// =========================================================================
// =========================================================================
// <<< FUNCIÓN FINAL: USA EL ID DIRECTAMENTE DESDE EL MODELO PAGO >>>
// Esta es la versión definitiva, más limpia y correcta.
// =========================================================================
  // EN TU CLASE _PaginaControlState

Future<void> _aplicarSaldoAFavor(
  BuildContext popupContext,
  Pago pagoDestino,
  double montoTotalAAplicar,
) async {
  // 1. Evita múltiples clics si ya se está procesando algo
  //if (_isSaving) return;

  final mainContext = context;
  
  // 2. Activa el estado de carga ANTES de empezar
  //    (Importante: necesita estar dentro de un setState para que la UI se actualice)
  //    Lo haremos dentro del builder del botón para que el efecto sea inmediato en el popup.
  //    Aquí solo lo activamos para la lógica principal.
  setState(() => _isSaving = true);

    try {
      // 1. OBTENER TOKEN (sin cambios)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      if (token.isEmpty) {
        if (!mounted) return;
        _mostrarDialogoError(
            'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.');
        Navigator.pushAndRemoveUntil(
            mainContext,
            MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false);
        setState(() => _isSaving = false);
        return;
      }

      // ================== LÓGICA SIMPLIFICADA ==================
      // 2. OBTENER EL ID DIRECTAMENTE DEL MODELO
      final String? idPagosDetalles = pagoDestino.idpagosdetalles;

      // Verificación de seguridad: nos aseguramos de que el ID no sea nulo o vacío.
      if (idPagosDetalles == null || idPagosDetalles.isEmpty) {
        _mostrarDialogoError(
            "El pago de destino no tiene un ID de detalle válido (idpagosdetalles).");
        setState(() => _isSaving = false);
        return;
      }
      // ========================================================

      // 3. CONSTRUIR EL PAYLOAD
      final List<Map<String, dynamic>> payload = [
        {
          "idcredito": widget.idCredito,
          "idpagos": pagoDestino.idpagos,
          "montoAdepositar": pagoDestino.capitalMasInteres,
          "idpagosdetalles":
              idPagosDetalles, // <-- ¡AHORA USAMOS EL CAMPO CORRECTO DEL MODELO!
          "idfechaspagos": pagoDestino.idfechaspagos,
          "saldofavor": double.parse(montoTotalAAplicar.toStringAsFixed(2)),
        }
      ];

      // 4. ENVIAR LA SOLICITUD (con prints para depuración)
      final url = Uri.parse('$baseUrl/api/v1/pagos/utilizar/saldofavor');

      print("=============================================");
      print("🚀 APLICANDO SALDO A FAVOR (VERSIÓN FINAL) 🚀");
      print("➡️  URL: $url");
      print("📦 PAYLOAD: ${jsonEncode(payload)}");

      final response = await http.post(
        url,
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(payload),
      );

      print("⬅️  RESPUESTA: ${response.statusCode} - ${response.body}");
      print("=============================================");

      if (!mounted) return;

      // 5. MANEJAR LA RESPUESTA (sin cambios)
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(mainContext).showSnackBar(
          const SnackBar(
              content: Text("Saldo a favor aplicado exitosamente."),
              backgroundColor: Colors.green),
        );

           Navigator.of(popupContext).pop();
      Navigator.of(mainContext).pop();
      await recargarPagos();
      _infoCreditoState?._refrescarDatosCredito();
    } else {
      final errorData = json.decode(response.body);
      String mensajeError = errorData["Error"]?["Message"] ??
          "Error desconocido al aplicar saldo.";
      _mostrarDialogoError(mensajeError);
    }
  } catch (e) {
    if (mounted) _mostrarDialogoError("Error de conexión: $e");
  /* } finally {
    // 3. Desactiva el estado de carga SIEMPRE al finalizar (éxito o error)
    if (mounted) {
      setState(() => _isSaving = false);
    } */
  }
}

  // =========================================================================
// NUEVA FUNCIÓN QUE CONSTRUYE EL SUBMENÚ PARA EL SALDO A FAVOR
// =========================================================================
  // =========================================================================
// FUNCIÓN MEJORADA: Permite al usuario elegir el monto a aplicar
// =========================================================================
// =========================================================================
// <<< FUNCIÓN ACTUALIZADA: SUBMENÚ INTERACTIVO PARA SALDO A FAVOR >>>
// Reemplaza tu función _buildSaldoAFavorSubMenuItems existente con esta.
// =========================================================================
  // EN TU CLASE _PaginaControlState, REEMPLAZA ESTA FUNCIÓN COMPLETA

// EN TU CLASE _PaginaControlState, REEMPLAZA ESTA FUNCIÓN COMPLETA:

  List<MenuItemModel> _buildSaldoAFavorSubMenuItems(
  BuildContext context,
  Pago pago,
  List<Pago> allPagos,
  bool isDarkMode,
  double saldoFavorTotalAcumulado,
) {
  final List<MenuItemModel> items = [];
  final double montoAPagar = pago.saldoEnContra ?? 0.0;
  final double favorYaUtilizado = pago.favorUtilizado;

  // --- Header e Información (sin cambios) ---
  items.add(MenuInfoItem(
      child: Transform.translate(
    offset: const Offset(0, -8.0),
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF3F51B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                Icon(Icons.savings_outlined, color: Colors.white, size: 18),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Gestionar Saldo a Favor",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  )));

  items.add(MenuInfoItem(
    child: _buildInfoRowInteligente(
      Icons.account_balance_wallet_outlined,
      "Saldo Total Disponible",
      "\$${formatearNumero(saldoFavorTotalAcumulado)}",
      isDarkMode,
      isAmount: true,
      iconColor: Color(0xFF00C853),
      iconBackgroundColor: Color(0xFF00C853).withOpacity(0.1),
    ),
  ));

  if (favorYaUtilizado > 0) {
    items.add(MenuInfoItem(
      child: _buildInfoRowInteligente(
        Icons.check_circle_outline,
        "Saldo a favor ya aplicado",
        "\$${formatearNumero(favorYaUtilizado)}",
        isDarkMode,
        isAmount: true,
        iconColor: Color(0xFF3F51B5),
        iconBackgroundColor: Color(0xFF3F51B5).withOpacity(0.1),
      ),
    ));
  }

  if (montoAPagar > 0 && !pago.estaFinalizado) {
    items.add(MenuInfoItem(
      child: _buildInfoRowInteligente(
        Icons.warning_amber_rounded,
        "Deuda restante en este pago",
        "\$${formatearNumero(montoAPagar)}",
        isDarkMode,
        isAmount: true,
        iconColor: Color(0xFFFFA000),
        iconBackgroundColor: Color(0xFFFFA000).withOpacity(0.1),
      ),
    ));
  }

  items.add(MenuInfoItem(child: Divider(height: 12)));

  if (!pago.estaFinalizado &&
      (widget.tipoUsuario == 'Admin' || widget.tipoUsuario == 'Asistente') &&
      _puedeEditarPago(pago)) {
    final bool tieneActividadGuardadaEnServidor =
        (pago.sumaDepositoMoratorisos ?? 0.0) > 0.0;
    final bool puedeCubrirPagoCompleto =
        saldoFavorTotalAcumulado >= montoAPagar && montoAPagar > 0.01;

     // ESCENARIO 1: Cubrir pago completo
    if (puedeCubrirPagoCompleto && !tieneActividadGuardadaEnServidor) {
      items.add(
        MenuCustomItem(
          builder: (popupContext) {
            return StatefulBuilder(
              builder: (context, setStateInPopup) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSaving
                          ? SizedBox.shrink()
                          : Icon(Icons.check_circle_outline,
                              size: 14, color: Colors.white),
                      label: _isSaving
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Text(
                              "Cubrir pago completo con saldo",
                              style: TextStyle(fontSize: 12),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        disabledBackgroundColor:
                            Color(0xFF00C853).withOpacity(0.5),
                      ),
                      // ==========================================================
                      // <<< INICIO DEL CAMBIO CLAVE 1 >>>
                      // ==========================================================
                      onPressed: _isSaving
                          ? null
                          : () async {
                              setStateInPopup(() {
                                _isSaving = true;
                              });
                              try {
                                await _aplicarSaldoAFavor(popupContext, pago, montoAPagar);
                              } finally {
                                // Se ejecuta siempre, incluso si hay un error
                                if (mounted) {
                                  setStateInPopup(() {
                                    _isSaving = false;
                                  });
                                }
                              }
                            },
                      // ==========================================================
                      // <<< FIN DEL CAMBIO CLAVE 1 >>>
                      // ==========================================================
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }
     // ESCENARIO 2: Aplicar monto parcial
    else if (tieneActividadGuardadaEnServidor &&
        montoAPagar > 0.01 &&
        saldoFavorTotalAcumulado > 0.01) {
      items.add(
        MenuCustomItem(
          builder: (popupContext) {
            final montoController = TextEditingController();
            final montoAAplicarNotifier = ValueNotifier<double>(0.0);
            final double montoMaximoAplicable =
                min(montoAPagar, saldoFavorTotalAcumulado);

            if (montoMaximoAplicable > 0) {
              montoController.text = montoMaximoAplicable.toStringAsFixed(2);
              montoAAplicarNotifier.value = montoMaximoAplicable;
            }

            return StatefulBuilder(
              builder: (context, setStateInPopup) {
                return ValueListenableBuilder<double>(
                  valueListenable: montoAAplicarNotifier,
                  builder: (context, montoActual, child) {
                    final bool puedeAplicar = montoActual > 0.01 && !_isSaving;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Monto a Utilizar:",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black87)),
                          SizedBox(height: 8),
                          TextField(
                            controller: montoController,
                            autofocus: true,
                            enabled: !_isSaving, // Deshabilita el campo al cargar
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                                fontSize: 14,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                                prefixText: '\$ ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 12.0, horizontal: 12.0),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade400)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color(0xFF3F51B5), width: 2),
                                    borderRadius: BorderRadius.circular(8)),
                                hintText:
                                    "Máx: \$${formatearNumero(montoMaximoAplicable)}",
                                hintStyle: TextStyle(
                                    fontWeight: FontWeight.normal, fontSize: 12)),
                            onChanged: (value) {
                              double nuevoMonto =
                                  double.tryParse(value.replaceAll(",", "")) ?? 0.0;
                              if (nuevoMonto > montoMaximoAplicable) {
                                nuevoMonto = montoMaximoAplicable;
                                final formattedValue =
                                    nuevoMonto.toStringAsFixed(2);
                                montoController.text = formattedValue;
                                montoController.selection =
                                    TextSelection.fromPosition(TextPosition(
                                        offset: formattedValue.length));
                              }
                              montoAAplicarNotifier.value = nuevoMonto;
                            },
                          ),
                           SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: _isSaving
                                  ? SizedBox.shrink()
                                  : Icon(Icons.download_done_rounded,
                                      size: 18, color: Colors.white),
                              label: _isSaving
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5, color: Colors.white))
                                  : Text("Aplicar Monto"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3F51B5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                disabledBackgroundColor:
                                    Color(0xFF3F51B5).withOpacity(0.5),
                                disabledForegroundColor:
                                    Colors.white.withOpacity(0.7),
                              ),
                              // ==========================================================
                              // <<< INICIO DEL CAMBIO CLAVE 2 >>>
                              // ==========================================================
                              onPressed: puedeAplicar
                                  ? () async {
                                      setStateInPopup(() {
                                        _isSaving = true;
                                      });
                                      try {
                                        await _aplicarSaldoAFavor(
                                            popupContext,
                                            pago,
                                            montoAAplicarNotifier.value);
                                      } finally {
                                        if (mounted) {
                                          setStateInPopup(() {
                                            _isSaving = false;
                                          });
                                        }
                                      }
                                    }
                                  : null,
                              // ==========================================================
                              // <<< FIN DEL CAMBIO CLAVE 2 >>>
                              // ==========================================================
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      );
    }
      // --- ESCENARIO 3: "MENSAJE DE ADVERTENCIA" ---
      // Si no se cumplen los escenarios anteriores, y hay saldo, mostramos el mensaje.
      else {
        if (!tieneActividadGuardadaEnServidor && saldoFavorTotalAcumulado > 0) {
          items.add(MenuInfoItem(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDarkMode
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.blue.shade200,
                    width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: isDarkMode
                          ? Colors.blue.shade300
                          : Colors.blue.shade700,
                      size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Guarde primero un abono para usar el saldo a favor.",
                      style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.blue.shade200
                              : Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                          height: 1.3),
                    ),
                  )
                ],
              ),
            ),
          ));
        }
      }
    }
    // Si el pago está finalizado, no hay cambios.
    else if (pago.estaFinalizado) {
      items.add(MenuInfoItem(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.green.withOpacity(0.1)
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDarkMode
                    ? Colors.green.withOpacity(0.3)
                    : Colors.green.shade200,
                width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_outlined,
                  color: isDarkMode
                      ? Colors.green.shade300
                      : Colors.green.shade700,
                  size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Este pago ya está liquidado.",
                  style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.green.shade200
                          : Colors.green.shade800,
                      fontWeight: FontWeight.w500),
                ),
              )
            ],
          ),
        ),
      ));
    }

    return items;
  }

// ==========================================================
// ===== WIDGETS HELPER ACTUALIZADOS ========================
// ==========================================================

  /// Construye el campo de texto editable.
  /// AHORA ACEPTA CONTEXT PARA MANEJAR EL FOCO.
// EN TU CLASE _PaginaControlState, REEMPLAZA ESTA FUNCIÓN:

  /// Construye el campo de texto editable.
  /// AHORA GUARDA AL PERDER EL FOCO (HACER CLIC FUERA).
  Widget _buildEditableField(
      BuildContext context,
      String clientId,
      double montoFinal,
      Map<String, TextEditingController> controllers,
      ValueNotifier<String?> currentlyEditingNotifier,
      ValueNotifier<Map<String, double>> montosNotifier,
      bool isDarkMode) {
    // Configuración del controlador (sin cambios)
    final controller = controllers.putIfAbsent(
      clientId,
      () => TextEditingController(text: montoFinal.toStringAsFixed(2)),
    );
    controller.text = montoFinal.toStringAsFixed(2);
    controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length));

    // --- Lógica de guardado encapsulada para ser reutilizada ---
    void saveAndCloseEditor() {
      // Si el widget ya no está montado, no hacemos nada.
      if (!context.mounted) return;

      final double? newAmount =
          double.tryParse(controller.text.replaceAll(",", ""));
      if (newAmount != null) {
        final currentMontos = Map<String, double>.from(montosNotifier.value);
        currentMontos[clientId] = newAmount;
        montosNotifier.value = currentMontos;
      }
      // Cerramos el modo de edición.
      currentlyEditingNotifier.value = null;
    }

    return Focus(
      // --- LÓGICA CLAVE: Detectar la pérdida de foco ---
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          // Si el TextField pierde el foco, guardamos y cerramos el editor.
          saveAndCloseEditor();
        }
      },
      // Manejo de la tecla "Escape" para cancelar la edición (sin cambios)
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is RawKeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          currentlyEditingNotifier.value = null;
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: controller,
        autofocus: true,
        textAlign: TextAlign.right,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          prefixText: '\$',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF3F51B5), width: 2),
              borderRadius: BorderRadius.circular(6)),
        ),
        // Al presionar "Enter", también guardamos y cerramos.
        onSubmitted: (_) => saveAndCloseEditor(),
      ),
    );
  }

  /// Construye el widget de texto estático que se muestra por defecto.
  /// (Este widget no necesita cambios).
  Widget _buildStaticText(
      String clientId,
      double montoFinal,
      double montoOriginal,
      double descuentoAplicado,
      ValueNotifier<String?> currentlyEditingNotifier,
      bool yaEstaGuardado,
      bool isDarkMode) {
    return GestureDetector(
      onTap: yaEstaGuardado
          ? null
          : () {
              currentlyEditingNotifier.value = clientId;
            },
      child: Container(
        alignment: Alignment.centerRight,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (descuentoAplicado.abs() > 0.01)
              Text(
                '\$${formatearNumero(montoOriginal)}',
                style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                    decoration: TextDecoration.lineThrough),
              ),
            Text(
              '\$${formatearNumero(montoFinal)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

// Widget helper mejorado para las filas de información
  Widget _buildInfoRowInteligente(
    IconData icon,
    String label,
    String value,
    bool isDarkMode, {
    bool isAmount = false,
    // --- PARÁMETROS AÑADIDOS ---
    // Hacemos que los colores del icono sean configurables.
    // Son opcionales, por lo que el widget puede seguir usándose como antes.
    Color? iconColor,
    Color? iconBackgroundColor,
  }) {
    // --- LÓGICA DE COLORES ---
    // Si no se proporciona un color específico, usamos el azul/púrpura por defecto.
    // Esto mantiene el comportamiento original pero nos da el control para anular la opacidad del menú.
    final Color finalIconColor = iconColor ?? const Color(0xFF5162F6);
    final Color finalIconBackgroundColor = iconBackgroundColor ??
        finalIconColor.withOpacity(isAmount ? 0.15 : 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isAmount
            ? const Color(0xFF5162F6).withOpacity(0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // --- WIDGET DEL ICONO CORREGIDO ---
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // Usamos el color de fondo que definimos, que no será afectado por la opacidad del menú.
              color: finalIconBackgroundColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              // Usamos el color del icono que definimos, que se mostrará vibrante.
              color: finalIconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Container(
            padding: isAmount
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isAmount
                  ? const Color(0xFF5162F6).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: isAmount ? 13 : 12,
                fontWeight: isAmount ? FontWeight.bold : FontWeight.w600,
                color: isAmount
                    ? const Color(0xFF5162F6)
                    : (isDarkMode ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nuevo método auxiliar
  // En la clase _PaginaControlState

// En la clase _PaginaControlState

// En la clase _PaginaControlState

// En _PaginaControlState -> _recalcularSaldos

// En la clase _PaginaControlState

  // EN TU CLASE _PaginaControlState, REEMPLAZA LA FUNCIÓN ANTIGUA CON ESTA:

// EN TU CLASE _PaginaControlState, REEMPLAZA LA FUNCIÓN OTRA VEZ CON ESTA VERSIÓN MEJORADA:

  void _recalcularSaldos(Pago pago) {
    // 1. Calcular abonos en efectivo (pagos que NO son de garantía).
    double abonosEnEfectivo = pago.abonos
        .where((abono) => abono['garantia'] != 'Si')
        .fold(0.0, (total, abono) => total + (abono['deposito'] ?? 0.0));

    // 2. Calcular el monto pagado específicamente con la garantía.
    double abonosConGarantia = pago.abonos
        .where((abono) => abono['garantia'] == 'Si')
        .fold(0.0, (total, abono) => total + (abono['deposito'] ?? 0.0));

    // 3. Calcular lo cubierto por renovación pendiente.
    double cubiertoPorRenovacion = pago.renovacionesPendientes.fold(
        0.0, (total, renovacion) => total + (renovacion.descuento ?? 0.0));
    if (pago.renovacionesPendientes.isNotEmpty) {
      cubiertoPorRenovacion = cubiertoPorRenovacion.roundToDouble();
    }

    // 4. Calcular la deuda total de la semana.
    double totalDeudaSemana = pago.capitalMasInteres ?? 0.0;
    if (pago.moratorioDesabilitado != "Si") {
      totalDeudaSemana += pago.moratorios?.moratorios ?? 0.0;
    }

    // 5. Ajustar la deuda con el descuento del remanente de garantía del pago anterior (si aplica).
    double deudaAjustada =
        totalDeudaSemana - (pago.descuentoGarantiaAplicado ?? 0.0);

    // ---- INICIO DE LA LÓGICA DE CÁLCULO DE SALDOS CORREGIDA ----

    // a. Para calcular si AÚN SE DEBE DINERO (Saldo en Contra), consideramos TODOS los pagos.
    //    Esto determina si la deuda de la semana fue cubierta, sin importar cómo.
    double montoTotalPagado =
        abonosEnEfectivo + abonosConGarantia + cubiertoPorRenovacion;
    double saldoContraCalculado = deudaAjustada - montoTotalPagado;
    pago.saldoEnContra = max(0, saldoContraCalculado);

    // b. Para calcular si SOBRÓ DINERO A FAVOR DEL CLIENTE (Saldo a Favor),
    //    NO consideramos el sobrepago de la garantía. Un "saldo a favor" real
    //    solo puede venir de un sobrepago en efectivo o por renovación.
    double montoParaSaldoFavor = abonosEnEfectivo + cubiertoPorRenovacion;
    double saldoFavorCalculado = montoParaSaldoFavor - deudaAjustada;
    pago.saldoFavor = max(0, saldoFavorCalculado);

    // ---- FIN DE LA LÓGICA DE CÁLCULO DE SALDOS CORREGIDA ----
  }

  // Método auxiliar para construir items del popup
  Widget _buildPopupItem(String title, String value,
      {TextStyle? extraStyle, bool isApplied = false}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: isApplied
                  ? (isDarkMode ? Colors.green[300] : Colors.green[800])
                  : (isDarkMode ? Colors.white : Colors.black),
              fontWeight: isApplied ? FontWeight.bold : FontWeight.bold,
            ).merge(extraStyle),
          ),
        ],
      ),
    );
  }

  // 1. Este es el método para editar la fecha
  void _editarFechaPago(BuildContext context, Pago pago) async {
    // 1. Detectar si el modo oscuro está activo
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    DateTime initialDate = DateTime.now();
    DateTime lastDate = DateTime.now();

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
        // 2. Usar el Theme.of(context).copyWith para heredar estilos
        // y sobreescribir solo el colorScheme.
        return Theme(
          data: Theme.of(context).copyWith(
            // 3. Aplicar el ColorScheme correcto basado en isDarkMode
            colorScheme: isDarkMode
                ? ColorScheme.dark(
                    primary: Color(
                        0xFF5162F6), // Color principal (header, día seleccionado)
                    onPrimary:
                        Colors.white, // Color del texto sobre el primario
                    surface: Color(0xFF303030), // Fondo del calendario
                    onSurface: Colors.white, // Color del texto de los días
                  )
                : ColorScheme.light(
                    primary: Color(0xFF5162F6), // Color principal
                    onPrimary: Colors.white, // Texto sobre el primario
                    // Los demás colores se heredan del tema claro por defecto.
                  ),
            // Opcional: Estilizar los botones de OK/CANCELAR
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode
                    ? Colors.white
                    : Color(0xFF5162F6), // Color del texto de los botones
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada != null) {
      setState(() {
        pago.fechaPagoCompleto =
            fechaSeleccionada.toIso8601String().split('T')[0];

        if (pago.fechaPago.isEmpty) {
          pago.fechaPago = DateTime.now().toString();
        }

        Provider.of<PagosProvider>(context, listen: false)
            .actualizarPago(pago.toPagoSeleccionado());
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
                    fontSize: 13,
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
  String? idfechaspagos;
  String? idpagosdetalles;
  String? idpagos;
  //double totalFavorUtilizado;
  double? sumaDepositosFavor;
  double? sumaDepositoMoratorisos;
  Moratorios? moratorios;
  List<Map<String, dynamic>> pagosMoratorios;
  String moratorioDesabilitado;
  List<RenovacionPendiente> renovacionesPendientes;
  bool estaFinalizado = false;
  double descuentoGarantiaAplicado = 0.0;
  double montoDeSaldoAplicado;
  double? saldoFavorTotalOriginal;
  bool fueLiquidadoConSaldo;
  double saldoFavorInicial;
  double saldoFavorOriginalGenerado;
  bool fueUtilizadoPorServidor;
  double? saldoRestante;
  double favorUtilizado; 

  Pago({
    required this.semana,
    required this.fechaPago,
    required this.capital,
    required this.interes,
    required this.capitalMasInteres,
    required this.idpagos,
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
    this.idfechaspagos,
    this.idpagosdetalles,
    //required this.totalFavorUtilizado,
    this.sumaDepositosFavor,
    this.sumaDepositoMoratorisos,
    this.moratorios,
    required this.pagosMoratorios,
    required this.moratorioDesabilitado,
    required this.renovacionesPendientes,
    this.montoDeSaldoAplicado = 0.0,
    this.saldoFavorTotalOriginal,
    this.fueLiquidadoConSaldo = false,
    this.saldoFavorInicial = 0.0,
    required this.saldoFavorOriginalGenerado,
    required this.fueUtilizadoPorServidor,
    this.saldoRestante,
    required this.favorUtilizado,
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    // --- Lógica para extraer el idpagos del primer abono (si existe) ---
    final List<dynamic>? pagosList = json['pagos'] as List?;
    final String idPagoPrincipal = (pagosList != null && pagosList.isNotEmpty)
        ? pagosList[0]['idpagos'] ?? ''
        : '';
    // -------------------------------------------------------------------

    List<String?> fechasDepositos = [];
    if (pagosList != null) {
      for (var pago in pagosList) {
        fechasDepositos.add(pago['fechaDeposito']);
      }
    }

    List<Map<String, dynamic>> pagosMoratorios =
        (json['pagosMoratorios'] as List?)
                ?.map((moratorio) => Map<String, dynamic>.from(moratorio))
                .toList() ??
            [];

    List<RenovacionPendiente> pendientes = [];
    if (json['RenovacionPendientes'] != null) {
      if (json['RenovacionPendientes'] is List) {
        pendientes = (json['RenovacionPendientes'] as List)
            .map((i) => RenovacionPendiente.fromJson(i))
            .toList();
      } else if (json['RenovacionPendientes'] is Map) {
        pendientes
            .add(RenovacionPendiente.fromJson(json['RenovacionPendientes']));
      }
    }

    /* double favorUtilizadoSuma = 0.0;
    if (json['pagos'] is List) {
      for (var abono in json['pagos']) {
        if (abono['favorUtilizado'] is num) {
          favorUtilizadoSuma += (abono['favorUtilizado'] as num).toDouble();
        }
      }
    } */

    return Pago(
      semana: json['semana'] ?? 0,
      fechaPago: json['fechaPago'] ?? '',
      capital: (json['capital'] as num?)?.toDouble() ?? 0.0,
      interes: (json['interes'] as num?)?.toDouble() ?? 0.0,
      capitalMasInteres: (json['capitalMasInteres'] as num?)?.toDouble() ?? 0.0,

      // --- Usamos la variable que calculamos al principio ---
      idpagos: idPagoPrincipal,
      // ------------------------------------------------------

      sumaDepositosFavor: json['sumaDepositosFavor'] != null
          ? double.tryParse(json['sumaDepositosFavor'].toString())
          : null,
      sumaDepositoMoratorisos: json['sumaDepositoMoratorisos'] != null
          ? double.tryParse(json['sumaDepositoMoratorisos'].toString())
          : null,
      saldoEnContra: json['saldoEnContra'] != null
          ? double.tryParse(json['saldoEnContra'].toString())
          : null,
      restanteTotal: (json['restanteTotal'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado'] ?? '',
      deposito: (json['pagos'] as List?)?.isNotEmpty ?? false
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
      idfechaspagos: json['idfechaspagos'],
      idpagosdetalles: json['idpagosdetalles'],
      moratorios: json['moratorios'] is Map<String, dynamic>
          ? Moratorios.fromJson(Map<String, dynamic>.from(json['moratorios']))
          : null,
      pagosMoratorios: pagosMoratorios,
      moratorioDesabilitado: json['moratorioDesabilitado'] ?? "No",
      renovacionesPendientes: pendientes,
      saldoFavorInicial: 0.0,
      //totalFavorUtilizado: favorUtilizadoSuma,
            // <-- CAMBIO 3: Leer el valor directamente del JSON
      favorUtilizado: (json['favorUtilizado'] as num?)?.toDouble() ?? 0.0,

      saldoFavorOriginalGenerado:
          (json['saldoFavor'] as num?)?.toDouble() ?? 0.0,
      fueUtilizadoPorServidor: json['saldoFavorUtilizado'] == 'Si',
      saldoFavor: json['saldoFavor'] != null
          ? double.tryParse(json['saldoFavor'].toString())
          : null,
      saldoRestante: json['saldoRestante'] != null
          ? double.tryParse(json['saldoRestante'].toString())
          : null,
    );
  }

  PagoSeleccionado toPagoSeleccionado() {
    return PagoSeleccionado(
      semana: semana,
      tipoPago: tipoPago,
      deposito: deposito ?? 0.00,
      fechaPago: this.fechaPagoCompleto.isNotEmpty
          ? this.fechaPagoCompleto
          : this.fechaPago,
      idfechaspagos: idfechaspagos ?? '',
      capitalMasInteres: capitalMasInteres,
      moratorio: moratorios?.moratorios,
      saldoFavor: saldoFavor,
      saldoEnContra: saldoEnContra,
      abonos: abonos,
      moratorioDesabilitado: this.moratorioDesabilitado,
      pagosMoratorios: pagosMoratorios,
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
  final String moratorioDesabilitado; // <-- Nuevo parámetro
  final double? moratorios; // <-- Nuevo parámetro

  AbonosDialog({
    required this.montoAPagar,
    required this.onConfirm,
    required this.moratorioDesabilitado, // <-- Añade esto
    this.moratorios, // <-- Añade esto
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

    // 1. Añade estas variables al inicio del build (para acceder a los parámetros del widget)
    String moratorioDesabilitado = widget.moratorioDesabilitado;
    double? moratorios = widget.moratorios;

// 2. Calcula si el botón debe estar habilitado
    bool isDateButtonEnabled =
        (moratorioDesabilitado == "Si" || (moratorios ?? 0) == 0);

    String _formatearFecha(dynamic fecha) {
      try {
        if (fecha is String) {
          final parsedDate = DateTime.parse(fecha);
          return DateFormat('dd/MM/yyyy').format(parsedDate);
        }
        return 'Fecha inválida';
      } catch (e) {
        return 'Fecha inválida';
      }
    }

    // Colores adaptados según el modo
    final Color primaryColor = Color(0xFF5162F6);
    final Color? backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final Color cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.grey[50]!;
    final Color textColor = isDarkMode ? Colors.white : Colors.grey[800]!;
    final Color labelColor = isDarkMode ? Colors.grey[300]! : Colors.grey[800]!;
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
                            fontSize: 13,
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
                                    : Colors.grey[700]),
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
                          style: TextStyle(fontSize: 13, color: textColor),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: // 3. Modifica el InkWell y su contenido:
                                  InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: isDateButtonEnabled
                                    ? () async {
                                        // Solo permite tocar si está habilitado
                                        DateTime? pickedDate =
                                            await showDatePicker(
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
                                                dialogBackgroundColor:
                                                    isDarkMode
                                                        ? Color(0xFF1E1E1E)
                                                        : Colors.white,
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (pickedDate != null &&
                                            pickedDate != fechaPago) {
                                          setState(
                                              () => fechaPago = pickedDate);
                                        }
                                      }
                                    : null, // Deshabilita el onTap si no cumple las condiciones
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: isDateButtonEnabled
                                        ? inputBackground
                                        : inputBackground.withOpacity(
                                            0.5), // Fondo más claro si está deshabilitado
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDateButtonEnabled
                                          ? (isDarkMode
                                              ? inputBorderColor
                                              : Color(0xFFAAAAAA))
                                          : Colors
                                              .transparent, // Borde transparente si está deshabilitado
                                      width: isDarkMode ? 1.2 : 1.5,
                                    ),
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
                                        DateFormat('dd/MM/yyyy').format(
                                            fechaPago), // Formato dd-MM-yyyy
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDateButtonEnabled
                                              ? textColor
                                              : textColor.withOpacity(0.5),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_today,
                                        color: isDateButtonEnabled
                                            ? primaryColor
                                            : primaryColor.withOpacity(
                                                0.5), // Ícono atenuado
                                      ),
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
                                    fontSize: 13, color: Colors.white),
                              ),
                              onPressed: () {
                                if (montoPorAbono > 0.0) {
                                  setState(() {
                                    abonos.add({
                                      'deposito': montoPorAbono,
                                      // CAMBIA ESTA LÍNEA: Usar formato ISO en lugar de dd/MM/yyyy
                                      'fechaDeposito': fechaPago
                                          .toIso8601String(), // Formato correcto para DateTime.parse
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
                    fontSize: 13,
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
                            "Monto: \$${abonos[index]['deposito']} - Fecha: ${_formatearFecha(abonos[index]['fechaDeposito'])}",
                            style: TextStyle(
                              fontSize: 11,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(width: 100),
                  /* Text(
                    "Monto a Pagar: \$${widget.montoAPagar.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    "Falta: \$${montoFaltante.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 13,
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
                      style: TextStyle(fontSize: 13, color: Colors.white),
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
                      style: TextStyle(fontSize: 13, color: Colors.white),
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
class PaginaIntegrantes extends StatefulWidget {
  final List<ClienteMonto> clientesMontosInd;
  final String tipoPlazo;
  final double pagoCuota;
  final int plazo;
  final String garantia;
  final String idgrupo; // <--- NUEVO: Necesitamos el ID del grupo

  const PaginaIntegrantes({
    Key? key,
    required this.clientesMontosInd,
    required this.tipoPlazo,
    required this.pagoCuota,
    required this.plazo,
    required this.garantia,
    required this.idgrupo, // <--- NUEVO
  }) : super(key: key);

  @override
  _PaginaIntegrantesState createState() => _PaginaIntegrantesState();
}

class _PaginaIntegrantesState extends State<PaginaIntegrantes> {
  // <--- NUEVO: Variables de estado para manejar la carga de descuentos --->
  bool _cargandoDescuentos = true;
  String? _errorDescuentos;
  Map<String, double> _descuentosRenovacion = {};

  @override
  void initState() {
    super.initState();
    // <--- NUEVO: Hacemos la llamada a la API al iniciar el widget --->
    _fetchDescuentosRenovacion();
  }

  // <--- NUEVO: La función para obtener los descuentos (adaptada de tu otra pantalla) --->
  Future<void> _fetchDescuentosRenovacion() async {
    setState(() {
      _cargandoDescuentos = true;
      _errorDescuentos = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final url = Uri.parse(
          '$baseUrl/api/v1/grupodetalles/renovacion/${widget.idgrupo}');

      final response = await http.get(url, headers: {'tokenauth': token});

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final Map<String, double> descuentosObtenidos = {};
        for (var item in data) {
          // <<< ¡AQUÍ ESTÁ LA LÓGICA CLAVE! >>>
          // Comparamos el ID del grupo actual con el ID del grupo que viene en los datos de renovación.
          if (item['idclientes'] != null &&
              item['descuento'] != null &&
              widget.idgrupo != item['idgrupos']) {
            // <-- NUEVA CONDICIÓN
            descuentosObtenidos[item['idclientes']] =
                (item['descuento'] as num).toDouble();
          }
        }
        if (mounted) {
          setState(() {
            _descuentosRenovacion = descuentosObtenidos;
            _cargandoDescuentos = false;
          });
        }
      } else if (response.statusCode == 404) {
        // No es un error, simplemente no hay descuentos para este grupo.
        if (mounted) {
          setState(() {
            _cargandoDescuentos = false;
          });
        }
      } else {
        throw Exception('Error al cargar descuentos: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorDescuentos = 'No se pudieron cargar los descuentos.';
          _cargandoDescuentos = false;
        });
      }
    }
  }

  String formatearNumero(double numero) {
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numero);
  }

  // <--- NUEVO: Helper para crear las filas del desglose en el tooltip --->
  Widget _buildDesgloseRow(String label, String value, bool isDarkMode,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDescuentos) {
      return Center(child: CircularProgressIndicator());
    }
    if (_errorDescuentos != null) {
      return Center(
          child: Text(_errorDescuentos!, style: TextStyle(color: Colors.red)));
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    const headerTextStyle = TextStyle(
        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13);
    final contentTextStyle = TextStyle(
        fontSize: 11, color: isDarkMode ? Colors.white : Colors.black87);
    const totalRowTextStyle = TextStyle(
        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13);

    Widget _buildHeaderCell(String text) => Expanded(
        child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(text,
                style: headerTextStyle, textAlign: TextAlign.center)));
    Widget _buildDataCell(Widget child) => Expanded(
        child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: child)); // Modificado para aceptar Widget
    Widget _buildTotalCell(String text) => Expanded(
        child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(text,
                style: totalRowTextStyle, textAlign: TextAlign.center)));

    const totalRowColor = Color(0xFF5162F6);
    final pagoColumnText =
        widget.tipoPlazo == 'Semanal' ? 'Pago Sem.' : 'Pago Qna.';
    final capitalColumnText =
        widget.tipoPlazo == 'Semanal' ? 'Capital Sem.' : 'Capital Qna.';
    final interesColumnText =
        widget.tipoPlazo == 'Semanal' ? 'Interés Sem.' : 'Interés Qna.';

    final garantiaPorcentaje =
        double.tryParse(widget.garantia.replaceAll('%', '').trim()) ?? 0.0;

    double sumCapitalIndividual = 0;
    double sumMontoDesembolsado = 0;
    // ... otras sumatorias
    double sumPeriodoCapital = 0;
    double sumPeriodoInteres = 0;
    double sumTotalCapital = 0;
    double sumTotalIntereses = 0;
    double sumCapitalMasInteres = 0;
    double sumTotal = 0;

    for (var cliente in widget.clientesMontosInd) {
      final descuentoDirecto = _descuentosRenovacion[cliente.idclientes] ?? 0.0;
      final garantiaIndividual =
          cliente.capitalIndividual * (garantiaPorcentaje / 100);
      final montoDesembolsadoIndividual =
          cliente.capitalIndividual - descuentoDirecto - garantiaIndividual;

      sumCapitalIndividual += cliente.capitalIndividual;
      sumMontoDesembolsado += montoDesembolsadoIndividual;
      // ... sumar el resto
      sumPeriodoCapital += cliente.periodoCapital;
      sumPeriodoInteres += cliente.periodoInteres;
      sumTotalCapital += cliente.totalCapital;
      sumTotalIntereses += cliente.totalIntereses;
      sumCapitalMasInteres += cliente.capitalMasInteres;
      sumTotal += cliente.total;
    }

    final sumTotalRedondeado = widget.pagoCuota * widget.plazo;

    return Container(
      // ... (el resto del Container y LayoutBuilder se mantiene igual)
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double tableWidth = constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Container(
                width: tableWidth,
                child: Column(
                  children: [
                    Container(
                      // ... (encabezado sin cambios)
                      height: 50,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Color(0xFF5162F6)),
                      child: Row(
                        children: [
                          _buildHeaderCell("Nombre"),
                          _buildHeaderCell("Autorizado"),
                          _buildHeaderCell("Desembolsado"),
                          _buildHeaderCell(capitalColumnText),
                          _buildHeaderCell(interesColumnText),
                          _buildHeaderCell("Total Capital"),
                          _buildHeaderCell("Total Interes"),
                          _buildHeaderCell(pagoColumnText),
                          _buildHeaderCell("Pago Total"),
                        ],
                      ),
                    ),
                    for (var cliente in widget.clientesMontosInd)
                      () {
                        final descuentoDirecto =
                            _descuentosRenovacion[cliente.idclientes] ?? 0.0;
                        final garantiaIndividual = cliente.capitalIndividual *
                            (garantiaPorcentaje / 100);
                        final montoDesembolsadoIndividual =
                            cliente.capitalIndividual -
                                descuentoDirecto -
                                garantiaIndividual;
                        final bool tieneDescuento = descuentoDirecto > 0;

                        final estiloDesembolso = TextStyle(
                            fontSize: 11,
                            color: tieneDescuento
                                ? (isDarkMode
                                    ? Colors.greenAccent[400]
                                    : Colors.green[800])
                                : (isDarkMode ? Colors.white : Colors.black87),
                            fontWeight: tieneDescuento
                                ? FontWeight.bold
                                : FontWeight.normal);

                        return Row(
                          children: [
                            _buildDataCell(Text(cliente.nombreCompleto,
                                style: contentTextStyle,
                                textAlign: TextAlign.center)),
                            _buildDataCell(Text(
                                "\$${formatearNumero(cliente.capitalIndividual)}",
                                style: contentTextStyle,
                                textAlign: TextAlign.center)),

                            // <--- CELDA MODIFICADA CON TEXTO E ÍCONO/TOOLTIP CONDICIONAL --->
                            _buildDataCell(Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    "\$${formatearNumero(montoDesembolsadoIndividual)}",
                                    style: estiloDesembolso,
                                    textAlign: TextAlign.center),
                                // El ícono solo aparece si hay descuento
                                if (tieneDescuento)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Tooltip(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Colors.grey[800]
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 5,
                                                offset: Offset(0, 2))
                                          ]),
                                      richMessage: WidgetSpan(
                                          child: ConstrainedBox(
                                        constraints:
                                            BoxConstraints(maxWidth: 220),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text("Desglose del Desembolso",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black)),
                                            Divider(
                                                color: isDarkMode
                                                    ? Colors.white30
                                                    : Colors.black26,
                                                height: 15),
                                            _buildDesgloseRow(
                                                "Monto Autorizado",
                                                "\$${formatearNumero(cliente.capitalIndividual)}",
                                                isDarkMode),
                                            _buildDesgloseRow(
                                                "(-) Garantía",
                                                "-\$${formatearNumero(garantiaIndividual)}",
                                                isDarkMode),
                                            _buildDesgloseRow(
                                                "(-) Descuento Renov.",
                                                "-\$${formatearNumero(descuentoDirecto)}",
                                                isDarkMode),
                                            Divider(
                                                color: isDarkMode
                                                    ? Colors.white30
                                                    : Colors.black26,
                                                height: 10),
                                            _buildDesgloseRow(
                                                "(=) Total a Recibir",
                                                "\$${formatearNumero(montoDesembolsadoIndividual)}",
                                                isDarkMode,
                                                isTotal: true),
                                          ],
                                        ),
                                      )),
                                      child: Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            )),

                            _buildDataCell(Text(
                                "\$${formatearNumero(cliente.periodoCapital)}",
                                style: contentTextStyle,
                                textAlign: TextAlign.center)),
                            _buildDataCell(Text(
                                "\$${formatearNumero(cliente.periodoInteres)}",
                                style: contentTextStyle,
                                textAlign: TextAlign.center)),
                            _buildDataCell(Text(
                                "\$${formatearNumero(cliente.totalCapital)}",
                                style: contentTextStyle,
                                textAlign: TextAlign.center)),
                            _buildDataCell(Text(
                                "\$${formatearNumero(cliente.totalIntereses)}",
                                style: contentTextStyle,
                                textAlign: TextAlign.center)),
                            _buildDataCell(Text(
                                "\$${formatearNumero(cliente.capitalMasInteres)}",
                                style: contentTextStyle,
                                textAlign: TextAlign.center)),
                            _buildDataCell(Text(
                                "\$${formatearNumero(cliente.total)}",
                                style: contentTextStyle,
                                textAlign: TextAlign.center)),
                          ],
                        );
                      }(),
                    Container(
                      // ... (fila de totales sin cambios)
                      height: 40,
                      decoration: BoxDecoration(
                        color: totalRowColor,
                        borderRadius: (widget.pagoCuota != sumCapitalMasInteres)
                            ? BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12))
                            : BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildTotalCell("Totales"),
                          _buildTotalCell(
                              "\$${formatearNumero(sumCapitalIndividual)}"),
                          _buildTotalCell(
                              "\$${formatearNumero(sumMontoDesembolsado)}"),
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
                    if (widget.pagoCuota != sumCapitalMasInteres)
                      Container(
                        // ... (fila de redondeo sin cambios)
                        height: 40,
                        margin: EdgeInsets.only(top: 0),
                        decoration: BoxDecoration(
                          color: totalRowColor,
                          borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            _buildTotalCell("Redondeado"),
                            _buildTotalCell(""),
                            _buildTotalCell(""),
                            _buildTotalCell(""),
                            _buildTotalCell(""),
                            _buildTotalCell(""),
                            _buildTotalCell(""),
                            _buildTotalCell(
                                "\$${formatearNumero(widget.pagoCuota)}"),
                            _buildTotalCell(
                                "\$${formatearNumero(sumTotalRedondeado)}"),
                          ],
                        ),
                      ),
                  ],
                ),
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
  final bool descargando;
  final Credito credito;

  const PaginaDescargables({
    Key? key,
    required this.tipo,
    required this.folio,
    this.descargando = false,
    required this.credito,
  }) : super(key: key);

  @override
  State<PaginaDescargables> createState() => _PaginaDescargablesState();
}

class _PaginaDescargablesState extends State<PaginaDescargables> {
  String? _documentoDescargando; // null, 'contrato', 'pagare' o 'control_pagos'
  bool dialogShown = false; // Controlar diálogos mostrados

  Future<void> _descargarDocumento(String documento) async {
    setState(() => _documentoDescargando = documento);

    bool dialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      // Verificar si el token está disponible
      if (token.isEmpty) {
        _handleError(
          dialogShown,
          'Token de autenticación no encontrado. Por favor, inicia sesión.',
          redirectToLogin: true,
        );
        return;
      }

      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/v1/formato/'
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
          // Asegurarnos de que la ruta termine en ".docx"
          String finalPath = savePath.toLowerCase().endsWith('.docx')
              ? savePath
              : '$savePath.docx';

          final file = File(finalPath);
          await file.writeAsBytes(response.bodyBytes);

          if (!mounted) return;
          await _abrirArchivoGuardado(finalPath);
        }
      } else {
        try {
          final errorData = json.decode(response.body);

          if (errorData["Error"] != null) {
            final mensajeError = errorData["Error"]["Message"];

            if (mensajeError == "La sesión ha cambiado. Cerrando sesión...") {
              await prefs.remove('tokenauth');

              if (!dialogShown) {
                dialogShown = true;
                mostrarDialogoCierreSesion(
                  'La sesión ha cambiado. Cerrando sesión...',
                  onClose: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false,
                    );
                  },
                );
              }
              return;
            } else if (mensajeError == "jwt expired") {
              await prefs.remove('tokenauth');

              if (!dialogShown) {
                dialogShown = true;
                _handleError(
                  dialogShown,
                  'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
                  redirectToLogin: true,
                );
              }
              return;
            }
          }
        } catch (e) {
          print('Error al procesar la respuesta: $e');
        }

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

  Future<void> _generarControlPagos() async {
    // Establecer estado de carga
    setState(() => _documentoDescargando = 'control_pagos');

    try {
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Control de Pagos',
        fileName: 'Control_Pagos_${widget.folio}.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      if (!mounted) return;

      if (savePath != null) {
        await PDFControlPagos.generar(context, widget.credito, savePath);
        if (!mounted) return;
        await _abrirArchivoGuardado(savePath);
      }
    } catch (e) {
      _mostrarError('Error al generar PDF: ${e.toString()}');
    } finally {
      // Limpiar estado de carga cuando termine (ya sea éxito o error)
      if (mounted) {
        setState(() => _documentoDescargando = null);
      }
    }
  }

  // --- NEW Method for Ficha de Pago Semanal PDF ---
  Future<void> _generarFichaPagoSemanal() async {
    setState(() => _documentoDescargando = 'ficha_pago');
    try {
      // Validate required data before proceeding
      if (widget.credito.pagoCuota == null) {
        _mostrarError(
            'Faltan datos necesarios en el crédito para generar la ficha de pago (monto semanal, titular o tarjeta).');
        setState(() => _documentoDescargando = null); // Reset loading state
        return;
      }

      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Ficha de Pago Semanal',
        fileName: 'Ficha_Pago_Semanal_${widget.folio}.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );
      if (!mounted || savePath == null) return;

      // Pass context and credito object to the new generator
      await PDFCuentasPago.generar(context, widget.credito, savePath);
      if (!mounted) return;
      await _abrirArchivoGuardado(savePath);
    } catch (e) {
      if (mounted)
        _mostrarError('Error al generar Ficha de Pago: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _documentoDescargando = null);
    }
  }

  Future<void> _generarResumenCredito() async {
    setState(() => _documentoDescargando = 'resumen_credito');

    try {
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Resumen de Crédito',
        fileName: 'Resumen_Credito_${widget.folio}.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      if (!mounted || savePath == null) return;

      await PDFResumenCredito.generar(context, widget.credito, savePath);
      if (!mounted) return;
      await _abrirArchivoGuardado(savePath);
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al generar Resumen de Crédito: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _documentoDescargando = null);
    }
  }

  void mostrarDialogoCierreSesion(String mensaje,
      {required Function() onClose}) {
    // Detectar si estamos en modo oscuro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          contentPadding: EdgeInsets.only(top: 25, bottom: 10),
          title: Column(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 60,
                color: Colors.red[700],
              ),
              SizedBox(height: 15),
              Text(
                'Sesión Finalizada',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          actionsPadding: EdgeInsets.only(bottom: 20, right: 25, left: 25),
          actions: [
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(double.infinity, 48), // Ancho completo
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onClose();
              },
              child: Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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
        title: SelectableText('Error', style: TextStyle(color: Colors.red)),
        content: SelectableText(mensaje),
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
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Container(
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
              fontSize: 13,
              fontWeight: FontWeight.w500,
            )),
        Expanded(
          child: Text(valor,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 13,
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
          documento: 'contrato',
          onTap: () => _descargarDocumento('contrato'),
        ),
        const SizedBox(height: 15),
        _buildBotonDescarga(
          titulo: 'Descargar Pagaré',
          icono: Icons.monetization_on_rounded,
          color: Colors.green[700]!,
          documento: 'pagare',
          onTap: () => _descargarDocumento('pagare'),
        ),
        const SizedBox(height: 15),
        _buildBotonDescarga(
          titulo: 'Descargar Control de Pagos',
          icono: Icons.table_chart,
          color: Colors.purple[700]!,
          documento: 'control_pagos',
          onTap: _generarControlPagos, // Usar la nueva función
        ),
        const SizedBox(height: 15), // Add space
        // --- NEW BUTTON ---
        _buildBotonDescarga(
          titulo: 'Descargar Ficha de Pago',
          icono: Icons.receipt_long, // Example icon
          color: Colors.orange[900]!, // Example color
          documento: 'ficha_pago', // Unique identifier for loading state
          onTap: _generarFichaPagoSemanal, // Link to the new function
        ),
        const SizedBox(height: 15),
        _buildBotonDescarga(
          titulo: 'Descargar Resumen de Crédito',
          icono: Icons.picture_as_pdf_rounded,
          color: Colors.teal[700]!,
          documento: 'resumen_credito',
          onTap: _generarResumenCredito,
        ),
      ],
    );
  }

  Widget _buildBotonDescarga({
    required String titulo,
    required IconData icono,
    required Color color,
    required String documento,
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
          child: _buildButtonContent(titulo, icono, estaDescargando),
        ),
      ),
    );
  }

  Widget _buildButtonContent(
      String titulo, IconData icono, bool estaDescargando) {
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
        // Aquí reemplazamos el icono de descarga con un indicador de carga cuando está descargando
        estaDescargando
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_rounded, color: Colors.white, size: 24),
      ],
    );
  }
}
