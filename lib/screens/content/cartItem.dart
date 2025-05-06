class CartItem {
  final int id;
  final int product_id;
  final String category;
  final String name;
  final String price;
  final String imageUrl;
  int quantity;
  bool isSelected;

  CartItem({
    required this.id,
    required this.product_id,
    required this.category,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
    this.isSelected = true,
  });
}
