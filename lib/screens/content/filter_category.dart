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
      final response = await _supabase
          .from('products')
          .select('id, name, photos, price_ori, price_display, sold')
          .eq('category_id', widget.categoryId)
          .order(orderBy, ascending: ascending);

      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _filteredProducts = List<Map<String, dynamic>>.from(response);
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
    if (sold < 10) return sold.toString();
    if (sold < 100) return '10+';
    if (sold < 1000) return '100+';
    if (sold < 10000) return '1RB+';
    if (sold < 100000) return '10RB+';
    if (sold < 1000000) return '100RB+';
    return '1JT+';
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
    final cardWidth = (screenWidth - 32 - ((crossAxisCount - 1) * 16)) / crossAxisCount;

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
                            childAspectRatio: 0.7, // Fixed aspect ratio for consistent cards
                          ),
                          itemBuilder: (context, index) {
                            return _buildProductCard(_filteredProducts[index], isSmallScreen, cardWidth);
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

  Widget _buildProductCard(Map<String, dynamic> product, bool isSmallScreen, double cardWidth) {
    final String? photoPath = product['photos'];
    final imageUrl = (photoPath != null && photoPath.isNotEmpty)
        ? _supabase.storage.from('picture-products').getPublicUrl(photoPath)
        : null;

    final soldCount = product['sold'] ?? 0;
    final formattedSold = _formatSoldCount(soldCount is int ? soldCount : int.tryParse(soldCount.toString()) ?? 0);
    final hasDiscount = product['price_ori'] != null && product['price_ori'] > product['price_display'];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.zero,
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
                // Image section with fixed aspect ratio
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
                // Content section that expands based on text content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name']?.toString() ?? 'No Name',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
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
                        ],
                      ),
                      const SizedBox(height: 8),
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
              ],
            ),
          ),
        );
      },
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