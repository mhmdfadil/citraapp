import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '/screens/content/product_detail_page.dart';
import '/screens/content/address_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class COBuyPage extends StatefulWidget {
  final List<CardProduct> cartItems;
  final double totalPrice;
  final int totalItems;

  const COBuyPage({
    Key? key,
    required this.cartItems,
    required this.totalPrice,
    required this.totalItems,
  }) : super(key: key);

  @override
  State<COBuyPage> createState() => _COBuyPageState();
}

class _COBuyPageState extends State<COBuyPage> {
  late double shippingCost;
  late double finalTotal;
  AddressData? selectedAddress;
  String? selectedPaymentMethod;
  List<String> availablePaymentMethods = [];
  final supabase = Supabase.instance.client;
  bool isLoadingPaymentMethods = true;
  bool isProcessingOrder = false;

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

      // Handle all possible data formats
      if (paymentData is String) {
        try {
          final decoded = jsonDecode(paymentData);
          if (decoded is String) {
            paymentMethods = [decoded];
          } else if (decoded is List) {
            paymentMethods = List<String>.from(decoded);
          }
        } catch (e) {
          debugPrint('JSON decode error: $e');
          paymentMethods = [paymentData];
        }
      } else if (paymentData is List) {
        paymentMethods = List<String>.from(paymentData);
      } else {
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

  Future<void> _updateProductStockAndSold() async {
    try {
      // Update stock and sold quantity for each product in the order
      for (final item in widget.cartItems) {
        // First get current stock and sold values
        final productResponse = await supabase
            .from('products')
            .select('stock, sold')
            .eq('id', item.product_id)
            .single();

        if (productResponse != null) {
          final currentStock = productResponse['stock'] as int;
          final currentSold = productResponse['sold'] as int;

          // Update stock (decrease by quantity) and sold (increase by quantity)
          await supabase
              .from('products')
              .update({
                'stock': currentStock - item.quantity,
                'sold': currentSold + item.quantity,
              })
              .eq('id', item.product_id);
        }
      }
    } catch (e) {
      debugPrint('Error updating product stock and sold: $e');
      throw Exception('Failed to update product inventory');
    }
  }

  // In COBuyPage.dart
Future<void> _createOrder() async {
    if (isProcessingOrder) return;
    
    try {
      setState(() => isProcessingOrder = true);
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null || selectedAddress == null || selectedPaymentMethod == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing required information')),
        );
        return;
      }

      // Generate order number
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      // Create order in database
      final orderResponse = await supabase
          .from('orders')
          .insert({
            'user_id': userId,
            'order_number': orderNumber,
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
            'product_id': item.product_id,
            'quantity': item.quantity,
            'price': double.tryParse(item.price) ?? 0,
          });
        }

        // Update product stock and sold quantities
        await _updateProductStockAndSold();

        // Create payment record
        await supabase.from('payments').insert({
          'order_id': orderId,
          'method': selectedPaymentMethod,
          'status': 'pending',
          'amount': finalTotal,
        });

        // Handle payment based on method
        if (selectedPaymentMethod == 'COD') {
          // For COD, just update status to pending
          await supabase
              .from('orders')
              .update({'status': 'pending'})
              .eq('id', orderId);
              
          _showOrderSuccess(context, orderNumber);
        } else if (selectedPaymentMethod == 'BSI' || selectedPaymentMethod == 'DANA') {
          // For online payments, redirect to payment gateway
          _showPaymentInstructions(context, orderNumber);
        }

        // Return success result
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error creating order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create order: $e')),
      );
    } finally {
      setState(() => isProcessingOrder = false);
    }
  }

  void _showPaymentInstructions(BuildContext context, String orderNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Instructions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, color: Colors.blue, size: 60),
            const SizedBox(height: 16),
            Text('Please complete your payment for order #$orderNumber'),
            const SizedBox(height: 16),
            Text(
              'Payment Method: $selectedPaymentMethod',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'You will be redirected to the payment page to complete your transaction.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showOrderSuccess(context, orderNumber);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

// In COBuyPage.dart
void _showOrderSuccess(BuildContext context, String orderNumber) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Order Created'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 60),
          const SizedBox(height: 16),
          Text('Your order #$orderNumber has been created successfully'),
          const SizedBox(height: 16),
          if (selectedPaymentMethod == 'COD')
            const Text('Your order will be processed soon'),
          if (selectedPaymentMethod == 'BSI' || selectedPaymentMethod == 'DANA')
            const Text('Please complete your payment to process the order'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Notify the parent that products should be refreshed
            Navigator.of(context).popUntil((route) => route.isFirst);
            Navigator.of(context).pop(true); // Pass true to indicate success
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
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
                              final itemTotal = price * item.quantity;
                              
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
                                        '${item.quantity} item${item.quantity > 1 ? 's' : ''}',
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
                  onPressed: isProcessingOrder ? null : _createOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1E00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: isProcessingOrder
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
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