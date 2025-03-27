import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:finora/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:finora/custom_app_bar.dart';
import 'package:finora/dialogs/editGrupo.dart';
import 'package:finora/dialogs/infoGrupo.dart';
import 'package:finora/dialogs/nCliente.dart';
import 'package:finora/dialogs/nGrupo.dart';
import 'package:finora/ip.dart';
import 'package:finora/screens/login.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GruposScreen extends StatefulWidget {
  const GruposScreen();

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  List<Grupo> listaGrupos = [];
  bool isLoading = true;
  bool showErrorDialog = false;
  Timer? _timer;
  bool errorDeConexion = false;
  bool noGroupsFound = false;
  Timer? _debounceTimer; // Para el debounce de la búsqueda
  final TextEditingController _searchController =
      TextEditingController(); // Controlador para el SearchBar

  @override
  void initState() {
    super.initState();
    obtenerGrupos();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  final double textHeaderTableSize = 12.0;
  final double textTableSize = 12.0;

  Future<void> obtenerGrupos() async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noGroupsFound = false;
    });

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        final response = await http.get(
          Uri.parse('http://$baseUrl/api/v1/grupodetalles'),
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        if (mounted) {
          if (response.statusCode == 200) {
            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
              listaGrupos.sort((a, b) => b.fCreacion.compareTo(a.fCreacion));

              isLoading = false;
              errorDeConexion = false;
            });
            _timer?.cancel();
          } else {
            try {
              final errorData = json.decode(response.body);

              // Verificar si es el mensaje específico de sesión cambiada
              if (errorData["Error"] != null &&
                  errorData["Error"]["Message"] ==
                      "La sesión ha cambiado. Cerrando sesión...") {
                if (mounted) {
                  setState(() => isLoading = false);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('tokenauth');
                  _timer?.cancel();

                  // Mostrar diálogo y redirigir al login
                  mostrarDialogoCierreSesion(
                      'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false, // Elimina todas las rutas anteriores
                    );
                  });
                }
                return;
              }
              // Manejar error JWT expirado
              else if (response.statusCode == 404 &&
                  errorData["Error"]["Message"] == "jwt expired") {
                if (mounted) {
                  setState(() => isLoading = false);
                  final prefs = await SharedPreferences.getInstance();
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
              }
              // Manejar error de no hay grupos
              else if (response.statusCode == 400 &&
                  errorData["Error"]["Message"] ==
                      "No hay detalle de grupos registrados") {
                setState(() {
                  listaGrupos = [];
                  isLoading = false;
                  noGroupsFound = true;
                });
                _timer?.cancel();
              }
              // Otros errores
              else {
                setErrorState(dialogShown);
              }
            } catch (parseError) {
              // Si no se puede parsear el cuerpo de la respuesta, manejar como error genérico
              setErrorState(dialogShown);
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setErrorState(dialogShown, e);
        }
      }
    }

    fetchData();

    if (!noGroupsFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noGroupsFound) {
          setState(() {
            isLoading = false;
            errorDeConexion = true;
          });
          dialogShown = true;
          mostrarDialogoError(
              'No se pudo conectar al servidor. Verifica tu red.');
        }
      });
    }
  }

  Future<void> searchGrupos(String query) async {
    if (query.trim().isEmpty) {
      obtenerGrupos();
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noGroupsFound = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('http://$baseUrl/api/v1/grupodetalles/$query'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;

      print('Status code (search): ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        // Intentar decodificar el cuerpo de la respuesta para verificar mensajes de error específicos
        try {
          final errorData = json.decode(response.body);

          // Verificar si es el mensaje específico de sesión cambiada
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            if (mounted) {
              setState(() => isLoading = false);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');

              // Mostrar diálogo y redirigir al login
              mostrarDialogoCierreSesion(
                  'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false, // Elimina todas las rutas anteriores
                );
              });
            }
            return;
          }
          // Manejar error JWT expirado
          else if (response.statusCode == 404 &&
              errorData["Error"] != null &&
              errorData["Error"]["Message"] == "jwt expired") {
            if (mounted) {
              setState(() => isLoading = false);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');
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
          }
          // Manejar 401 para token expirado
          else if (response.statusCode == 401) {
            _handleTokenExpiration();
          }
          // Manejar error de no hay clientes
          else if (response.statusCode == 400) {
            // Si el mensaje específicamente dice que no hay resultados
            if (errorData["Error"] != null &&
                errorData["Error"]["Message"] ==
                    "No hay ningun cliente registrado") {
              setState(() {
                listaGrupos = [];
                isLoading = false;
                noGroupsFound = true;
              });
            } else {
              // Otros errores 400
              setState(() {
                listaGrupos = [];
                isLoading = false;
                noGroupsFound = true;
              });
            }
          }
          // Otros errores
          else {
            setState(() {
              isLoading = false;
              errorDeConexion = true;
            });
          }
        } catch (parseError) {
          // Si no se puede parsear el cuerpo de la respuesta, manejar como error genérico
          setState(() {
            isLoading = false;
            errorDeConexion = true;
          });
        }
      }
    } on SocketException catch (e) {
      print('SocketException: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
      }
    } on TimeoutException catch (_) {
      print('Timeout');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
      }
    } catch (e) {
      print('Error general: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
      }
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

  void _handleTokenExpiration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tokenauth');

    if (mounted) {
      mostrarDialogoError(
        'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
        onClose: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
          );
        },
      );
    }
  }

  void setErrorState(bool dialogShown, [dynamic error]) {
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
      _timer?.cancel();
    }
  }

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    showDialog(
      barrierDismissible: false, // Impide cerrar tocando fuera
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

  String formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Scaffold(
      backgroundColor:
          isDarkMode ? Colors.grey[900] : Color(0xFFF7F8FA), // Fondo dinámico

      appBar: CustomAppBar(
          isDarkMode: isDarkMode,
          toggleDarkMode: (value) {
            themeProvider.toggleDarkMode(value); // Cambia el tema
          },
          title: 'Grupos'),
      body: Column(
        children: [
          if (!errorDeConexion) filaBuscarYAgregar(context),
          Expanded(child: _buildTableContainer()),
        ],
      ),
    );
  }

  Widget _buildTableContainer() {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFF5162F6),
        ),
      );
    } else if (errorDeConexion) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No hay conexión o no se pudo cargar la información. Intenta más tarde.',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_searchController.text.trim().isEmpty) {
                  obtenerGrupos();
                } else {
                  searchGrupos(_searchController.text);
                }
              },
              child: Text('Recargar'),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Color(0xFF5162F6)),
                foregroundColor: MaterialStateProperty.all(Colors.white),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return noGroupsFound || listaGrupos.isEmpty
          ? Center(
              child: Text(
                'No hay grupos para mostrar.',
                style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.grey),
              ),
            )
          : filaTabla(context);
    }
  }

  Widget filaBuscarYAgregar(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    double maxWidth = MediaQuery.of(context).size.width * 0.35;
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 40,
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.grey[800]
                  : Colors.white, // Fondo dinámico
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8.0)],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide:
                      BorderSide(color: Color.fromARGB(255, 137, 192, 255)),
                ),
                prefixIcon: Icon(Icons.search,
                    color: isDarkMode ? Colors.white : Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: isDarkMode ? Colors.white : Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          obtenerGrupos();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode
                    ? Colors.grey[800]
                    : Colors.white, // Fondo dinámico
                hintText: 'Buscar...',
                hintStyle:
                    TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                if (_debounceTimer?.isActive ?? false) {
                  _debounceTimer!.cancel();
                }
                _debounceTimer = Timer(Duration(milliseconds: 500), () {
                  searchGrupos(value);
                });
              },
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              padding: MaterialStateProperty.all(
                  EdgeInsets.symmetric(vertical: 15, horizontal: 20)),
              backgroundColor: MaterialStateProperty.all(Color(0xFF5162F6)),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            onPressed: mostrarDialogAgregarGrupo,
            child: Text('Agregar Grupo'),
          ),
        ],
      ),
    );
  }

  Widget filaTabla(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color:
                isDarkMode ? Colors.grey[800] : Colors.white, // Fondo dinámico
            borderRadius: BorderRadius.circular(15.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 0.5,
                blurRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.0),
            child: listaGrupos.isEmpty
                ? Center(
                    child: Text(
                      'No hay grupos para mostrar.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      var gruposFiltrados = listaGrupos
                          .where((grupo) =>
                              grupo.estado == 'Disponible' ||
                              grupo.estado == 'Liquidado' ||
                              grupo.estado == 'Activo')
                          .toList();
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowColor: MaterialStateProperty.resolveWith(
                                (states) => const Color(0xFF5162F6)),
                            dataRowHeight: 50,
                            columnSpacing: 30,
                            horizontalMargin: 50,
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: textHeaderTableSize,
                            ),
                            columns: [
                              DataColumn(
                                  label: Text('ID Grupo',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Tipo Grupo',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Nombre',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Detalles',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Asesor',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Fecha Creación',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                  label: Text('Estado',
                                      style: TextStyle(
                                          fontSize: textHeaderTableSize))),
                              DataColumn(
                                label: Text(
                                  'Acciones',
                                  style:
                                      TextStyle(fontSize: textHeaderTableSize),
                                ),
                              ),
                            ],
                            rows: gruposFiltrados.map((grupo) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(grupo.idgrupos.toString(),
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(grupo.tipoGrupo.toString(),
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(grupo.nombreGrupo,
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(grupo.detalles,
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(grupo.asesor,
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(Text(formatDate(grupo.fCreacion),
                                      style:
                                          TextStyle(fontSize: textTableSize))),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(grupo.estado,
                                            context), // Fondo dinámico
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getStatusColor(
                                                  grupo.estado, context)
                                              .withOpacity(
                                                  0.6), // Borde dinámico
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        grupo.estado ?? 'N/A',
                                        style: TextStyle(
                                          color: _getStatusTextColor(
                                              grupo.estado,
                                              context), // Texto dinámico
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Colors.grey),
                                          onPressed: () {
                                            mostrarDialogoEditarCliente(
                                                grupo.idgrupos!);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.grey),
                                          onPressed: () {
                                            _eliminarGrupo(grupo.idgrupos);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelectChanged: (isSelected) async {
                                  if (isSelected!) {
                                    final resultado = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => InfoGrupo(
                                        idGrupo: grupo.idgrupos.toString(),
                                        nombreGrupo: grupo.nombreGrupo,
                                      ),
                                    );

                                    if (resultado == true) {
                                      obtenerGrupos();
                                    }
                                  }
                                },
                                color: MaterialStateColor.resolveWith((states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return Colors.blue.withOpacity(0.1);
                                  } else if (states
                                      .contains(MaterialState.hovered)) {
                                    return Colors.blue.withOpacity(0.2);
                                  }
                                  return Colors.transparent;
                                }),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? estado, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    switch (estado) {
      case 'Finalizado':
        return isDarkMode
            ? Color(0xFE73879)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFE73879).withOpacity(0.1); // Fondo claro para modo claro
      case 'Liquidado':
        return isDarkMode
            ? Color(0xFFFAA300)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFFFAA300).withOpacity(0.1); // Fondo claro para modo claro
      case 'Cancelado':
        return isDarkMode
            ? Color(0xFFA31D1D)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFFA31D1D).withOpacity(0.1); // Fondo claro para modo claro
      case 'Activo':
        return isDarkMode
            ? Color(0xFF3674B5)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFF3674B5).withOpacity(0.1); // Fondo claro para modo claro
      case 'Disponible':
        return isDarkMode
            ? Color(0xFF059212)
                .withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Color(0xFF059212).withOpacity(0.1); // Fondo claro para modo claro
      default:
        return isDarkMode
            ? Colors.grey.withOpacity(0.4) // Fondo más oscuro para modo oscuro
            : Colors.grey.withOpacity(0.1); // Fondo claro para modo claro
    }
  }

  Color _getStatusTextColor(String? estado, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context,
        listen: false); // Obtén el ThemeProvider
    final isDarkMode = themeProvider.isDarkMode; // Estado del tema

    if (isDarkMode) {
      // En modo oscuro, el texto será blanco para contrastar con el fondo oscuro
      return Colors.white;
    } else {
      // En modo claro, mantenemos el color original del texto
      switch (estado) {
        case 'Finalizado':
          return Color(0xFE73879)
              .withOpacity(0.8); // Color original para "Finalizado"
        case 'Liquidado':
          return Color(0xFFFAA300)
              .withOpacity(0.8); // Color original para "Liquidado"
        case 'Cancelado':
          return Color(0xFFA31D1D)
              .withOpacity(0.8); // Color original para "Cancelado"
        case 'Activo':
          return Color(0xFF3674B5)
              .withOpacity(0.8); // Color original para "Activo"
        case 'Disponible':
          return Color(0xFF059212)
              .withOpacity(0.8); // Color original para "Disponible"
        default:
          return Colors.grey.withOpacity(0.8); // Color original por defecto
      }
    }
  }

  Future<void> _eliminarGrupo(String idGrupo) async {
    print('[ELIMINAR GRUPO] Iniciando proceso...');

    // Diálogo de confirmación
    bool confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Grupo'),
        content: const Text(
            '¿Estás seguro de eliminar este grupo y todos sus clientes asociados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    print(
        '[ELIMINAR GRUPO] Confirmación del usuario: ${confirmado ? "Aceptada" : "Cancelada"}');
    if (confirmado != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tokenauth') ?? '';
    print(
        '[ELIMINAR GRUPO] Token obtenido: ${token.isNotEmpty ? "OK" : "ERROR - Token vacío"}');

    try {
      // 1. Obtener la lista de clientes asociados al grupo
      final urlClientes = 'http://$baseUrl/api/v1/grupodetalles/$idGrupo';
      print('[ELIMINAR GRUPO] URL para obtener clientes: $urlClientes');

      final responseClientes = await http.get(
        Uri.parse(urlClientes),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      print(
          '[ELIMINAR GRUPO] Respuesta obtener clientes - Código: ${responseClientes.statusCode}');
      print(
          '[ELIMINAR GRUPO] Respuesta obtener clientes - Body: ${responseClientes.body}');

      if (responseClientes.statusCode == 200) {
        final data = json.decode(responseClientes.body) as List;
        print('[ELIMINAR GRUPO] Número de grupos encontrados: ${data.length}');

        // Recorrer cada grupo (aunque debería ser solo uno)
        for (var grupo in data) {
          final clientes = grupo['clientes'] as List;
          print(
              '[ELIMINAR GRUPO] Número de clientes en el grupo: ${clientes.length}');

          // 2. Eliminar cada cliente asociado al grupo
          for (var cliente in clientes) {
            final idCliente = cliente['idclientes'];
            final urlEliminarCliente =
                'http://$baseUrl/api/v1/grupodetalles/$idGrupo/$idCliente';
            print(
                '[ELIMINAR GRUPO] URL para eliminar cliente: $urlEliminarCliente');

            final responseEliminarCliente = await http.delete(
              Uri.parse(urlEliminarCliente),
              headers: {
                'tokenauth': token,
                'Content-Type': 'application/json',
              },
            );

            print(
                '[ELIMINAR GRUPO] Respuesta eliminar cliente $idCliente - Código: ${responseEliminarCliente.statusCode}');
            print(
                '[ELIMINAR GRUPO] Respuesta eliminar cliente $idCliente - Body: ${responseEliminarCliente.body}');

            // Verificar si hay error de sesión en la respuesta de eliminar cliente
            if (responseEliminarCliente.statusCode != 200) {
              try {
                final errorData = json.decode(responseEliminarCliente.body);

                // Verificar si es el mensaje específico de sesión cambiada
                if (errorData["Error"] != null &&
                    errorData["Error"]["Message"] ==
                        "La sesión ha cambiado. Cerrando sesión...") {
                  print('[ELIMINAR GRUPO] Sesión cambiada detectada');
                  if (mounted) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('tokenauth');
                    _timer?.cancel();

                    // Mostrar diálogo y redirigir al login
                    mostrarDialogoCierreSesion(
                        'La sesión ha cambiado. Cerrando sesión...',
                        onClose: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false, // Elimina todas las rutas anteriores
                      );
                    });
                  }
                  return;
                }
                // Manejar error JWT expirado
                else if (responseEliminarCliente.statusCode == 404 &&
                    errorData["Error"]["Message"] == "jwt expired") {
                  print('[ELIMINAR GRUPO] JWT expirado detectado');
                  if (mounted) {
                    final prefs = await SharedPreferences.getInstance();
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
                  print(
                      '[ELIMINAR GRUPO] Error al eliminar cliente $idCliente');
                  print(
                      '[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
                  // Use SnackBar to show the error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        errorData['Error']?['Message'] ??
                            'Error al eliminar cliente $idCliente',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              } catch (parseError) {
                print(
                    '[ELIMINAR GRUPO] Error al parsear respuesta: $parseError');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error al eliminar cliente $idCliente',
                      style: TextStyle(
                        color:
                            Colors.white, // Explicitly set text color to white
                      ),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
            }
          }
        }

        // 3. Eliminar el grupo
        final urlEliminarGrupo = 'http://$baseUrl/api/v1/grupos/$idGrupo';
        print('[ELIMINAR GRUPO] URL para eliminar grupo: $urlEliminarGrupo');

        final responseEliminarGrupo = await http.delete(
          Uri.parse(urlEliminarGrupo),
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        print(
            '[ELIMINAR GRUPO] Respuesta eliminar grupo - Código: ${responseEliminarGrupo.statusCode}');
        print(
            '[ELIMINAR GRUPO] Respuesta eliminar grupo - Body: ${responseEliminarGrupo.body}');

        if (responseEliminarGrupo.statusCode == 200) {
          print('[ELIMINAR GRUPO] Eliminación exitosa, actualizando lista...');
          obtenerGrupos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Grupo y clientes asociados eliminados exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          try {
            final errorData = json.decode(responseEliminarGrupo.body);

            // Verificar si es el mensaje específico de sesión cambiada
            if (errorData["Error"] != null &&
                errorData["Error"]["Message"] ==
                    "La sesión ha cambiado. Cerrando sesión...") {
              print('[ELIMINAR GRUPO] Sesión cambiada detectada');
              if (mounted) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('tokenauth');
                _timer?.cancel();

                // Mostrar diálogo y redirigir al login
                mostrarDialogoCierreSesion(
                    'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false, // Elimina todas las rutas anteriores
                  );
                });
              }
              return;
            }
            // Manejar error JWT expirado
            else if (responseEliminarGrupo.statusCode == 404 &&
                errorData["Error"]["Message"] == "jwt expired") {
              print('[ELIMINAR GRUPO] JWT expirado detectado');
              if (mounted) {
                final prefs = await SharedPreferences.getInstance();
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
              print('[ELIMINAR GRUPO] Error al eliminar grupo');
              print('[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
              mostrarDialogoError(errorData['Error']['Message'] ??
                  'Error al eliminar el grupo');
            }
          } catch (parseError) {
            print('[ELIMINAR GRUPO] Error al parsear respuesta: $parseError');
            mostrarDialogoError('Error al eliminar el grupo');
          }
        }
      } else {
        try {
          final errorData = json.decode(responseClientes.body);

          // Verificar si es el mensaje específico de sesión cambiada
          if (errorData["Error"] != null &&
              errorData["Error"]["Message"] ==
                  "La sesión ha cambiado. Cerrando sesión...") {
            print('[ELIMINAR GRUPO] Sesión cambiada detectada');
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tokenauth');
              _timer?.cancel();

              // Mostrar diálogo y redirigir al login
              mostrarDialogoCierreSesion(
                  'La sesión ha cambiado. Cerrando sesión...', onClose: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false, // Elimina todas las rutas anteriores
                );
              });
            }
            return;
          }
          // Manejar error JWT expirado
          else if (responseClientes.statusCode == 404 &&
              errorData["Error"]["Message"] == "jwt expired") {
            print('[ELIMINAR GRUPO] JWT expirado detectado');
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
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
            print('[ELIMINAR GRUPO] Error al obtener clientes del grupo');
            print('[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
            mostrarDialogoError(errorData['Error']['Message'] ??
                'Error al obtener los clientes del grupo');
          }
        } catch (parseError) {
          print('[ELIMINAR GRUPO] Error al parsear respuesta: $parseError');
          mostrarDialogoError('Error al obtener los clientes del grupo');
        }
      }
    } catch (e) {
      print('[ELIMINAR GRUPO] Excepción capturada: $e');
      print('[ELIMINAR GRUPO] StackTrace: ${e is Error ? e.stackTrace : ""}');
      mostrarDialogoError('Error de conexión: $e');
    }

    print('[ELIMINAR GRUPO] Proceso finalizado');
  }

  void mostrarDialogAgregarGrupo() {
    showDialog(
      barrierDismissible: false, // Evita que se cierre al tocar fuera
      context: context,
      builder: (context) {
        return nGrupoDialog(
          onGrupoAgregado: () {
            obtenerGrupos(); // Refresca la lista de clientes después de agregar uno
          },
        );
      },
    );
  }

  void mostrarDialogoEditarCliente(String idGrupo) {
    showDialog(
      barrierDismissible: false, // No se puede cerrar tocando fuera
      context: context,
      builder: (context) {
        return editGrupoDialog(
          idGrupo: idGrupo, // Pasamos el idGrupo al diálogo
          onGrupoEditado: () {
            obtenerGrupos();
          },
        );
      },
    );
  }
}

class Grupo {
  final String idgrupos;
  final String tipoGrupo;
  final String nombreGrupo;
  final String detalles;
  final String asesor;
  final String fCreacion;
  final String estado; // Agregamos el campo 'estado'

  Grupo({
    required this.idgrupos,
    required this.tipoGrupo,
    required this.nombreGrupo,
    required this.detalles,
    required this.asesor,
    required this.fCreacion,
    required this.estado, // Inicializamos el campo 'estado' en el constructor
  });

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      idgrupos: json['idgrupos'],
      tipoGrupo: json['tipoGrupo'],
      nombreGrupo: json['nombreGrupo'],
      detalles: json['detalles'],
      asesor: json['asesor'],
      fCreacion: json['fCreacion'],
      estado:
          json['estado'], // Asignamos el valor del campo 'estado' desde el JSON
    );
  }
}
