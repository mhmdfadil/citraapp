import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:citraapp/screens/content/product_detail_page.dart'; // Import the product detail page
import 'package:citraapp/login.dart';
import 'dart:convert';

class FavoritPage extends StatefulWidget {
  const FavoritPage({super.key});

  @override
  State<FavoritPage> createState() => _FavoritPageState();
}

class _FavoritPageState extends State<FavoritPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? userId;
  String _selectedSort = 'Terbaru';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
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

      // Get favorite product IDs for this user
      final favoritesResponse = await _supabase
          .from('favorites')
          .select('product_id')
          .eq('user_id', userId as Object);

      if (favoritesResponse.isEmpty) {
        setState(() {
          _favorites = [];
          _products = [];
          _isLoading = false;
        });
        return;
      }

      final favoriteIds = favoritesResponse.map((fav) => fav['product_id']).toList();

      // Get full product details for these IDs
      final productsResponse = await _supabase
          .from('products')
          .select()
          .inFilter('id', favoriteIds);

      setState(() {
        _products = List<Map<String, dynamic>>.from(productsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading favorites: $e')),
      );
    }
  }

  Future<void> _toggleFavorite(String productId) async {
    try {
      // Check if already favorited
      final existing = await _supabase
          .from('favorites')
          .select()
          .eq('user_id', userId!)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing == null) {
        // Add to favorites
        await _supabase
            .from('favorites')
            .insert({
              'user_id': userId,
              'product_id': productId,
              'created_at': DateTime.now().toIso8601String(),
            });
      } else {
        // Remove from favorites
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId!)
            .eq('product_id', productId);
      }

      // Refresh the list
      await _loadFavorites();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorite: $e')),
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
    if (sold < 10) return sold.toString();
    if (sold < 100) return '10+';
    if (sold < 1000) return '100+';
    if (sold < 10000) return '1RB+';
    if (sold < 100000) return '10RB+';
    if (sold < 1000000) return '100RB+';
    return '1JT+';
  }

  void _handleSortChange(String sortType) {
    setState(() {
      _selectedSort = sortType;
      if (sortType == 'Terbaru') {
        _products.sort((a, b) => b['created_at'].compareTo(a['created_at']));
      } else if (sortType == 'Harga Tertinggi') {
        _products.sort((a, b) => b['price_display'].compareTo(a['price_display']));
      } else if (sortType == 'Harga Terendah') {
        _products.sort((a, b) => a['price_display'].compareTo(b['price_display']));
      }
    });
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _selectedSort == title ? Colors.transparent : const Color(0xFFF273F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isSmallScreen) {
    final String? photoPath = product['photos'];
    final imageUrl = (photoPath != null && photoPath.isNotEmpty)
        ? _supabase.storage.from('picture-products').getPublicUrl(photoPath)
        : null;

    final soldCount = product['sold'] ?? 0;
    final formattedSold = _formatSoldCount(soldCount is int ? soldCount : int.tryParse(soldCount.toString()) ?? 0);
    final hasDiscount = product['price_ori'] != null && product['price_ori'] > product['price_display'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              productId: product['id'].toString(),
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
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
                                Container(
                                  color: Colors.grey[200],
                                  child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                                ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.favorite,
                      color: Colors.red[400],
                    ),
                    onPressed: () => _toggleFavorite(product['id'].toString()),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name']?.toString() ?? 'No Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 12 : 14),
                    ),
                    const SizedBox(height: 4),
                    if (hasDiscount)
                      Text(
                        'Rp ${_formatPrice(product['price_ori'])}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey[600],
                        ),
                      ),
                    Text(
                      'Rp ${_formatPrice(product['price_display'] ?? 0)}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF273F0),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.local_shipping, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Icon(Icons.credit_card, size: 14, color: Colors.grey),
                          ],
                        ),
                        Text(
                          '$formattedSold terjual',
                          style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorit Saya'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF273F0),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
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
                        Icons.favorite_border,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada produk favorit',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tambahkan produk ke favorit untuk melihatnya di sini',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSortChip('Terbaru'),
                            const SizedBox(width: 8),
                            _buildSortChip('Tertinggi'),
                            const SizedBox(width: 8),
                            _buildSortChip('Terendah'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isSmallScreen ? 2 : 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(_products[index], isSmallScreen);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}