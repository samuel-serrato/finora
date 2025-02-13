import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:money_facil/ip.dart';
import 'package:money_facil/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoUsuario extends StatefulWidget {
  final String idUsuario;

  const InfoUsuario({super.key, required this.idUsuario});

  @override
  _InfoUsuarioState createState() => _InfoUsuarioState();
}

class _InfoUsuarioState extends State<InfoUsuario> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  Timer? _timer;
  bool dialogShown = false;
  bool errorDeConexion = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    setState(() {
      isLoading = true;
      errorDeConexion = false;
    });

    bool localDialogShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('tokenauth') ?? '';

      final response = await http.get(
        Uri.parse('http://$baseUrl/api/v1/usuarios/${widget.idUsuario}'),
        headers: {
          'tokenauth': token,
          'Content-Type': 'application/json',
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> dataList = json.decode(response.body);
          if (dataList.isNotEmpty) {
            setState(() {
              userData = dataList.first as Map<String, dynamic>;
              isLoading = false;
            });
          } else {
            setErrorState(localDialogShown);
          }
          _timer?.cancel();
        } else if (response.statusCode == 401) {
          final errorData = json.decode(response.body);
          if (errorData["Error"]["Message"] == "jwt expired") {
            if (mounted) {
              setState(() => isLoading = false);
              await prefs.remove('tokenauth');
              _timer?.cancel();
              mostrarDialogoError(
                'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
                onClose: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) =>  LoginScreen()),
                  );
                },
              );
            }
            return;
          } else {
            setErrorState(localDialogShown);
          }
        } else if (response.statusCode == 404) {
          setState(() {
            isLoading = false;
            errorDeConexion = true;
          });
          mostrarDialogoError('Usuario no encontrado');
        } else {
          setErrorState(localDialogShown);
        }
      }
    } catch (e, stackTrace) {
      print('Error inesperado: $e');
      print('StackTrace: $stackTrace');
      if (mounted) {
        setErrorState(localDialogShown, e);
      }
    }

    _timer = Timer(const Duration(seconds: 10), () {
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

  void mostrarDialogoError(String mensaje, {VoidCallback? onClose}) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text('Error', 
                style: TextStyle(color: Color(0xFFFB2056))),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onClose != null) onClose();
                },
                child: const Text('OK',
                    style: TextStyle(color: Color(0xFFFB2056))),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 15,
              offset: Offset(0, 5),
            )
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.5,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: isLoading
              ? _buildLoadingIndicator()
              : userData != null
                  ? _buildUserInfo()
                  : _buildErrorState(),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB2056)),
          ),
          SizedBox(height: 20),
          Text('Cargando información...',
              style: TextStyle(color: Color(0xFF666666))),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        _buildHeader(),
        Divider(height: 0, color: Colors.grey[200], thickness: 1.5),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                _buildInfoSection(
                  title: 'Información Personal',
                  icon: Icons.person_outline,
                  children: [
                    _buildInfoItem('Usuario', userData!['usuario']),
                    _buildInfoItem('Nombre', userData!['nombreCompleto']),
                    //_buildInfoItem('Email', userData!['email']),
                  ],
                ),
                const SizedBox(height: 25),
                _buildInfoSection(
                  title: 'Detalles de la Cuenta',
                  icon: Icons.assignment_ind_outlined,
                  children: [
                    _buildInfoItem('ID', userData!['idusuarios']),
                    _buildInfoItem('Tipo de Usuario', userData!['tipoUsuario']),
                    _buildInfoItem('Fecha de Creación', 
                        _formatDate(userData!['fCreacion'])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
    decoration: BoxDecoration(
      color: const Color(0xFFFB2056).withOpacity(0.95),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
     /*  gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFB2056).withOpacity(0.9),
          const Color(0xFFC2185B),
        ],
      ), */
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center, // Centrar horizontalmente
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.black.withOpacity(0.2),
          child: Icon(
            Icons.person_rounded,
            size: 50,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const SizedBox(width: 20),

        // Columna con nombre y tipo de usuario
        Flexible(  // Cambiar de Expanded a Flexible para mejor manejo de espacio
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Centrar texto
            mainAxisSize: MainAxisSize.min, // Evitar expansión vertical innecesaria
            children: [
              Text(
                userData!['nombreCompleto'] ?? '',
                textAlign: TextAlign.center, // Alinear texto al centro
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  userData!['tipoUsuario'] ?? '',
                  textAlign: TextAlign.center, // Alinear texto al centro
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFB2056).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 50, color: Colors.red[400]),
          const SizedBox(height: 20),
          Text('Error al cargar datos',
              style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          const Text('No se pudo obtener la información del usuario',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Intentar nuevamente'),
            onPressed: fetchUserData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB2056),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      DateTime parsedDate = DateTime.parse(date);
      return DateFormat('dd MMM yyyy - hh:mm a').format(parsedDate);
    } catch (e) {
      return date;
    }
  }
}