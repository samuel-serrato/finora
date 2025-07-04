import 'dart:async';
import 'dart:io';

import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoCliente extends StatefulWidget {
  final String idCliente;

  InfoCliente({required this.idCliente});

  @override
  _InfoClienteState createState() => _InfoClienteState();
}

class _InfoClienteState extends State<InfoCliente>
    with SingleTickerProviderStateMixin {
  // Estado para la información general
  Map<String, dynamic>? clienteData;
  bool isLoading = true;
  bool errorDeConexion = false;

  // --- NUEVAS VARIABLES DE ESTADO PARA EL HISTORIAL ---
  List<Map<String, dynamic>>? historialData;
  bool _isHistorialLoading = true;
  bool _historialError = false;
  // --- FIN DE NUEVAS VARIABLES ---

  bool _isUpdating = false;
  Timer? _timer;
  bool dialogShown = false;
  late ScrollController _scrollController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController = TabController(length: 2, vsync: this);

    // Iniciar ambas cargas de datos
    fetchClienteData();
    _fetchHistorialCliente();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // --- NUEVA FUNCIÓN PARA OBTENER EL HISTORIAL ---
  Future<void> _fetchHistorialCliente() async {
    if (!mounted) return;
    setState(() {
      _isHistorialLoading = true;
      _historialError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final url =
          '$baseUrl/api/v1/grupodetalles/historial/clientes/${widget.idCliente}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'tokenauth': token, 'Content-Type': 'application/json'},
      );

      if (mounted) {
        // CASO 1: Éxito, se encontró historial
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          setState(() {
            historialData =
                data.map((item) => item as Map<String, dynamic>).toList();
            _isHistorialLoading = false;
          });
        }
        // << NUEVO: Manejo específico para el 404 "No Encontrado" >>
        else if (response.statusCode == 404) {
          // Esto NO es un error, significa que el historial está vacío.
          setState(() {
            historialData = []; // Asignamos una lista vacía.
            _isHistorialLoading = false;
            _historialError =
                false; // Nos aseguramos que no se marque como error.
          });
        }
        // CASO 3: Es un error real del servidor o de otro tipo
        else {
          setState(() {
            _isHistorialLoading = false;
            _historialError = true; // Ahora sí marcamos como error.
          });
        }
      }
    } catch (e) {
      // Si ocurre una excepción de red (ej. sin conexión a internet)
      if (mounted) {
        setState(() {
          _isHistorialLoading = false;
          _historialError = true;
        });
      }
    }
  }

  Future<void> fetchClienteData() async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
    });

    bool localDialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/clientes/${widget.idCliente}'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
            setState(() {
              clienteData = data[0];
              isLoading = false;
            });
          } else {
            setErrorState(localDialogShown);
          }
          _timer?.cancel();
        } else if (response.statusCode == 404) {
          final errorData = json.decode(response.body);
          if (errorData["Error"]["Message"] == "jwt expired") {
            if (mounted) {
              setState(() => isLoading = false);
              await prefs.remove('tokenauth');
              _timer?.cancel();
              mostrarDialogoError(
                  'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                  onClose: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              });
            }
            return;
          } else {
            setErrorState(localDialogShown);
          }
        } else {
          setErrorState(localDialogShown);
        }
      }
    } catch (e) {
      if (mounted) {
        setErrorState(localDialogShown, e);
      }
    }

    _timer = Timer(Duration(seconds: 10), () {
      if (mounted && !localDialogShown && isLoading) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
        localDialogShown = true;
        mostrarDialogoError(
          'No se pudo conectar al servidor. Verifica tu red.',
        );
      }
    });
  }

  void setErrorState(bool dialogShown, [dynamic error]) {
    if (mounted) {
      setState(() {
        isLoading = false;
        errorDeConexion = true;
      });
      if (!dialogShown) {
        dialogShown = true;
        if (error is SocketException) {
          mostrarDialogoError('Error de conexión. Verifica tu red.');
        } else {
          mostrarDialogoError('Ocurrió un error inesperado.');
        }
      }
      _timer?.cancel();
    }
  }

  void mostrarDialogoError(String mensaje,
      {VoidCallback? onClose, bool isDarkMode = false}) {
    if (mounted) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
            title: Text(
              'Error',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: Text(
              mensaje,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onClose != null) onClose();
                },
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  String _formatearFecha(String fechaStr) {
    try {
      //Intenta parsear la fecha con hora
      final fecha = DateTime.parse(fechaStr);
      // Formatear a dd/MM/yyyy
      return DateFormat('dd/MM/yyyy').format(fecha);
    } catch (e) {
      // Si falla, es posible que no tenga hora, intenta sin ella
      try {
        if (RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(fechaStr)) {
          List<String> partes = fechaStr.split('/');
          return '${partes[2]}/${partes[1]}/${partes[0]}';
        }
        return 'Fecha inválida';
      } catch (e2) {
        return 'Fecha inválida';
      }
    }
  }

  Future<void> _habilitarMultigrupo() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';
      final url =
          '$baseUrl/api/v1/clientes/estado/creditonuevo/${widget.idCliente}';

      final response = await http.put(
        Uri.parse(url),
        headers: {'tokenauth': token},
      );

      if (mounted) {
        if (response.statusCode == 200) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Estado del cliente actualizado correctamente.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final errorBody = json.decode(response.body);
          final errorMessage =
              errorBody['Error']?['Message'] ?? 'Ocurrió un error desconocido.';
          mostrarDialogoError('Error: $errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        mostrarDialogoError(
            'Error de conexión. No se pudo completar la operación.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _mostrarDialogoConfirmacion() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 450),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_alt_1,
                      size: 60, color: Color(0xFF5162F6)),
                  SizedBox(height: 15),
                  Text(
                    'Confirmar Acción',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '¿Realmente quiere habilitar a este cliente?\n\nEste cliente cambiará de estado para permitir entrar a otro grupo, pero una vez esté en otro grupo volverá a su estado normal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        height: 1.4),
                  ),
                  SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isDarkMode ? Colors.white70 : Colors.grey[700],
                            side: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey[600]!
                                    : Colors.grey[400]!),
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text('Cancelar'),
                        ),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF5162F6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _habilitarMultigrupo();
                          },
                          child: Text('Confirmar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final width = MediaQuery.of(context).size.width * 0.8;
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 30),
        width: width,
        height: height,
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: isDarkMode ? Colors.white : Color(0xFF5162F6)))
            : clienteData != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 25,
                        child: Container(
                          decoration: BoxDecoration(
                              color: Color(0xFF5162F6),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20))),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_circle,
                                  size: 100, color: Colors.white),
                              _buildDetailRowIGFlexible('',
                                  '${clienteData!['nombres']} ${clienteData!['apellidoP']} ${clienteData!['apellidoM']}',
                                  isTitle: true),
                              SizedBox(height: 8),
                              _buildDetailRowIGFlexible('Fecha Nac:',
                                  _formatearFecha(clienteData!['fechaNac'])),
                              _buildDetailRowIGFlexible('Tipo Cliente:',
                                  clienteData!['tipo_cliente']),
                              _buildDetailRowIGFlexible(
                                  'Sexo:', clienteData!['sexo']),
                              _buildDetailRowIGFlexible(
                                  'Ocupación:', clienteData!['ocupacion']),
                              _buildDetailRowIGFlexible(
                                  'Teléfono:', clienteData!['telefono']),
                              _buildDetailRowIGFlexible(
                                  'Estado Civil:', clienteData!['eCivil']),
                              _buildDetailRowIGFlexible(
                                  'Dependientes Económicos:',
                                  clienteData!['dependientes_economicos']),
                              _buildDetailRowIGFlexible('Email:',
                                  _getValidatedValue(clienteData!['email'])),
                              _buildDetailRowIGFlexible(
                                  'Estado:', clienteData!['estado'] ?? 'N/A'),
                              _buildDetailRowIGFlexible(
                                  'F. Creación:',
                                  clienteData!['fCreacion'] != null
                                      ? _formatearFecha(
                                          clienteData!['fCreacion'])
                                      : 'N/A'),
                              SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _isUpdating
                                    ? null
                                    : _mostrarDialogoConfirmacion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Color(0xFF5162F6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                  disabledBackgroundColor:
                                      Colors.white.withOpacity(0.5),
                                ),
                                child: _isUpdating
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: Color(0xFF5162F6),
                                            strokeWidth: 2.0),
                                      )
                                    : Text("Habilitar multigrupo",
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 75,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.transparent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8)),
                              child: TabBar(
                                controller: _tabController,
                                labelColor: isDarkMode
                                    ? Colors.white
                                    : Color(0xFF5162F6),
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Color(0xFF5162F6),
                                indicator: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Color(0xFF5162F6),
                                            width: 3))),
                                tabs: [
                                  Tab(text: 'Información General'),
                                  Tab(text: 'Historial del Cliente'),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildInformacionGeneralTab(isDarkMode),
                                  _buildHistorialClienteTab(isDarkMode),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error al cargar datos del cliente',
                            style: TextStyle(
                                color:
                                    isDarkMode ? Colors.white : Colors.black)),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => isLoading = true);
                            fetchClienteData();
                          },
                          child: Text('Recargar'),
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Color(0xFF5162F6)),
                            foregroundColor:
                                MaterialStateProperty.all(Colors.white),
                            shape: MaterialStateProperty.all<
                                RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  // --- WIDGET PARA LA PESTAÑA DE HISTORIAL ---
  Widget _buildHistorialClienteTab(bool isDarkMode) {
    if (_isHistorialLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: isDarkMode ? Colors.white : Color(0xFF5162F6)));
    }

    if (_historialError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'No se pudo cargar el historial',
              style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchHistorialCliente,
              child: Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5162F6),
                  foregroundColor: Colors.white),
            )
          ],
        ),
      );
    }

    if (historialData == null || historialData!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off,
                size: 60,
                color: isDarkMode ? Colors.white54 : Colors.grey[400]),
            SizedBox(height: 20),
            Text(
              'Este cliente no tiene historial de grupos.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: historialData!.length,
      itemBuilder: (context, index) {
        final grupo = historialData![index];
        return _buildHistorialCard(grupo, isDarkMode);
      },
    );
  }

  // --- WIDGET PARA CADA TARJETA DEL HISTORIAL ---
  Widget _buildHistorialCard(Map<String, dynamic> grupo, bool isDarkMode) {
    final estado = _getValidatedValue(grupo['estado']);
    final Color estadoColor = _getColorForEstado(estado);
    final String nombreGrupo = _getValidatedValue(grupo['nombreGrupo']);
    final String detalles = _getValidatedValue(grupo['detalles']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Texto adicional a la izquierda
              /*  Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.blue[900] : Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'GRUPO', // Puedes cambiar este texto por el que necesites
                style: TextStyle(
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(width: 12), */
              // Nombre del grupo con detalles
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: nombreGrupo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: ' - ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      TextSpan(
                        text: detalles,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 12),
              // Estado a la derecha
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  estado,
                  style: TextStyle(
                    color: estadoColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Divider(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              height: 24),
          Row(
            children: [
              Expanded(
                  flex: 3,
                  child: _buildDetailRow('Folio del Crédito:',
                      _getValidatedValue(grupo['folio']), isDarkMode)),
              Expanded(
                  flex: 2,
                  child: _buildDetailRow('Tipo:',
                      _getValidatedValue(grupo['tipoGrupo']), isDarkMode)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  flex: 3,
                  child: _buildDetailRow('Adicional:',
                      _getValidatedValue(grupo['isAdicional']), isDarkMode)),
              Expanded(
                  flex: 2,
                  child: _buildDetailRow('Fecha Creación:',
                      _formatearFecha(grupo['fCreacion']), isDarkMode)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorForEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'liquidado':
        return Color(0xFFFAA300);
      case 'disponible':
        return Colors.green;
      case 'finalizado':
        return Colors.red;
      case 'activo':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInformacionGeneralTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Cuentas de Banco', isDarkMode),
                      Container(
                        margin: EdgeInsets.symmetric(
                            horizontal: 4.0, vertical: 4.0),
                        height: 180,
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    isDarkMode ? Colors.black : Colors.black26,
                                blurRadius: 3,
                                offset: Offset(0, 1)),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (clienteData!['cuentabanco'] is List)
                                for (var cuenta
                                    in clienteData!['cuentabanco']) ...[
                                  _buildDetailRow(
                                      'Banco:',
                                      _getValidatedValue(cuenta['nombreBanco']),
                                      isDarkMode),
                                  _buildDetailRow(
                                      'Núm. de Cuenta:',
                                      _getValidatedValue(cuenta['numCuenta']),
                                      isDarkMode),
                                  _buildDetailRow(
                                      'CLABE Interbancaria:',
                                      _getValidatedValue(cuenta['clbIntBanc']),
                                      isDarkMode),
                                  _buildDetailRow(
                                      'Núm. de Tarjeta:',
                                      _getValidatedValue(cuenta['numTarjeta']),
                                      isDarkMode),
                                  SizedBox(height: 16),
                                ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Datos Adicionales', isDarkMode),
                      Container(
                        margin: EdgeInsets.symmetric(
                            horizontal: 4.0, vertical: 4.0),
                        height: 180,
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    isDarkMode ? Colors.black : Colors.black26,
                                blurRadius: 3,
                                offset: Offset(0, 1))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (clienteData!['adicionales'] is List)
                              for (var adicional
                                  in clienteData!['adicionales']) ...[
                                _buildDetailRow(
                                    'CURP:', adicional['curp'], isDarkMode),
                                _buildDetailRow(
                                    'RFC:', adicional['rfc'], isDarkMode),
                                _buildDetailRow('Clv Elector:',
                                    adicional['clvElector'], isDarkMode),
                                SizedBox(height: 16),
                              ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Inf. del Cónyuge', isDarkMode),
                      Container(
                        margin: EdgeInsets.symmetric(
                            horizontal: 4.0, vertical: 4.0),
                        height: 180,
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    isDarkMode ? Colors.black : Colors.black26,
                                blurRadius: 3,
                                offset: Offset(0, 1))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Nombre:',
                                _getConyugeValue('nombreConyuge'), isDarkMode),
                            _buildDetailRow(
                                'Teléfono:',
                                _getConyugeValue('telefonoConyuge'),
                                isDarkMode),
                            _buildDetailRow(
                                'Ocupacion:',
                                _getConyugeValue('ocupacionConyuge'),
                                isDarkMode),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildSectionTitle('Domicilio', isDarkMode),
            if (clienteData!['domicilios'] is List)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: isDarkMode ? Colors.black : Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var domicilio in clienteData!['domicilios']) ...[
                      _buildAddresses(domicilio, isDarkMode),
                      SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            SizedBox(height: 16),
            _buildSectionTitle('Ingresos y Egresos', isDarkMode),
            if (clienteData!['ingresos_egresos'] is List)
              _buildIncomeInfo(clienteData!['ingresos_egresos'], isDarkMode),
            SizedBox(height: 16),
            _buildSectionTitle('Referencias', isDarkMode),
            if (clienteData!['referencias'] is List)
              _buildReferences(clienteData!['referencias'], isDarkMode),
          ],
        ),
      ),
    );
  }

  // --- El resto de tus widgets (_buildDetailRow, etc.) no necesitan cambios ---
  // ... (Pega aquí el resto de tus funciones helper sin modificar) ...

  String _getConyugeValue(String key) {
    if (clienteData == null || !clienteData!.containsKey(key))
      return 'No asignado';
    final value = clienteData![key];
    if (value == null || value == "null" || (value is String && value.isEmpty))
      return 'No asignado';
    return value.toString();
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black)));
  }

  Widget _buildDetailRow(String title, String? value, bool isDarkMode) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontFamily: 'Roboto'),
            children: [
              TextSpan(
                  text: '$title ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: value ?? 'N/A'),
            ],
          ),
        ));
  }

  Widget _buildDetailRowIGFlexible(String title, String? value,
      {String? tooltip, bool isTitle = false, double? fontSize}) {
    double finalFontSize = fontSize ?? (isTitle ? 16.0 : 12.0);
    FontWeight fontWeight = isTitle ? FontWeight.bold : FontWeight.normal;
    Widget textWidget = Text('$title ${value ?? ''}',
        style: TextStyle(
            fontSize: finalFontSize,
            fontWeight: fontWeight,
            color: Colors.white),
        textAlign: isTitle ? TextAlign.center : TextAlign.center,
        overflow: TextOverflow.visible,
        softWrap: true,
        maxLines: isTitle ? 3 : 2);
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
        child: tooltip != null
            ? Tooltip(message: tooltip, child: textWidget)
            : textWidget);
  }

  Widget _buildIncomeInfo(List<dynamic> ingresos, bool isDarkMode) {
    final List<dynamic> ingresosValidos = ingresos
        .where((ingreso) =>
            ingreso != null &&
            (ingreso['tipo_info'] != null ||
                ingreso['años_actividad'] != null ||
                ingreso['descripcion'] != null ||
                ingreso['monto_semanal'] != null ||
                ingreso['fCreacion'] != null))
        .toList();
    if (ingresosValidos.isEmpty)
      return Center(
          child: Text('No hay ingresos disponibles',
              style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.grey)));
    return Stack(children: [
      SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: ClampingScrollPhysics(),
        child: Row(
            children: ingresosValidos.map<Widget>((ingreso) {
          double montoSemanal = (ingreso['monto_semanal'] is String
                  ? double.tryParse(ingreso['monto_semanal'])
                  : ingreso['monto_semanal']) ??
              0.0;
          String montoFormateado =
              montoSemanal.toString().replaceAll(RegExp(r'\.0*$'), '');
          return Container(
              margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: isDarkMode ? Colors.black : Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 2))
                  ]),
              padding: const EdgeInsets.all(8.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _buildDetailRow(
                    'Tipo de Info:', ingreso['tipo_info'], isDarkMode),
                _buildDetailRow('Años de Actividad:', ingreso['años_actividad'],
                    isDarkMode),
                _buildDetailRow(
                    'Descripción:', ingreso['descripcion'], isDarkMode),
                _buildDetailRow('Monto Semanal:', montoFormateado, isDarkMode)
              ]));
        }).toList()),
      ),
      Positioned(
          left: 0,
          top: 50,
          child: IconButton(
              icon: Icon(Icons.arrow_back_ios,
                  color: Color(0xFF5162F6), size: 20),
              onPressed: () => _scrollController.hasClients
                  ? _scrollController
                      .jumpTo(_scrollController.position.pixels - 100)
                  : null)),
      Positioned(
          right: 0,
          top: 50,
          child: IconButton(
              icon: Icon(Icons.arrow_forward_ios,
                  color: Color(0xFF5162F6), size: 20),
              onPressed: () => _scrollController.hasClients
                  ? _scrollController
                      .jumpTo(_scrollController.position.pixels + 100)
                  : null)),
    ]);
  }

  Widget _buildReferences(List<dynamic> referencias, bool isDarkMode) {
    final ScrollController _scrollController = ScrollController();
    final List<dynamic> referenciasValidas = referencias
        .where((ref) =>
            ref != null &&
            (ref['nombres'] != null ||
                ref['apellidoP'] != null ||
                ref['apellidoM'] != null ||
                ref['parentescoRefProp'] != null ||
                ref['telefono'] != null ||
                ref['timepoCo'] != null ||
                (ref['domicilio_ref'] is List &&
                    ref['domicilio_ref'].isNotEmpty)))
        .toList();
    if (referenciasValidas.isEmpty)
      return Center(
          child: Text('No hay referencias disponibles',
              style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.grey)));
    return Stack(children: [
      SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: NeverScrollableScrollPhysics(),
        child: Row(
            children: referenciasValidas.map<Widget>((referencia) {
          return Container(
              width: 650,
              margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: isDarkMode ? Colors.black : Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 2))
                  ]),
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          '${referencia['nombres']} ${referencia['apellidoP']} ${referencia['apellidoM']}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black)))
                ]),
                Row(children: [
                  Expanded(
                      child: _buildDetailRow('Parentesco:',
                          referencia['parentescoRefProp'], isDarkMode)),
                  Expanded(
                      child: _buildDetailRow(
                          'Teléfono:', referencia['telefono'], isDarkMode)),
                  Expanded(
                      child: _buildDetailRow('Tiempo de Conocer:',
                          referencia['tiempoCo'], isDarkMode))
                ]),
                Row(children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Domicilio',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black)))
                ]),
                Builder(builder: (context) {
                  bool hayDomicilioValido =
                      (referencia['domicilio_ref'] is List &&
                              referencia['domicilio_ref'].isNotEmpty) &&
                          (referencia['domicilio_ref'] as List)
                              .any((dom) => !_isDomicilioEmpty(dom));
                  if (hayDomicilioValido)
                    return Column(
                        children: (referencia['domicilio_ref'] as List)
                            .where((dom) => !_isDomicilioEmpty(dom))
                            .map<Widget>(
                                (dom) => _buildAddresses(dom, isDarkMode))
                            .toList());
                  return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Esta referencia no cuenta con domicilio',
                          style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white : Colors.grey)));
                }),
              ]));
        }).toList()),
      ),
      Positioned(
          left: 0,
          top: 80,
          child: IconButton(
              icon: Icon(Icons.arrow_back_ios,
                  color: Color(0xFF5162F6), size: 20),
              onPressed: () => _scrollController.hasClients
                  ? _scrollController
                      .jumpTo(_scrollController.position.pixels - 600)
                  : null)),
      Positioned(
          right: 0,
          top: 80,
          child: IconButton(
              icon: Icon(Icons.arrow_forward_ios,
                  color: Color(0xFF5162F6), size: 20),
              onPressed: () => _scrollController.hasClients
                  ? _scrollController
                      .jumpTo(_scrollController.position.pixels + 600)
                  : null)),
    ]);
  }

  Widget _buildAddresses(Map<String, dynamic> domicilio, bool isDarkMode) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SizedBox(height: 8),
        Expanded(
            child: _buildDetailRow('Tipo Domicilio:',
                _getValidatedValue(domicilio['tipo_domicilio']), isDarkMode)),
        Expanded(
            child: _buildDetailRow(
                'Propietario:',
                _getValidatedValue(domicilio['nombre_propietario']),
                isDarkMode)),
        Expanded(
            child: _buildDetailRow('Parentesco:',
                _getValidatedValue(domicilio['parentesco']), isDarkMode))
      ]),
      Row(children: [
        Expanded(
            child: _buildDetailRow(
                'Calle:', _getValidatedValue(domicilio['calle']), isDarkMode)),
        Expanded(
            child: _buildDetailRow('Número Ext:',
                _getValidatedValue(domicilio['nExt']), isDarkMode)),
        Expanded(
            child: _buildDetailRow('Número Int:',
                _getValidatedValue(domicilio['nInt']), isDarkMode))
      ]),
      Row(children: [
        Expanded(
            child: _buildDetailRow('Colonia:',
                _getValidatedValue(domicilio['colonia']), isDarkMode)),
        Expanded(
            child: _buildDetailRow('Estado:',
                _getValidatedValue(domicilio['estado']), isDarkMode)),
        Expanded(
            child: _buildDetailRow('Municipio:',
                _getValidatedValue(domicilio['municipio']), isDarkMode))
      ]),
      Row(children: [
        Expanded(
            child: _buildDetailRow('Código Postal:',
                _getValidatedValue(domicilio['cp']), isDarkMode)),
        Expanded(
            child: _buildDetailRow('Entre Calles:',
                _getValidatedValue(domicilio['entreCalle']), isDarkMode)),
        Expanded(
            child: _buildDetailRow('Tiempo Viviendo:',
                _getValidatedValue(domicilio['tiempoViviendo']), isDarkMode))
      ]),
    ]);
  }

  bool _isDomicilioEmpty(Map<String, dynamic> domicilio) {
    final camposDomicilio = [
      'tipo_domicilio',
      'nombre_propietario',
      'parentesco',
      'calle',
      'nExt',
      'nInt',
      'colonia',
      'estado',
      'municipio',
      'cp',
      'entreCalle',
      'tiempoViviendo'
    ];
    return camposDomicilio.every((campo) =>
        domicilio[campo] == null || domicilio[campo].toString().trim().isEmpty);
  }

  String _getValidatedValue(dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty))
      return 'No asignado';
    return value.toString();
  }
}
