import 'package:flutter/material.dart';

class CardUserWidget extends StatelessWidget {
  final String username;

  CardUserWidget({required this.username});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      //color: Color(0xFFEFF5FD),
      padding: EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(
            width: 200,
            padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: Colors.black,
                ),
                SizedBox(width: 10.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:
                      MainAxisSize.min, // Para ajustar el tamaño verticalmente
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 16.0,
                      ),
                    ),
                    SizedBox(height: 2.0), // Ajuste de espacio vertical
                    Text(
                      'Tipo de usuario',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
