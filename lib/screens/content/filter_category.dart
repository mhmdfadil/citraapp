import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:citraapp/screens/content/product_detail_page.dart';

class FilterCategoryPage extends StatefulWidget {
  final int categoryId;

  const FilterCategoryPage({Key? key, required this.categoryId}) : super(key: key);

  @override
  _FilterCategoryPageState createState() => _FilterCategoryPageState();
}

class _FilterCategoryPageState extends State<FilterCategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  String _selectedSort = 'Terlaris';
  String _categoryName = '';
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchCategoryAndProducts();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => _filterProducts();

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchCategoryAndProducts() async {
    try {
      final categoryResponse = await _supabase
          .from('categories')
          .select('name')
          .eq('id', widget.categoryId)
          .single();

      setState(() {
        _categoryName = categoryResponse['name'] ?? 'Unknown Category';
      });

      await _fetchProducts(orderBy: 'sold', ascending: false);
    } catch (e) {
      print('Error fetching category: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProducts({required String orderBy, bool ascending = false}) async {
    setState(() => _isLoading = true);

    try {
      // First fetch all products
      final productsResponse = await _supabase
          .from('products')
          .select('id, name, price_ori, price_display, sold')
          .eq('category_id', widget.categoryId)
          .order(orderBy, ascending: ascending);

      // Convert to list of products
      List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(productsResponse);

      // For each product, fetch its first photo
      for (var product in products) {
        final photoResponse = await _supabase
            .from('photo_items')
            .select('id, name')
            .eq('product_id', product['id'])
            .order('created_at', ascending: true)
            .limit(1);

        if (photoResponse.isNotEmpty) {
          product['photo_item'] = photoResponse[0];
        }
      }

      setState(() {
        _products = products;
        _filteredProducts = List<Map<String, dynamic>>.from(products);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching products: $e');
      setState(() => _isLoading = false);
    }
  }

  void _handleSortChange(String sortType) {
    setState(() => _selectedSort = sortType);

    switch (sortType) {
      case 'Terlaris':
        _fetchProducts(orderBy: 'sold', ascending: false);
        break;
      case 'Tertinggi':
        _fetchProducts(orderBy: 'price_display', ascending: false);
        break;
      case 'Terendah':
        _fetchProducts(orderBy: 'price_display', ascending: true);
        break;
    }
  }

  String _formatSoldCount(int sold) {
  if (sold < 1000) {
    return sold.toString();
  } else if (sold < 10000) {
    double thousands = sold / 1000;
    return thousands.toStringAsFixed(thousands % 1 == 0 ? 0 : 1) + ' K+';
  } else if (sold < 1000000) {
    double thousands = sold / 1000;
    return thousands.toStringAsFixed(thousands % 1 == 0 ? 0 : 1) + ' K+';
  } else {
    double millions = sold / 1000000;
    return millions.toStringAsFixed(millions % 1 == 0 ? 0 : 1) + ' JT+';
  }
}

  String _formatPrice(dynamic price) {
    final intPrice = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return intPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final crossAxisCount = screenWidth < 600 ? 2 : 4;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Kategori Produk: $_categoryName',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFF273F0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Cari produk...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFF273F0)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                ),
                onTap: () => setState(() => _isSearching = true),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                _buildSortChip('Terlaris'),
                const SizedBox(width: 8),
                _buildSortChip('Tertinggi'),
                const SizedBox(width: 8),
                _buildSortChip('Terendah'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF273F0)))
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Produk tidak ditemukan', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          itemCount: _filteredProducts.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.7,
                          ),
                          itemBuilder: (context, index) {
                            return _buildProductCard(_filteredProducts[index], isSmallScreen);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
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
    // Get the photo item if it exists
    final photoItem = product['photo_item'] as Map<String, dynamic>?;
    final imageUrl = photoItem != null 
        ? _supabase.storage.from('picture-products').getPublicUrl(photoItem['name'])
        : null;

    final soldCount = product['sold'] ?? 0;
    final formattedSold = _formatSoldCount(soldCount is int ? soldCount : int.tryParse(soldCount.toString()) ?? 0);
    final hasDiscount = product['price_ori'] != null && product['price_ori'] > product['price_display'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias, // Ensure nothing overflows the card
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image container with fixed aspect ratio
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Colors.grey[200],
                ),
                child: imageUrl?.isNotEmpty == true
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
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
            // Content section with flexible height but constrained
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name with max lines and overflow handling
                        SizedBox(
                          height: isSmallScreen ? 36 : 40, // Fixed height for name
                          child: Text(
                            product['name']?.toString() ?? 'No Name',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Price section
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
                      ],
                    ),
                    // Bottom row with shipping icons and sold count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_shipping, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Icon(Icons.credit_card, size: 14, color: Colors.grey),
                          ],
                        ),
                        Text(
                          '$formattedSold terjual',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: Colors.grey[600],
                          ),
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
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}