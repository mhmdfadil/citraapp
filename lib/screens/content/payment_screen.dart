import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/widget/appbar_b.dart';

class PaymentContent extends StatefulWidget {
  final String? searchQuery;

  const PaymentContent({Key? key, this.searchQuery}) : super(key: key);

  @override
  _PaymentContentState createState() => _PaymentContentState();
}

class _PaymentContentState extends State<PaymentContent> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> filteredPayments = [];
  String selectedStatus = 'paid';
  bool isLoading = true;
  String? userId;
  int currentPage = 1;
  final int itemsPerPage = 10;
  String? currentSearchQuery;

  final List<String> paymentStatuses = ['paid', 'pending', 'deny', 'expire'];

  @override
  void initState() {
    super.initState();
    currentSearchQuery = widget.searchQuery;
    _loadUserIdAndPayments();
  }

  Future<void> _loadUserIdAndPayments() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id');
    });
    await _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() => isLoading = true);
    
    try {
      final response = await supabase
          .from('payments')
          .select('''
            *, 
            orders:order_id(*, addresses:address_id(recipient_name))
          ''')
          .eq('orders.user_id', userId ?? '')
          .order('created_at', ascending: false);
      
      if (response != null && response is List) {
        setState(() {
          payments = List<Map<String, dynamic>>.from(response);
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching payments: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat pembayaran')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      filteredPayments = payments.where((payment) {
        final statusMatch = payment['status'] == selectedStatus;
        final order = payment['orders'] as Map<String, dynamic>?;
        final address = order?['addresses'] as Map<String, dynamic>?;
        final recipientName = address?['recipient_name']?.toString().toLowerCase() ?? '';
        final paymentId = payment['id']?.toString().toLowerCase() ?? '';
        final orderId = payment['order_id']?.toString().toLowerCase() ?? '';
        
        // If there's a search query, filter by it
        if (currentSearchQuery != null && currentSearchQuery!.isNotEmpty) {
          final query = currentSearchQuery!.toLowerCase();
          return statusMatch && 
              (recipientName.contains(query) || 
               paymentId.contains(query) || 
               orderId.contains(query));
        }
        return statusMatch;
      }).toList();
      currentPage = 1;
    });
  }

  List<Map<String, dynamic>> get paginatedPayments {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    return endIndex > filteredPayments.length
        ? filteredPayments.sublist(startIndex)
        : filteredPayments.sublist(startIndex, endIndex);
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
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'deny':
        return Colors.red;
      case 'expire':
        return Colors.grey;
      default:
        return Colors.deepPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (filteredPayments.length / itemsPerPage).ceil();
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
                'Hasil pencarian pembayaran "${currentSearchQuery}"',
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
          
          // Payment Cards
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        if (filteredPayments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              currentSearchQuery != null && currentSearchQuery!.isNotEmpty
                                  ? 'Tidak ada pembayaran dengan status $selectedStatus yang cocok dengan pencarian'
                                  : 'Tidak ada pembayaran dengan status $selectedStatus',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        else
                          ListView.builder(
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.all(8),
                            itemCount: paginatedPayments.length,
                            itemBuilder: (context, index) {
                              final payment = paginatedPayments[index];
                              final order = payment['orders'] as Map<String, dynamic>?;
                              final address = order?['addresses'] as Map<String, dynamic>?;
                              
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
                                            'ID Pembayaran: #${payment['id']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(payment['status']),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              payment['status']?.toUpperCase() ?? '',
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
                                        'Pesanan: #${payment['order_id']}',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Penerima: ${address?['recipient_name'] ?? 'Tidak diketahui'}',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Metode: ${payment['method'] ?? 'Tidak diketahui'}',
                                        style: TextStyle(fontSize: 13),
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
                                            _formatCurrency(payment['amount']),
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
                                            'Tanggal: ${_formatDate(payment['created_at'])}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (payment['status'] == 'pending')
                                            TextButton(
                                              onPressed: () {
                                                // Add payment confirmation logic here
                                              },
                                              child: Text(
                                                'Konfirmasi',
                                                style: TextStyle(color: Colors.deepPurple),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        
                        // Pagination Controls
                        if (filteredPayments.isNotEmpty)
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