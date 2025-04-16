import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'odoo_service.dart';
import 'sale_order_list_screen.dart';
import 'collection_screen.dart';
import 'check_giro_screen.dart';

class NavigationScreen extends StatefulWidget {
  final OdooService odooService;
  final int initialIndex;

  const NavigationScreen(
      {Key? key, required this.odooService, this.initialIndex = 0})
      : super(key: key);

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late int _selectedIndex;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pages = [
      HomeScreen(odooService: widget.odooService),
      SaleOrderListScreen(odooService: widget.odooService),
      CollectionScreen(odooService: widget.odooService),
      CheckGiroScreen(odooService: widget.odooService),
      ProfileScreen(odooService: widget.odooService),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Gunakan variabel lokal untuk menyimpan dan menghapus argumen
    final int? arguments = ModalRoute.of(context)?.settings.arguments as int?;
    if (arguments != null) {
      setState(() {
        _selectedIndex = arguments; // Set tab yang akan ditampilkan
      });

      // Simulasi penghapusan argumen dengan logika tambahan
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => NavigationScreen(
              odooService:
                  widget.odooService, // Pastikan odooService diteruskan
              initialIndex: arguments, // Tetapkan initialIndex ke argumen
            ),
            settings: const RouteSettings(
                arguments: null), // Atur arguments menjadi null
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.blueAccent, Colors.indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          showUnselectedLabels: false,
          selectedFontSize: 14,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: [
            _buildNavItem(Icons.home, "Home", 0),
            _buildNavItem(Icons.shopping_cart, "Sales Order", 1),
            _buildNavItem(Icons.attach_money, "Collection", 2),
            _buildNavItem(Icons.menu_book, "Check Giro", 3),
            _buildNavItem(Icons.person, "Profile", 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: Animate(
        target: _selectedIndex == index ? 1 : 0,
        effects: [
          ScaleEffect(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.2, 1.2),
            duration: const Duration(milliseconds: 300),
          ),
        ],
        child: Icon(icon),
      ),
      label: label,
    );
  }
}
