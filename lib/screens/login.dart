import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF0F3),
                  Colors.white,
                  
                ],
              ),
            ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: content(context),
      ),
    );
  }

  Widget content(BuildContext context) {
    return Row(
      children: [
        // Contenedor de imagen mejorado
        Container(
          width: MediaQuery.of(context).size.width / 2.5,
          decoration: BoxDecoration(
            color: Colors.transparent,
            /* boxShadow: [
              BoxShadow(
                color: Color(0xFFFB2056).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ], */
          ),
          padding: const EdgeInsets.all(40),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Color(0xFFFB2056),
              image: DecorationImage(
                image: AssetImage('assets/finance.png'), // Agrega tu imagen
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Text(
                'Money Fácil',
                style: TextStyle(
                  fontSize: 32.0,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black.withOpacity(0.3),
                      offset: Offset(2, 2),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
        // Formulario de login mejorado
        Expanded(
          child: Container(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
              child: LoginForm(),
            ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet,
                    color: Color(0xFFFB2056), size: 40),
                SizedBox(width: 10),
                Text(
                  'Money Fácil',
                  style: TextStyle(
                    fontSize: 34.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFB2056),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Iniciar Sesión',
              style: TextStyle(
                fontSize: 24.0,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 50.0),
        _buildTextField(
          label: 'Usuario',
          icon: Icons.person_outline,
        ),
        SizedBox(height: 30.0),
        _buildTextField(
          label: 'Contraseña',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(color: Color(0xFFFB2056)),
            ),
          ),
        ),
        SizedBox(height: 40.0),
        ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Color(0xFFFB2056)),
            padding: MaterialStateProperty.all(
                EdgeInsets.symmetric(vertical: 18)),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            elevation: MaterialStateProperty.all(5),
            shadowColor: MaterialStateProperty.all(Color(0xFFFB2056).withOpacity(0.3)),
          ),
          onPressed: () {},
          child: Text(
            'Ingresar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('¿No tienes cuenta? ',
                style: TextStyle(color: Colors.grey[700])),
            TextButton(
              onPressed: () {},
              child: Text(
                'Regístrate',
                style: TextStyle(
                  color: Color(0xFFFB2056),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({required String label, required IconData icon, bool isPassword = false}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          fontSize: 15,
        ),
      ),
      SizedBox(height: 8),
      TextFormField(
        style: TextStyle(color: Colors.grey[800]),
        obscureText: isPassword,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[500]), // Ícono con color destacado
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          
          enabledBorder: OutlineInputBorder( // Borde normal (sin foco)
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
          ),
          
          focusedBorder: OutlineInputBorder( // Borde cuando se enfoca
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color(0xFFFB2056), width: 2),
          ),

          errorBorder: OutlineInputBorder( // Borde en caso de error
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.redAccent, width: 2),
          ),
          
          focusedErrorBorder: OutlineInputBorder( // Borde en error cuando está enfocado
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),

          hintText: 'Ingrese su ${label.toLowerCase()}',
          hintStyle: TextStyle(color: Colors.grey[400]),

     
        ),
      ),
    ],
  );
}
}