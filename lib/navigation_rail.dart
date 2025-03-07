import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:finora/screens/reportes.dart';
import 'package:flutter/material.dart';
import 'package:finora/screens/clientes.dart';
import 'package:finora/screens/grupos.dart';
import 'package:finora/screens/home.dart';
import 'package:finora/screens/creditos.dart';
import 'package:finora/screens/simulador.dart';
import 'package:finora/screens/usuarios.dart';

class NavigationScreen extends StatefulWidget {
  final String username;
  final String rol;
  final String userId;
  final String userType;
  final double scaleFactor; // Pasa el scaleFactor calculado

  const NavigationScreen({
    required this.username,
    required this.rol,
    required this.userId,
    required this.userType,
    required this.scaleFactor,
  });

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
      if (index < _buildPages().length) {
        pageController.jumpToPage(index);
      }
    });
  }

  void toggleMenu() {
    setState(() {
      isMenuOpen = !isMenuOpen;
    });
  }

  List<Widget> _buildPages() {
    List<Widget> pages = [
      HomeScreen(username: widget.username, tipoUsuario: widget.userType),
      SeguimientoScreen(username: widget.username, tipoUsuario: widget.userType),
      GruposScreen(username: widget.username, tipoUsuario: widget.userType),
      ClientesScreen(username: widget.username, tipoUsuario: widget.userType),
      SimuladorScreen(username: widget.username, tipoUsuario: widget.userType),
    ];

    if (widget.userType == 'Admin') {
      pages.add(GestionUsuariosScreen(username: widget.username, tipoUsuario: widget.userType));
    }

    if (widget.userType != 'Invitado') {
      pages.add(ReportesScreen(username: widget.username, tipoUsuario: widget.userType));
    }

    return pages;
  }

  List<SideMenuItem> _buildMenuItems() {
    List<SideMenuItem> items = [
      SideMenuItem(title: 'Home', onTap: (index, _) => sideMenu.changePage(0), icon: const Icon(Icons.home)),
      SideMenuItem(title: 'Créditos', onTap: (index, _) => sideMenu.changePage(1), icon: const Icon(Icons.request_page)),
      SideMenuItem(title: 'Grupos', onTap: (index, _) => sideMenu.changePage(2), icon: const Icon(Icons.group)),
      SideMenuItem(title: 'Clientes', onTap: (index, _) => sideMenu.changePage(3), icon: const Icon(Icons.person)),
      SideMenuItem(title: 'Simulador', onTap: (index, _) => sideMenu.changePage(4), icon: const Icon(Icons.edit_document)),
    ];

    if (widget.userType == 'Admin') {
      items.add(SideMenuItem(title: 'Usuarios', onTap: (index, _) => sideMenu.changePage(5), icon: const Icon(Icons.manage_accounts)));
    }

    if (widget.userType != 'Invitado') {
      int reportesIndex = widget.userType == 'Admin' ? 6 : 5; // Ajuste de índice dinámico
      items.add(SideMenuItem(title: 'Reportes', onTap: (index, _) => sideMenu.changePage(reportesIndex), icon: const Icon(Icons.insert_chart_rounded)));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = _buildPages();
    final List<SideMenuItem> menuItems = _buildMenuItems();

    // Depuración: Ver lista de páginas y elementos del menú
    print("Páginas disponibles: ${pages.length}");
    print("Elementos del menú: ${menuItems.length}");

    double menuWidth = 180 * widget.scaleFactor;
    double collapsedMenuWidth = 90 * widget.scaleFactor;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: isMenuOpen ? menuWidth : collapsedMenuWidth,
            child: SideMenu(
              controller: sideMenu,
              showToggle: false,
              style: SideMenuStyle(
                itemOuterPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                displayMode: isMenuOpen ? SideMenuDisplayMode.open : SideMenuDisplayMode.compact,
                hoverColor: Colors.blue[100],
                selectedHoverColor: Color(0xFF2D336B),
                selectedColor: Color(0xFF5162F6),
                selectedTitleTextStyle: const TextStyle(color: Colors.white),
                selectedIconColor: Colors.white,
                unselectedTitleTextStyle: TextStyle(color: Colors.black),
                unselectedIconColor: Colors.black,
                backgroundColor: Colors.white,
              ),
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10),
                child: Row(
                  children: [
                    Padding(
                      padding: isMenuOpen ? EdgeInsets.zero : const EdgeInsets.all(10),
                      child: SizedBox(
                        width: isMenuOpen ? 140 : 30,
                        height: isMenuOpen ? 80 : 30,
                        child: Image.asset(isMenuOpen ? 'assets/finora_hzt.png' : 'assets/finora_icon.png', fit: BoxFit.contain),
                      ),
                    ),
                    if (isMenuOpen) Spacer(),
                    Center(
                      child: IconButton(
                        icon: Icon(
                          isMenuOpen ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey[700],
                        ),
                        onPressed: toggleMenu,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minHeight: 20, minWidth: 20),
                      ),
                    ),
                  ],
                ),
              ),
              items: menuItems,
              footer: Container(
                alignment: Alignment.bottomCenter,
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMenuOpen) ...[
                      SizedBox(height: 4),
                      Text('Desarrollado por', style: TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'Verdana', fontWeight: FontWeight.w100), textAlign: TextAlign.center),
                      Container(
                        alignment: Alignment.center,
                        height: 30,
                        width: 60,
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child: Image.asset('assets/codx_transparente_full_negro.png'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: double.infinity, color: Colors.grey[300]),
          Expanded(
            child: PageView(
              controller: pageController,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}