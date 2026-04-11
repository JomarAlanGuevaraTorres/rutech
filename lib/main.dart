import 'package:flutter/material.dart';
import 'package:rutech/database/db_helper.dart';
import 'theme/colors.dart';
import 'screens/mapa_screen.dart';
import 'screens/geo_screen.dart';
import 'screens/ruta_screen.dart';
import 'screens/base_screen.dart';
import 'screens/reportes_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RuTechApp());
  await DBHelper.limpiarRutasDuplicadas();
}

class RuTechApp extends StatelessWidget {
  const RuTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RuTech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.verde),
        fontFamily: 'DM Sans',
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    MapaScreen(),
    GeoScreen(),
    RutaScreen(),
    BaseScreen(),
    ReportesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppColors.verdeDark,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.none,
            indicatorColor: AppColors.amarillo,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined, color: Colors.white54),
                selectedIcon: Icon(Icons.map, color: Color(0xFF145A25)),
                label: Text('Mapa'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.my_location_outlined, color: Colors.white54),
                selectedIcon: Icon(Icons.my_location, color: Color(0xFF145A25)),
                label: Text('Geo'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.route_outlined, color: Colors.white54),
                selectedIcon: Icon(Icons.route, color: Color(0xFF145A25)),
                label: Text('Ruta'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline, color: Colors.white54),
                selectedIcon: Icon(Icons.people, color: Color(0xFF145A25)),
                label: Text('Base'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined, color: Colors.white54),
                selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF145A25)),
                label: Text('Reportes'),
              ),
            ],
          ),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}