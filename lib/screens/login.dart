import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: content(context),
    );
  }

  Widget content(BuildContext context) {
    return Row(
      children: [
        Container(
          color: const Color(0xFFFB2056),
          width: MediaQuery.of(context).size.width / 2,
          child: const Center(
            child: Text(
              'Imagen',
              style: TextStyle(fontSize: 24.0, color: Colors.white),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: LoginForm(),
          ),
        ),
      ],
    );
  }
}

class LoginForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Column(
            children: [
              Text(
                'Bienvenido a Money Fácil',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
              Text(
                'Iniciar Sesión',
                style: TextStyle(fontSize: 24.0),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.0),
        Text(
          'Usuario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10.0),
        TextFormField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.person),
            hintText: 'Ingrese su usuario',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        SizedBox(height: 20.0),
        Text(
          'Contraseña',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10.0),
        TextFormField(
          obscureText: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock),
            hintText: 'Ingrese su contraseña',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        SizedBox(height: 20.0),
        Center(
          child: ElevatedButton(
            style: const ButtonStyle(
              backgroundColor: MaterialStatePropertyAll( Color(0xFF98EF8D),)
            ),
            onPressed: () {
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('Iniciar Sesión', style: TextStyle(color: Colors.black),),
            ),
          ),
        ),
      ],
    );
  }
}
