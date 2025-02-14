import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:money_facil/custom_app_bar.dart';
import 'package:money_facil/dialogs/usuario/editUsuario.dart';
import 'package:money_facil/dialogs/usuario/infoUsuario.dart';
import 'package:money_facil/dialogs/usuario/nUsuario.dart';
import 'package:money_facil/ip.dart';
import 'package:money_facil/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GestionUsuariosScreen extends StatefulWidget {
  final String username;
  final String tipoUsuario;

  const GestionUsuariosScreen(
      {required this.username, required this.tipoUsuario});

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  List<Usuario> listaUsuarios = [];
  bool isLoading = true;
  bool showErrorDialog = false;
  Timer? _timer;
  bool errorDeConexion = false;
  bool noUsersFound = false;

  @override
  void initState() {
    super.initState();
    obtenerUsuarios();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final double textHeaderTableSize = 12.0;
  final double textTableSize = 12.0;

  Future<void> obtenerUsuarios() async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
      noUsersFound = false;
    });

    bool dialogShown = false;

    Future<void> fetchData() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('tokenauth') ?? '';

        final response = await http.get(
          Uri.parse('http://$baseUrl/api/v1/usuarios'),
          headers: {
            'tokenauth': token,
            'Content-Type': 'application/json',
          },
        );

        if (mounted) {
          if (response.statusCode == 200) {
            List<dynamic> data = json.decode(response.body);
            setState(() {
              listaUsuarios =
                  data.map((item) => Usuario.fromJson(item)).toList();
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
                "No hay usuarios registrados") {
              setState(() {
                listaUsuarios = [];
                isLoading = false;
                noUsersFound = true;
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

    if (!noUsersFound) {
      _timer = Timer(Duration(seconds: 10), () {
        if (mounted && !dialogShown && !noUsersFound) {
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
        title: 'Gestión de Usuarios',
        nombre: widget.username,
        tipoUsuario: widget.tipoUsuario,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFB2056),
              ),
            )
          : (errorDeConexion
              ? Center(
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
                          obtenerUsuarios();
                        },
                        child: Text('Recargar'),
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Color(0xFFFB2056)),
                          foregroundColor:
                              MaterialStateProperty.all(Colors.white),
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    filaBuscarYAgregar(context),
                    listaUsuarios.isEmpty
                        ? Expanded(
                            child: Center(
                              child: Text(
                                'No hay usuarios para mostrar.',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          )
                        : filaTabla(context),
                  ],
                )),
    );
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
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide:
                      BorderSide(color: Color.fromARGB(255, 137, 192, 255)),
                ),
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Color(0xFFFB2056)),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            onPressed: mostrarDialogAgregarUsuario,
            child: Text('Agregar Usuario'),
          ),
        ],
      ),
    );
  }

  Widget filaTabla(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15.0),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0.5,
                  blurRadius: 5)
            ],
          ),
          child: listaUsuarios.isEmpty
              ? Center(
                  child: Text(
                    'No hay usuarios para mostrar.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : LayoutBuilder(builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowColor: MaterialStateProperty.resolveWith(
                            (states) => Color(0xFFDFE7F5)),
                        dataRowHeight: 50,
                        columnSpacing: 30,
                        headingTextStyle: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                        columns: [
                          DataColumn(
                              label: Text('Tipo',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                              label: Text('Usuario',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                              label: Text('Nombre Completo',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                              label: Text('Email',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          
                          DataColumn(
                              label: Text('Fecha Creación',
                                  style: TextStyle(
                                      fontSize: textHeaderTableSize))),
                          DataColumn(
                            label: Text(
                              'Acciones',
                              style: TextStyle(fontSize: textHeaderTableSize),
                            ),
                          ),
                        ],
                        rows: listaUsuarios.map((usuario) {
                          return DataRow(
                            cells: [
                              DataCell(Text(usuario.tipoUsuario,
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(Text(usuario.usuario,
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(Text(usuario.nombreCompleto,
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(Text(usuario.email,
                                  style: TextStyle(fontSize: textTableSize))),
                              
                              DataCell(Text(formatDate(usuario.fCreacion),
                                  style: TextStyle(fontSize: textTableSize))),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined,
                                          color: Colors.grey),
                                      onPressed: () {
                                        mostrarDialogoEditarUsuario(
                                            usuario.idusuarios);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.grey),
                                      onPressed: () {
                                        // Lógica para eliminar el usuario
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
                                  builder: (context) => InfoUsuario(
                                    idUsuario: usuario.idusuarios,
                                  ),
                                );

                                if (resultado == true) {
                                  obtenerUsuarios();
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
                }),
        ),
      ),
    );
  }

  void mostrarDialogAgregarUsuario() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return nUsuarioDialog(
          onUsuarioAgregado: () {
            obtenerUsuarios();
          },
        );
      },
    );
  }

  void mostrarDialogoEditarUsuario(String idUsuario) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return editUsuarioDialog(
          idUsuario: idUsuario,
          onUsuarioEditado: () {
            obtenerUsuarios();
          },
        );
      },
    );
  }
}

class Usuario {
  final String idusuarios;
  final String usuario;
  final String tipoUsuario;
  final String nombreCompleto;
  final String email;
  final List<String> roles;
  final String fCreacion;

  Usuario({
    required this.idusuarios,
    required this.usuario,
    required this.tipoUsuario,
    required this.nombreCompleto,
    required this.email,
    required this.roles,
    required this.fCreacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      idusuarios: json['idusuarios'],
      usuario: json['usuario'],
      tipoUsuario: json['tipoUsuario'],
      nombreCompleto: json['nombreCompleto'],
      email: json['email'],
      roles: List<String>.from(json['roles']),
      fCreacion: json['fCreacion'],
    );
  }
}
