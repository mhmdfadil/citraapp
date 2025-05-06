import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/content/profile_mitra.dart';
import '/screens/content/filter_category.dart';
import '/screens/content/filter_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/login.dart';
import '/screens/content/payment_screen.dart';

class AppBarB extends StatefulWidget implements PreferredSizeWidget {
  @override
  _AppBarBState createState() => _AppBarBState();

  @override
  Size get preferredSize => Size.fromHeight(140);
}

class _AppBarBState extends State<AppBarB> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentSearchController = TextEditingController();
  bool _isSearching = false;
  bool _isPaymentSearching = false;
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late OverlayEntry _menuOverlay;
  bool _isCategoryDropdownOpen = false;
  List<Map<String, dynamic>> _categories = [];
  late AnimationController _dropdownAnimationController;

  late final List<Map<String, dynamic>> _menuItems;

  @override
  void initState() {
    super.initState();

    _menuItems = [
      {'icon': Icons.menu_outlined, 'isFirstItem': true, 'onTap': true},
      {
        'icon': Icons.dashboard_outlined,
        'text': 'Kategori Produk',
        'action': _toggleCategoryDropdown
      },
      {'icon': Icons.credit_card_outlined, 'text': 'Status Pesanan'},
      {'icon': Icons.settings_outlined, 'text': 'Pengaturan'},
      {
        'icon': Icons.info_outline_rounded,
        'text': 'Info Toko',
        'action': (BuildContext context) {
          _closeMenuAndNavigate(() {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileMitraPage()),
            );
          });
        }
      },
      {
        'icon': Icons.logout_outlined,
        'text': 'Keluar',
        'action': _handleLogout
      },
    ];

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _dropdownAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _menuOverlay = OverlayEntry(builder: (context) => _buildMenuOverlay());
    _fetchCategories();
  }

  void _handleSearch() {
    final searchText = _searchController.text.trim();
    if (searchText.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FilterSearchPage(initialQuery: searchText),
        ),
      );
    }
  }

  void _handlePaymentSearch() {
    final searchText = _paymentSearchController.text.trim();
    if (searchText.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentContent(searchQuery: searchText),
        ),
      );
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name', ascending: true);

      if (response != null && response is List) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  void _toggleCategoryDropdown(BuildContext context) {
    setState(() {
      _isCategoryDropdownOpen = !_isCategoryDropdownOpen;
      if (_isCategoryDropdownOpen) {
        _dropdownAnimationController.forward();
      } else {
        _dropdownAnimationController.reverse();
      }
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    if (_isMenuOpen) {
      _toggleMenu();
      await Future.delayed(Duration(milliseconds: 300));
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, size: 56, color: Color(0xFFF273F0)),
                SizedBox(height: 16),
                Text(
                  "Keluar dari Akun?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "Anda akan keluar dari aplikasi. Yakin ingin melanjutkan?",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text("Batal", 
                              style: TextStyle(color: Colors.grey[700])),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Flexible(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Color(0xFFF273F0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text("Keluar", 
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldLogout == true) {
      await _performLogout(context);
    }
  }

  Future<void> _performLogout(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      await Supabase.instance.client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('session_expiry');

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal logout: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paymentSearchController.dispose();
    _animationController.dispose();
    _dropdownAnimationController.dispose();
    _removeMenuOverlay();
    super.dispose();
  }

  void _removeMenuOverlay() {
    if (_menuOverlay.mounted) {
      _menuOverlay.remove();
    }
  }

  void _closeMenuAndNavigate(VoidCallback navigationAction) {
    if (_isMenuOpen) {
      _animationController.reverse().then((_) {
        _removeMenuOverlay();
        setState(() {
          _isMenuOpen = false;
          _isCategoryDropdownOpen = false;
          _dropdownAnimationController.reset();
        });
        navigationAction();
      });
    } else {
      navigationAction();
    }
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        Overlay.of(context)?.insert(_menuOverlay);
        _animationController.forward();
      } else {
        _animationController.reverse().then((_) {
          _removeMenuOverlay();
        });
        _isCategoryDropdownOpen = false;
        _dropdownAnimationController.reset();
      }
    });
  }

  Widget _buildMenuOverlay() {
    final RenderBox? appBarRenderBox = context.findRenderObject() as RenderBox?;
    if (appBarRenderBox == null) return Container();
    
    final position = appBarRenderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        if (_isMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

        Positioned(
          top: position.dy + widget.preferredSize.height - 45,
          right: 0,
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(1, 0),
                  end: Offset(0, 0),
                ).animate(_animationController),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: screenWidth * 0.7,
                    constraints: BoxConstraints(
                      maxWidth: 250,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._menuItems.map((item) {
                          if (item['isFirstItem'] == true) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: 12,
                                top: 10,
                                left: 18, 
                                right: 16,
                              ),
                              child: GestureDetector(
                                onTap: _toggleMenu,
                                child: Icon(item['icon'], size: 28),
                              ),
                            );
                          }
                          
                          return _buildMenuItem(
                            item['icon'], 
                            item['text'],
                            item['action'],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String text, [Function(BuildContext)? action]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (text == 'Kategori Produk') {
                _toggleCategoryDropdown(context);
              } else if (action != null) {
                action(context);
              } else {
                _toggleMenu();
              }
            },
            hoverColor: Color(0xFFF273F0).withOpacity(0.1),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: [
                  Icon(icon, size: 24, color: Colors.black87),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(text, 
                        style: TextStyle(fontSize: 16, color: Colors.black87)),
                  ),
                  if (text == 'Kategori Produk')
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(
                        CurvedAnimation(
                          parent: _dropdownAnimationController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 24,
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (text == 'Kategori Produk')
          SizeTransition(
            sizeFactor: _dropdownAnimationController,
            axisAlignment: 1.0,
            child: _buildCategoryDropdown(),
          ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: 60, right: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_categories.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada kategori tersedia',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ..._categories.map((category) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    print('Selected category: ${category['name']}');
                    _closeMenuAndNavigate(() {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FilterCategoryPage(
                            categoryId: category['id'],
                          ),
                        ),
                      );
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      category['name'],
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Color(0xFFF273F0),
      toolbarHeight: 150, // Adjusted height for both rows
      flexibleSpace: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: 15, left: 11, right: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Baris pertama (search dan menu button)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey, size: 28),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _paymentSearchController,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Cari pembayaran disini...',
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _isPaymentSearching = value.isNotEmpty;
                                });
                              },
                              onSubmitted: (value) {
                                _handlePaymentSearch();
                              },
                            ),
                          ),
                          if (_isPaymentSearching)
                            TextButton(
                              onPressed: _handlePaymentSearch,
                              child: Text(
                                'Cari',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.menu, color: Colors.white, size: 30),
                    onPressed: _toggleMenu,
                  ),
                ],
              ),
              
              SizedBox(height: 10), // Spasi antara search dan payment
              
              // Baris kedua (pembayaran)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: Colors.grey, size: 28),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Pembayaran',
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}