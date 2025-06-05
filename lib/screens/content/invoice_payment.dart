import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clipboard/clipboard.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'product_detail_page.dart'; // Import the ProductDetailPage

class InvoicePaymentPage extends StatefulWidget {
  final String orderId;

  const InvoicePaymentPage({Key? key, required this.orderId}) : super(key: key);

  @override
  _InvoicePaymentPageState createState() => _InvoicePaymentPageState();
}

class _InvoicePaymentPageState extends State<InvoicePaymentPage> {
  late Future<Map<String, dynamic>> _invoiceData;
  final supabase = Supabase.instance.client;
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  bool _isLoading = true;
  String _errorMessage = '';
  DateTime? _paymentExpiryTime;
  Timer? _paymentTimer;
  Timer? _refreshTimer;
  bool _showFullAddress = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadInvoiceData();
      // Set up periodic refresh every 10 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _loadInvoiceData();
      });
    });
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInvoiceData() async {
    try {
      final data = await _fetchInvoiceData();
      _setupPaymentTimer(data);
      if (mounted) {
        setState(() {
          _invoiceData = Future.value(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data pembayaran: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _setupPaymentTimer(Map<String, dynamic> data) {
    final payment = data['payment'] as Map<String, dynamic>;
    final order = data['order'] as Map<String, dynamic>;
    
    if (payment['created_at'] != null) {
      final createdAtStr = payment['created_at'].toString();
      final cleanedCreatedAtStr = createdAtStr.split('.')[0];
      final createdAt = DateTime.parse(cleanedCreatedAtStr);

      final paymentMethod = order['payment_method']?.toString().toLowerCase();
      
      if (paymentMethod == 'bsi') {
        _paymentExpiryTime = createdAt.add(const Duration(days: 1));
      } else if (paymentMethod == 'gopay' || paymentMethod == 'shopeepay') {
        _paymentExpiryTime = createdAt.add(const Duration(hours: 1));
      }
      
      _paymentTimer?.cancel();
      _paymentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_paymentExpiryTime == null || DateTime.now().isAfter(_paymentExpiryTime!)) {
          timer.cancel();
          if (mounted) {
            setState(() {});
          }
        } else {
          if (mounted) {
            setState(() {});
          }
        }
      });
    }
  }

  Future<Map<String, dynamic>> _fetchInvoiceData() async {
    final orderResponse = await supabase
        .from('orders')
        .select()
        .eq('id', widget.orderId)
        .maybeSingle();

    if (orderResponse == null) {
      throw 'Order tidak ditemukan';
    }

    final orderData = orderResponse;

    final itemsResponse = await supabase
        .from('order_items')
        .select('''
          quantity, price, 
          products:product_id (name, price_display, id)
        ''')
        .eq('order_id', widget.orderId);

    final itemsData = itemsResponse;

    // Fetch product photos separately
    for (var item in itemsData) {
      final product = item['products'] as Map<String, dynamic>;
      final productId = product['id'].toString();
      
      final photoResponse = await supabase
          .from('photo_items')
          .select('id, name')
          .eq('product_id', productId)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (photoResponse != null && photoResponse['name'] != null) {
        final photoUrl = supabase.storage
            .from('picture-products')
            .getPublicUrl(photoResponse['name']);
            product['photo'] = photoUrl;
      }
    }

    Map<String, dynamic> addressData = {};
    if (orderData['address_id'] != null) {
      final addressResponse = await supabase
          .from('addresses')
          .select()
          .eq('id', orderData['address_id'])
          .maybeSingle();

      addressData = addressResponse ?? {};
    }

    Map<String, dynamic> paymentData = {
      'status': 'pending',
      'method': orderData['payment_method'] ?? 'Unknown'
    };

    final paymentResponse = await supabase
        .from('payments')
        .select()
        .eq('order_id', widget.orderId)
        .maybeSingle();

    if (paymentResponse != null) {
      paymentData = paymentResponse;
    }

    return {
      'order': orderData,
      'items': itemsData,
      'address': addressData,
      'payment': paymentData,
    };
  }

  String _getPaymentStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'BELUM DIBAYAR';
      case 'paid':
        return 'DIBAYAR';
      case 'expired':
      case 'denied':
        return 'DIBATALKAN';
      default:
        return status.toUpperCase();
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF4CAF50);
      case 'pending':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFFF44336);
    }
  }

  Widget _buildPaymentMethodSection(Map<String, dynamic> payment, Map<String, dynamic> order) {
    final paymentMethod = order['payment_method']?.toString().toLowerCase() ?? '';
    final paymentStatus = payment['status']?.toString().toLowerCase() ?? 'pending';
    final isPending = paymentStatus == 'pending';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'METODE PEMBAYARAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPaymentMethodIcon(paymentMethod),
                const SizedBox(width: 12),
                Text(
                  order['payment_method']?.toString().toUpperCase() ?? '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'STATUS PEMBAYARAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getPaymentStatusColor(paymentStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getPaymentStatusColor(paymentStatus),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getPaymentStatusIcon(paymentStatus),
                    size: 16,
                    color: _getPaymentStatusColor(paymentStatus),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getPaymentStatusText(paymentStatus),
                    style: TextStyle(
                      color: _getPaymentStatusColor(paymentStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isPending && _paymentExpiryTime != null) ...[
              const SizedBox(height: 16),
              const Text(
                'BATAS WAKTU PEMBAYARAN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy, HH:mm', 'id_ID').format(_paymentExpiryTime!),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sisa waktu: ${_formatCountdown(_paymentExpiryTime!)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _paymentExpiryTime!.difference(DateTime.now()).inMinutes < 10
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            if (isPending && paymentMethod == 'bsi' && payment['va_number'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'NOMOR VIRTUAL ACCOUNT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        payment['va_number'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      onPressed: () {
                        FlutterClipboard.copy(payment['va_number']).then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Nomor VA berhasil disalin'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Salin nomor VA dan bayar melalui ATM/mobile banking BSI',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
            if (isPending && (paymentMethod == 'gopay' || paymentMethod == 'shopeepay') && payment['link_url'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'QR CODE PEMBAYARAN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Center(
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
        // QR Code dengan dot lingkaran (paling mirip bintang)
        QrImageView(
          data: payment['link_url'],
          version: QrVersions.auto,
          size: 280,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF2E86C1),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.circle, // Dot bulat (paling dekat dengan bintang)
            color: Colors.black,
          ),
          gapless: false, // Pastikan dot tidak masuk area tengah
        ),

        // Logo di tengah (40x40)
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white, // Background putih agar dot tidak terlihat
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset('assets/images/logo.png'),
        ),
      ],
    ),
  ),
),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final url = payment['link_url'];
                     try {
                                    await launch(
                                      url,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: paymentMethod == 'gopay' ? const Color(0xFF00AA13) : const Color(0xFFEE2D24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        paymentMethod == 'gopay' ? Icons.account_balance_wallet : Icons.shopping_bag,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bayar dengan ${paymentMethod.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.error;
    }
  }

  Widget _buildPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'bsi':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.account_balance,
            color: Colors.blue,
            size: 20,
          ),
        );
      case 'gopay':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00AA13).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.account_balance_wallet,
            color: Color(0xFF00AA13),
            size: 20,
          ),
        );
      case 'shopeepay':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFEE2D24).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.shopping_bag,
            color: Color(0xFFEE2D24),
            size: 20,
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.payment,
            color: Colors.grey,
            size: 20,
          ),
        );
    }
  }

  String _formatCountdown(DateTime expiryTime) {
    final now = DateTime.now();
    if (now.isAfter(expiryTime)) {
      return 'Waktu pembayaran telah habis';
    }
    
    final difference = expiryTime.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Widget _buildOrderItems(List<dynamic> items) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PRODUK DIPESAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map<Widget>((item) {
              final product = item['products'] as Map<String, dynamic>;
              final productId = product['id'].toString() ;
              final photo = product['photo'];
              final placeholderImage = 'assets/images/placeholder.png';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(productId: productId),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade100,
                          image: DecorationImage(
                            image: photo != null
                                ? NetworkImage(photo) as ImageProvider
                                : AssetImage(placeholderImage),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'Produk',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item['quantity']} × ${currencyFormat.format(item['price']  ?? 0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        currencyFormat.format((item['quantity'] as int) * (item['price'] as num)),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(Map<String, dynamic> address) {
    final fullAddress = [
      address['street_address'],
    ].where((part) => part != null && part.toString().isNotEmpty).join(', ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ALAMAT PENGIRIMAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  address['label'] ?? 'Alamat',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address['recipient_name'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              address['phone_number'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _showFullAddress ? fullAddress : '${fullAddress.substring(0, fullAddress.length > 60 ? 60 : fullAddress.length)}${fullAddress.length > 60 ? '...' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
            if (fullAddress.length > 60) ...[
              TextButton(
                onPressed: () {
                  setState(() {
                    _showFullAddress = !_showFullAddress;
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                ),
                child: Text(
                  _showFullAddress ? 'Sembunyikan' : 'Lihat Selengkapnya',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(Map<String, dynamic> order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RINGKASAN PESANAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Subtotal Produk',
              (order['total_amount'] ?? 0) - 
              (order['shipping_cost'] ?? 0) - 
              (order['service_fee'] ?? 0) + 
              (order['discount'] ?? 0),
            ),
            _buildSummaryRow(
              'Biaya Pengiriman',
              order['shipping_cost'] ?? 0,
            ),
            _buildSummaryRow(
              'Biaya Layanan',
              order['service_fee'] ?? 0,
            ),
            if ((order['discount'] ?? 0) > 0)
              _buildSummaryRow(
                'Diskon',
                -(order['discount'] ?? 0),
                isDiscount: true,
              ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.grey),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Total Pembayaran',
              order['total_amount'] ?? 0,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, num amount, {
    bool isTotal = false, 
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF2E86C1) : Colors.grey.shade800,
            ),
          ),
          Text(
            isDiscount ? '-${currencyFormat.format(amount)}' : currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount 
                  ? const Color(0xFFF44336)
                  : (isTotal ? const Color(0xFF2E86C1) : Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Rincian Pembayaran',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF87CEEB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoiceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E86C1)),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadInvoiceData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E86C1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Coba Lagi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : FutureBuilder<Map<String, dynamic>>(
                  future: _invoiceData,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: Text('Data pembayaran tidak ditemukan'),
                      );
                    }

                    final data = snapshot.data!;
                    final order = data['order'] as Map<String, dynamic>;
                    final payment = data['payment'] as Map<String, dynamic>;
                    final items = data['items'] as List<dynamic>;
                    final address = data['address'] as Map<String, dynamic>;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Invoice Header
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E86C1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      size: 28,
                                      color: Color(0xFF2E86C1),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'INVOICE',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'INV/${DateFormat('yyyy').format(DateTime.now())}/CTRCMTK/${order['order_number']}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(order['created_at'])),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Payment method section
                          _buildPaymentMethodSection(payment, order),
                          const SizedBox(height: 16),

                          // Order items
                          _buildOrderItems(items),
                          const SizedBox(height: 16),

                          // Address section if exists
                          if (address.isNotEmpty) ...[
                            _buildAddressSection(address),
                            const SizedBox(height: 16),
                          ],

                          // Order summary
                          _buildOrderSummary(order),
                          const SizedBox(height: 24),

                          // Help section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.help_outline,
                                      size: 20,
                                      color: Color(0xFF2E86C1),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'BUTUH BANTUAN?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E86C1),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Jika Anda mengalami kesulitan dalam pembayaran, silakan hubungi tim dukungan kami.',
                                  style: TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      // Handle contact support
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFF2E86C1),
                                      ),
                                    ),
                                    child: const Text(
                                      'Hubungi Dukungan',
                                      style: TextStyle(
                                        color: Color(0xFF2E86C1),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}