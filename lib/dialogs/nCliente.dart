import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class nClienteDialog extends StatefulWidget {
  final VoidCallback? onClienteAgregado; // Cambia a opcional
  final VoidCallback? onClienteEditado; // Cambia a opcional
  final String? idCliente; // Parámetro opcional para modo de edición

  nClienteDialog(
      {this.onClienteAgregado,
      this.onClienteEditado,
      this.idCliente}); // No requiere `required`

  @override
  _nClienteDialogState createState() => _nClienteDialogState();
}

class _nClienteDialogState extends State<nClienteDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController apellidoPController = TextEditingController();
  final TextEditingController nombresController = TextEditingController();
  final TextEditingController apellidoMController = TextEditingController();
  final TextEditingController calleController = TextEditingController();
  final TextEditingController entreCalleController = TextEditingController();
  final TextEditingController coloniaController = TextEditingController();
  final TextEditingController cpController = TextEditingController();
  final TextEditingController nExtController = TextEditingController();
  final TextEditingController nIntController = TextEditingController();
  final TextEditingController estadoController = TextEditingController();
  final TextEditingController municipioController = TextEditingController();
  final TextEditingController curpController = TextEditingController();
  final TextEditingController claveElectorController = TextEditingController();
  final TextEditingController _claveInterbancariaController =
      TextEditingController();

  final TextEditingController rfcController = TextEditingController();
  final TextEditingController tiempoViviendoController =
      TextEditingController();
  final TextEditingController emailClientecontroller = TextEditingController();
  final TextEditingController telefonoClienteController =
      TextEditingController();

  final TextEditingController nombrePropietarioController =
      TextEditingController();
  final TextEditingController parentescoPropietarioController =
      TextEditingController();

  final TextEditingController nombrePropietarioRefController =
      TextEditingController();
  final TextEditingController parentescoRefPropController =
      TextEditingController();

  final TextEditingController ocupacionController = TextEditingController();
  final TextEditingController depEconomicosController = TextEditingController();

  final TextEditingController nombreConyugeController = TextEditingController();
  final TextEditingController telefonoConyugeController =
      TextEditingController();
  final TextEditingController ocupacionConyugeController =
      TextEditingController();

  String? selectedSexo;
  String? selectedECivil;
  String? selectedTipoCliente;
  DateTime? selectedDate;
  String? selectedTipoDomicilio;
  String? selectedTipoDomicilioRef;
  String? idcuantabank;
  int? iddomicilios;
  int? idingegr;
  String? iddomiciliosRef;

  final _fechaController = TextEditingController();

  bool _isLoading = true; // Estado para controlar el CircularProgressIndicator

  bool dialogShown = false;
  dynamic clienteData; // Almacena los datos del cliente
  Timer? _timer;
  bool _dialogShown = false;

  Map<String, dynamic> originalData = {};

  List<int> idingegrList = [];
  List<int> idreferenciasList = [];

  final List<String> sexos = ['Masculino', 'Femenino'];
  final List<String> estadosCiviles = [
    'Soltero',
    'Casado',
    'Divorciado',
    'Viudo',
    'Unión Libre'
  ];

  final List<String> tiposClientes = [
    'Asalariado',
    'Independiente',
    'Comerciante',
    'Jubilado'
  ];

  List<String> tiposIngresoEgreso = [
    'Actividad economica',
    'Actividad Laboral',
    'Credito con otras financieras',
    'Aportaciones del esposo',
    'Otras aportaciones'
  ];

  // Lista de bancos
  final List<String> _bancos = [
    "BBVA",
    "Santander",
    "Banorte",
    "HSBC",
    "Citibanamex",
    "Scotiabank",
    "Bancoppel",
    "Banco Azteca"
  ];

  // Mapa para asociar tipos con sus respectivos IDs
  Map<String, int> tiposIngresoEgresoIds = {
    'Actividad economica': 1,
    'Actividad Laboral': 2,
    'Credito con otras financieras': 3,
    'Aportaciones del esposo': 4,
    'Otras aportaciones': 5
  };

  final List<String> tiposDomicilio = [
    'Propio',
    'Familiar',
    'Rentado',
    'Prestado'
  ];

  final List<Map<String, dynamic>> ingresosEgresos = [];

  List<Map<String, dynamic>> referencias =
      []; // Lista para almacenar referencias

  late TabController _tabController;
  int _currentIndex = 0;

  // Mapa para almacenar todos los datos por endpoint
  // Mapa para almacenar todos los datos por endpoint
  Map<String, Map<String, dynamic>> allFieldsByEndpoint = {
    "Cliente": {},
    "Cuenta Banco": {},
    "Domicilio": {},
    "Datos Adicionales": {},
    "Ingresos": {},
    "Referencias": {}
  };

  // Mapa para rastrear si un endpoint fue editado
  Map<String, bool> isEndpointEdited = {
    "Cliente": false,
    "Cuenta Banco": false,
    "Domicilio": false,
    "Datos Adicionales": false,
    "Ingresos": false,
    "Referencias": false
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _personalFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _cuentaBancariaFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _ingresosEgresosFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _referenciasFormKey = GlobalKey<FormState>();

  bool _noCuentaBancaria = false;
  // Controladores de texto para los campos
  final TextEditingController _numCuentaController = TextEditingController();
  final TextEditingController _numTarjetaController = TextEditingController();

  bool isEditing = false; // Variable que indica si estamos editando

  // Variables para manejar el banco seleccionado
  String? _nombreBanco; // Almacena el nombre del banco seleccionado

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });

    // Imprime el idCliente en la consola
    print("ID del cliente: ${widget.idCliente}");

    // Determinar si estamos en modo edición o agregando un cliente
    isEditing = widget.idCliente != null && widget.idCliente!.isNotEmpty;

    // Llama a fetchClienteData solo si idCliente no es nulo (si estamos editando)
    if (isEditing) {
      fetchClienteData();
    } else {
      _isLoading = false; // Si no estamos editando, cambia el estado de carga
    }
  }

  Future<void> fetchClienteData() async {
    if (!mounted) return;

    _timer?.cancel();
    setState(() => _isLoading = true);

    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_dialogShown) {
        setState(() => _isLoading = false);
        _dialogShown = true;
        mostrarDialogoError('Error de conexión. Revise su red.');
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('http://$baseUrl/api/v1/clientes/${widget.idCliente}'),
        headers: {'tokenauth': token},
      );

      if (!mounted) return;
      _timer?.cancel();

      if (response.statusCode == 200) {
        setState(() {
          clienteData = json.decode(response.body)[0];

          originalData = {
            // Datos personales del cliente
            'nombres': clienteData['nombres'],
            'apellidoP': clienteData['apellidoP'],
            'apellidoM': clienteData['apellidoM'],
            'sexo': clienteData['sexo'],
            'tipo_cliente': clienteData['tipo_cliente'],
            'ocupacion': clienteData['ocupacion'],
            'dependientes_economicos': clienteData['dependientes_economicos'],
            'telefono': clienteData['telefono'],
            'email': clienteData['email'],
            'eCivil': clienteData['eCivil'],
            'fechaNac': clienteData['fechaNac'],
            'nombreConyuge': clienteData['nombreConyuge'],
            'telefonoConyuge': clienteData['telefonoConyuge'],
            'ocupacionConyuge': clienteData['ocupacionConyuge'],

            // Datos del domicilio del cliente
            // Agregar el iddomicilios si está disponible en clienteData['domicilios']
            'iddomicilios': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['iddomicilios'] ?? 'No asignado'
                : 'No asignado',
            'calle': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['calle']
                : '',
            'entreCalle': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['entreCalle']
                : '',
            'colonia': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['colonia']
                : '',
            'cp': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['cp']
                : '',
            'nExt': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['nExt']
                : '',
            'nInt': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['nInt']
                : '',
            'estado': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['estado']
                : '',
            'municipio': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['municipio']
                : '',
            'tipo_domicilio': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['tipo_domicilio']
                : '',
            'nombre_propietario': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['nombre_propietario']
                : '',
            'parentesco': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['parentesco']
                : '',
            'tiempoViviendo': clienteData['domicilios']?.isNotEmpty == true
                ? clienteData['domicilios'][0]['tiempoViviendo']
                : '',

            // Datos adicionales del cliente (como CURP, RFC)
            'curp': clienteData['adicionales']?.isNotEmpty == true
                ? clienteData['adicionales'][0]['curp']
                : '',
            'rfc': clienteData['adicionales']?.isNotEmpty == true
                ? clienteData['adicionales'][0]['rfc']
                : '',

            'clvElector': clienteData['adicionales']?.isNotEmpty == true
                ? clienteData['adicionales'][0]['clvElector']
                : '',

            // Datos de la cuenta bancaria
            'numCuenta': clienteData['cuentabanco']?.isNotEmpty == true
                ? clienteData['cuentabanco'][0]['numCuenta'] ?? 'No asignado'
                : 'No asignado',

            // Agrega el idcuentabanco (si está disponible en clienteData['cuentabanco'])
            'idcuantabank': clienteData['cuentabanco']?.isNotEmpty == true
                ? clienteData['cuentabanco'][0]['idcuantabank'] ?? 'No asignado'
                : 'No asignado',
            'clbIntBanc': clienteData['cuentabanco']?.isNotEmpty == true
                ? clienteData['cuentabanco'][0]['clbIntBanc'] ?? 'No asignado'
                : 'No asignado',

            'numTarjeta': clienteData['cuentabanco']?.isNotEmpty == true
                ? clienteData['cuentabanco'][0]['numTarjeta'] ?? 'No asignado'
                : 'No asignado',

            'nombreBanco': clienteData['cuentabanco']?.isNotEmpty == true
                ? clienteData['cuentabanco'][0]['nombreBanco'] ?? 'No asignado'
                : 'No asignado',

            // Datos del cliente en ingresos y egresos
            'ingresos_egresos':
                clienteData['ingresos_egresos']?.map((ingresoEgreso) {
                      return {
                        'idingegr': ingresoEgreso['idingegr'] ?? 'No asignado',
                        'tipo_info':
                            ingresoEgreso['tipo_info'] ?? 'No asignado',
                        'años_actividad':
                            ingresoEgreso['años_actividad'] ?? 'No asignado',
                        'descripcion':
                            ingresoEgreso['descripcion'] ?? 'No asignado',
                        'monto_semanal':
                            ingresoEgreso['monto_semanal'] ?? 'No asignado',
                      };
                    }).toList() ??
                    [],

            // Datos de referencias
            'referencias': clienteData['referencias']?.map((referencia) {
                  if (referencia['datos'] == 'No asignado') {
                    return {
                      'datos': 'No asignado',
                      // Si 'datos' es 'No asignado', puedes incluir algún valor por defecto aquí si quieres
                    };
                  }

                  var domicilioRef = referencia['domicilio_ref'];
                  return {
                    'idreferencias': referencia['idreferencias'],
                    'nombresRef': referencia['nombres'] ?? '',
                    'apellidoPRef': referencia['apellidoP'] ?? '',
                    'apellidoMRef': referencia['apellidoM'] ?? '',
                    'parentescoRef': referencia['parentescoRefProp'] ?? '',
                    'telefonoRef': referencia['telefono'] ?? '',
                    'tiempoConocerRef': referencia['tiempoCo'] ?? '',
                    'iddomicilios': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['iddomicilios']
                        : '',
                    'tipoDomicilioRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['tipo_domicilio']
                        : '',
                    'nombrePropietarioRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['nombre_propietario']
                        : '',
                    'parentescoRefProp': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['parentesco']
                        : '',
                    'calleRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['calle']
                        : '',
                    'entreCalleRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['entreCalle']
                        : '',
                    'coloniaRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['colonia']
                        : '',
                    'cpRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['cp']
                        : '',
                    'nExtRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['nExt']
                        : '',
                    'nIntRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['nInt']
                        : '',
                    'estadoRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['estado']
                        : '',
                    'municipioRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['municipio']
                        : '',
                    'tiempoViviendoRef': domicilioRef?.isNotEmpty == true
                        ? domicilioRef[0]['tiempoViviendo']
                        : '',
                  };
                }).toList() ??
                [],
          };
          print('OriginalData en Fetch: $originalData');
          idcuantabank = originalData['idcuantabank'];
          // Después de crear el originalData, puedes guardar el valor en una variable separada
          iddomicilios = originalData['iddomicilios'];
          // Imprime el valor de `idingegr` para cada elemento en `ingresos_egresos`
          // Aquí debes asignar el valor de 'idingegr' a la variable externa
          // Recorrer los elementos de ingresos_egresos y guardar los idingegr
          originalData['ingresos_egresos'].forEach((ingresoEgreso) {
            int idingegr = ingresoEgreso['idingegr'];
            idingegrList.add(idingegr); // Agregar el idingegr a la lista
            print('idingegrAA: $idingegr');
          });
          //print('Referencias: ${originalData['referencias']}');

          originalData['referencias'].forEach((referencia) {
            if (referencia.containsKey('idreferencias')) {
              int idreferencias = referencia['idreferencias'];
              idreferenciasList.add(idreferencias);
              //   print('idreferencias: $idreferencias');
            } else {
              //  print('idreferencias no encontrado');
            }
          });

          // Datos básicos del cliente
          nombresController.text = clienteData['nombres'] ?? '';
          apellidoPController.text = clienteData['apellidoP'] ?? '';
          apellidoMController.text = clienteData['apellidoM'] ?? '';
          selectedTipoCliente = clienteData['tipo_cliente'] ?? '';
          selectedSexo = clienteData['sexo'] ?? '';
          ocupacionController.text = clienteData['ocupacion'] ?? '';
          depEconomicosController.text =
              clienteData['dependientes_economicos'] ?? '';
          telefonoClienteController.text = clienteData['telefono'] ?? '';
          emailClientecontroller.text = clienteData['email'] ?? '';

          // Información adicional del cliente
          selectedECivil = clienteData['eCivil'] ?? '';
          _fechaController.text = clienteData['fechaNac'] ?? '';

          // Si hay una fecha válida, establece también el selectedDate
          if (clienteData['fechaNac'] != null &&
              clienteData['fechaNac'].isNotEmpty) {
            selectedDate = DateTime.parse(clienteData['fechaNac']);
          }

          nombreConyugeController.text = clienteData['nombreConyuge'] ?? '';
          telefonoConyugeController.text = clienteData['telefonoConyuge'] ?? '';
          ocupacionConyugeController.text =
              clienteData['ocupacionConyuge'] ?? '';

          // Información de domicilio del cliente
          if (clienteData['domicilios'] != null &&
              clienteData['domicilios'].isNotEmpty) {
            var domicilio = clienteData['domicilios'][0];
            calleController.text = domicilio['calle'] ?? '';
            entreCalleController.text = domicilio['entreCalle'] ?? '';
            coloniaController.text = domicilio['colonia'] ?? '';
            cpController.text = domicilio['cp'] ?? '';
            nExtController.text = domicilio['nExt'] ?? '';
            nIntController.text = domicilio['nInt'] ?? '';
            estadoController.text = domicilio['estado'] ?? '';
            municipioController.text = domicilio['municipio'] ?? '';
            selectedTipoDomicilio = domicilio['tipo_domicilio'] ?? '';
            nombrePropietarioController.text =
                domicilio['nombre_propietario'] ?? '';
            parentescoPropietarioController.text =
                domicilio['parentesco'] ?? '';
            tiempoViviendoController.text = domicilio['tiempoViviendo'] ?? '';
          }

          // Información adicional
          if (clienteData['adicionales'] != null &&
              clienteData['adicionales'].isNotEmpty) {
            curpController.text = clienteData['adicionales'][0]['curp'] ?? '';
            rfcController.text = clienteData['adicionales'][0]['rfc'] ?? '';
            claveElectorController.text =
                clienteData['adicionales'][0]['clvElector'] ?? '';
          }

          // Información de cuenta bancaria
          if (clienteData['cuentabanco'] != null &&
              clienteData['cuentabanco'].isNotEmpty) {
            setState(() {
              _numCuentaController.text =
                  clienteData['cuentabanco'][0]['numCuenta'] ?? 'No asignado';
              _numTarjetaController.text =
                  clienteData['cuentabanco'][0]['numTarjeta'] ?? 'No asignado';
              _nombreBanco =
                  clienteData['cuentabanco'][0]['nombreBanco'] ?? 'No asignado';
              _claveInterbancariaController.text =
                  clienteData['cuentabanco'][0]['clbIntBanc'] ?? 'No asignado';
            });
          }

          // Inicialización de ingresos y egresos
          ingresosEgresos.clear();
          if (clienteData['ingresos_egresos'] != null) {
            for (var ingresoEgreso in clienteData['ingresos_egresos']) {
              // Verifica si algún campo tiene el valor 'No asignado' y asigna 'No asignado'
              ingresosEgresos.add({
                'tipo_info': ingresoEgreso['tipo_info'] == 'No asignado'
                    ? 'No asignado'
                    : ingresoEgreso['tipo_info'] ?? 'No asignado',
                'años_actividad':
                    ingresoEgreso['años_actividad'] == 'No asignado'
                        ? 'No asignado'
                        : ingresoEgreso['años_actividad'] ?? 'No asignado',
                'descripcion': ingresoEgreso['descripcion'] == 'No asignado'
                    ? 'No asignado'
                    : ingresoEgreso['descripcion'] ?? 'No asignado',
                'monto_semanal': ingresoEgreso['monto_semanal'] == 'No asignado'
                    ? 'No asignado'
                    : ingresoEgreso['monto_semanal'] ?? 'No asignado',
              });
            }
          }

          // Inicialización de referencias
          referencias.clear();
          if (clienteData['referencias'] != null) {
            for (var referencia in clienteData['referencias']) {
              // Verifica si la referencia tiene el valor 'No asignado'
              if (referencia['datos'] == 'No asignado') {
                // Si 'datos' es 'No asignado', se agrega una referencia con ese valor
                referencias.add({
                  'nombresRef': 'No asignado',
                  'apellidoPRef': 'No asignado',
                  'apellidoMRef': 'No asignado',
                  'parentescoRef': 'No asignado',
                  'telefonoRef': 'No asignado',
                  'tiempoConocerRef': 'No asignado',
                  // Datos del domicilio de la referencia
                  'iddomicilios': 'No asignado',
                  'tipoDomicilioRef': 'No asignado',
                  'nombrePropietarioRef': 'No asignado',
                  'parentescoRefProp': 'No asignado',
                  'calleRef': 'No asignado',
                  'entreCalleRef': 'No asignado',
                  'coloniaRef': 'No asignado',
                  'cpRef': 'No asignado',
                  'nExtRef': 'No asignado',
                  'nIntRef': 'No asignado',
                  'estadoRef': 'No asignado',
                  'municipioRef': 'No asignado',
                  'tiempoViviendoRef': 'No asignado',
                });
              } else {
                var domicilioRef = referencia['domicilio_ref'];
                // Verifica si la lista de domicilios no está vacía antes de acceder a ella
                iddomiciliosRef = domicilioRef.isNotEmpty
                    ? (domicilioRef[0]['iddomicilios'] ?? '').toString()
                    : '';

                String tipoDomicilio = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['tipo_domicilio'] ?? ''
                    : '';
                String nombrePropietario = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['nombre_propietario'] ?? ''
                    : '';
                String parentescoRefProp = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['parentesco'] ?? ''
                    : '';
                String calle = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['calle'] ?? ''
                    : '';
                String entreCalle = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['entreCalle'] ?? ''
                    : '';
                String colonia = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['colonia'] ?? ''
                    : '';
                String cp =
                    domicilioRef.isNotEmpty ? domicilioRef[0]['cp'] ?? '' : '';
                String nExt = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['nExt'] ?? ''
                    : '';
                String nInt = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['nInt'] ?? ''
                    : '';
                String estado = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['estado'] ?? ''
                    : '';
                String municipio = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['municipio'] ?? ''
                    : '';
                String tiempoViviendo = domicilioRef.isNotEmpty
                    ? domicilioRef[0]['tiempoViviendo'] ?? ''
                    : '';

                // Ahora agregamos la referencia a la lista
                referencias.add({
                  'nombresRef': referencia['nombres'] ?? '',
                  'apellidoPRef': referencia['apellidoP'] ?? '',
                  'apellidoMRef': referencia['apellidoM'] ?? '',
                  'parentescoRef': referencia['parentescoRefProp'] ?? '',
                  'telefonoRef': referencia['telefono'] ?? '',
                  'tiempoConocerRef': referencia['tiempoCo'] ?? '',

                  // Datos del domicilio de la referencia
                  'iddomicilios': iddomicilios,
                  'tipoDomicilioRef': tipoDomicilio,
                  'nombrePropietarioRef': nombrePropietario,
                  'parentescoRefProp': parentescoRefProp,
                  'calleRef': calle,
                  'entreCalleRef': entreCalle,
                  'coloniaRef': colonia,
                  'cpRef': cp,
                  'nExtRef': nExt,
                  'nIntRef': nInt,
                  'estadoRef': estado,
                  'municipioRef': municipio,
                  'tiempoViviendoRef': tiempoViviendo,
                });
              }
            }
          }

          _isLoading = false; // Cambiar el estado de carga a false
        });
        _timer
            ?.cancel(); // Cancela el temporizador al completar la carga exitosa
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _dialogShown = false;
      }
    }
  }

  void _handleErrorResponse(http.Response response) {
    try {
      final errorData = json.decode(response.body);
      final statusCode = response.statusCode;

      // Extraer mensaje de error con diferentes posibles estructuras
      final errorMessage = (errorData['Error']?['Message'] ??
              errorData['error']?['message'] ??
              errorData['message'] ??
              '')
          .toString()
          .toLowerCase();

      // Manejar casos de token expirado
      if ((statusCode == 401 || statusCode == 403 || statusCode == 404) &&
          (errorMessage.contains('jwt expired') ||
              errorMessage.contains('token expired'))) {
        _handleTokenExpiration();
      }
      // Manejar otros errores
      else if (statusCode == 404) {
        mostrarDialogoError('Recurso no encontrado (404)');
      } else {
        mostrarDialogoError(
            'Error $statusCode: ${errorMessage.isNotEmpty ? errorMessage : 'Error desconocido'}');
      }
    } catch (e) {
      mostrarDialogoError(
          'Error ${response.statusCode}: No se pudo procesar la respuesta');
    }
  }

  void _handleNetworkError(dynamic error) {
    if (error is SocketException) {
      mostrarDialogoError('Error de conexión. Verifique su internet');
    } else {
      mostrarDialogoError('Error inesperado: ${error.toString()}');
    }
  }

  void _handleTokenExpiration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tokenauth');

    if (mounted) {
      mostrarDialogoError(
        'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
        onClose: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        ),
      );
    }
  }

  void compareAndPrintEditedEndpointFields() {
    // Función para agregar un campo a un endpoint específico
    void addFieldToEndpoint(
        String endpoint, String key, dynamic value, dynamic originalValue) {
      // Asegurarse de que el valor sea un mapa adecuado
      if (allFieldsByEndpoint[endpoint] is Map<String, dynamic>) {
        allFieldsByEndpoint[endpoint]![key] = value;
      }

      // Imprimir los valores originales y los valores nuevos
      print("Comparando $key: original = $originalValue, nuevo = $value");

      // Comparación segura que trata nulls y valores vacíos
      if ((value?.toString().trim() ?? '') !=
          (originalValue?.toString().trim() ?? '')) {
        print("Campo editado: $key");
        isEndpointEdited[endpoint] = true;
      }
    }

    print('original data dentro de compare $originalData');

    // Recolectar datos y verificar si fueron editados
    addFieldToEndpoint("Cliente", "nombres", nombresController.text ?? '',
        originalData['nombres']);
    addFieldToEndpoint("Cliente", "apellidoP", apellidoPController.text ?? '',
        originalData['apellidoP']);
    addFieldToEndpoint("Cliente", "apellidoM", apellidoMController.text ?? '',
        originalData['apellidoM']);
    addFieldToEndpoint(
        "Cliente", "sexo", selectedSexo ?? '', originalData['sexo']);
    addFieldToEndpoint("Cliente", "tipo_cliente", selectedTipoCliente ?? '',
        originalData['tipo_cliente']);
    addFieldToEndpoint("Cliente", "ocupacion", ocupacionController.text ?? '',
        originalData['ocupacion']);
    addFieldToEndpoint(
        "Cliente",
        "dependientes_economicos",
        depEconomicosController.text ?? '',
        originalData['dependientes_economicos']);
    addFieldToEndpoint("Cliente", "telefono",
        telefonoClienteController.text ?? '', originalData['telefono']);
    addFieldToEndpoint("Cliente", "email", emailClientecontroller.text ?? '',
        originalData['email']);
    addFieldToEndpoint(
        "Cliente", "eCivil", selectedECivil ?? '', originalData['eCivil']);
    addFieldToEndpoint("Cliente", "fechaNac", _fechaController.text ?? '',
        originalData['fechaNac']);
    addFieldToEndpoint("Cliente", "nombreConyuge",
        nombreConyugeController.text ?? '', originalData['nombreConyuge']);
    addFieldToEndpoint("Cliente", "telefonoConyuge",
        telefonoConyugeController.text ?? '', originalData['telefonoConyuge']);
    addFieldToEndpoint(
        "Cliente",
        "ocupacionConyuge",
        ocupacionConyugeController.text ?? '',
        originalData['ocupacionConyuge']);

    addFieldToEndpoint("Cuenta Banco", "numCuenta",
        _numCuentaController.text ?? '', originalData['numCuenta']);
    addFieldToEndpoint("Cuenta Banco", "numTarjeta",
        _numTarjetaController.text ?? '', originalData['numTarjeta']);
    addFieldToEndpoint("Cuenta Banco", "nombreBanco", _nombreBanco ?? '',
        originalData['nombreBanco']);
    addFieldToEndpoint("Cuenta Banco", "clbIntBanc",
        _claveInterbancariaController.text ?? '', originalData['clbIntBanc']);

    addFieldToEndpoint("Domicilio", "calle", calleController.text ?? '',
        originalData['calle']);
    addFieldToEndpoint("Domicilio", "entreCalle",
        entreCalleController.text ?? '', originalData['entreCalle']);
    addFieldToEndpoint("Domicilio", "colonia", coloniaController.text ?? '',
        originalData['colonia']);
    addFieldToEndpoint(
        "Domicilio", "cp", cpController.text ?? '', originalData['cp']);
    addFieldToEndpoint(
        "Domicilio", "nExt", nExtController.text ?? '', originalData['nExt']);
    addFieldToEndpoint(
        "Domicilio", "nInt", nIntController.text ?? '', originalData['nInt']);
    addFieldToEndpoint("Domicilio", "estado", estadoController.text ?? '',
        originalData['estado']);
    addFieldToEndpoint("Domicilio", "municipio", municipioController.text ?? '',
        originalData['municipio']);
    addFieldToEndpoint("Domicilio", "tipo_domicilio",
        selectedTipoDomicilio ?? '', originalData['tipo_domicilio']);
    addFieldToEndpoint(
        "Domicilio",
        "nombre_propietario",
        nombrePropietarioController.text ?? '',
        originalData['nombre_propietario']);
    addFieldToEndpoint("Domicilio", "parentesco",
        parentescoPropietarioController.text ?? '', originalData['parentesco']);
    addFieldToEndpoint("Domicilio", "tiempoViviendo",
        tiempoViviendoController.text ?? '', originalData['tiempoViviendo']);

    addFieldToEndpoint("Datos Adicionales", "curp", curpController.text ?? '',
        originalData['curp']);
    addFieldToEndpoint("Datos Adicionales", "rfc", rfcController.text ?? '',
        originalData['rfc']);
    addFieldToEndpoint("Datos Adicionales", "clvElector",
        claveElectorController.text ?? '', originalData['clvElector']);

    // Ingresos y egresos
    for (int i = 0; i < ingresosEgresos.length; i++) {
      var ingresoEgreso = ingresosEgresos[i];
      var originalIngresoEgreso = originalData['ingresos_egresos'][i];
      addFieldToEndpoint("Ingresos", "ingresos_egresos_${i}_tipo_info",
          ingresoEgreso['tipo_info'], originalIngresoEgreso['tipo_info']);
      addFieldToEndpoint(
          "Ingresos",
          "ingresos_egresos_${i}_años_actividad",
          ingresoEgreso['años_actividad'],
          originalIngresoEgreso['años_actividad']);
      addFieldToEndpoint("Ingresos", "ingresos_egresos_${i}_descripcion",
          ingresoEgreso['descripcion'], originalIngresoEgreso['descripcion']);
      addFieldToEndpoint(
          "Ingresos",
          "ingresos_egresos_${i}_monto_semanal",
          ingresoEgreso['monto_semanal'],
          originalIngresoEgreso['monto_semanal']);
    }

    // Referencias
    for (int i = 0; i < referencias.length; i++) {
      var ref = referencias[i];
      var originalRef = originalData['referencias'][i];
      addFieldToEndpoint("Referencias", "referencias_${i}_nombresRef",
          ref['nombresRef'], originalRef['nombresRef']);
      addFieldToEndpoint("Referencias", "referencias_${i}_apellidoPRef",
          ref['apellidoPRef'], originalRef['apellidoPRef']);
      addFieldToEndpoint("Referencias", "referencias_${i}_apellidoMRef",
          ref['apellidoMRef'], originalRef['apellidoMRef']);
      addFieldToEndpoint("Referencias", "referencias_${i}_parentescoRef",
          ref['parentescoRef'], originalRef['parentescoRef']);

      addFieldToEndpoint("Referencias", "referencias_${i}_telefonoRef",
          ref['telefonoRef'], originalRef['telefonoRef']);

      addFieldToEndpoint("Referencias", "referencias_${i}_tiempoCo",
          ref['tiempoConocerRef'], originalRef['tiempoConocerRef']);
    }

    // DomicilioReferencia: Iterar y comparar los campos de manera similar a las referencias
    for (int i = 0; i < referencias.length; i++) {
      var ref = referencias[i];
      var originalRef = originalData['referencias'][i];

      // Aquí debes comparar los valores correspondientes a 'DomicilioReferencia' de manera similar
      addFieldToEndpoint("DomicilioReferencia", "calleRef", ref['calleRef'],
          originalRef['calleRef']);
      addFieldToEndpoint("DomicilioReferencia", "entreCalleRef",
          ref['entreCalleRef'], originalRef['entreCalleRef']);
      addFieldToEndpoint("DomicilioReferencia", "coloniaRef", ref['coloniaRef'],
          originalRef['coloniaRef']);
      addFieldToEndpoint(
          "DomicilioReferencia", "cpRef", ref['cpRef'], originalRef['cpRef']);
      addFieldToEndpoint("DomicilioReferencia", "nExtRef", ref['nExtRef'],
          originalRef['nExtRef']);
      addFieldToEndpoint("DomicilioReferencia", "nIntRef", ref['nIntRef'],
          originalRef['nIntRef']);
      addFieldToEndpoint("DomicilioReferencia", "estadoRef", ref['estadoRef'],
          originalRef['estadoRef']);
      addFieldToEndpoint("DomicilioReferencia", "municipioRef",
          ref['municipioRef'], originalRef['municipioRef']);
      addFieldToEndpoint("DomicilioReferencia", "tipoDomicilioRef",
          ref['tipoDomicilioRef'], originalRef['tipoDomicilioRef']);
      addFieldToEndpoint("DomicilioReferencia", "nombrePropietarioRef",
          ref['nombrePropietarioRef'], originalRef['nombrePropietarioRef']);
      addFieldToEndpoint("DomicilioReferencia", "parentescoRefProp",
          ref['parentescoRefProp'], originalRef['parentescoRefProp']);
      addFieldToEndpoint("DomicilioReferencia", "tiempoViviendoRef",
          ref['tiempoViviendoRef'], originalRef['tiempoViviendoRef']);
    }

    // Imprimir solo los campos del endpoint editado
    isEndpointEdited.forEach((endpoint, wasEdited) {
      if (wasEdited) {
        print("Endpoint editado: $endpoint");
        allFieldsByEndpoint[endpoint]?.forEach((key, value) {
          print("$key: $value");
        });
      }
    });
  }

  Future<void> sendEditedData(
    BuildContext context,
    String clientId,
    String idcuantabank,
    int iddomicilios,
    List<int> idingegr,
    List<int> idreferencias,
    String iddomiciliosRef,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      bool anyErrors = false;
      bool tokenExpired = false;
      print('idcuentabank dentro de sendedited: $idcuantabank');

      idingegr.forEach((idingegr) {
        print('idingegr dentro de sendedited: $idingegr');
      });

      idreferencias.forEach((idreferencias) {
        print('idreferencias dentro de sendedited: $idreferencias');
      });

      // Preparar los datos de las referencias editadas
      List<Map<String, dynamic>> referenciasList = [];
      if (isEndpointEdited["Referencias"] ?? false) {
        for (int i = 0; i < referencias.length; i++) {
          var ref = referencias[i];
          var originalRef = originalData['referencias'][i];

          var referenceMap = {
            "idreferencias": idreferencias[i],
            "nombres": ref['nombresRef'] ?? "",
            "apellidoP": ref['apellidoPRef'] ?? "",
            "apellidoM": ref['apellidoMRef'] ?? "",
            "parentescoRefProp": ref['parentescoRef'] ?? "",
            "telefono": ref['telefonoRef'] ?? "",
            "tiempoCo": ref['tiempoConocerRef'] ?? "",
          };

          bool isEdited = referenceMap.keys.any((key) {
            var originalValue = originalRef[key];
            var newValue = referenceMap[key];

            if (originalValue is String && newValue is String) {
              originalValue = originalValue.trim();
              newValue = newValue.trim();
            }
            return newValue != originalValue;
          });

          if (isEdited) {
            print("Referencia editada: ${jsonEncode(referenceMap)}");
            referenciasList.add(referenceMap);
          }
        }
      }

      Map<String, String> endpointUrls = {
        "Cliente": "http://$baseUrl/api/v1/clientes/$clientId",
        "Cuenta Banco": "http://$baseUrl/api/v1/cuentabanco/$idcuantabank",
        "Domicilio": "http://$baseUrl/api/v1/domicilios/$clientId",
        "DomicilioReferencia":
            "http://$baseUrl/api/v1/domicilios/${idreferencias[0]}",
        "Datos Adicionales":
            "http://$baseUrl/api/v1/datosadicionales/$clientId",
        "Ingresos": "http://$baseUrl/api/v1/ingresos/$clientId",
        "Referencias": "http://$baseUrl/api/v1/referencia/$clientId",
      };

      // Preparar los datos de "Ingresos"
      List<Map<String, dynamic>> ingresosList = [];
      for (int i = 0; i < ingresosEgresos.length; i++) {
        var ingresoEgreso = ingresosEgresos[i];
        int idInfo = tiposIngresoEgresoIds[ingresoEgreso['tipo_info']] ?? 0;

        var ingresoData = {
          "idingegr": idingegr[i],
          "idinfo": idInfo,
          "años_actividad": ingresoEgreso['años_actividad'],
          "descripcion": ingresoEgreso['descripcion'],
          "monto_semanal": ingresoEgreso['monto_semanal']
        };
        ingresosList.add(ingresoData);
      }

      // Preparar los datos de DomicilioReferencia
      List<Map<String, dynamic>> domicilioReferenciaList = [];
      if (isEndpointEdited["DomicilioReferencia"] ?? false) {
        for (int i = 0; i < idreferencias.length; i++) {
          var ref = referencias[i];
          var originalRef = originalData['referencias'][i];

          var domicilioReferenciaMap = {
            "idreferencias": idreferencias[i],
            "iddomicilios": iddomiciliosRef ?? iddomicilios,
            "calle": ref['calleRef'] ?? "",
            "entreCalle": ref['entreCalleRef'] ?? "",
            "colonia": ref['coloniaRef'] ?? "",
            "cp": ref['cpRef'] ?? "",
            "nExt": ref['nExtRef'] ?? "",
            "nInt": ref['nIntRef'] ?? "",
            "estado": ref['estadoRef'] ?? "",
            "municipio": ref['municipioRef'] ?? "",
            "tipo_domicilio": ref['tipoDomicilioRef'] ?? "",
            "nombre_propietario": ref['nombrePropietarioRef'] ?? "",
            "parentescoRefDomProp": ref['parentescoRefProp'] ?? "",
            "tiempoViviendo": ref['tiempoViviendoRef'] ?? "",
          };

          bool isEdited = domicilioReferenciaMap.keys.any((key) {
            var originalValue = originalRef[key];
            var newValue = domicilioReferenciaMap[key];

            if (originalValue is String && newValue is String) {
              originalValue = originalValue.trim();
              newValue = newValue.trim();
            }

            return newValue != originalValue;
          });

          if (isEdited) {
            print(
                "DomicilioReferencia editado: ${jsonEncode(domicilioReferenciaMap)}");
            domicilioReferenciaList.add(domicilioReferenciaMap);
          }
        }
      }

      // Enviar los datos para cada endpoint editado
      for (var entry in isEndpointEdited.entries) {
        if (tokenExpired) break;

        String endpoint = entry.key;
        bool wasEdited = entry.value;

        if (wasEdited) {
          String? url = endpointUrls[endpoint];
          if (url != null) {
            dynamic dataToSendEndpoint;

            print("Enviando datos a la URL: $url");

            if (endpoint == "Referencias") {
              dataToSendEndpoint =
                  referenciasList.isNotEmpty ? referenciasList : [];
              print(
                  "Datos de referencias a enviar: ${jsonEncode(dataToSendEndpoint)}");
            } else if (endpoint == "Ingresos") {
              dataToSendEndpoint = ingresosList;
              print("Datos de ingresos a enviar: ${jsonEncode(ingresosList)}");
            } else if (endpoint == "DomicilioReferencia") {
              dataToSendEndpoint = domicilioReferenciaList.isNotEmpty
                  ? domicilioReferenciaList
                  : [];
              print(
                  "Datos de DomicilioReferencia a enviar: ${jsonEncode(dataToSendEndpoint)}");
            } else {
              dataToSendEndpoint = allFieldsByEndpoint[endpoint]!;
            }

            if (endpoint == "Cuenta Banco") {
              dataToSendEndpoint["iddetallegrupos"] = "";
              if (!dataToSendEndpoint.containsKey("idclientes")) {
                dataToSendEndpoint["idclientes"] = clientId;
              }
            }

            if (endpoint == "Domicilio") {
              dataToSendEndpoint["iddomicilios"] = iddomicilios;
            }

            final body = (endpoint == "Domicilio")
                ? [dataToSendEndpoint]
                : dataToSendEndpoint;

            print("Datos a enviar para $endpoint: ${jsonEncode(body)}");

            try {
              final response = await http.put(
                Uri.parse(url),
                headers: {
                  "Content-Type": "application/json",
                  "tokenauth": token,
                },
                body: jsonEncode(body),
              );

              print("Respuesta de $endpoint: ${response.body}");

              if (response.statusCode == 200) {
                // _showSnackbar(context,"Datos enviados correctamente para $endpoint", Colors.green);
              } else {
                final errorData = jsonDecode(response.body);
                final errorMessage = (errorData['error']?['message'] ??
                        errorData['Error']?['Message'] ??
                        '')
                    .toString()
                    .toLowerCase();

                if (response.statusCode == 401 ||
                    response.statusCode == 403 ||
                    errorMessage.contains('jwt') ||
                    errorMessage.contains('token')) {
                  tokenExpired = true;
                  _handleTokenExpiration();
                  break;
                } else {
                  anyErrors = true;
                  _showSnackbar(
                      context,
                      "Error ${response.statusCode}: ${errorData['error']?['message'] ?? 'Error desconocido'}",
                      Colors.red);
                }
              }
            } catch (e) {
              anyErrors = true;
              _showSnackbar(context,
                  "Excepción al enviar datos para $endpoint: $e", Colors.red);
            }
          }
        }
      }

      if (tokenExpired) return;

      if (!anyErrors) {
        _handleSuccess(context);
      } else {
        _showSnackbar(
            context, "Hubo errores al enviar algunos datos", Colors.red);
      }
    } catch (e) {
      if (e is SocketException) {
        _showSnackbar(
            context, "Error de conexión. Verifique su internet", Colors.red);
      } else {
        _showSnackbar(context, "Error inesperado: ${e.toString()}", Colors.red);
      }
    }
  }

  void _handleSuccess(BuildContext context) {
    if (!mounted) return;

    _showSnackbar(context, "Cliente actualizado correctamente", Colors.green);
    Navigator.pop(context);

    if (widget.onClienteEditado != null) {
      widget.onClienteEditado!();
    }
  }

  void _showSnackbar(BuildContext context, String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(mensaje),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                onClose?.call();
              },
              child: const Text('Aceptar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      surfaceTintColor: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(20),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Text(
                    isEditing ? 'Editar Cliente' : 'Agregar Cliente',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Focus(
                    canRequestFocus: false,
                    descendantsAreFocusable: false,
                    child: IgnorePointer(
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Color(0xFF5162F6),
                        unselectedLabelColor:
                            isDarkMode ? Colors.grey[400] : Colors.grey,
                        indicatorColor: Color(0xFF5162F6),
                        tabs: [
                          Tab(text: 'Información Personal'),
                          Tab(text: 'Cuenta Bancaria'),
                          Tab(text: 'Ingresos y Egresos'),
                          Tab(text: 'Referencias'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 30, top: 10, bottom: 10, left: 0),
                          child: _paginaInfoPersonal(),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 30, top: 10, bottom: 10, left: 0),
                          child: _paginaCuentaBancaria(),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 30, top: 10, bottom: 10, left: 0),
                          child: _paginaIngresosEgresos(),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 30, top: 10, bottom: 10, left: 0),
                          child: _paginaReferencias(),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDarkMode ? Colors.grey[300] : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Cancelar'),
                      ),
                      Row(
                        children: [
                          if (_currentIndex > 0)
                            TextButton(
                              onPressed: () {
                                _tabController.animateTo(_currentIndex - 1);
                              },
                              child: Text(
                                'Atrás',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.blue[300] : null,
                                ),
                              ),
                            ),
                          if (_currentIndex <= 3)
                            ElevatedButton(
                              onPressed: () {
                                if (_currentIndex < 3) {
                                  if (_currentIndex == 2 &&
                                      ingresosEgresos.isEmpty) {
                                    _showErrorDialog(
                                      "No se puede avanzar",
                                      "Por favor, agregue al menos un ingreso o egreso.",
                                    );
                                    return;
                                  }

                                  if (_validarFormularioActual()) {
                                    _tabController.animateTo(_currentIndex + 1);
                                  } else {
                                    print(
                                        "Validación fallida en la pestaña $_currentIndex");
                                  }
                                } else if (_currentIndex == 3) {
                                  if (referencias.isEmpty) {
                                    _showErrorDialog(
                                      "No se puede agregar el cliente",
                                      "Por favor, agregue al menos una referencia.",
                                    );
                                    return;
                                  }

                                  if (ingresosEgresos.isEmpty) {
                                    _showErrorDialog(
                                      "No se puede avanzar",
                                      "Por favor, agregue al menos un ingreso o egreso.",
                                    );
                                    return;
                                  }

                                  if (_validarFormularioActual()) {
                                    if (isEditing) {
                                      print('Se va a editar');
                                      compareAndPrintEditedEndpointFields();
                                      sendEditedData(
                                          context,
                                          widget.idCliente!,
                                          idcuantabank!,
                                          iddomicilios!,
                                          idingegrList,
                                          idreferenciasList,
                                          iddomiciliosRef!);
                                    } else {
                                      _agregarCliente();
                                    }
                                  } else {
                                    _showErrorDialog(
                                      "No se puede agregar el cliente",
                                      "Por favor, complete todos los campos requeridos.",
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDarkMode
                                    ? Color(0xFF3A4AD1)
                                    : Color(0xFF5162F6),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                  _currentIndex == 3 ? 'Guardar' : 'Siguiente'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  // Modifica el método _validarFormularioActual para solo comprobar el estado de la fecha
  bool _validarFormularioActual() {
    if (_currentIndex == 0) {
      return _personalFormKey.currentState?.validate() ?? false;
    } else if (_currentIndex == 1) {
      return _cuentaBancariaFormKey.currentState?.validate() ?? false;
    } else if (_currentIndex == 2) {
      return _ingresosEgresosFormKey.currentState?.validate() ?? false;
    } else if (_currentIndex == 3) {
      return _referenciasFormKey.currentState?.validate() ?? false;
    }
    return false;
  }

  void _mostrarDialogoErrorFecha() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text('Por favor, selecciona una fecha de nacimiento.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Función que crea cada paso con el círculo y el texto
  Widget _buildPasoItem(int numeroPaso, String titulo, bool isActive) {
    return Row(
      children: [
        // Círculo numerado para el paso
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.white
                : Colors.transparent, // Fondo blanco solo si está activo
            border: Border.all(
                color: Colors.white,
                width: 2), // Borde blanco en todos los casos
          ),
          alignment: Alignment.center,
          child: Text(
            numeroPaso.toString(),
            style: TextStyle(
              color: isActive
                  ? Color(0xFF5162F6)
                  : Colors.white, // Texto rojo si está activo, blanco si no
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(width: 10),

        // Texto del paso
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _paginaInfoPersonal() {
    const double verticalSpacing = 20.0; // Variable para el espaciado vertical
    int pasoActual = 1; // Paso actual que queremos marcar como activo

    return Form(
      key: _personalFormKey, // Asignar la clave al formulario
      child: Row(
        children: [
          // Columna a la izquierda con el círculo y el ícono
          Container(
            decoration: BoxDecoration(
                color: Color(0xFF5162F6),
                borderRadius: BorderRadius.all(Radius.circular(20))),
            width: 250,
            height: 500,
            padding: EdgeInsets.symmetric(
                vertical: 20, horizontal: 10), // Espaciado vertical
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Paso 1
                _buildPasoItem(1, "Información Personal", pasoActual == 1),
                SizedBox(height: 20),

                // Paso 2
                _buildPasoItem(2, "Cuenta Bancaria", pasoActual == 2),
                SizedBox(height: 20),

                // Paso 3
                _buildPasoItem(3, "Ingresos y Egresos", pasoActual == 3),
                SizedBox(height: 20),

                // Paso 4
                _buildPasoItem(4, "Referencias", pasoActual == 4),
              ],
            ),
          ),
          SizedBox(width: 50), // Espacio entre la columna y el formulario

          // Columna con el formulario
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Alinear el texto a la izquierda
                children: [
                  SizedBox(height: verticalSpacing),

                  // Sección de Datos Personales
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      'Información Básica',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: nombresController,
                          label: 'Nombres',
                          icon: Icons.person,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(
                                r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese nombres';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: apellidoPController,
                          label: 'Apellido Paterno',
                          icon: Icons.person_outline,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(
                                r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Apellido Paterno';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: apellidoMController,
                          label: 'Apellido Materno',
                          icon: Icons.person_outline,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(
                                r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Apellido Materno';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),

                  // Agrupamos Dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: selectedTipoCliente,
                          hint: 'Tipo de Cliente',
                          items: tiposClientes,
                          onChanged: (value) {
                            setState(() {
                              selectedTipoCliente = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, seleccione el Tipo de Cliente';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          value: selectedSexo,
                          hint: 'Sexo',
                          items: sexos,
                          onChanged: (value) {
                            setState(() {
                              selectedSexo = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, seleccione el Sexo';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: ocupacionController,
                          label: 'Ocupación',
                          icon: Icons.work,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(
                                r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese la ocupación';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: depEconomicosController,
                          label: 'Dependientes económicos',
                          icon: Icons.family_restroom,
                          /*    validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese el dato';
                            }
                            return null;
                          }, */
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: telefonoClienteController,
                          label: 'Teléfono',
                          icon: Icons.phone,
                          keyboardType:
                              TextInputType.phone, // <- Aquí se especifica
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly // Solo permite números
                          ],
                          maxLength: 10, // Especificar la longitud máxima aquí
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese el Teléfono';
                            } else if (value.length != 10) {
                              return 'Debe tener 10 dígitos';
                            }
                            return null; // Si es válido
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: emailClientecontroller,
                          label: 'Correo electrónico',
                          icon: Icons.email,
                          keyboardType: TextInputType
                              .emailAddress, // <- Aquí se especifica
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese el correo electrónico';
                            }
                            // Expresión regular para validar el formato de un correo electrónico
                            final emailRegex =
                                RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Por favor, ingrese un correo electrónico válido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  // Agrupamos Estado Civil y Fecha de Nacimiento
                  Column(
                    children: [
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
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, seleccione estado civil';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10.0),
                              child:
                                  _buildFechaNacimientoField(), // Llama a la función que crea el campo de fecha
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: verticalSpacing),
                      if (selectedECivil == 'Casado' ||
                          selectedECivil == 'Unión Libre')
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: nombreConyugeController,
                                label: 'Nombre del Conyuge',
                                icon: Icons.person,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(
                                      r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, ingrese nombres';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: telefonoConyugeController,
                                label: 'Número celular del Conyuge',
                                icon: Icons.person_outline,
                                keyboardType: TextInputType.phone,
                                maxLength:
                                    10, // Especificar la longitud máxima aquí
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly // Solo permite números
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingrese el Teléfono';
                                  } else if (value.length != 10) {
                                    return 'Debe tener 10 dígitos';
                                  }
                                  return null; // Si es válido
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: ocupacionConyugeController,
                                label: 'Ocupación',
                                icon: Icons.person_outline,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(
                                      r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, ingrese el dato';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                  // Sección de Domicilio
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      'Domicilio',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Agrupamos Calle, No. Ext y No. Int
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildDropdown(
                          value: selectedTipoDomicilio,
                          hint: 'Tipo de Domicilio',
                          items: tiposDomicilio,
                          onChanged: (value) {
                            setState(() {
                              selectedTipoDomicilio = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, seleccione Tipo de domicilio';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: _buildTextField(
                          controller: calleController,
                          label: 'Calle',
                          icon: Icons.location_on,
                          keyboardType: TextInputType.streetAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Calle';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: nExtController,
                          label: 'No. Ext',
                          icon: Icons.house,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly // Solo permite números
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese No. Ext';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: nIntController,
                          label: 'No. Int',
                          icon: Icons.house,
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly // Solo permite números
                          ],
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

// Aquí agregamos el nuevo Row que aparece si no es "Propio"
                  // Verificar si `selectedTipoDomicilio` no es vacío y no es "Propio"
                  if (selectedTipoDomicilio != null &&
                      selectedTipoDomicilio != 'Propio') ...[
                    SizedBox(height: 20), // Espacio entre los rows
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildTextField(
                            controller: nombrePropietarioController,
                            label: 'Nombre del Propietario',
                            icon: Icons.person,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(
                                  r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese el nombre del propietario';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: _buildTextField(
                            controller: parentescoPropietarioController,
                            label: 'Parentesco',
                            icon: Icons.family_restroom,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(
                                  r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingrese el parentesco';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: verticalSpacing),

                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildTextField(
                          controller: entreCalleController,
                          label: 'Entre Calle',
                          icon: Icons.location_on,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(
                                r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Entre Calle';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: cpController,
                          label: 'Código Postal',
                          icon: Icons.mail,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          maxLength: 5, // Especificar la longitud máxima aquí
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese el Código Postal';
                            } else if (value.length != 5) {
                              return 'Debe tener 5 dígitos';
                            }
                            return null; // Si es válido
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: tiempoViviendoController,
                          label: 'Tiempo Viviendo',
                          icon: Icons.timelapse,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Tiempo Viviendo';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),

                  // Agrupamos Colonia, Estado y Municipio
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: coloniaController,
                          label: 'Colonia',
                          icon: Icons.location_city,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Colonia';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          value: estadoController.text.isNotEmpty
                              ? estadoController.text
                              : null,
                          hint: 'Estado',
                          items: ['Guerrero'],
                          onChanged: (newValue) {
                            if (newValue != null) {
                              estadoController.text =
                                  newValue; // Actualiza el controlador
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, seleccione el estado';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: municipioController,
                          label: 'Municipio',
                          icon: Icons.map,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(
                                r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingrese Municipio';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      'Datos adicionales',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Agrupamos Calle, No. Ext y No. Int
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: curpController,
                          label: 'CURP',
                          icon: Icons
                              .account_box, // Ícono de identificación más relevante
                          maxLength: 18, // Especificar la longitud máxima aquí
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese el CURP';
                            } else if (value.length != 18) {
                              return 'El dato tener exactamente 18 dígitos';
                            }
                            curpController.text = value.toUpperCase();

                            return null; // Si es válido
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                            controller: rfcController,
                            label: 'RFC',
                            icon: Icons
                                .assignment_ind, // Ícono de archivo/identificación
                            keyboardType: TextInputType.number,
                            maxLength:
                                13, // Especificar la longitud máxima aquí
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingrese el RFC';
                              } else if (value.length != 12 &&
                                  value.length != 13) {
                                return 'El RFC debe tener 12 o 13 caracteres';
                              }

                              rfcController.text = value.toUpperCase();

                              return null;
                            }),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: claveElectorController,
                          label: 'Clave de Elector',
                          icon: Icons
                              .switch_account_rounded, // Ícono de identificación más relevante
                          maxLength: 18, // Especificar la longitud máxima aquí
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese la Clave de Elector';
                            } else if (value.length != 18) {
                              return 'El dato tener exactamente 18 dígitos';
                            }
                            claveElectorController.text = value.toUpperCase();

                            return null; // Si es válido
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaCuentaBancaria() {
    @override
    void initState() {
      super.initState();

      // Listener para el número de cuenta
      _numCuentaController.addListener(() {
        if (clienteData != null && clienteData.containsKey('cuentabanco')) {
          clienteData['cuentabanco'][0]['numCuenta'] =
              _numCuentaController.text;
        }
      });

      // Listener para el número de tarjeta
      _numTarjetaController.addListener(() {
        if (clienteData != null && clienteData.containsKey('cuentabanco')) {
          clienteData['cuentabanco'][0]['numTarjeta'] =
              _numTarjetaController.text;
        }
      });

      _claveInterbancariaController.addListener(() {
        if (clienteData != null && clienteData.containsKey('cuentabanco')) {
          clienteData['cuentabanco'][0]['clbIntBanc'] =
              _claveInterbancariaController.text;
        }
      });
    }

    int pasoActual = 2; // Paso actual en la página de "Cuenta Bancaria"

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contenedor azul a la izquierda para los pasos
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF5162F6),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          width: 250,
          height: 500,
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildPasoItem(1, "Información Personal", pasoActual == 1),
              SizedBox(height: 20),
              _buildPasoItem(2, "Cuenta Bancaria", pasoActual == 2),
              SizedBox(height: 20),
              _buildPasoItem(3, "Ingresos y Egresos", pasoActual == 3),
              SizedBox(height: 20),
              _buildPasoItem(4, "Referencias", pasoActual == 4),
            ],
          ),
        ),
        SizedBox(width: 50), // Espacio entre el contenedor azul y la lista

        // Contenido principal: Formulario de cuenta bancaria
        Expanded(
          child: Form(
            key: _cuentaBancariaFormKey, // Usar el GlobalKey aquí
            child: Column(
              children: [
                SizedBox(height: 20),
                CheckboxListTile(
                  title: Text("No tiene cuenta bancaria"),
                  value: _noCuentaBancaria,
                  onChanged: (bool? value) {
                    setState(() {
                      _noCuentaBancaria = value ?? false;
                      if (_noCuentaBancaria) {
                        _nombreBanco =
                            'No asignado'; // Internamente 'No asignado'
                        _numCuentaController.clear();
                        _numTarjetaController.clear();
                      } else {
                        // Si es false, vuelve a asignar los valores previos si es necesario
                        _nombreBanco =
                            'No asignado'; // Puedes poner el valor predeterminado si lo deseas
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.symmetric(horizontal: 0),
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(height: 20),
                if (!_noCuentaBancaria) ...[
                  // Dropdown que no mostrará 'No asignado'
                  _buildDropdown(
                    value: _nombreBanco == 'No asignado'
                        ? null
                        : _nombreBanco, // Ignora 'No asignado'
                    hint: 'Seleccione un Banco',
                    items: _bancos
                        .where((item) =>
                            item !=
                            'No asignado') // Filtra 'No asignado' de las opciones
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _nombreBanco = value ??
                            'No asignado'; // Asigna 'No asignado' si es null
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Por favor seleccione un banco';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10),
                  if (_nombreBanco == "Santander")
                    _buildTextField(
                      controller: _claveInterbancariaController,
                      label: 'Clave Interbancaria',
                      icon: Icons.security,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      maxLength:
                          18, // Longitud estándar para claves interbancarias
                      validator: (value) {
                        if (_nombreBanco == "Santander") {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese la clave interbancaria';
                          } else if (value.length != 18) {
                            return 'La clave interbancaria debe tener 18 dígitos';
                          }
                        }
                        return null;
                      },
                    ),
                  SizedBox(height: 10),
                  _buildTextField(
                    controller: _numCuentaController,
                    label: 'Número de Cuenta',
                    icon: Icons.account_balance,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    keyboardType: TextInputType.number,
                    maxLength: 11, // Especificar la longitud máxima aquí
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el número de cuenta';
                      } else if (value.length != 11) {
                        return 'El número de cuenta debe tener exactamente 11 dígitos';
                      }
                      return null; // Si es válido
                    },
                  ),
                  SizedBox(height: 10),
                  _buildTextField(
                    controller: _numTarjetaController,
                    label: 'Número de Tarjeta',
                    icon: Icons.credit_card,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 16, // Especificar la longitud máxima aquí
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el número de tarjeta';
                      } else if (value.length != 16) {
                        return 'El número de tarjeta debe tener exactamente 16 dígitos';
                      }
                      return null; // Si es válido
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paginaIngresosEgresos() {
    int pasoActual = 3; // Paso actual en la página de "Ingresos y Egresos"

    // Función para manejar 'No asignado' y mostrar un texto más adecuado
    String _getIngresoEgresoData(String data) {
      print(
          "Valor de data en _getIngresoEgresoData: $data"); // Imprimir el valor
      return data == 'No asignado' ? 'No asignado' : data ?? 'No asignado';
    }

    // Función que verifica si el ingreso/egreso tiene datos válidos
    bool _isIngresoEgresoValido(Map ingresoEgreso) {
      print(
          "Ingreso/Egreso a evaluar: $ingresoEgreso"); // Imprimir el objeto a evaluar

      // Verificamos si los campos clave tienen valores válidos
      bool isValid = ingresoEgreso['tipo_info'] != 'No asignado' &&
          ingresoEgreso['años_actividad'] != 'No asignado' &&
          ingresoEgreso['descripcion'] != 'No asignado' &&
          ingresoEgreso['monto_semanal'] != 'No asignado';

      print(
          "Es ingreso/egreso válido: $isValid"); // Imprimir el resultado de la validación
      return isValid;
    }

    print(
        "Número de ingresos y egresos: ${ingresosEgresos.length}"); // Ver cuántos elementos hay

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contenedor azul a la izquierda para los pasos
        Container(
          decoration: BoxDecoration(
              color: Color(0xFF5162F6),
              borderRadius: BorderRadius.all(Radius.circular(20))),
          width: 250,
          height: 500,
          padding: EdgeInsets.symmetric(
              vertical: 20, horizontal: 10), // Espaciado vertical
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildPasoItem(1, "Información Personal", pasoActual == 1),
              SizedBox(height: 20),
              _buildPasoItem(2, "Cuenta Bancaria", pasoActual == 2),
              SizedBox(height: 20),
              _buildPasoItem(3, "Ingresos y Egresos", pasoActual == 3),
              SizedBox(height: 20),
              _buildPasoItem(4, "Referencias", pasoActual == 4),
            ],
          ),
        ),
        SizedBox(width: 50), // Espacio entre el contenedor azul y la lista

        // Contenido principal: Lista de ingresos y egresos
        Expanded(
          child: Form(
            key: _ingresosEgresosFormKey, // Usar el GlobalKey aquí
            child: Column(
              children: [
                Expanded(
                  child: ingresosEgresos.isEmpty ||
                          !ingresosEgresos.any(_isIngresoEgresoValido)
                      ? Center(
                          child: Text(
                            'No hay ingresos o egresos agregados',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: ingresosEgresos.length,
                          itemBuilder: (context, index) {
                            final item = ingresosEgresos[index];

                            // Si el ingreso/egreso no es válido, no mostrar la tarjeta
                            if (!_isIngresoEgresoValido(item)) {
                              return SizedBox.shrink(); // No muestra nada
                            }

                            return Card(
                              margin: EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              child: ListTile(
                                title: Text(item['descripcion']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${_getIngresoEgresoData(item['tipo_info'])} - \$${_getIngresoEgresoData(item['monto_semanal'])}'),
                                    Text(
                                        'Años en Actividad - ${_getIngresoEgresoData(item['años_actividad'])}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon:
                                          Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () =>
                                          _mostrarDialogIngresoEgreso(
                                              index: index, item: item),
                                    ),
                                    IconButton(
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          ingresosEgresos.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 10),
                  child: ElevatedButton(
                    onPressed: _mostrarDialogIngresoEgreso,
                    child: Text('Añadir Ingreso/Egreso'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getReferenciaData(String? data) {
    return data == null || data == 'No asignado' ? 'No asignado' : data;
  }

  Widget _paginaReferencias() {
    int pasoActual = 4; // Paso actual en la página de "Ingresos y Egresos"

    // Función que verifica si la referencia tiene datos válidos
    bool _isReferenciaValida(Map referencia) {
      // Verificamos si los campos clave tienen valores válidos
      return referencia['nombresRef'] != 'No asignado' &&
          referencia['apellidoPRef'] != 'No asignado' &&
          referencia['telefonoRef'] != 'No asignado' &&
          referencia['tiempoConocerRef'] != 'No asignado' &&
          referencia['parentescoRef'] != 'No asignado' &&
          referencia['tipoDomicilioRef'] != 'No asignado' &&
          referencia['nombrePropietarioRef'] != 'No asignado';
    }

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF5162F6),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          width: 250,
          height: 500,
          padding: EdgeInsets.symmetric(
              vertical: 20, horizontal: 10), // Espaciado vertical
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Paso 1
              _buildPasoItem(1, "Información Personal", pasoActual == 1),
              SizedBox(height: 20),

              // Paso 2
              _buildPasoItem(2, "Cuenta Bancaria", pasoActual == 2),
              SizedBox(height: 20),

              // Paso 3
              _buildPasoItem(3, "Ingresos y Egresos", pasoActual == 3),
              SizedBox(height: 20),

              // Paso 4
              _buildPasoItem(4, "Referencias", pasoActual == 4),
            ],
          ),
        ),
        SizedBox(width: 50), // Espacio entre el contenedor rojo y la lista
        Expanded(
          child: Form(
            key: _referenciasFormKey,
            child: Column(
              children: [
                Expanded(
                  child: referencias.isEmpty ||
                          !referencias.any(_isReferenciaValida)
                      ? Center(
                          child: Text(
                            'No hay referencias agregadas',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: referencias.length,
                          itemBuilder: (context, index) {
                            final referencia = referencias[index];

                            // Si la referencia no es válida, no mostrar la tarjeta
                            if (!_isReferenciaValida(referencia)) {
                              return SizedBox.shrink(); // No muestra nada
                            }

                            return Card(
                              margin: EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              child: ListTile(
                                title: Text(
                                  '${_getReferenciaData(referencia['nombresRef'])} ${_getReferenciaData(referencia['apellidoPRef'])} ${_getReferenciaData(referencia['apellidoMRef'])}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Datos de la referencia
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            'Parentesco: ${_getReferenciaData(referencia['parentescoRef'])}'),
                                        Text(
                                            'Teléfono: ${_getReferenciaData(referencia['telefonoRef'])}'),
                                        Text(
                                            'Tiempo de conocer: ${_getReferenciaData(referencia['tiempoConocerRef'])}'),
                                      ],
                                    ),

                                    SizedBox(height: 10), // Separador

                                    // Datos del domicilio de la referencia
                                    Text('Domicilio',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                            child: Text(
                                                'Tipo: ${_getReferenciaData(referencia['tipoDomicilioRef'])}')),
                                        Expanded(
                                          child: Text(
                                              'Propietario: ${_getReferenciaData(referencia['nombrePropietarioRef'])}'),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                            child: Text(
                                                'Parentesco con propietario: ${_getReferenciaData(referencia['parentescoRefProp'])}')),
                                        Expanded(
                                            child: Text(
                                                'Calle: ${_getReferenciaData(referencia['calleRef'])}')),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                            child: Text(
                                                'Num Ext: ${_getReferenciaData(referencia['nExtRef'])}')),
                                        Expanded(
                                            child: Text(
                                                'Num Int: ${_getReferenciaData(referencia['nIntRef'])}')),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                            child: Text(
                                                'Entre calles: ${_getReferenciaData(referencia['entreCalleRef'])}')),
                                        Expanded(
                                            child: Text(
                                                'Tiempo viviendo: ${_getReferenciaData(referencia['tiempoViviendoRef'])}')),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                            child: Text(
                                                'Colonia: ${_getReferenciaData(referencia['coloniaRef'])}')),
                                        Expanded(
                                            child: Text(
                                                'CP: ${_getReferenciaData(referencia['cpRef'])}')),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                            child: Text(
                                                'Estado: ${_getReferenciaData(referencia['estadoRef'])}')),
                                        Expanded(
                                            child: Text(
                                                'Municipio: ${_getReferenciaData(referencia['municipioRef'])}')),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon:
                                          Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _mostrarDialogReferencia(
                                          index: index, item: referencia),
                                    ),
                                    IconButton(
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          referencias.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 10),
                  child: ElevatedButton(
                    onPressed: _mostrarDialogReferencia,
                    child: Text('Añadir Referencia'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarDialogReferencia({int? index, Map<String, dynamic>? item}) {
    // Obtener estado del tema
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final GlobalKey<FormState> dialogAddReferenciasFormKey =
        GlobalKey<FormState>();

    // Inicialización de los valores del dropdown
    String? selectedParentesco = (item != null &&
            item['parentescoRef'] != null &&
            ['Padre', 'Madre', 'Hermano/a', 'Amigo/a', 'Vecino', 'Otro']
                .contains(item['parentescoRef']))
        ? item['parentescoRef']
        : null; // Asignar null si el valor no es válido

    String? selectedTipoDomicilioRef = (item != null &&
            item['tipoDomicilioRef'] != null &&
            ['Propio', 'Alquilado', 'Prestado', 'Otro']
                .contains(item['tipoDomicilioRef']))
        ? item['tipoDomicilioRef']
        : null; // Asignar null si el valor no es válido

    // Controladores
    final nombresRefController =
        TextEditingController(text: item?['nombresRef'] ?? '');
    final apellidoPRefController =
        TextEditingController(text: item?['apellidoPRef'] ?? '');
    final apellidoMRefController =
        TextEditingController(text: item?['apellidoMRef'] ?? '');
    final telefonoRefController =
        TextEditingController(text: item?['telefonoRef'] ?? '');
    final tiempoConocerRefController =
        TextEditingController(text: item?['tiempoConocerRef'] ?? '');

    // Controladores de domicilio de referencia
    final nombrePropietarioRefController =
        TextEditingController(text: item?['nombrePropietarioRef'] ?? '');
    final calleRefController =
        TextEditingController(text: item?['calleRef'] ?? '');
    final nExtRefController =
        TextEditingController(text: item?['nExtRef'] ?? '');
    final nIntRefController =
        TextEditingController(text: item?['nIntRef'] ?? '');
    final entreCalleRefController =
        TextEditingController(text: item?['entreCalleRef'] ?? '');
    final parentescoRefPropController =
        TextEditingController(text: item?['parentescoRefProp'] ?? '');
    final coloniaRefController =
        TextEditingController(text: item?['coloniaRef'] ?? '');
    final cpRefController = TextEditingController(text: item?['cpRef'] ?? '');
    final estadoRefController =
        TextEditingController(text: item?['estadoRef'] ?? '');
    final municipioRefController =
        TextEditingController(text: item?['municipioRef'] ?? '');
    final tiempoViviendoRefController =
        TextEditingController(text: item?['tiempoViviendoRef'] ?? '');

    // Configuración del diálogo
    final width = MediaQuery.of(context).size.width * 0.7;
    final height = MediaQuery.of(context).size.height * 0.55;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        title: Center(
          child: Text(
            index == null ? 'Nueva Referencia' : 'Editar Referencia',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black),
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Container(
            width: width,
            height: height,
            child: SingleChildScrollView(
              child: Form(
                key: dialogAddReferenciasFormKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Información de la persona de referencia',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Divider(color: Colors.grey[300]),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: nombresRefController,
                              label: 'Nombres',
                              icon: Icons.person,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingrese el nombre';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: apellidoPRefController,
                              label: 'Apellido Paterno',
                              icon: Icons.person_outline,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingrese el apellido paterno';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: apellidoMRefController,
                              label: 'Apellido Materno',
                              icon: Icons.person_outline,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingrese el apellido materno';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            _buildDropdown(
                              value: selectedParentesco,
                              hint: 'Parentesco',
                              items: [
                                'Padre',
                                'Madre',
                                'Esposo/a',
                                'Hermano/a',
                                'Amigo/a',
                                'Vecino',
                                'Otro'
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedParentesco = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, seleccione el parentesco';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: telefonoRefController,
                              label: 'Teléfono',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              maxLength:
                                  10, // Especificar la longitud máxima aquí
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingrese el teléfono';
                                } else if (value.length != 10) {
                                  return 'Debe tener 10 dígitos';
                                }
                                return null; // Si es válido
                              },
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: tiempoConocerRefController,
                              label: 'Tiempo de conocer',
                              icon: Icons.timelapse_rounded,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingrese el tiempo de conocer';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datos del domicilio de la referencia',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Divider(color: Colors.grey[300]),
                            Text(
                              'Los datos de domicilio de la referencia son opcionales',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey[700]),
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildDropdown(
                                    value: selectedTipoDomicilioRef,
                                    hint: 'Tipo Domicilio',
                                    items: [
                                      'Propio',
                                      'Alquilado',
                                      'Prestado',
                                      'Otro'
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        selectedTipoDomicilioRef = value;
                                        // Imprimir en consola para verificar el valor seleccionado
                                        print(
                                            "selectedTipoDomicilioRef: $selectedTipoDomicilioRef");
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 6,
                                  child: _buildTextField(
                                    controller: calleRefController,
                                    label: 'Calle',
                                    icon: Icons.location_on,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(
                                          r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                                    ],
                                    /*   validator: (value) => value?.isEmpty == true
                                        ? 'Por favor, ingrese Calle'
                                        : null, */
                                  ),
                                ),
                              ],
                            ),

                            // Mostrar los campos adicionales solo si selectedTipoDomicilioRef es diferente de Propio
                            if (selectedTipoDomicilioRef != null &&
                                selectedTipoDomicilioRef != 'Propio') ...[
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _buildTextField(
                                      controller:
                                          nombrePropietarioRefController,
                                      label: 'Nombre del Propietario',
                                      icon: Icons.person,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(
                                            r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    flex: 4,
                                    child: _buildTextField(
                                      controller: parentescoRefPropController,
                                      label: 'Parentesco con propietario',
                                      icon: Icons.family_restroom,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(
                                            r'[a-zA-ZÀ-ÿ ]')), // Permite letras y espacios
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: nExtRefController,
                                    label: 'No. Ext',
                                    icon: Icons.house,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    /*  validator: (value) => value?.isEmpty == true
                                        ? 'Por favor, ingrese No. Ext'
                                        : null, */
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: nIntRefController,
                                    label: 'No. Int',
                                    icon: Icons.house,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: entreCalleRefController,
                              label: 'Entre Calle',
                              icon: Icons.location_on,
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: coloniaRefController,
                                    label: 'Colonia',
                                    icon: Icons.location_city,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _buildTextField(
                                    controller: cpRefController,
                                    label: 'Código Postal',
                                    icon: Icons.mail,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    maxLength:
                                        5, // Especificar la longitud máxima aquí
                                    validator: (value) {
                                      // Verificamos si el campo está vacío
                                      if (value == null || value.isEmpty) {
                                        return null; // No se valida si está vacío
                                      }
                                      // Validamos si tiene exactamente 5 dígitos cuando hay algo escrito
                                      if (value.length != 5) {
                                        return 'Debe tener 5 dígitos';
                                      }
                                      return null; // Si es válido
                                    },
                                  ),
                                )
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDropdown(
                                    value: estadoRefController.text.isNotEmpty
                                        ? estadoRefController.text
                                        : null,
                                    hint: 'Estado',
                                    items: ['Guerrero'],
                                    onChanged: (value) {
                                      setState(() {
                                        estadoRefController.text = value ?? '';
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _buildTextField(
                                    controller: municipioRefController,
                                    label: 'Municipio',
                                    icon: Icons.map,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            _buildTextField(
                              controller: tiempoViviendoRefController,
                              label: 'Tiempo Viviendo',
                              icon: Icons.timelapse,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (dialogAddReferenciasFormKey.currentState!.validate()) {
                // Recoger los datos de los controladores
                final nuevaReferencia = {
                  'nombresRef': nombresRefController.text.isNotEmpty
                      ? nombresRefController.text
                      : '',
                  'apellidoPRef': apellidoPRefController.text.isNotEmpty
                      ? apellidoPRefController.text
                      : '',
                  'apellidoMRef': apellidoMRefController.text.isNotEmpty
                      ? apellidoMRefController.text
                      : '',
                  'parentescoRef': selectedParentesco ?? '',
                  'telefonoRef': telefonoRefController.text.isNotEmpty
                      ? telefonoRefController.text
                      : '',
                  'tiempoConocerRef': tiempoConocerRefController.text.isNotEmpty
                      ? tiempoConocerRefController.text
                      : '',
                  'tipoDomicilioRef': selectedTipoDomicilioRef ?? '',
                  'calleRef': calleRefController.text.isNotEmpty
                      ? calleRefController.text
                      : '',
                  'nExtRef': nExtRefController.text.isNotEmpty
                      ? nExtRefController.text
                      : '',
                  'nIntRef': nIntRefController.text.isNotEmpty
                      ? nIntRefController.text
                      : '',
                  'entreCalleRef': entreCalleRefController.text.isNotEmpty
                      ? entreCalleRefController.text
                      : '',
                  'coloniaRef': coloniaRefController.text.isNotEmpty
                      ? coloniaRefController.text
                      : '',
                  'cpRef': cpRefController.text.isNotEmpty
                      ? cpRefController.text
                      : '',
                  'estadoRef': estadoRefController.text.isNotEmpty
                      ? estadoRefController.text
                      : '',
                  'municipioRef': municipioRefController.text.isNotEmpty
                      ? municipioRefController.text
                      : '',
                  'tiempoViviendoRef':
                      tiempoViviendoRefController.text.isNotEmpty
                          ? tiempoViviendoRefController.text
                          : '',
                  if (selectedTipoDomicilioRef != 'Propio')
                    'nombrePropietarioRef':
                        nombrePropietarioRefController.text.isNotEmpty
                            ? nombrePropietarioRefController.text
                            : '',
                  if (selectedTipoDomicilioRef != 'Propio')
                    'parentescoRefProp':
                        parentescoRefPropController.text.isNotEmpty
                            ? parentescoRefPropController.text
                            : '',
                };

                // Lógica para agregar o actualizar la referencia
                setState(() {
                  if (index == null) {
                    referencias
                        .add(nuevaReferencia); // Agregar nueva referencia
                  } else {
                    referencias[index] =
                        nuevaReferencia; // Actualizar referencia existente
                  }
                });

                Navigator.pop(context); // Cerrar el formulario
              }
            },
            child: Text(index == null ? 'Añadir' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogIngresoEgreso({int? index, Map<String, dynamic>? item}) {
    // Ajustar el valor seleccionado
    String? selectedTipo = item?['tipo_info'];

    // Imprimir el valor original de selectedTipo
    print("Valor original de selectedTipo: $selectedTipo");

    // Si el valor es 'No asignado', asignamos null para no mostrarlo en el dropdown
    if (selectedTipo == 'No asignado') {
      selectedTipo = null;
    }

    // Imprimir el valor de selectedTipo después de la comprobación
    print(
        "Valor de selectedTipo después de comprobar 'No asignado': $selectedTipo");

    final descripcionController =
        TextEditingController(text: item?['descripcion'] ?? '');
    final montoController =
        TextEditingController(text: item?['monto_semanal']?.toString() ?? '');

    final anosenActividadController =
        TextEditingController(text: item?['años_actividad']?.toString() ?? '');

    // Crea un nuevo GlobalKey para el formulario del diálogo
    final GlobalKey<FormState> dialogAddIngresosEgresosFormKey =
        GlobalKey<FormState>();

    final width = MediaQuery.of(context).size.width * 0.4;
    final height = MediaQuery.of(context).size.height * 0.5;

    // Obtener estado del tema
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Imprimir la lista original de tipos de ingreso/egreso
    print("Lista original de tiposIngresoEgreso: $tiposIngresoEgreso");

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          index == null ? 'Nuevo Ingreso/Egreso' : 'Editar Ingreso/Egreso',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Filtrar 'No asignado' de la lista
            List<String> tiposFiltrados = tiposIngresoEgreso
                .where((item) => item != 'No asignado')
                .toList();

            // Imprimir la lista filtrada
            print("Lista filtrada de tiposIngresoEgreso: $tiposFiltrados");

            return Container(
              width: width,
              height: height,
              child: Form(
                key: dialogAddIngresosEgresosFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdown(
                      value: selectedTipo,
                      hint: 'Tipo',
                      items: tiposFiltrados, // Usamos la lista filtrada
                      onChanged: (value) {
                        setState(() {
                          selectedTipo = value;
                        });
                      },
                      fontSize: 14.0,
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor, seleccione el tipo';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    _buildTextField(
                      controller: descripcionController,
                      label: 'Descripción',
                      icon: Icons.description,
                      fontSize: 14.0,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese una descripción';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    _buildTextField(
                      controller: montoController,
                      label: 'Monto',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      fontSize: 14.0,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese el monto';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'Ingrese un monto válido';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    _buildTextField(
                      controller: anosenActividadController,
                      label: 'Años en Actividad',
                      icon: Icons.timelapse,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      fontSize: 14.0,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese un dato';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.grey[300] : Colors.grey,
            ),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (dialogAddIngresosEgresosFormKey.currentState!.validate() &&
                  selectedTipo != null) {
                final nuevoItem = {
                  'tipo_info': selectedTipo,
                  'descripcion': descripcionController.text,
                  'monto_semanal': montoController.text,
                  'años_actividad': anosenActividadController.text,
                };
                setState(() {
                  if (index == null) {
                    ingresosEgresos.add(nuevoItem);
                  } else {
                    ingresosEgresos[index] = nuevoItem;
                  }
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDarkMode ? Color(0xFF3A4AD1) : Color(0xFF5162F6),
              foregroundColor: Colors.white,
            ),
            child: Text(index == null ? 'Añadir' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarAlerta(String mensaje) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    double fontSize = 12.0,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters, // Nuevo parámetro
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(fontSize: fontSize),
      ),
      textCapitalization: TextCapitalization.characters,
      validator: validator,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ...(inputFormatters ?? []), // Agrega los formateadores personalizados
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    double fontSize = 12.0,
    String? Function(String?)? validator,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final textColor = isDarkMode ? Colors.white : Colors.black;
    final borderColor =
        isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700;
    final focusedBorderColor = isDarkMode ? Color(0xFF5162F6) : Colors.black;

    return DropdownButtonFormField<String>(
      value: value,
      hint: value == null
          ? Text(
              hint,
              style: TextStyle(
                  fontSize: fontSize,
                  color: isDarkMode ? Colors.grey[300] : Colors.black),
            )
          : null,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: TextStyle(fontSize: fontSize, color: textColor),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: value != null ? hint : null,
        labelStyle: TextStyle(color: isDarkMode ? Colors.grey[300] : null),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: focusedBorderColor),
        ),
        fillColor: isDarkMode ? Color(0xFF303030) : Colors.white,
        filled: true,
      ),
      style: TextStyle(fontSize: fontSize, color: textColor),
      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
      icon: Icon(Icons.arrow_drop_down,
          color: isDarkMode ? Colors.grey[300] : Colors.black),
    );
  }

  // El widget para el campo de fecha
  Widget _buildFechaNacimientoField() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            locale: const Locale('es', 'ES'),
            builder: (BuildContext context, Widget? child) {
              return Theme(
                data: isDarkMode
                    ? ThemeData.dark().copyWith(
                        colorScheme: ColorScheme.dark().copyWith(
                          primary: const Color(0xFF5162F6),
                          surface: const Color(0xFF303030),
                          onSurface: Colors.white,
                        ),
                        dialogBackgroundColor:
                            const Color.fromARGB(255, 43, 43, 43),
                      )
                    : ThemeData.light().copyWith(
                        primaryColor: Colors.white,
                        colorScheme: ColorScheme.fromSwatch().copyWith(
                          primary: const Color(0xFF5162F6),
                        ),
                      ),
                child: child!,
              );
            },
          );
          if (pickedDate != null) {
            setState(() {
              selectedDate = pickedDate;
              _fechaController.text =
                  DateFormat('dd/MM/yyyy').format(selectedDate!);
            });
          }
        },
        child: AbsorbPointer(
          child: TextFormField(
            controller: _fechaController,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: 'Fecha de Nacimiento',
              labelStyle: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.white30 : Colors.black26,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: const Color(0xFF5162F6),
                ),
              ),
              hintText: 'Selecciona una fecha',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white38 : Colors.black38,
              ),
              fillColor: isDarkMode
                  ? const Color.fromARGB(255, 48, 48, 48)
                  : Colors.white,
              filled: true,
            ),
            validator: (value) {
              if (selectedDate == null) {
                return 'Por favor, selecciona una fecha de nacimiento';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  void _agregarCliente() async {
    setState(() {
      _isLoading = true; // Activa el indicador de carga
    });

    final clienteResponse = await _enviarCliente();
    if (clienteResponse != null) {
      final idCliente = clienteResponse["idclientes"];
      print("ID del cliente creado: $idCliente");

      if (idCliente != null) {
        // Paso 2: Crear cuenta bancaria
        await _enviarCuentaBanco(idCliente);

        // Paso 3: Crear domicilio
        await _enviarDomicilio(idCliente);

        // Paso 4: Crear datos adicionales
        await _enviarDatosAdicionales(idCliente);

        // Paso 5: Crear ingresos
        await _enviarIngresos(idCliente);

        // Paso 6: Crear referencias
        await _enviarReferencias(idCliente);

        // Llama al callback para refrescar la lista de clientes
        widget.onClienteAgregado!();

        // Muestra el SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente agregado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Cierra el diálogo
        Navigator.of(context).pop();
      } else {
        print("Error: idCliente es nulo.");
      }
    } else {
      print("Error: clienteResponse es nulo.");
    }

    setState(() {
      _isLoading = false; // Desactiva el indicador de carga
    });
  }

  Future<Map<String, dynamic>?> _enviarCliente() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    final url = Uri.parse("http://$baseUrl/api/v1/clientes");

    final datosCliente = {
      "tipo_cliente": selectedTipoCliente ?? "",
      "ocupacion": ocupacionController.text,
      "nombres": nombresController.text,
      "apellidoP": apellidoPController.text,
      "apellidoM": apellidoMController.text,
      "fechaNac": selectedDate != null
          ? "${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}"
          : null,
      "sexo": selectedSexo ?? "",
      "telefono": telefonoClienteController.text,
      "eCivil": selectedECivil ?? "",
      "email": emailClientecontroller.text,
      "dependientes_economicos": depEconomicosController.text,
      "nombreConyuge": nombreConyugeController.text,
      "telefonoConyuge": telefonoConyugeController.text,
      "ocupacionConyuge": ocupacionConyugeController.text
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "tokenauth": token, // Agregar token
        },
        body: jsonEncode(datosCliente),
      );
      print("Código de estado de la respuesta: ${response.statusCode}");
      print(
          "Cuerpo de la respuesta: ${response.body}"); // Imprime el cuerpo completo

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        _handleApiError(response, 'Error al crear cliente');
      }
    } catch (e) {
      _handleNetworkError(e);
    }
    return null;
  }

  Future<void> _enviarCuentaBanco(String idCliente) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    final url = Uri.parse("http://$baseUrl/api/v1/cuentabanco");

    final datosCuentaBanco = {
      "idclientes": idCliente,
      "iddetallegrupos": "",
      "nombreBanco": _nombreBanco ?? "",
      "numCuenta": _numCuentaController.text,
      "numTarjeta": _numTarjetaController.text,
      "clbIntBanc": _claveInterbancariaController.text
    };

    print('IMPRESION domicilio en array!');
    print(jsonEncode(datosCuentaBanco));

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "tokenauth": token,
        },
        body: jsonEncode(datosCuentaBanco),
      );
      print(
          "Código de estado de la respuesta de cuenta bancaria: ${response.statusCode}");
      print("Cuerpo de la respuesta de cuenta bancaria: ${response.body}");

      if (response.statusCode == 201) {
        print("Cuenta bancaria creada correctamente");
      } else {
        _handleApiError(response, 'Error en cuenta bancaria');
      }
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<void> _enviarDomicilio(String idCliente) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    final url = Uri.parse("http://$baseUrl/api/v1/domicilios");

    // Convertir los datos en un array que contiene un solo map
    final datosDomicilio = [
      {
        "idclientes": idCliente,
        "tipo_domicilio": selectedTipoDomicilio ?? "",
        "nombre_propietario": nombrePropietarioController.text,
        "parentesco": parentescoPropietarioController.text,
        "calle": calleController.text,
        "nExt": nExtController.text,
        "nInt": nIntController.text,
        "entreCalle": entreCalleController.text,
        "colonia": coloniaController.text,
        "cp": cpController.text,
        "estado": estadoController.text,
        "municipio": municipioController.text,
        "tiempoViviendo": tiempoViviendoController.text
      }
    ];

    print('IMPRESION domicilio en array!');
    print(jsonEncode(datosDomicilio));

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "tokenauth": token,
        },
        body: jsonEncode(datosDomicilio),
      );
      if (response.statusCode == 201) {
        print("Domicilio agregado correctamente");
      } else {
        _handleApiError(response, 'Error al crear domicilio');
      }
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<void> _enviarDatosAdicionales(String idCliente) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    final url = Uri.parse("http://$baseUrl/api/v1/datosadicionales");

    final datosAdicionales = {
      "idclientes": idCliente,
      "curp": curpController.text,
      "rfc": rfcController.text,
      "clvElector": claveElectorController.text
    };

    print('IMPRESION datos adicionales!');
    print(jsonEncode({
      "curp": curpController.text,
      "rfc": rfcController.text,
      "clvElector": claveElectorController.text
    }));

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "tokenauth": token, // Agregar token
        },
        body: jsonEncode(datosAdicionales),
      );
      if (response.statusCode == 201) {
        print("Datos adicionales agregados correctamente");
      } else {
        print('Respuesta ${response.body}');
        _handleApiError(response, 'Error al crear Datos Adicionales');
      }
    } catch (e) {
      _handleNetworkError(e);
    }
    return null;
  }

  Future<void> _enviarIngresos(String idCliente) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    final url = Uri.parse("http://$baseUrl/api/v1/ingresos");

    final ingresosData = ingresosEgresos
        .map((item) => {
              "idclientes": idCliente,
              "idinfo": tiposIngresoEgresoIds[item['tipo_info']] ??
                  0, // Obtener el ID en lugar del texto
              "años_actividad": item['años_actividad'] ?? 0,
              "descripcion": item['descripcion'] ?? "",
              "monto_semanal": item['monto_semanal'] ?? 0
            })
        .toList();

    // Imprimir los datos antes de enviarlos
    print("Datos a enviar para ingresos:");
    print(jsonEncode(ingresosData));

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "tokenauth": token, // Agregar token
        },
        body: jsonEncode(ingresosData),
      );
      if (response.statusCode == 201) {
        print("Ingresos agregados correctamente");
      } else {
        _handleApiError(response, 'Error al crear ingresos');
      }
    } catch (e) {
      _handleNetworkError(e);
    }
    return null;
  }

  Future<void> _enviarReferencias(String idCliente) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';

    final url = Uri.parse("http://$baseUrl/api/v1/referencia");

    final referenciasData = referencias
        .map((referencia) => {
              "idclientes": idCliente,
              "nombres": referencia['nombresRef'] ?? "",
              "apellidoP": referencia['apellidoPRef'] ?? "",
              "apellidoM": referencia['apellidoMRef'] ?? "",
              "parentesco": referencia['parentescoRef'] ?? "",
              "telefono": referencia['telefonoRef'] ?? "",
              "tiempoConocer": referencia['tiempoConocerRef'] ?? "",
              //DOMICILIO
              "tipo_domicilio": referencia['tipoDomicilioRef'] ?? "",
              "nombre_propietario": referencia['nombrePropietarioRef'] ?? "",
              "parentescoRefProp": referencia['parentescoRefProp'] ?? "",
              "calle": referencia['calleRef'] ?? "",
              "nExt": referencia['nExtRef'] ?? "",
              "nInt": referencia['nIntRef'] ?? "",
              "entreCalle": referencia['entreCalleRef'] ?? "",
              "colonia": referencia['coloniaRef'] ?? "",
              "cp": referencia['cpRef'] ?? "",
              "estado": referencia['estadoRef'] ?? "",
              "municipio": referencia['municipioRef'] ?? "",
              "tiempoViviendo": referencia['tiempoViviendoRef'] ?? ""
            })
        .toList(growable: false);
    print("Datos a enviar para referencias:");
    print(jsonEncode(referenciasData));

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "tokenauth": token, // Agregar token
        },
        body: jsonEncode(referenciasData),
      );
      if (response.statusCode == 201) {
        print("Referencias agregadas correctamente");
      } else {
        _handleApiError(response, 'Error en crear referencias');
      }
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  void imprimirDatosCliente() {
    final datosCliente = {
      "InformacionPersonal": {
        "nombres": nombresController.text,
        "apellidoPaterno": apellidoPController.text,
        "apellidoMaterno": apellidoMController.text,
        "tipoCliente": selectedTipoCliente ?? "",
        "sexo": selectedSexo ?? "",
        "estadoCivil": selectedECivil ?? "",
        "fechaNacimiento": selectedDate != null
            ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
            : null,
        "ocupacion": ocupacionController.text,
        "dependientes_economicos": depEconomicosController.text,
        "telefono": telefonoClienteController.text,
        "correoElectronico": emailClientecontroller.text,
        "nombreConyuge": nombreConyugeController.text,
        "numeroConyuge": telefonoConyugeController.text,
        "ocupacionConyuge": ocupacionConyugeController.text,
        "domicilio": {
          "tipoDomicilio": selectedTipoDomicilio ?? "",
          "nombredelPropietario": nombrePropietarioController.text,
          "parentescoPropietario": parentescoPropietarioController.text,
          "calle": calleController.text,
          "noExt": nExtController.text,
          "noInt": nIntController.text,
          "entreCalle": entreCalleController.text,
          "codigoPostal": cpController.text,
          "tiempoViviendo": tiempoViviendoController.text,
          "colonia": coloniaController.text,
          "estado": estadoController.text,
          "municipio": municipioController.text
        },
        "curp": curpController.text,
        "rfc": rfcController.text,
      },
      "IngresosEgresos": ingresosEgresos
          .map((item) => {
                "descripcion": item['descripcion'] ?? "",
                "tipo": item['tipo'] ?? "",
                "monto": item['monto'] ?? 0,
                "añosenActividad": item['años_actividad'] ?? 0
              })
          .toList(),
      "Referencias": referencias
          .map((referencia) => {
                "nombres": referencia['nombres'] ?? "",
                "apellidoP": referencia['apellidoP'] ?? "",
                "apellidoM": referencia['apellidoM'] ?? "",
                "parentesco": referencia['parentesco'] ?? "",
                "telefono": referencia['telefono'] ?? "",
                "tiempoConocer": referencia['tiempoConocer'] ?? "",
                "calle": referencia['calle'] ?? "",
                "nExt": referencia['nExt'] ?? "",
                "nInt": referencia['nInt'] ?? "",
                "entreCalle": referencia['entreCalle'] ?? "",
                "colonia": referencia['colonia'] ?? "",
                "cp": referencia['cp'] ?? "",
                "estado": referencia['estado'] ?? "",
                "municipio": referencia['municipio'] ?? "",
                "tiempoViviendo": referencia['tiempoViviendo'] ?? ""
              })
          .toList()
    };

    // Convertir a JSON y mostrar en consola
    try {
      print(jsonEncode(datosCliente));
    } catch (e) {
      print("Error al convertir a JSON: $e");
    }
  }

// Métodos de ayuda para manejo de errores
  void _handleApiError(http.Response response, String mensajeBase) {
    try {
      final errorData = jsonDecode(response.body);
      final errorMessage =
          errorData['error']?['message']?.toString().toLowerCase() ?? '';

      if (response.statusCode == 401 ||
          response.statusCode == 403 ||
          errorMessage.contains('jwt') ||
          errorMessage.contains('token')) {
        _handleTokenExpiration();
      } else {
        final mensajeError =
            errorData['error']?['message'] ?? 'Error desconocido';
        _showSnackbar(
            context,
            '$mensajeBase: $mensajeError (Código: ${response.statusCode})',
            Colors.red);
      }
    } catch (e) {
      _showSnackbar(context, '$mensajeBase: Error desconocido', Colors.red);
    }
  }
}
