import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/widget/appbar_a.dart';
import '/register.dart';

class HomeContent extends StatefulWidget {
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _showPopup = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
    
    if (isFirstTime && mounted) {
      setState(() {
        _showPopup = true;
      });
      await prefs.setBool('isFirstTime', false);
    }
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarA(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 4),
                // Banner
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/banner.png',
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Products
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ProductCard(
                              imageUrl: 'assets/images/war1.png',
                              title: 'Sunscreen Wardah',
                              price: 'Rp.35.000-50.000',
                              sold: '5RB+ terjual',
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ProductCard(
                              imageUrl: 'assets/images/war2.png',
                              title: 'Serum Skintific',
                              price: 'Rp.90.000',
                              sold: '1RB+ terjual',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ProductCard(
                              imageUrl: 'assets/images/war3.png',
                              title: 'Cushion Instaperfect',
                              price: 'Rp.160.000',
                              sold: '2RB+ terjual',
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ProductCard(
                              imageUrl: 'assets/images/war4.png',
                              title: 'Moisturizer Glad2glow',
                              price: 'Rp.35.000',
                              sold: '10RB+ terjual',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ProductCard(
                              imageUrl: 'assets/images/war3.png',
                              title: 'Cushion Instaperfect',
                              price: 'Rp.160.000',
                              sold: '2RB+ terjual',
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ProductCard(
                              imageUrl: 'assets/images/war4.png',
                              title: 'Moisturizer Glad2glow',
                              price: 'Rp.35.000',
                              sold: '10RB+ terjual',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showPopup)
            AnimatedOpacity(
              opacity: _showPopup ? 1.0 : 0.0,
              duration: Duration(milliseconds: 500),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Untuk bisa menikmati fitur aplikasi ini silahkan daftar terlebih dahulu',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.start,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tanpa daftar terlebih dahulu, anda tidak bisa mengakses aplikasi ini. Apakah anda ingin mendaftar?',
                        style: TextStyle(color: Colors.grey[700], fontSize: 16),
                        textAlign: TextAlign.start,
                      ),
                      const SizedBox(height: 21),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showPopup = false;
                              });
                            },
                            child: const Text(
                              'Sudah Daftar',
                              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 21),
                          TextButton(
                            onPressed:() => _navigateToRegister(context),
                            child: const Text(
                              'Daftar',
                              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String sold;

  const ProductCard({
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.sold,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      child: SizedBox(
        height: 235,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.asset(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            color: Colors.grey,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.credit_card, color: Colors.grey, size: 16),
                        ],
                      ),
                      Text(
                        sold,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}