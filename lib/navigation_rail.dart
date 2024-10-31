import 'package:flutter/material.dart';
import 'package:money_facil/screens/clientes.dart';
import 'package:money_facil/screens/grupos.dart';
import 'package:money_facil/screens/home.dart';
import 'package:money_facil/screens/seguimiento.dart';
import 'package:money_facil/screens/simulador.dart'; // Importa el archivo de ajustes


class NavigationRailScreen extends StatefulWidget {
  @override
  _NavigationRailScreenState createState() => _NavigationRailScreenState();
}

class _NavigationRailScreenState extends State<NavigationRailScreen> {
  int _selectedIndex = 0;

  List<Widget> _widgetOptions = <Widget>[
    HomeScreen(username: 'samuel',),
    SeguimientoScreen(),
    GruposScreen(),
    ClientesScreen(),
    SimuladorScreen(username: 'samuel',)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            elevation: 5,
            minWidth: 150,
            labelType: NavigationRailLabelType.all,
            selectedLabelTextStyle: TextStyle(color: Color(0xFF2A61FF), fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: TextStyle(color: Color(0xFF5A5A5A), fontWeight: FontWeight.bold),
            backgroundColor: Colors.white,
            indicatorColor: Color(0xFFF2F6FF),
            useIndicator: true,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home, color: Color(0xFF5A5A5A),),
                selectedIcon: Icon(Icons.home, color: Color(0xFF2A61FF)),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.content_paste_search, color: Color(0xFF5A5A5A)),
                selectedIcon: Icon(Icons.content_paste_search, color: Color(0xFF2A61FF)),
                label: Text('Seguimiento'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.group, color: Color(0xFF5A5A5A)),
                selectedIcon: Icon(Icons.group, color: Color(0xFF2A61FF)),
                label: Text('Grupos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person, color: Color(0xFF5A5A5A)),
                selectedIcon: Icon(Icons.person, color: Color(0xFF2A61FF)),
                label: Text('Clientes'),
              ),
               NavigationRailDestination(
                icon: Icon(Icons.edit_document, color: Color(0xFF5A5A5A)),
                selectedIcon: Icon(Icons.edit_document, color: Color(0xFF2A61FF)),
                label: Text('Simulador'),
              ),
            ],
          ),
          Expanded(
            child: _widgetOptions.elementAt(_selectedIndex),
          ),
        ],
      ),
    );
  }
}
