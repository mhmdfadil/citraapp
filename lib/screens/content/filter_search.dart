import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:citraapp/screens/content/product_detail_page.dart'; // Import the product detail page

class FilterSearchPage extends StatefulWidget {
  final String initialQuery;

  const FilterSearchPage({Key? key, required this.initialQuery}) : super(key: key);

  @override
  _FilterSearchPageState createState() => _FilterSearchPageState();
}

class _FilterSearchPageState extends State<FilterSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  String _selectedSort = 'Terlaris';
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  final FocusNode _searchFocusNode = FocusNode();
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.initialQuery;
    _searchController.text = widget.initialQuery;
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);

    try {
      // Main query to get products with first photo from photo_items
      PostgrestFilterBuilder<dynamic> query = _supabase
          .from('products')
          .select('''
            id, 
            name, 
            price_ori, 
            price_display, 
            sold, 
            desc,
            photo_items:photo_items!product_id (
              id,
              name
            ).limit(1).order(created_at, ascending: true)
          ''');

      if (_currentQuery.isNotEmpty) {
        query = query.ilike('name', '%${_currentQuery.toLowerCase()}%');
      }

      PostgrestTransformBuilder<dynamic> sortedQuery;
      switch (_selectedSort) {
        case 'Terlaris':
          sortedQuery = query.order('sold', ascending: false);
          break;
        case 'Tertinggi':
          sortedQuery = query.order('price_display', ascending: false);
          break;
        case 'Terendah':
          sortedQuery = query.order('price_display', ascending: true);
          break;
        default:
          sortedQuery = query.order('sold', ascending: false);
      }

      final response = await sortedQuery;

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

  void _handleSearch() {
    final searchText = _searchController.text.trim();
    setState(() {
      _currentQuery = searchText;
    });
    _fetchProducts();
    _searchFocusNode.unfocus();
  }

  void _handleSortChange(String sortType) {
    setState(() => _selectedSort = sortType);
    _fetchProducts();
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
    final cardHeight = screenWidth < 600 ? cardWidth * 1.6 : cardWidth * 1.6;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pencarian Produk',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFF273F0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
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
                                  setState(() {
                                    _currentQuery = '';
                                  });
                                  _fetchProducts();
                                },
                              )
                            : null,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _handleSearch(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 75, 61, 75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Cari', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Hasil pencarian untuk: "$_currentQuery"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    _buildSortChip('Terlaris'),
                    const SizedBox(width: 8),
                    _buildSortChip('Tertinggi'),
                    const SizedBox(width: 8),
                    _buildSortChip('Terendah'),
                  ],
                ),
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
                            Text(
                              _currentQuery.isEmpty
                                  ? 'Masukkan kata kunci pencarian'
                                  : 'Produk tidak ditemukan',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                            if (_currentQuery.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Coba kata kunci lain atau periksa ejaan',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                ),
                              ),
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
                            childAspectRatio: cardWidth / cardHeight,
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
    // Get the first photo item (if any)
    final photoItems = product['photo_items'] as List?;
    final photoItem = photoItems != null && photoItems.isNotEmpty ? photoItems[0] : null;
    final photoName = photoItem != null ? photoItem['name'] as String? : null;
    
    final imageUrl = photoName != null
        ? _supabase.storage.from('picture-products').getPublicUrl(photoName)
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
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}