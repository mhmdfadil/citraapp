import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:citraapp/screens/content/promo_detail_page.dart'; 
import 'package:citraapp/login.dart';
import 'package:citraapp/screens/user_screen.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class PromoPage extends StatefulWidget {
  const PromoPage({super.key});

  @override
  State<PromoPage> createState() => _PromoPageState();
}

class _PromoPageState extends State<PromoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _promos = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, String?> _productPhotos = {};
  bool _isLoading = true;
  String? userId;
  String _selectedSort = 'Terbaru';
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPromos();
  }

  Future<void> _loadPromos() async {
    try {
      setState(() => _isLoading = true);
      
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');
      
      if (userId == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
        return;
      }

      // Format tanggal sekarang untuk query
      final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_now);

      // Get active promos (where current date is between start_date and end_date)
      final promosResponse = await _supabase
          .from('promos')
          .select()
          .lte('start_date', nowStr)
          .gte('end_date', nowStr);

      if (promosResponse.isEmpty) {
        setState(() {
          _promos = [];
          _products = [];
          _isLoading = false;
        });
        return;
      }

      // Get product IDs from promos
      final productIds = promosResponse.map((promo) => promo['product_id']).toList();

      // Get full product details for these IDs
      final productsResponse = await _supabase
          .from('products')
          .select()
          .inFilter('id', productIds);

      // Get photos for these products from photo_items table
      final photosResponse = await _supabase
          .from('photo_items')
          .select('id, name, product_id')
          .inFilter('product_id', productIds)
          .order('created_at', ascending: true);

      // Create a map of product_id to first photo
      final photoMap = <String, String?>{};
      for (var photo in photosResponse) {
        if (!photoMap.containsKey(photo['product_id'].toString())) {
          photoMap[photo['product_id'].toString()] = photo['name'];
        }
      }

      // Create a map of product_id to promo data
      final promoMap = <String, Map<String, dynamic>>{};
      for (var promo in promosResponse) {
        promoMap[promo['product_id'].toString()] = promo;
      }

      setState(() {
        _products = List<Map<String, dynamic>>.from(productsResponse);
        _productPhotos = photoMap;
        _promos = promosResponse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading promos: $e')),
      );
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatSoldCount(int sold) {
    if (sold < 1000) {
      return sold.toString();
    } else if (sold < 10000) {
      double thousands = sold / 1000;
      return thousands.toStringAsFixed(thousands % 1 == 0 ? 0 : 1) + 'rb';
    } else if (sold < 1000000) {
      double thousands = sold / 1000;
      return thousands.toStringAsFixed(thousands % 1 == 0 ? 0 : 1) + 'rb';
    } else {
      double millions = sold / 1000000;
      return millions.toStringAsFixed(millions % 1 == 0 ? 0 : 1) + 'jt';
    }
  }

  Widget _buildSortChip(String title) {
    return ChoiceChip(
      label: Text(
        title,
        style: TextStyle(
          color: _selectedSort == title ? Colors.white : const Color(0xFFF273F0),
          fontSize: 12,
        ),
      ),
      selected: _selectedSort == title,
      onSelected: (_) => _handleSortChange(title),
      selectedColor: const Color(0xFFF273F0),
     
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _selectedSort == title ? Colors.transparent : const Color(0xFFF273F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  void _handleSortChange(String sortType) {
    setState(() {
      _selectedSort = sortType;
      
      switch (sortType) {
        case 'Terbaru':
          _products.sort((a, b) => b['created_at'].compareTo(a['created_at']));
          break;
        case 'Tertinggi':
          _products.sort((a, b) => (b['price_display'] ?? 0).compareTo(a['price_display'] ?? 0));
          break;
        case 'Terendah':
          _products.sort((a, b) => (a['price_display'] ?? 0).compareTo(b['price_display'] ?? 0));
          break;
      }
    });
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
      // Get promo data for this product
    final promo = _promos.firstWhere(
      (p) => p['product_id'] == product['id'],
      orElse: () => {},
    );

    // Get photo from our photo map
    final photoPath = _productPhotos[product['id'].toString()];
    final imageUrl = photoPath != null
        ? _supabase.storage.from('picture-products').getPublicUrl(photoPath)
        : null;

    final soldCount = product['sold'] ?? 0;
    final formattedSold = _formatSoldCount(soldCount is int ? soldCount : int.tryParse(soldCount.toString()) ?? 0);
    final hasDiscount = promo.isNotEmpty && promo['price_ori'] != null && promo['price_ori'] > promo['price_display'];

    // Format promo period
    String promoPeriod = '';
    if (promo.isNotEmpty) {
      final startDate = DateTime.parse(promo['start_date']).toLocal();
      final endDate = DateTime.parse(promo['end_date']).toLocal();
      
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      
      final formatTime = (DateTime date) {
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      };
      
      final formattedStartDate = '${startDate.day.toString().padLeft(2, '0')} ${monthNames[startDate.month - 1]} ${startDate.year} ${formatTime(startDate)}';
      final formattedEndDate = '${endDate.day.toString().padLeft(2, '0')} ${monthNames[endDate.month - 1]} ${endDate.year} ${formatTime(endDate)}';
      
      promoPeriod = '$formattedStartDate - $formattedEndDate';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PromoDetailPage(
              productId: product['id'].toString(),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: const Color(0xFFF273F0),
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => 
                              Image.asset(
                                'assets/images/placeholder.png',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/images/placeholder.png',
                              fit: BoxFit.cover,
                          ),
                  ),
                ),
                if (promo.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PROMO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Product Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    product['name']?.toString() ?? 'No Name',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Price Section
                  if (hasDiscount)
                    Text(
                      'Rp${_formatPrice(promo['price_ori'])}',
                      style: TextStyle(
                        fontSize: 10,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  
                  Row(
                    children: [
                      Text(
                        'Rp${_formatPrice(promo.isNotEmpty ? promo['price_display'] : product['price_display'] ?? 0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF273F0),
                        ),
                      ),
                      if (promo.isNotEmpty && promo['diskon'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${promo['diskon']}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Promo Period
                  if (promo.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 12, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            promoPeriod,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 6),
                  
                  // Footer (Shipping icons and sold count)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Icon(Icons.credit_card_outlined, size: 14, color: Colors.grey.shade500),
                        ],
                      ),
                      Text(
                        '$formattedSold terjual',
                        style: TextStyle(
                          fontSize: 10, 
                          color: Colors.grey.shade600
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Disable back button functionality
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Promo Hari Ini'),
          centerTitle: true,
          backgroundColor: const Color(0xFFF273F0),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => UserScreen()),
              );
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF273F0)))
            : _products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.discount_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada promo saat ini',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cek kembali di lain waktu untuk promo menarik',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Sort Chips
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              _buildSortChip('Terbaru'),
                              const SizedBox(width: 8),
                              _buildSortChip('Tertinggi'),
                              const SizedBox(width: 8),
                              _buildSortChip('Terendah'),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),
                      ),
                      
                      // Product Grid
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75, // Adjusted for better proportions
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(_products[index]);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}