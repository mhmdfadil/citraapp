import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '/screens/content/cart_screen.dart';
import '/screens/content/address_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalPrice;
  final int totalItems;

  const CheckoutPage({
    Key? key,
    required this.cartItems,
    required this.totalPrice,
    required this.totalItems,
  }) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late double shippingCost;
  late double finalTotal;
  AddressData? selectedAddress;
  String? selectedPaymentMethod;
  List<String> availablePaymentMethods = [];
  final supabase = Supabase.instance.client;
  bool isLoadingPaymentMethods = true;

  @override
  void initState() {
    super.initState();
    shippingCost = 40000; // Default shipping cost
    finalTotal = widget.totalPrice + shippingCost + 5000 - 40000;
    _loadPrimaryAddress();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
  try {
    if (widget.cartItems.isEmpty) {
      setState(() => isLoadingPaymentMethods = false);
      return;
    }

    final productId = widget.cartItems.first.product_id;
    debugPrint('Fetching payment methods for product ID: $productId');

    final response = await supabase
        .from('products')
        .select('payment')
        .eq('id', productId)
        .maybeSingle();

    if (response == null || response['payment'] == null) {
      debugPrint('No payment methods found for product $productId');
      setState(() => isLoadingPaymentMethods = false);
      return;
    }

    final paymentData = response['payment'];
    debugPrint('Raw payment data: $paymentData (type: ${paymentData.runtimeType})');

    List<String> paymentMethods = [];

    // Handle semua kemungkinan format data:
    if (paymentData is String) {
      try {
        // Case 1: Data berupa JSON string (baik "COD" atau "[\"COD\",\"BSI\"]")
        final decoded = jsonDecode(paymentData);
        if (decoded is String) {
          paymentMethods = [decoded]; // Jika "COD" berubah jadi ["COD"]
        } else if (decoded is List) {
          paymentMethods = List<String>.from(decoded);
        }
      } catch (e) {
        debugPrint('JSON decode error: $e');
        // Jika gagal decode, anggap sebagai string biasa
        paymentMethods = [paymentData];
      }
    } else if (paymentData is List) {
      // Case 2: Data sudah berupa List/array
      paymentMethods = List<String>.from(paymentData);
    } else {
      // Case 3: Data format tidak dikenali (misal number, bool, dll)
      paymentMethods = [paymentData.toString()];
    }

    debugPrint('Parsed payment methods: $paymentMethods');

    setState(() {
      availablePaymentMethods = paymentMethods;
      selectedPaymentMethod = paymentMethods.isNotEmpty ? paymentMethods.first : null;
      isLoadingPaymentMethods = false;
    });

  } catch (e) {
    debugPrint('Error loading payment methods: $e');
    setState(() => isLoadingPaymentMethods = false);
  }
}

  Future<void> _loadPrimaryAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null) return;

      final response = await supabase
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .eq('is_primary', true)
          .maybeSingle();

      if (response != null) {
        setState(() {
          selectedAddress = AddressData(
            id: response['id'] as int,
            recipientName: response['recipient_name'] as String,
            phoneNumber: response['phone_number'] as String,
            province: response['province'] as String,
            city: response['city'] as String,
            district: response['district'] as String,
            village: response['village'] as String,
            postalCode: response['postal_code'] as String,
            streetAddress: response['street_address'] as String,
            isPrimary: response['is_primary'] as bool,
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading primary address: $e');
    }
  }

  Future<void> _selectAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressPage(),
      ),
    );

    if (result != null && result is AddressData) {
      setState(() {
        selectedAddress = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 207, 242),
      body: Column(
        children: [
          // Header
          Container(
            color: const Color(0xFFF273F0),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Checkout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Content with scroll
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // Address Card
                    Card(
                      child: InkWell(
                        onTap: _selectAddress,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.mapMarkerAlt,
                                color: Color(0xFFFF1E00),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (selectedAddress != null)
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${selectedAddress!.recipientName} ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            TextSpan(
                                              text: selectedAddress!.phoneNumber,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (selectedAddress != null)
                                      const SizedBox(height: 4),
                                    if (selectedAddress != null)
                                      Text(
                                        '${selectedAddress!.streetAddress}\n'
                                        '${selectedAddress!.village}, ${selectedAddress!.district}, '
                                        '${selectedAddress!.city}, ${selectedAddress!.province} '
                                        '${selectedAddress!.postalCode}',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    if (selectedAddress == null)
                                      const Text(
                                        'Tap to select delivery address',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Product List
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show all products in cart
                            ...widget.cartItems.map((item) {
                              final price = double.tryParse(item.price) ?? 0;
                              final itemTotal = price * item.count;
                              
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.category.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${item.count} item${item.count > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: item.imageUrl.isNotEmpty
                                            ? Image.network(
                                                item.imageUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.image_not_supported),
                                              )
                                            : const Icon(Icons.image_not_supported),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Colors.black,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Rp ${price.toStringAsFixed(0).replaceAllMapped(
                                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                                (Match m) => '${m[1]}.',
                                              )}',
                                              style: const TextStyle(
                                                color: Color(0xFFFF1E00),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Total: Rp ${itemTotal.toStringAsFixed(0).replaceAllMapped(
                                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                                (Match m) => '${m[1]}.',
                                              )}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item != widget.cartItems.last) 
                                    const Divider(height: 24, thickness: 1),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment Method
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFF1E00),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: FaIcon(
                                      FontAwesomeIcons.dollarSign,
                                      color: const Color(0xFFFF1E00),
                                      size: 17,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Metode Pembayaran',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            if (isLoadingPaymentMethods)
                              const Center(child: CircularProgressIndicator()),
                            
                            if (!isLoadingPaymentMethods && availablePaymentMethods.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value: selectedPaymentMethod,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items: availablePaymentMethods.map((method) {
                                  return DropdownMenuItem<String>(
                                    value: method,
                                    child: Text(method),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentMethod = value;
                                  });
                                },
                              ),
                            
                            if (!isLoadingPaymentMethods && availablePaymentMethods.isEmpty)
                              const Text(
                                'No payment methods available',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment Details
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rincian Pembayaran',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPaymentRow(
                              'Subtotal Untuk Produk',
                              'Rp ${widget.totalPrice.toStringAsFixed(0).replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]}.',
                              )}',
                            ),
                            _buildPaymentRow(
                              'Subtotal Pengiriman',
                              'Rp ${shippingCost.toStringAsFixed(0).replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]}.',
                              )}',
                            ),
                            _buildPaymentRow(
                              'Biaya Layanan',
                              'Rp ${5000.toStringAsFixed(0).replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]}.',
                              )}',
                            ),
                            _buildPaymentRow(
                              'Total Diskon Pengiriman',
                              '-Rp ${40000.toStringAsFixed(0).replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]}.',
                              )}',
                              isDiscount: true,
                            ),
                            const Divider(height: 24),
                            _buildPaymentRow(
                              'Total Bayar',
                              'Rp ${finalTotal.toStringAsFixed(0).replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]}.',
                              )}',
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total '),
                        Text(
                          'Rp ${finalTotal.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]}.',
                          )}',
                          style: const TextStyle(
                            color: Color(0xFFFF1E00),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Hemat '),
                        Text(
                          'Rp ${40000.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]}.',
                          )}',
                          style: const TextStyle(
                            color: Color(0xFFFF1E00),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedAddress == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an address first')),
                      );
                      return;
                    }
                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a payment method')),
                      );
                      return;
                    }
                    // Handle order creation here
                    _createOrder();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1E00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Buat Pesanan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null || selectedAddress == null || selectedPaymentMethod == null) {
        return;
      }

      // Create order in database
      final orderResponse = await supabase
          .from('orders')
          .insert({
            'user_id': userId,
            'total_amount': finalTotal,
            'shipping_cost': shippingCost,
            'service_fee': 5000,
            'discount': 40000,
            'status': 'pending',
            'payment_method': selectedPaymentMethod,
            'address_id': selectedAddress!.id,
          })
          .select()
          .single();

      if (orderResponse != null) {
        final orderId = orderResponse['id'] as int;
        
        // Add order items
        for (final item in widget.cartItems) {
          await supabase.from('order_items').insert({
            'order_id': orderId,
            'product_id': item.id,
            'quantity': item.count,
            'price': double.tryParse(item.price) ?? 0,
          });
        }

        // Navigate to order confirmation or clear cart
        // Navigator.push(...);
      }
    } catch (e) {
      debugPrint('Error creating order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create order: $e')),
      );
    }
  }

  Widget _buildPaymentRow(String label, String value,
      {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDiscount 
                  ? const Color(0xFFFF1E00)
                  : isTotal 
                      ? Colors.black 
                      : Colors.black,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class AddressData {
  final int id;
  final String recipientName;
  final String phoneNumber;
  final String province;
  final String city;
  final String district;
  final String village;
  final String postalCode;
  final String streetAddress;
  final bool isPrimary;

  AddressData({
    required this.id,
    required this.recipientName,
    required this.phoneNumber,
    required this.province,
    required this.city,
    required this.district,
    required this.village,
    required this.postalCode,
    required this.streetAddress,
    required this.isPrimary,
  });
}