import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/content/profile_mitra.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/login.dart';

class AppBarA extends StatefulWidget implements PreferredSizeWidget {
  @override
  _AppBarAState createState() => _AppBarAState();

  @override
  Size get preferredSize => Size.fromHeight(84);
}

class _AppBarAState extends State<AppBarA> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late OverlayEntry _menuOverlay;

  late final List<Map<String, dynamic>> _menuItems;

  @override
  void initState() {
    super.initState();

    _menuItems = [
      {'icon': Icons.menu_outlined, 'isFirstItem': true, 'onTap': true},
      {'icon': Icons.dashboard_outlined, 'text': 'Kategori Produk'},
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
        'action': _handleLogout // Updated to use the dedicated logout handler
      },
    ];

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(1, 0),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _menuOverlay = OverlayEntry(builder: (context) => _buildMenuOverlay());
  }

  Future<void> _handleLogout(BuildContext context) async {
    if (_isMenuOpen) {
      _toggleMenu();
      await Future.delayed(Duration(milliseconds: 300));
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: EdgeInsets.all(24),
        content: Column(
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
            Text(
              "Anda akan keluar dari aplikasi. Yakin ingin melanjutkan?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text("Batal", style: TextStyle(color: Colors.grey[700])),
                  ),
                ),
                SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Color(0xFFF273F0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text("Keluar", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
      // 1. Clear Supabase session
      await Supabase.instance.client.auth.signOut();

      // 2. Clear local session data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id'); // Remove only user_id
      await prefs.remove('session_expiry'); // Remove session expiry

      // 3. Navigate to login page
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
      navigator.pop(); // Close loading dialog
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal logout: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
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
      }
    });
  }

  Widget _buildMenuOverlay() {
    final RenderBox? appBarRenderBox = context.findRenderObject() as RenderBox?;
    if (appBarRenderBox == null) return Container();
    
    final position = appBarRenderBox.localToGlobal(Offset.zero);

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
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 250,
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
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String text, [Function(BuildContext)? action]) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (action != null) {
            action(context);
          } else {
            _toggleMenu();
          }
        },
        hoverColor: Color(0xFFF273F0),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 24, color: Colors.black87),
              SizedBox(width: 16),
              Text(text, style: TextStyle(fontSize: 16, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Color(0xFFF273F0),
      flexibleSpace: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: 25, left: 11, right: 11),
          child: Row(
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
                          controller: _searchController,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Cari produk di sini',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _isSearching = value.isNotEmpty;
                            });
                          },
                        ),
                      ),
                      if (_isSearching)
                        TextButton(
                          onPressed: () {
                            print('Searching for: ${_searchController.text}');
                          },
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
        ),
      ),
    );
  }
}