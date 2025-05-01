import 'package:flutter/material.dart';
import '/screens/widget/botappbar_a.dart';
import '/screens/content/home_screen.dart';
import '/screens/content/cart_screen.dart';
import '/screens/content/payment_screen.dart';
import '/screens/content/profile_screen.dart';

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  int _selectedIndex = 0; // Default: Home (index 0)
  final PageController _pageController = PageController(initialPage: 0);

  final List<Widget> _pages = [
    HomeContent(),    // Index 0 (Home)
    CartContent(),    // Index 1 (Cart)
    PaymentContent(), // Index 2 (Payment)
    ProfileContent(), // Index 3 (Profile)
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      // Hanya tampilkan BottomAppBarA jika bukan PaymentContent (index 2)
     bottomNavigationBar: (_selectedIndex != 1 && _selectedIndex != 3)
          ? BottomAppBarA(
              selectedIndex: _selectedIndex,
              onItemSelected: _onItemTapped,
            )
          : null,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}