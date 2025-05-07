import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/content/filter_category.dart';

class CategoryContent extends StatefulWidget {
  const CategoryContent({super.key});

  @override
  State<CategoryContent> createState() => _CategoryContentState();
}

class _CategoryContentState extends State<CategoryContent> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  // Sophisticated color palette
  final List<Color> _cardColors = [
    const Color(0xFF6C5CE7), // Deep lavender
    const Color(0xFF00B894), // Mint green
    const Color(0xFFFD79A8), // Soft pink
    const Color(0xFF0984E3), // Ocean blue
    const Color(0xFFE17055), // Coral
    const Color(0xFF00CEC9), // Tiffany blue
    const Color(0xFFA29BFE), // Light lavender
    const Color(0xFF55EFC4), // Light mint
    const Color(0xFF74B9FF), // Sky blue
    const Color(0xFFFDCB6E), // Golden
    const Color(0xFFE84393), // Raspberry
    const Color(0xFF636E72), // Gray
    const Color(0xFFB2BEC3), // Light gray
    const Color(0xFF00B4D8), // Cyan
    const Color(0xFF6D6875), // Muted purple
  ];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select('id, name')
          .order('name', ascending: true);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching categories: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  void _closeMenuAndNavigate(VoidCallback action) {
    // Close any open drawers or menus if needed
    if (Scaffold.of(context).isDrawerOpen) {
      Navigator.of(context).pop(); // Close drawer
      Future.delayed(const Duration(milliseconds: 250), action);
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 
        ? (screenWidth > 900 ? 5 : 4) 
        : (screenWidth > 400 ? 3 : 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Kategori Produk',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 19,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF273F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.85,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return _buildCategoryCard(category, index);
                },
              ),
            ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    final color = _cardColors[index % _cardColors.length];
    final textColor = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
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
              splashColor: Colors.white.withOpacity(0.2),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.9),
                      color.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative elements
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // Content
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getCategoryIcon(category['name']),
                                size: 32,
                                color: textColor.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              category['name'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('elec')) return Icons.electrical_services;
    if (name.contains('cloth')) return Icons.checkroom;
    if (name.contains('food')) return Icons.fastfood;
    if (name.contains('book')) return Icons.menu_book;
    if (name.contains('tech')) return Icons.computer;
    if (name.contains('home')) return Icons.home;
    if (name.contains('sport')) return Icons.sports;
    if (name.contains('health')) return Icons.medical_services;
    if (name.contains('beauty')) return Icons.spa;
    if (name.contains('toy')) return Icons.toys;
    return Icons.category;
  }
}