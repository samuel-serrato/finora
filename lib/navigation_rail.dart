import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:finora/screens/bitacora.dart';
import 'package:finora/screens/reportes.dart';
import 'package:flutter/material.dart';
import 'package:finora/screens/clientes.dart';
import 'package:finora/screens/grupos.dart';
import 'package:finora/screens/home.dart';
import 'package:finora/screens/creditos.dart';
import 'package:finora/screens/simulador.dart';
import 'package:finora/screens/usuarios.dart';
import 'package:provider/provider.dart';
import 'package:finora/providers/theme_provider.dart';
import 'package:finora/providers/user_data_provider.dart'; // Añadir import

class NavigationScreen extends StatefulWidget {
  final double scaleFactor;

  const NavigationScreen({
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
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    List<Widget> pages = [
      HomeScreen(),
      SeguimientoScreen(),
      GruposScreen(),
      ClientesScreen(),
      SimuladorScreen(),
    ];

    if (userData.tipoUsuario == 'Admin') {
      pages.add(GestionUsuariosScreen());
    }

    if (userData.tipoUsuario != 'Invitado') {
      pages.add(ReportesScreen());
    }

    if (userData.tipoUsuario == 'Admin' || userData.tipoUsuario == 'Contador') {
      pages.add(BitacoraScreen()); // Bitácora al final
    }

    return pages;
  }

  // Reemplaza tu función _buildMenuItems completa con esta:
List<SideMenuItem> _buildMenuItems() {
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  
  // Usamos el índice que nos da el callback `onTap` para evitar errores.
  // El índice del menú coincidirá con el de la página si los construimos en el mismo orden.
  final changePage = (int index) => sideMenu.changePage(index);

  List<SideMenuItem> items = [
    SideMenuItem(
        title: 'Home',
        onTap: (index, _) => changePage(index),
        icon: const Icon(Icons.home_outlined)),
    SideMenuItem(
        title: 'Créditos',
        onTap: (index, _) => changePage(index),
        icon: const Icon(Icons.wallet_outlined)),
    SideMenuItem(
        title: 'Grupos',
        onTap: (index, _) => changePage(index),
        icon: const Icon(Icons.groups_2_outlined)),
    SideMenuItem(
        title: 'Clientes',
        onTap: (index, _) => changePage(index),
        icon: const Icon(Icons.person_outline)),
    SideMenuItem(
        title: 'Simulador',
        onTap: (index, _) => changePage(index),
        icon: const Icon(Icons.tune_outlined)),
  ];

  // La lógica ahora es IDÉNTICA a la de _buildPages
  
  // 1. Añadir Usuarios si es Admin
  if (userData.tipoUsuario == 'Admin') {
    items.add(SideMenuItem(
        title: 'Usuarios',
        onTap: (index, _) => changePage(index),
        icon: const Icon(Icons.manage_accounts_outlined)));
  }

  // 2. Añadir Reportes si NO es Invitado (esto ahora está fuera del bloque de Admin)
  if (userData.tipoUsuario != 'Invitado') {
    items.add(SideMenuItem(
        title: 'Reportes',
        onTap: (index, _) => changePage(index),
        icon: const Icon(Icons.insert_chart_outlined)));
  }
  
  // 3. Añadir Bitácora si es Admin (al final)
  if (userData.tipoUsuario == 'Admin' || userData.tipoUsuario == 'Contador') {
    items.add(SideMenuItem(
        title: 'Bitácora',
        onTap: (index, _) => changePage(index),
        icon: const Icon(Icons.history)));
  }

  return items;
}

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final List<Widget> pages = _buildPages();
    final List<SideMenuItem> menuItems = _buildMenuItems();

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
                itemOuterPadding:
                    EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                displayMode: isMenuOpen
                    ? SideMenuDisplayMode.open
                    : SideMenuDisplayMode.compact,
                hoverColor:
                    isDarkMode ? Colors.blueGrey[800] : Colors.blue[100],
                selectedHoverColor:
                    isDarkMode ? Colors.blueGrey[700] : Color(0xFF2D336B),
                selectedColor:
                    isDarkMode ? Colors.blueGrey[900] : Color(0xFF5162F6),
                selectedTitleTextStyle: TextStyle(color: Colors.white),
                selectedIconColor: Colors.white,
                unselectedTitleTextStyle:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                unselectedIconColor: isDarkMode ? Colors.white : Colors.black,
                backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              ),
              title: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10),
                child: Row(
                  children: [
                    Padding(
                      padding: isMenuOpen
                          ? EdgeInsets.zero
                          : const EdgeInsets.all(10),
                      child: SizedBox(
                        width: isMenuOpen ? 140 : 30,
                        height: isMenuOpen ? 80 : 30,
                        child: Image.asset(
                          isMenuOpen
                              ? (isDarkMode
                                  ? 'assets/finora_blanco.png' // Imagen horizontal para modo oscuro
                                  : 'assets/finora_hzt.png') // Imagen horizontal para modo claro
                              : (isDarkMode
                                  ? 'assets/finora_icon.png' // Imagen de ícono para modo oscuro
                                  : 'assets/finora_icon.png'), // Imagen de ícono para modo claro
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (isMenuOpen) Spacer(),
                    Center(
                      child: IconButton(
                        icon: Icon(
                          isMenuOpen
                              ? Icons.arrow_back_ios
                              : Icons.arrow_forward_ios,
                          size: 14,
                          color: isDarkMode ? Colors.white : Colors.grey[700],
                        ),
                        onPressed: toggleMenu,
                        padding: EdgeInsets.zero,
                        constraints:
                            BoxConstraints(minHeight: 20, minWidth: 20),
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
                      Text('Desarrollado por',
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontSize: 10,
                              fontFamily: 'Verdana',
                              fontWeight: FontWeight.w100),
                          textAlign: TextAlign.center),
                      Container(
                        alignment: Alignment.center,
                        height: 30,
                        width: 60,
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child: Image.asset(
                            isDarkMode
                                ? 'assets/codx_transparente_blanco.png' // Imagen para modo oscuro
                                : 'assets/codx_transparente_full_negro.png', // Imagen para modo claro
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
              width: 1,
              height: double.infinity,
              color: isDarkMode ? Colors.grey[800] : Colors.grey[300]),
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
