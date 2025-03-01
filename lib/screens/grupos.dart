import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'package:shared_preferences/shared_preferences.dart';

class GruposScreen extends StatefulWidget {
  final String username;
  final String tipoUsuario;

  const GruposScreen({required this.username, required this.tipoUsuario});

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
              listaGrupos.sort((a, b) =>
                  b.fCreacion.compareTo(a.fCreacion)); // <-- Agrega esta línea

              isLoading = false;
              errorDeConexion = false;
            });
            _timer?.cancel();
          } else if (response.statusCode == 404) {
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] == "jwt expired") {
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
            } else {
              setErrorState(dialogShown);
            }
          } else if (response.statusCode == 400) {
            final errorData = json.decode(response.body);
            if (errorData["Error"]["Message"] ==
                "No hay detalle de grupos registrados") {
              setState(() {
                listaGrupos = [];
                isLoading = false;
                noGroupsFound = true;
              });
              _timer?.cancel();
            } else {
              setErrorState(dialogShown);
            }
          } else {
            setErrorState(dialogShown);
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
        headers: {'tokenauth': token},
      ).timeout(Duration(seconds: 10));

      await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;

      print('Status code (search): ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        setState(() {
          listaGrupos = data.map((item) => Grupo.fromJson(item)).toList();
          isLoading = false;
          noGroupsFound = listaGrupos.isEmpty; // Se actualiza correctamente
        });
      } else if (response.statusCode == 401) {
        _handleTokenExpiration();
      } else if (response.statusCode == 400) {
        // Aquí manejamos cuando no hay resultados en la búsqueda
        setState(() {
          listaGrupos = [];
          isLoading = false;
          noGroupsFound = true;
        });
      } else {
        setState(() {
          isLoading = false;
          errorDeConexion = true;
        });
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

  bool _isDarkMode = false;

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      appBar: CustomAppBar(
        isDarkMode: _isDarkMode,
        toggleDarkMode: _toggleDarkMode,
        title: 'Grupos',
        nombre: widget.username,
        tipoUsuario: widget.tipoUsuario,
      ),
      body: Column(
        children: [
          if (!errorDeConexion) filaBuscarYAgregar(context),
          Expanded(child: _buildTableContainer()),
        ],
      ),
    );
  }

  Widget _buildTableContainer() {
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
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : filaTabla(context);
    }
  }

  Widget filaBuscarYAgregar(BuildContext context) {
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
              color: Colors.white,
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
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          obtenerGrupos();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar...',
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
  return Expanded(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: Colors.white,
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
                                style: TextStyle(fontSize: textHeaderTableSize),
                              ),
                            ),
                          ],
                          rows: gruposFiltrados.map((grupo) {
                            return DataRow(
                              cells: [
                                DataCell(Text(grupo.idgrupos.toString(),
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(grupo.tipoGrupo.toString(),
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(grupo.nombreGrupo,
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(grupo.detalles,
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(grupo.asesor,
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text(formatDate(grupo.fCreacion),
                                    style: TextStyle(fontSize: textTableSize))),
                                DataCell(Text((grupo.estado),
                                    style: TextStyle(fontSize: textTableSize))),
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
        headers: {'tokenauth': token},
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
              headers: {'tokenauth': token},
            );

            print(
                '[ELIMINAR GRUPO] Respuesta eliminar cliente $idCliente - Código: ${responseEliminarCliente.statusCode}');
            print(
                '[ELIMINAR GRUPO] Respuesta eliminar cliente $idCliente - Body: ${responseEliminarCliente.body}');

            if (responseEliminarCliente.statusCode != 200) {
              print('[ELIMINAR GRUPO] Error al eliminar cliente $idCliente');
              final errorData = json.decode(responseEliminarCliente.body);
              print('[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
              mostrarDialogoError('Error al eliminar cliente $idCliente');
              return;
            }
          }
        }

        // 3. Eliminar el grupo
        final urlEliminarGrupo = 'http://$baseUrl/api/v1/grupos/$idGrupo';
        print('[ELIMINAR GRUPO] URL para eliminar grupo: $urlEliminarGrupo');

        final responseEliminarGrupo = await http.delete(
          Uri.parse(urlEliminarGrupo),
          headers: {'tokenauth': token},
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
          print('[ELIMINAR GRUPO] Error al eliminar grupo');
          final errorData = json.decode(responseEliminarGrupo.body);
          print('[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
          mostrarDialogoError(
              errorData['Error']['Message'] ?? 'Error al eliminar el grupo');
        }
      } else {
        print('[ELIMINAR GRUPO] Error al obtener clientes del grupo');
        final errorData = json.decode(responseClientes.body);
        print('[ELIMINAR GRUPO] Error detallado: ${errorData?['Error']}');
        mostrarDialogoError(errorData['Error']['Message'] ??
            'Error al obtener los clientes del grupo');
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
