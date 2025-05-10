import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '/screens/content/cart_screen.dart';
import '/screens/content/address_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart'; // Untuk menampilkan Snap Midtrans
import '/utils/midtrans_service.dart'; // Import service Midtrans
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
            'quantity': item.count,
            'price': double.tryParse(item.price) ?? 0,
          });

          // Update product stock and sold count
          await _updateProductInventory(item);
          
          // Remove item from cart
          await _removeFromCart(item, userId);
        }

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
        } else if (selectedPaymentMethod == 'BSI' || selectedPaymentMethod == 'DANA' || selectedPaymentMethod == 'GOPAY' || selectedPaymentMethod == 'SHOPEEPAY') {
          // For online payments, process with Midtrans
          await _processMidtransPayment(orderNumber, finalTotal);
        }
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

// Fungsi untuk memproses pembayaran
Future<void> _processMidtransPayment(String orderId, double amount) async {
  try {
    final response = await MidtransService.createTransaction(
      orderId: orderId,
      grossAmount: amount,
      paymentMethod: selectedPaymentMethod,
    );

    if (selectedPaymentMethod == 'BSI') {
      final vaNumber = response['va_numbers'][0]['va_number'];
      _showBankTransferInstructions(context, vaNumber, orderId);
    } else if (selectedPaymentMethod == 'SHOPEEPAY') {
      final deeplinkUrl = response['actions'][0]['url']; // URL deeplink-redirect
      _showEWalletInstructions(context, 'ShopeePay', deeplinkUrl, orderId);
    } else if (selectedPaymentMethod == 'GOPAY') {
      final deeplinkUrl = response['actions'][1]['url']; // URL deeplink-redirect
      _showEWalletInstructions(context, 'GoPay', deeplinkUrl, orderId);
    } else if (selectedPaymentMethod == 'DANA') {
      final redirectUrl = response['actions'][0]['url'];
      _showMidtransSnap(redirectUrl, orderId);
    }
  } catch (e) {
    debugPrint('Error processing payment: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal memproses pembayaran: ${e.toString()}')),
    );
  }
}

// Tampilan instruksi pembayaran e-wallet dengan QR code dari deeplink
void _showEWalletInstructions(BuildContext context, String walletName, String deeplinkUrl, String orderNumber) {
  final isShopeePay = walletName == 'ShopeePay';
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isShopeePay ? Colors.orange : Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.wallet, color: Colors.white),
            SizedBox(width: 10),
            Text(walletName, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStoreInfoCard(orderNumber),
            SizedBox(height: 20),
            
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('QR Code Pembayaran $walletName', 
                         style: TextStyle(fontSize: 16)),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildQRCodeWidget(deeplinkUrl), // Widget QR code dari deeplink
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isShopeePay ? Colors.orange : Colors.blue,
                      ),
                     onPressed: () async {
                        try {
                          // Langsung buka URL Midtrans di browser
                          await launch(
                            deeplinkUrl,
                            forceSafariVC: false, // Buka di browser eksternal
                            universalLinksOnly: false,
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal membuka halaman pembayaran'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: Text('Buka di $walletName', 
                          style: TextStyle(color: Colors.white)),
                    ),
                    SizedBox(height: 16),
                    Text('Total Pembayaran', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),
                    Text(
                      'Rp ${finalTotal.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]}.',
                      )}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Scan QR code untuk membayar via $walletName',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Tutup'),
        ),
        // ElevatedButton(
        //   style: ElevatedButton.styleFrom(
        //     backgroundColor: isShopeePay ? Colors.orange : Colors.blue,
        //   ),
        //   onPressed: () {
        //     Navigator.of(context).pop();
        //     _showOrderSuccess(context, orderNumber);
        //   },
        //   child: Text('Saya Sudah Bayar', 
        //       style: TextStyle(color: Colors.white)),
        // ),
      ],
    ),
  );
}

// Widget untuk menampilkan QR code dari URL
Widget _buildQRCodeWidget(String deeplinkUrl) {
  // Menggunakan package qr_flutter untuk generate QR code
  return SizedBox(
    width: 200,
    height: 200,
    child: QrImageView(
      data: deeplinkUrl,
      version: QrVersions.auto,
      size: 200,
      gapless: false,
      embeddedImageStyle: QrEmbeddedImageStyle(
        size: Size(40, 40),
      ),
    ),
  );
}

void _showBankTransferInstructions(BuildContext context, String vaNumber, String orderNumber) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance, color: Colors.white),
            SizedBox(width: 10),
            Text('BSI Virtual Account', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Store Information
            _buildStoreInfoCard(orderNumber),
            SizedBox(height: 20),
            
            // Payment Info
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Nomor Virtual Account', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          vaNumber,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: Colors.blue),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: vaNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Nomor VA berhasil disalin!')),
                            );
                          },
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 8),
                    Text('Total Pembayaran', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),
                    Text(
                      'Rp ${finalTotal.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]}.',
                      )}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Pembayaran akan diproses otomatis setelah transfer',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Tutup', style: TextStyle(color: Colors.blue[800])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            _showOrderSuccess(context, orderNumber);
          },
          child: Text('Saya Sudah Bayar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}


Widget _buildStoreInfoCard(String orderNumber) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey[300]!),
    ),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Colors.blue[800], size: 20),
              SizedBox(width: 8),
              Text(
                'Toko Citra Cosmetic',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Jl. Muara Duara, Kota Lhokseumawe',
            style: TextStyle(fontSize: 14),
          ),
          Text(
            'Aceh Utara',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            'No. Pesanan: ${orderNumber}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    ),
  );
}

void _showMidtransSnap(String redirectUrl, String orderNumber) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Complete Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context);
              _showOrderSuccess(context, orderNumber);
            },
          ),
        ),
        body: WebView(
          initialUrl: redirectUrl,
          javascriptMode: JavascriptMode.unrestricted,
          navigationDelegate: (NavigationRequest request) {
            if (request.url.contains('/status/') || 
                request.url.contains('status_code=200')) {
              Navigator.pop(context);
              _showOrderSuccess(context, orderNumber);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      ),
    ),
  );
}

  Future<void> _updateProductInventory(CartItem item) async {
    try {
      // First get current stock and sold values
      final productResponse = await supabase
          .from('products')
          .select('stock, sold')
          .eq('id', item.product_id)
          .single();

      if (productResponse != null) {
        final currentStock = productResponse['stock'] as int;
        final currentSold = productResponse['sold'] as int;

        // Update product stock (stock - item.count)
        await supabase
            .from('products')
            .update({
              'stock': currentStock - item.count,
              'sold': currentSold + item.count,
            })
            .eq('id', item.product_id);
      }
    } catch (e) {
      debugPrint('Error updating product inventory: $e');
      // You might want to handle this error more gracefully
      rethrow;
    }
  }

  Future<void> _removeFromCart(CartItem item, String userId) async {
    try {
      await supabase
          .from('carts')
          .delete()
          .eq('id', item.id)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error removing item from cart: $e');
      // Even if cart removal fails, we should continue with the order
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
            if (selectedPaymentMethod == 'BSI' || selectedPaymentMethod == 'DANA' || selectedPaymentMethod == 'GOPAY' || selectedPaymentMethod == 'SHOPEEPAY')
              const Text('Please complete your payment to process the order'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
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

class JavascriptMode {
  static var unrestricted;
}

WebView({required String initialUrl, required javascriptMode, required NavigationDecision Function(NavigationRequest request) navigationDelegate}) {
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