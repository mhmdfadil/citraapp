import 'dart:async';
import 'package:citraapp/screens/content/chat.dart';
import 'package:citraapp/screens/content/cartItem.dart';
import 'package:citraapp/screens/content/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:citraapp/screens/content/card_product.dart';
import '/screens/content/address_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:citraapp/utils/rajaongkir.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '/utils/midtrans_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String? currentOrderNumber;
  bool isPaymentCompleted = false;
  RealtimeSubscription? paymentStatusSubscription;

   // Variabel baru untuk shipping
  String? _selectedCourier = 'jne';
  List<Map<String, dynamic>> _availableShippingServices = [];
  bool _isLoadingShipping = false;
  int _totalWeight = 0;
  Timer? _shippingTimer;

// Update your initState to calculate shipping cost
@override
void initState() {
  super.initState();
  shippingCost = 0; // Initialize to 0
  finalTotal = widget.totalPrice + shippingCost + 5000 - 40000;
  _loadPrimaryAddress();
  _loadPaymentMethods();
  
  _calculateTotalWeight().then((totalWeight) {
    if (mounted) {
      setState(() {
        _totalWeight = totalWeight;
      });
      if (selectedAddress != null) {
        _fetchShippingCost();
      }
    }
  });
}

  @override
  void dispose() {
    paymentStatusSubscription?.unsubscribe().catchError((e) {});
     paymentTimer?.cancel();
    super.dispose();
  }

 Future<int> _calculateTotalWeight() async {
  int totalWeight = 0;
  for (final item in widget.cartItems) {
    final productResponse = await supabase
        .from('products')
        .select('weight')
        .eq('id', item.product_id)
        .single();

    final productWeight = productResponse['weight'] as int;
    totalWeight += productWeight * item.quantity;
  }
  return totalWeight;
}

Future<void> _fetchShippingCost() async {
  if (selectedAddress == null || _totalWeight == 0 || _selectedCourier == null) {
    setState(() {
      shippingCost = 0;
      _updateFinalTotal();
    });
    return;
  }

  setState(() => _isLoadingShipping = true);

  try {
    final result = await RajaOngkirService.getShippingCost(
      origin: '1107',
      destination: selectedAddress!.cityId,
      weight: _totalWeight,
      courier: _selectedCourier!,
    );

    if (result['costs'] != null && result['costs'].isNotEmpty) {
      setState(() {
        shippingCost = (result['costs'][0]['cost'][0]['value'] as int).toDouble();
        _updateFinalTotal();
      });
    } else {
      setState(() {
        shippingCost = 0;
        _updateFinalTotal();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Layanan pengiriman ${_selectedCourier!.toUpperCase()} tidak tersedia untuk rute ini')),
      );
    }
  } catch (e) {
    debugPrint('Error fetching shipping cost: $e');
    setState(() {
      shippingCost = 0;
      _updateFinalTotal();
    });
    
    // Only show error if it's not a 404 (which we handle gracefully)
    if (!e.toString().contains('404')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan ongkos kirim: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoadingShipping = false);
    }
  }
}
void _updateFinalTotal() {
  if (mounted) {
    setState(() {
      // Calculate the actual discount (minimum between shipping cost and 40,000)
      double actualDiscount = shippingCost > 40000 ? 40000 : shippingCost;
      finalTotal = widget.totalPrice + shippingCost + 5000 - actualDiscount;
    });
  }
}

void _showShippingOptions() {
  if (selectedAddress == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Silakan pilih alamat pengiriman terlebih dahulu')),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilih Kurir dan Layanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCourier,
                  items: ['jne', 'jnt'].map((courier) {
                    return DropdownMenuItem<String>(
                      value: courier,
                      child: Text(courier.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      setState(() => _selectedCourier = value);
                      await _fetchShippingCost();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Kurir',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                if (_isLoadingShipping)
                  Center(child: CircularProgressIndicator())
                else if (_availableShippingServices.isEmpty)
                  Text('Tidak ada layanan pengiriman tersedia'),
                if (_availableShippingServices.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _availableShippingServices.length,
                      itemBuilder: (context, index) {
                        final service = _availableShippingServices[index];
                        final cost = service['cost'][0];
                        return Card(
                          child: ListTile(
                            title: Text(service['service']),
                            subtitle: Text('${cost['etd']} hari'),
                            trailing: Text(
                              'Rp ${NumberFormat('#,###').format(cost['value'])}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                shippingCost = (cost['value'] as int).toDouble();
                                _updateFinalTotal();
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tutup'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  Future<void> _setupPaymentStatusListener(String orderNumber) async {
  try {
    // Get order ID first
    final orderResponse = await supabase
        .from('orders')
        .select('id')
        .eq('order_number', orderNumber)
        .single();

    if (orderResponse != null) {
      final orderId = orderResponse['id'] as int;

      // Immediately check current payment status
      await _checkPaymentStatus(orderId, orderNumber);

      // Setup realtime subscription with proper filtering
      paymentStatusSubscription = supabase
          .from('payments')
          .on(SupabaseEventTypes.update, (payload) {
        debugPrint('Payment update received: ${payload.newRecord}');
        // Only process if it's our order's payment
        if (payload.newRecord['order_id'] == orderId && 
            payload.newRecord['status'] == 'paid') {
          if (mounted) {
            setState(() {
              isPaymentCompleted = true;
            });
            _showPaymentSuccess(context, orderNumber);
          }
        }
      }).subscribe();
    }
  } catch (e) {
    debugPrint('Error setting up payment listener: $e');
    // Retry after 1 second if failed
    await Future.delayed(Duration(seconds: 1));
    if (mounted) {
      _setupPaymentStatusListener(orderNumber);
    }
  }
}

 Future<void> _checkPaymentStatus(int orderId, String orderNumber) async {
  try {
    // Add a small delay to ensure Supabase has time to update
    await Future.delayed(Duration(seconds: 1));
    
    final paymentResponse = await supabase
        .from('payments')
        .select('status, midtrans_response')
        .eq('order_id', orderId)
        .maybeSingle();

    if (paymentResponse != null) {
      debugPrint('Current payment status: ${paymentResponse['status']}');
      debugPrint('Midtrans response: ${paymentResponse['midtrans_response']}');
      
      if (paymentResponse['status'] == 'paid') {
        if (mounted) {
          setState(() {
            isPaymentCompleted = true;
          });
          _showPaymentSuccess(context, orderNumber);
        }
      } else {
        // If not paid yet, check again after 1 second
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          _checkPaymentStatus(orderId, orderNumber);
        }
      }
    }
  } catch (e) {
    debugPrint('Error checking payment status: $e');
    // Retry after 1 second if failed
    await Future.delayed(Duration(seconds: 1));
    if (mounted) {
      _checkPaymentStatus(orderId, orderNumber);
    }
  }
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
          provinceId: response['province_id'] as String,
          cityId: response['city_id'] as String,
          districtId: response['district_id'] as String,
          villageId: response['village_id'] as String,
          postalCode: response['postal_code'] as String,
          streetAddress: response['street_address'] as String,
          isPrimary: response['is_primary'] as bool,
        );
      });
      
      // Jika berat sudah dihitung, fetch ongkir
      if (_totalWeight > 0) {
        _fetchShippingCost();
      }
    } else {
      debugPrint('No primary address found');
    }
  } catch (e) {
    debugPrint('Error loading primary address: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal memuat alamat pengiriman')),
    );
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
      for (final item in widget.cartItems) {
        final productResponse = await supabase
            .from('products')
            .select('stock, sold')
            .eq('id', item.product_id)
            .single();

        if (productResponse != null) {
          final currentStock = productResponse['stock'] as int;
          final currentSold = productResponse['sold'] as int;

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
      currentOrderNumber = orderNumber;

      // Create order in database
      final orderResponse = await supabase
          .from('orders')
          .insert({
            'user_id': userId,
            'order_number': orderNumber,
            'total_amount': finalTotal,
            'shipping_cost': shippingCost,
            'shipping_method': _selectedCourier,
            'service_fee': 5000,
            'discount': shippingCost > 40000 ? 40000 : shippingCost,
            'payment_method': selectedPaymentMethod,
            'address_id': selectedAddress!.id,
            'created_at': DateTime.now().toIso8601String(), // Tambahkan ini
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

          await supabase.from('stok_keluar').insert({
            'product_id': item.product_id,
            'brg_keluar': item.quantity,
            'user_id': userId,
          });

          await _updateProductInventory(item);
        }

        // Create payment record
        await supabase.from('payments').insert({
          'order_id': orderId,
          'method': selectedPaymentMethod,
          'status': 'pending',
          'amount': finalTotal,
          'created_at': DateTime.now().toIso8601String(), // Tambahkan ini
        });

        // Setup payment status listener
        _setupPaymentStatusListener(orderNumber);

        // Handle payment based on method
        if (selectedPaymentMethod == 'COD') {
          await supabase
              .from('orders')
              .update({'status': 'pending'})
              .eq('id', orderId);
              
          _showOrderSuccess(context, orderNumber);
        } else if (selectedPaymentMethod == 'BSI' || 
                  selectedPaymentMethod == 'DANA' || 
                  selectedPaymentMethod == 'GOPAY' || 
                  selectedPaymentMethod == 'SHOPEEPAY') {
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

  Future<String?> _getUserEmail(String userId) async {
  try {
    final response = await supabase
        .from('users')
        .select('email')
        .eq('id', userId)
        .single();

    return response['email'] as String?;
  } catch (e) {
    debugPrint('Error fetching user email: $e');
    return null;
  }
}

   Future<void> _processMidtransPayment(String orderNumber, double amount) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userEmail = userId != null ? await _getUserEmail(userId) : null;

    final response = await MidtransService.createTransaction(
      orderId: orderNumber,
      grossAmount: amount,
      paymentMethod: selectedPaymentMethod,
      customerEmail: userEmail,
    );

    // Get order ID to update payment record
    final orderResponse = await supabase
        .from('orders')
        .select('id')
        .eq('order_number', orderNumber)
        .single();

    if (orderResponse != null) {
      final orderId = orderResponse['id'] as int;
      
      // Update payment record with Midtrans response
      await supabase
          .from('payments')
          .update({
            'midtrans_response': response,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('order_id', orderId);
    }

    if (selectedPaymentMethod == 'BSI') {
      final vaNumber = response['va_numbers'][0]['va_number'];
      // Update va_number in payments table
      await supabase
          .from('payments')
          .update({'va_number': vaNumber})
          .eq('order_id', (await supabase
              .from('orders')
              .select('id')
              .eq('order_number', orderNumber)
              .single())['id']);
      
      _showBankTransferInstructions(context, vaNumber, orderNumber);
    } else if (selectedPaymentMethod == 'SHOPEEPAY') {
      final deeplinkUrl = response['actions'][0]['url'];
      // Update link_url in payments table
      await supabase
          .from('payments')
          .update({'link_url': deeplinkUrl})
          .eq('order_id', (await supabase
              .from('orders')
              .select('id')
              .eq('order_number', orderNumber)
              .single())['id']);
      
      _showEWalletInstructions(context, 'ShopeePay', deeplinkUrl, orderNumber);
    } else if (selectedPaymentMethod == 'GOPAY') {
      final deeplinkUrl = response['actions'][1]['url'];
      // Update link_url in payments table
      await supabase
          .from('payments')
          .update({'link_url': deeplinkUrl})
          .eq('order_id', (await supabase
              .from('orders')
              .select('id')
              .eq('order_number', orderNumber)
              .single())['id']);
      
      _showEWalletInstructions(context, 'GoPay', deeplinkUrl, orderNumber);
    } else if (selectedPaymentMethod == 'DANA') {
      final redirectUrl = response['actions'][0]['url'];
      _showMidtransSnap(redirectUrl, orderNumber);
    }
  } catch (e) {
    debugPrint('Error processing payment: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal memproses pembayaran: ${e.toString()}')),
    );
  }
}
DateTime? paymentExpiryTime;
Timer? paymentTimer;
bool isPaymentExpired = false;

// Modify _showBankTransferInstructions and _showEWalletInstructions to include countdown logic
void _showBankTransferInstructions(BuildContext context, String vaNumber, String orderNumber) async {
  // Get payment created_at time from Supabase
  final paymentData = await supabase
      .from('payments')
      .select('created_at')
      .eq('order_id', (await supabase
          .from('orders')
          .select('id')
          .eq('order_number', orderNumber)
          .single())['id'])
      .single();

  if (paymentData != null) {
    // Parse the timestamp and remove microseconds and timezone offset
    final createdAtStr = paymentData['created_at'].toString();
    final cleanedCreatedAtStr = createdAtStr.split('.')[0]; // Remove microseconds
    final createdAt = DateTime.parse(cleanedCreatedAtStr);

    paymentExpiryTime = createdAt.add(Duration(days: 1)); // 1 day expiry for bank transfer
    _startPaymentTimer(context, orderNumber); // Pass context here
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
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
                _buildStoreInfoCard(orderNumber),
                SizedBox(height: 20),
                
                if (isPaymentCompleted)
                  _buildPaymentSuccessContent()
                else if (isPaymentExpired)
                  _buildPaymentExpiredContent(context, orderNumber)
                else
                  Column(
                    children: [
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
                              _buildCountdownTimer(context), // Pass context here
                              SizedBox(height: 8),
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
              ],
            ),
          ),
          actions: [
            if (!isPaymentCompleted && !isPaymentExpired)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Tutup', style: TextStyle(color: Colors.blue[800])),
              ),
          ],
        );
      }
    ),
  );
}

void _showEWalletInstructions(BuildContext context, String walletName, String deeplinkUrl, String orderNumber) async {
  // Get payment created_at time from Supabase
  final paymentData = await supabase
      .from('payments')
      .select('created_at')
      .eq('order_id', (await supabase
          .from('orders')
          .select('id')
          .eq('order_number', orderNumber)
          .single())['id'])
      .single();

  if (paymentData != null) {
    // Parse the timestamp and remove microseconds and timezone offset
    final createdAtStr = paymentData['created_at'].toString();
    final cleanedCreatedAtStr = createdAtStr.split('.')[0]; // Remove microseconds
    final createdAt = DateTime.parse(cleanedCreatedAtStr);
    
    paymentExpiryTime = createdAt.add(Duration(hours: 1)); // 1 hour expiry for e-wallet
    _startPaymentTimer(context, orderNumber); // Pass context here
  }

  final isShopeePay = walletName == 'ShopeePay';
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
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
                
                if (isPaymentCompleted)
                  _buildPaymentSuccessContent()
                else if (isPaymentExpired)
                  _buildPaymentExpiredContent(context, orderNumber) // Pass context here
                else
                  Column(
                    children: [
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
                                child: _buildQRCodeWidget(deeplinkUrl),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isShopeePay ? Colors.orange : Colors.blue,
                                ),
                                onPressed: () async {
                                  try {
                                    await launch(
                                      deeplinkUrl,
                                      forceSafariVC: false,
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
                              _buildCountdownTimer(context), // Pass context here
                              SizedBox(height: 8),
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
              ],
            ),
          ),
          actions: [
            if (!isPaymentCompleted && !isPaymentExpired)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Tutup'),
              ),
          ],
        );
      }
    ),
  );
}

// Modified to accept context parameter
void _startPaymentTimer(BuildContext context, String orderNumber) {
  paymentTimer?.cancel();
  isPaymentExpired = false;
  
  paymentTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    if (paymentExpiryTime == null) {
      timer.cancel();
      return;
    }
    
    final now = DateTime.now();
    if (now.isAfter(paymentExpiryTime!)) {
      // Use the context from the dialog to update the state
      Navigator.of(context, rootNavigator: true).pop();
      _showPaymentExpiredDialog(context, orderNumber); // Show expired dialog
      timer.cancel();
      
      // Update payment status to failed in database
      _updatePaymentStatus(orderNumber, 'failed');
    } else {
      // This will trigger a rebuild of the dialog content
      (context as Element).markNeedsBuild();
    }
  });
}

// New method to show payment expired dialog
void _showPaymentExpiredDialog(BuildContext context, String orderNumber) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: _buildPaymentExpiredContent(context, orderNumber),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Tutup'),
        ),
      ],
    ),
  );
}

Future<void> _updatePaymentStatus(String orderNumber, String status) async {
  try {
    await supabase
        .from('payments')
        .update({'status': status})
        .eq('order_id', (await supabase
            .from('orders')
            .select('id')
            .eq('order_number', orderNumber)
            .single())['id']);
  } catch (e) {
    debugPrint('Error updating payment status: $e');
  }
}

// Modified to accept context parameter
Widget _buildCountdownTimer(BuildContext context) {
  if (paymentExpiryTime == null) return SizedBox();
  
  final now = DateTime.now();
  final remaining = paymentExpiryTime!.difference(now);
  
  if (remaining.isNegative) {
    return Text(
      'Waktu pembayaran telah habis',
      style: TextStyle(
        color: Colors.red,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  final seconds = remaining.inSeconds.remainder(60);
  
  return Column(
    children: [
      Text(
        'Selesaikan pembayaran dalam:',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      SizedBox(height: 4),
      StreamBuilder<DateTime>(
        stream: Stream.periodic(Duration(seconds: 1), (_) => DateTime.now()),
        builder: (context, snapshot) {
          final now = DateTime.now();
          final remaining = paymentExpiryTime!.difference(now);
          
          if (remaining.isNegative) {
            return Text(
              '00:00:00',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            );
          }
          
          final hours = remaining.inHours;
          final minutes = remaining.inMinutes.remainder(60);
          final seconds = remaining.inSeconds.remainder(60);
          
          return Text(
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          );
        },
      ),
    ],
  );
}

Widget _buildPaymentExpiredContent(BuildContext context, String orderNumber) {
  return Dialog(
    elevation: 0,
    backgroundColor: Colors.transparent,
    insetPadding: EdgeInsets.all(10),
    child: SingleChildScrollView(
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Color(0xFFF5F9FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error icon with animation
                  Container(
                    width: 150,
                    height: 150,
                    child: Lottie.asset(
                      'assets/animations/error_pulse.json',
                      fit: BoxFit.contain,
                      repeat: false,
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Main title
                  Text(
                    'Transaksi Gagal',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'Pembayaran tidak dapat diproses',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  SizedBox(height: 25),
                  
                // Order details card - Perbaikan alignment ke kiri
Container(
  width: double.infinity,
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey[200]!),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, // Ini yang diubah
    children: [
      // Order number
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nomor Pesanan',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 3),
          Text(
            '#$orderNumber',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
      
      SizedBox(height: 8),
      
      // Amount
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jumlah Pembayaran',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Rp ${finalTotal.toStringAsFixed(0).replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]}.',
              )}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
      
      SizedBox(height: 8),
      
      // Status
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 3),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Text(
              'Gagal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),
                  
                  SizedBox(height: 17),
                  
                  // Failure reason card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alasan Kegagalan:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Waktu pembayaran telah habis (melebihi batas waktu)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[700],
                          ),
                        ),
                        Text(
                          '• Transaksi otomatis dibatalkan oleh sistem',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 25),
                  
                  // Di dalam widget Anda
TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage()),
    );
  },
  child: RichText(
    text: TextSpan(
      children: [
        TextSpan(
          text: 'Butuh bantuan? ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
        TextSpan(
          text: 'Hubungi CS',
          style: TextStyle(
            color: Colors.red[600],
            fontSize: 13,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    ),
  ),
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
Widget _buildQRCodeWidget(String deeplinkUrl) {
  return SizedBox(
    width: 200,
    height: 200,
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: deeplinkUrl,
            version: QrVersions.auto,
            size: 200,
            gapless: false,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF2E86C1),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle,
              color: Colors.black,
            ),
            embeddedImageStyle: QrEmbeddedImageStyle(
              size: Size(40, 40),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset('assets/images/logo.png'),
          ),
        ],
      ),
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
                _showPaymentSuccessDialog(context, orderNumber);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        ),
      ),
    );
  }

Widget _buildPaymentSuccessContent() {
  return SingleChildScrollView(
    physics: ClampingScrollPhysics(),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Floating Confetti Animation Background
          Container(
            height: 200,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Lottie.asset(
                    'assets/animations/confetti.json',
                    fit: BoxFit.cover,
                    repeat: false,
                  ),
                ),
                // Animated Checkmark with Glow Effect
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Lottie.asset(
                    'assets/animations/success.json',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Payment Success Title with Fade Animation
          AnimatedOpacity(
            opacity: 1,
            duration: Duration(milliseconds: 800),
            child: Text(
              'Pembayaran Berhasil!',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A1B9A),
                letterSpacing: 0.5,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Payment Success Subtitle
          AnimatedOpacity(
            opacity: 1,
            duration: Duration(milliseconds: 800),

            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                'Transaksi Anda telah berhasil diproses. Terima kasih telah berbelanja di Toko Citra Cosmetic',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Elegant Amount Card
          AnimatedContainer(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeOutQuart,
            margin: EdgeInsets.symmetric(vertical: 16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Total Pembayaran',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.purple[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Rp ${finalTotal.toStringAsFixed(0).replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]}.',
                  )}',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A148C),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Store Information Card (Modern Neumorphic Design)
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(5, 5),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 20,
                  offset: Offset(-5, -5),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Store Icon and Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store_mall_directory_rounded,
                      color: Colors.purple[700],
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Toko Citra Cosmetic',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[800],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // Store Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jln. Muara Dua, Kota Lhokseumawe, Aceh Utara',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 8),
                
                // Transaction Time
                Row(
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())} WIB',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Decorative Divider
          Container(
            margin: EdgeInsets.symmetric(vertical: 24),
            height: 4,
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [Colors.purple[300]!, Colors.pink[200]!],
              ),
            ),
          ),
          
          // Thank You Message
          Text(
            'Terima kasih telah mempercayai kami',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ),
  );
}

void _showPaymentSuccessDialog(BuildContext context, String orderNumber) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Stack(
        children: [
          // Confetti background animation
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/confetti.json',
              fit: BoxFit.cover,
              repeat: false,
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Color(0xFFF5F9FF)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie Checkmark Animation
                  Container(
                    width: 150,
                    height: 150,
                    child: Lottie.asset(
                      'assets/animations/success.json',
                      fit: BoxFit.contain,
                      repeat: false,
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Success Title with fade animation
                  AnimatedOpacity(
                    opacity: 1,
                    duration: Duration(milliseconds: 500),
                    child: Text(
                      'Pembayaran Berhasil!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Order Number
                  Text(
                    'Nomor Pesanan: #$orderNumber',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  SizedBox(height: 25),
                  
                  // Payment Amount with animated container
                  AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 25),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'Rp ${finalTotal.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]}.',
                      )}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Store Info with divider
                  Column(
                    children: [
                      Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                        indent: 20,
                        endIndent: 20,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Terima kasih telah berbelanja di',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Citra Cosmetic',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Jln Muara Dua, Kota Lhokseumawe, Aceh Utara',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 25),
                  
                  // Home Button with scale animation
                  AnimatedScale(
                    scale: 1,
                    duration: Duration(milliseconds: 300),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shadowColor: Colors.green.withOpacity(0.4),
                        ),
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        child: Text(
                          'Tutup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
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

 void _showPaymentSuccess(BuildContext context, String orderNumber) {
  // Close any existing dialogs
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  
  // Show success dialog
  _showPaymentSuccessDialog(context, orderNumber);
}

  void _showOrderSuccess(BuildContext context, String orderNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Order Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/success.json',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
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

  Future<void> _updateProductInventory(CardProduct item) async {
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
              'stock': currentStock - item.quantity,
              'sold': currentSold + item.quantity,
            })
            .eq('id', item.product_id);
      }
    } catch (e) {
      debugPrint('Error updating product inventory: $e');
      // You might want to handle this error more gracefully
      rethrow;
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
Widget _buildShippingOption(String label, String courier) {
  final isSelected = _selectedCourier == courier;
  final isAvailable = courier != 'sicepat'; // You might want to make this dynamic based on actual API availability

  return Expanded(
    child: InkWell(
      onTap: isAvailable ? () {
        setState(() {
          _selectedCourier = courier;
        });
        _fetchShippingCost();
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFFF1E00) 
              : isAvailable 
                  ? Colors.grey[200] 
                  : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFFF1E00) 
                : isAvailable 
                    ? Colors.grey[300]! 
                    : Colors.grey[200]!,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.white 
                      : isAvailable 
                          ? Colors.black 
                          : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isAvailable)
                Text(
                  '(Tidak tersedia)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
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
                                        '${selectedAddress!.streetAddress}\n',
                                      
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
                    // Add this widget above the Payment Details Card in your build method
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Pengiriman',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingShipping)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              _buildShippingOption('JNE', 'jne'),
              const SizedBox(width: 8),
              _buildShippingOption('JNT', 'jnt'),
              const SizedBox(width: 8),
              _buildShippingOption('SiCepat', 'sicepat'),
            ],
          ),
        const SizedBox(height: 8),
        if (_selectedCourier != null && shippingCost > 0)
          Text(
            'Estimasi: 3 hari',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
      ],
    ),
  ),
),

                                      // Product List - Updated version
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show all products in cart
        ...widget.cartItems.map((item) {
          final prices = double.tryParse(item.price) ?? 0;
          final itemTotal = prices * item.quantity;
       
          
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailPage(productId: item.product_id.toString()),
                ),
              );
            },
            child: Column(
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
                            'Rp ${widget.totalPrice.toStringAsFixed(0).replaceAllMapped(
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
                           'Rp ${widget.totalPrice.toStringAsFixed(0).replaceAllMapped(
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
            ),
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

                   // In your build method, modify the Payment Details section to include shipping option:
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
          'Rp ${NumberFormat('#,###').format(widget.totalPrice)}',
        ),
        InkWell(
          // onTap: _showShippingOptions,
          child: _buildPaymentRow(
            'Subtotal Pengiriman',
            _isLoadingShipping 
                ? 'Menghitung...'
                : 'Rp ${NumberFormat('#,###').format(shippingCost)}',
            // isClickable: true,
          ),
        ),
        _buildPaymentRow(
          'Biaya Layanan',
          'Rp ${NumberFormat('#,###').format(5000)}',
        ),
        _buildPaymentRow(
  'Total Diskon Pengiriman',
  '-Rp ${NumberFormat('#,###').format(shippingCost > 40000 ? 40000 : shippingCost)}',
  isDiscount: true,
),
        const Divider(height: 24),
        _buildPaymentRow(
          'Total Bayar',
          'Rp ${NumberFormat('#,###').format(finalTotal)}',
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
                          'Rp ${NumberFormat('#,###').format(shippingCost > 40000 ? 40000 : shippingCost)}',
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
    {bool isDiscount = false, bool isTotal = false, bool isClickable = false}) {
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
        Row(
          children: [
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
            if (isClickable) 
              const Icon(Icons.chevron_right, size: 16),
          ],
        ),
      ],
    ),
  );
}
  
  DottedLinePainter() {}
}

extension on SupabaseQueryBuilder {
  on(SupabaseEventTypes update, Null Function(dynamic payload) param1) {}
}

class RealtimeSubscription {
  unsubscribe() {}
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
  final String provinceId;
  final String cityId;
  final String districtId;
  final String villageId;
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
    required this.provinceId,
    required this.cityId,
    required this.districtId,
    required this.villageId,
    required this.postalCode,
    required this.streetAddress,
    required this.isPrimary,
  });
}