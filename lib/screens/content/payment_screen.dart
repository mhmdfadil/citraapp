import 'package:citraapp/screens/content/invoice.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/widget/appbar_b.dart';
import 'package:intl/intl.dart';

class PaymentContent extends StatefulWidget {
  final String? searchQuery;

  const PaymentContent({Key? key, this.searchQuery}) : super(key: key);

  @override
  _PaymentContentState createState() => _PaymentContentState();
}

class _PaymentContentState extends State<PaymentContent> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> filteredOrders = [];
  String selectedStatus = 'pending'; // Default sesuai dengan orders table
  bool isLoading = true;
  String? userId;
  int currentPage = 1;
  final int itemsPerPage = 10;
  String? currentSearchQuery;

  // Status sesuai dengan yang ada di tabel orders dan payments
  final List<String> orderStatuses = ['pending', 'processed', 'shipped', 'delivered', 'cancelled', 'completed'];
  final List<String> paymentStatuses = ['pending', 'paid', 'denied', 'expired'];

  @override
  void initState() {
    super.initState();
    currentSearchQuery = widget.searchQuery;
    _loadUserIdAndOrders();
  }

  Future<void> _loadUserIdAndOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('user_id');
    
    setState(() {
      userId = storedUserId;
    });
    await _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => isLoading = true);
    
    try {
      final response = await supabase
          .from('orders')
          .select('''
            *,
            payments(*),
            addresses(*)
          ''')
          .eq('user_id', userId ?? '')
          .order('created_at', ascending: false);

      if (response != null && response is List) {
        setState(() {
          orders = List<Map<String, dynamic>>.from(response);
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching orders: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat pesanan')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      filteredOrders = orders.where((order) {
        // Filter berdasarkan status order atau payment
        final statusMatch = order['status'] == selectedStatus || 
                          (order['payments'] != null && 
                           order['payments'].isNotEmpty && 
                           order['payments'][0]['status'] == selectedStatus);
        
        // Informasi alamat
        final address = order['addresses'] as Map<String, dynamic>?;
        final recipientName = address?['recipient_name']?.toString().toLowerCase() ?? '';
        
        // Informasi order
        final orderNumber = order['order_number']?.toString().toLowerCase() ?? '';
        final orderId = order['id']?.toString().toLowerCase() ?? '';
        
        // Jika ada query pencarian
        if (currentSearchQuery != null && currentSearchQuery!.isNotEmpty) {
          final query = currentSearchQuery!.toLowerCase();
          return statusMatch && 
                (recipientName.contains(query) || 
                 orderNumber.contains(query) || 
                 orderId.contains(query));
        }
        return statusMatch;
      }).toList();
      currentPage = 1;
    });
  }

  List<Map<String, dynamic>> get paginatedOrders {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    return endIndex > filteredOrders.length
        ? filteredOrders.sublist(startIndex)
        : filteredOrders.sublist(startIndex, endIndex);
  }

  String _formatCurrency(dynamic amount) {
    final numValue = amount is num ? amount : double.tryParse(amount.toString()) ?? 0;
    return 'Rp ${numValue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString).add(Duration(hours: 7)); // Tambah 7 jam untuk WIB
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'denied':
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      case 'processing':
      case 'shipped':
        return Colors.blue;
      default:
        return Colors.deepPurple;
    }
  }

  String _getPaymentMethod(Map<String, dynamic> order) {
    if (order['payments'] != null && order['payments'].isNotEmpty) {
      return order['payment_method']?.toString().toUpperCase() ?? order['payment_method'] ?? 'Unknown';
    }
    return order['payment_method'] ?? 'Unknown';
  }

  double _getTotalAmount(Map<String, dynamic> order) {
    final total = order['total_amount'] ?? 0;
    final shipping = order['shipping_cost'] ?? 0;
    final serviceFee = order['service_fee'] ?? 0;
    final discount = order['discount'] ?? 0;
    
    return (total).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (filteredOrders.length / itemsPerPage).ceil();
    final hasPreviousPage = currentPage > 1;
    final hasNextPage = currentPage < totalPages;

    return Scaffold(
      appBar: AppBarB(),
      body: Column(
        children: [
          // Search results header
          if (currentSearchQuery != null && currentSearchQuery!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Hasil pencarian untuk "${currentSearchQuery}"',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          // Status Filter Chips
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: paymentStatuses.map((status) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: selectedStatus == status ? Colors.white : Colors.black,
                        fontSize: 12,
                      ),
                    ),
                    selected: selectedStatus == status,
                    selectedColor: _getStatusColor(status),
                    backgroundColor: Colors.grey[200],
                    onSelected: (selected) {
                      setState(() {
                        selectedStatus = status;
                        _applyFilters();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Order Cards
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        if (filteredOrders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              currentSearchQuery != null && currentSearchQuery!.isNotEmpty
                                  ? 'Tidak ada pesanan yang cocok dengan pencarian'
                                  : 'Tidak ada pesanan dengan status $selectedStatus',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        else
                          ListView.builder(
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.all(8),
                            itemCount: paginatedOrders.length,
                            itemBuilder: (context, index) {
                              final order = paginatedOrders[index];
                              final payment = order['payments'] != null && order['payments'].isNotEmpty 
                                  ? order['payments'][0] 
                                  : null;
                              final address = order['addresses'] as Map<String, dynamic>?;
                              final status = payment?['status'] ?? order['status'];
                              
                              return Card(
                                elevation: 2,
                                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Pesanan: #${order['order_number']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(status),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status?.toUpperCase() ?? '',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Divider(height: 1),
                                      SizedBox(height: 8),
                                      Text(
                                        'Metode Pembayaran: ${_getPaymentMethod(order)}',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Penerima: ${address?['recipient_name'] ?? 'Tidak diketahui'}',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Alamat: ${address?['street_address'] ?? ''}, ${address?['village'] ?? ''}, ${address?['district'] ?? ''}',
                                        style: TextStyle(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Pembayaran:',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          Text(
                                            _formatCurrency(_getTotalAmount(order)),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepPurple,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Tanggal: ${_formatDate(order['created_at'])}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (payment != null)
                                           Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
  icon: Icon(Icons.download_outlined, color: Colors.deepPurple),
  onPressed: () {
    final orderId = order['id']?.toString() ?? '';
     print('Order ID yang akan dikirim: $orderId'); // Debug pri
    if (orderId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoicePage(
            orderId: orderId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan ID pesanan')),
      );
    }
  },
  tooltip: 'Unduh Invoice',
),
                                                IconButton(
                                                  icon: Icon(Icons.remove_red_eye_outlined, color: Colors.deepPurple),
                                                  onPressed: () {
                                                    // Detail functionality
                                                  },
                                                  tooltip: 'Detail Pembayaran',
                                                ),
                                              ],
                                            )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        
                        // Pagination Controls
                        if (filteredOrders.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.arrow_back_ios, size: 20),
                                  color: hasPreviousPage ? Colors.deepPurple : Colors.grey,
                                  onPressed: hasPreviousPage
                                      ? () {
                                          setState(() {
                                            currentPage--;
                                          });
                                        }
                                      : null,
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Halaman $currentPage dari ${totalPages == 0 ? 1 : totalPages}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.arrow_forward_ios, size: 20),
                                  color: hasNextPage ? Colors.deepPurple : Colors.grey,
                                  onPressed: hasNextPage
                                      ? () {
                                          setState(() {
                                            currentPage++;
                                          });
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}