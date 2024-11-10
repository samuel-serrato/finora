import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:flutter/material.dart';
import 'package:money_facil/screens/clientes.dart';
import 'package:money_facil/screens/grupos.dart';
import 'package:money_facil/screens/home.dart';
import 'package:money_facil/screens/creditos.dart';
import 'package:money_facil/screens/simulador.dart';

class NavigationScreen extends StatefulWidget {
  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  PageController pageController = PageController();
  SideMenuController sideMenu = SideMenuController();
  bool isMenuOpen = true;

  @override
  void initState() {
    super.initState();
    sideMenu.addListener((index) {
      pageController.jumpToPage(index);
    });
  }

  void toggleMenu() {
    setState(() {
      isMenuOpen = !isMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: isMenuOpen ? 180 : 110,
            child: SideMenu(
              controller: sideMenu,
              showToggle: false,
              style: SideMenuStyle(
                displayMode: isMenuOpen
                    ? SideMenuDisplayMode.open
                    : SideMenuDisplayMode.compact,
                hoverColor: Colors.blue[100],
                selectedHoverColor: Color.fromARGB(255, 172, 17, 56),
                selectedColor: Color(0xFFFB2056),
                selectedTitleTextStyle: const TextStyle(color: Colors.white),
                selectedIconColor: Colors.white,
                unselectedTitleTextStyle: TextStyle(color: Colors.black),
                unselectedIconColor: Colors.black,
                backgroundColor: Colors.white,
              ),
              title: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 10), // Reduce el padding vertical
                child: Row(
                  children: [
                    SizedBox(
                      width: isMenuOpen ? 140 : 70,
                      height: isMenuOpen
                          ? 100
                          : 70, // Ajusta la altura cuando el menú esté abierto
                      child: Image.asset('assets/mf_logo.png',
                          fit: BoxFit
                              .contain), // Ajuste para evitar espacios innecesarios
                    ),
                    if (isMenuOpen) Spacer(),
                    Center(
                      child: IconButton(
                        icon: Icon(
                          isMenuOpen
                              ? Icons.arrow_back_ios
                              : Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey[700],
                        ),
                        onPressed: toggleMenu,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minHeight: 20,
                          minWidth: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              items: [
                SideMenuItem(
                  title: 'Home',
                  onTap: (index, _) => sideMenu.changePage(0),
                  icon: const Icon(Icons.home),
                ),
                SideMenuItem(
                  title: 'Créditos',
                  onTap: (index, _) => sideMenu.changePage(1),
                  icon: const Icon(Icons.request_page),
                ),
                SideMenuItem(
                  title: 'Grupos',
                  onTap: (index, _) => sideMenu.changePage(2),
                  icon: const Icon(Icons.group),
                ),
                SideMenuItem(
                  title: 'Clientes',
                  onTap: (index, _) => sideMenu.changePage(3),
                  icon: const Icon(Icons.person),
                ),
                SideMenuItem(
                  title: 'Simulador',
                  onTap: (index, _) => sideMenu.changePage(4),
                  icon: const Icon(Icons.edit_document),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: double.infinity,
            color: Colors.grey[300],
          ),
          Expanded(
            child: PageView(
              controller: pageController,
              children: [
                HomeScreen(username: 'samuel'),
                SeguimientoScreen(),
                GruposScreen(),
                ClientesScreen(),
                SimuladorScreen(username: 'samuel'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
