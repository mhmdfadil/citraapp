import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '/screens/content/chat.dart';
import '/screens/content/checkout.dart';

class CartContent extends StatefulWidget {
  const CartContent({super.key});

  @override
  State<CartContent> createState() => _CartContentState();
}

class _CartContentState extends State<CartContent> {
  bool selectAll = false;
  final List<CartItem> items = [
    CartItem(
      brand: 'WARDAH',
      name: 'Sunscreen Wardah',
      price: 'Rp.35.000-50.000',
      imageUrl:
          'assets/images/war1.png',
      isSelected: false,
    ),
    CartItem(
      brand: 'SKINTIFIC',
      name: 'Serum Skintific',
      price: 'Rp.90.000',
      imageUrl:
          'assets/images/war2.png',
      isSelected: false,
    ),
    CartItem(
      brand: 'GLAD2GLOW',
      name: 'Moisturizer Glad2glow',
      price: 'Rp.35.000',
      imageUrl:
          'assets/images/war3.png',
      isSelected: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 207, 242),
      appBar: AppBar(
        backgroundColor: Color(0xFFF273F0),
     leading: GestureDetector(
     onTap: () => Navigator.pop(context),
  child: Container(
    width: 40,
    height: 40,
    margin: const EdgeInsets.all(8), // beri jarak di sekitar icon
    decoration: BoxDecoration(
      color: Colors.grey[300],
      shape: BoxShape.circle,
    ),
    child: const Center(
      child: Icon(
        FontAwesomeIcons.arrowLeft,
        color: Colors.black,
        size: 18,
      ),
    ),
  ),
),

        title: const Text(
          'Keranjang Saya(10)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
       actions: [
  IconButton(
    icon: const Icon(
      FontAwesomeIcons.commentDots,
      color: Colors.black,
      size: 28,
    ),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage()),
      );
    },
  ),
],

      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: items.map((item) => buildCartItem(item)).toList(),
      ),
     bottomNavigationBar: Container(
  height: 100,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border(top: BorderSide(color: Colors.grey[400]!)),
  ), // Added missing closing parenthesis here
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Checkbox(
            value: selectAll,
            onChanged: (value) {
              setState(() {
                selectAll = value!;
                for (var item in items) {
                  item.isSelected = selectAll;
                }
              });
            },
            activeColor: Colors.black,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
          const Text(
            'Semua',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
      const Row(
        children: [
          Text(
            'Total ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            'Rp 40.000',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF1E00),
            ),
          ),
        ],
      ),
     ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CheckoutPage()),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor:  Color(0xFFFF1E00),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
    elevation: 4,
  ),
  child: const Text(
    'Checkout',
    style: TextStyle(
      fontWeight: FontWeight.bold,
    ),
  ),
),

    ],
  ),
),
    );
  }

  Widget buildCartItem(CartItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: item.isSelected,
              onChanged: (value) {
                setState(() {
                  item.isSelected = value!;
                  selectAll = items.every((item) => item.isSelected);
                });
              },
              activeColor: Colors.black,
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
            Text(
              item.brand,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Ubah',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
         decoration: BoxDecoration(
  color: Colors.transparent, // Ubah dari Colors.white
  borderRadius: BorderRadius.circular(8),
  boxShadow: [

  ],
),

          child: Row(
            children: [
          Padding(
  padding: const EdgeInsets.all(12),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Container(
      color: Colors.white, // Warna latar belakang putih
      width: 112,
      height: 112,
      child: Image.network(
        item.imageUrl,
        fit: BoxFit.contain,
      ),
    ),
  ),
),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.price,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF1E00),
                        ),
                      ),
                      const SizedBox(height: 12),
                    Align(
  alignment: Alignment.centerRight, // Geser ke kanan
  child: ElevatedButton(
    onPressed: () {
      setState(() {
        items.remove(item);
      });
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.grey[300],
      foregroundColor: Color(0xFFFF1E00),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 8,
      ),
    ),
    child: const Text(
      'Hapus',
      style: TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
)
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class CartItem {
  String brand;
  String name;
  String price;
  String imageUrl;
  bool isSelected;

  CartItem({
    required this.brand,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.isSelected,
  });
}