import 'dart:core';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class InvoicePage extends StatefulWidget {
  final String orderId;

  const InvoicePage({Key? key, required this.orderId}) : super(key: key);

  @override
  _InvoicePageState createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  late Future<Map<String, dynamic>> _invoiceData;
  final supabase = Supabase.instance.client;
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadInvoiceData();
    });
  }

  Future<void> _loadInvoiceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await _fetchInvoiceData();
      setState(() {
        _invoiceData = Future.value(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data invoice: $e';
        _isLoading = false;
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
          products:product_id (name, price_display, photos)
        ''')
        .eq('order_id', widget.orderId);

    final itemsData = itemsResponse;

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
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Color _getPaymentStatusColors(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color.fromARGB(255, 165, 255, 168);
      case 'pending':
        return const Color.fromARGB(255, 255, 225, 180);
      default:
        return const Color.fromARGB(255, 255, 188, 184);
    }
  }

  Future<void> _generateAndSavePdf(BuildContext context, Map<String, dynamic> data) async {
    try {
      // Generate PDF
      final pdf = await _generatePdfDocument(data);
      
      // Request storage permission
      if (!await _requestStoragePermission()) {
        throw 'Izin penyimpanan ditolak';
      }
      
      // Save PDF to device
      final filePath = await _savePdfToDevice(pdf, data['order']['order_number'].toString());
      
      // Show success message and open the file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice berhasil disimpan di: $filePath'),
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Open the PDF file
      await OpenFile.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: ${e.toString()}')),
      );
      debugPrint('PDF generation error: $e');
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

Future<pw.Document> _generatePdfDocument(Map<String, dynamic> data) async {
  final order = data['order'] as Map<String, dynamic>;
  final items = data['items'] as List<dynamic>;
  final address = data['address'] as Map<String, dynamic>;
  final payment = data['payment'] as Map<String, dynamic>;

  final orderDate = DateTime.parse(order['created_at']).toLocal();
  final formattedDate = DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(orderDate);
  final currentYear = DateFormat('yyyy').format(DateTime.now());
  final paymentStatus = _getPaymentStatusText(payment['status'] ?? 'pending');
  final statusColors = _getPaymentStatusColors(payment['status'] ?? 'pending');
  final statusColor = _getPaymentStatusColor(payment['status'] ?? 'pending');

  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(16),
      build: (pw.Context context) {
        return pw.Stack(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with logo and invoice info
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Toko Citra Cosmetik',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(const Color(0xFF2E86C1).value),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'INV/$currentYear/CTRCMTK/${order['order_number']}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        width: 50,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(const Color(0xFFE6F7FF).value),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                       
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Seller and buyer information
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'DITERBITKAN OLEH:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.Text(
                              'Penjual:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.Text('Toko Citra Cosmetik', style: pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'Alamat:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.Text('Jl. Muara Dua, Kota Lhokseumawe, Aceh Utara', 
                              style: pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Pembeli:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.Text(address['recipient_name'] ?? '-', style: pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'Tanggal Pesanan:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.Text(formattedDate, style: pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'No HP:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.Text(address['phone_number'] ?? '-', style: pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Shipping address
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Alamat Pengiriman:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        '${address['recipient_name'] ?? '-'} (${address['phone_number'] ?? '-'})',
                        style: pw.TextStyle(fontSize: 10)),
                      pw.Text(address['street_address'] ?? '-', style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Products table
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    children: [
                      // Table header
                      pw.Table(
                        columnWidths: const {
                          0: pw.FlexColumnWidth(3),
                          1: pw.FlexColumnWidth(1),
                          2: pw.FlexColumnWidth(1.5),
                          3: pw.FlexColumnWidth(1.5),
                        },
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(const Color(0xFFE6F7FF).value),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  'Produk',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  'Jmh.',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  'Harga',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  'Total',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Products list
                      ...items.map((item) {
                        final product = item['products'] as Map<String, dynamic>? ?? {};
                        final quantity = item['quantity'] as int? ?? 0;
                        final price = item['price'] as num? ?? 0;
                        final total = quantity * price;

                        return pw.Table(
                          columnWidths: const {
                            0: pw.FlexColumnWidth(3),
                            1: pw.FlexColumnWidth(1),
                            2: pw.FlexColumnWidth(1.5),
                            3: pw.FlexColumnWidth(1.5),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  child: pw.Text(product['name'] ?? 'Produk tidak ditemukan',
                                    style: pw.TextStyle(fontSize: 10)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  child: pw.Text(
                                    quantity.toString(),
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  child: pw.Text(
                                    currencyFormat.format(price),
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  child: pw.Text(
                                    currencyFormat.format(total),
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Payment summary
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    children: [
                      _buildPdfSummaryRow(
                        'Subtotal Harga Barang',
                        (order['total_amount'] ?? 0) - 
                        (order['shipping_cost'] ?? 0) - 
                        (order['service_fee'] ?? 0) + 
                        (order['discount'] ?? 0),
                        fontSize: 10,
                      ),
                      _buildPdfSummaryRow(
                        'Subtotal Pengiriman',
                        order['shipping_cost'] ?? 0,
                        fontSize: 10,
                      ),
                      _buildPdfSummaryRow(
                        'Biaya Layanan',
                        order['service_fee'] ?? 0,
                        fontSize: 10,
                      ),
                      if ((order['discount'] ?? 0) > 0)
                        _buildPdfSummaryRow(
                          'Subtotal Diskon',
                          -(order['discount'] ?? 0),
                          isDiscount: true,
                          fontSize: 10,
                        ),
                      pw.SizedBox(height: 8),
                      pw.Divider(height: 1),
                      pw.SizedBox(height: 8),
                      _buildPdfSummaryRow(
                        'Total Tagihan',
                        order['total_amount'] ?? 0,
                        isTotal: true,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Payment method and status
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Metode Pembayaran:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          pw.Text(
                            order['payment_method'] ?? 'Tidak diketahui',
                            style: pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Status Pembayaran:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(statusColors.value),
                              borderRadius: pw.BorderRadius.circular(16),
                              border: pw.Border.all(
                                color: PdfColor.fromInt(statusColor.value),
                                width: 1,
                              ),
                            ),
                            child: pw.Text(
                              paymentStatus,
                              style: pw.TextStyle(
                                color: PdfColor.fromInt(statusColor.value),
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),
                pw.Center(
                  child: pw.Text(
                    'Invoice diunduh pada ${DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(DateTime.now())}',
                    style: pw.TextStyle(
                      color: PdfColors.grey,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),

            // Watermark
            pw.Positioned.fill(
              child: pw.Center(
                child: pw.Transform.rotate(
                  angle: 0.8,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromInt(statusColors.value),
                        width: 3.5,
                      ),
                    ),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                    child: pw.Text(
                      paymentStatus,
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(statusColors.value),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf;
}


  Future<String> _savePdfToDevice(pw.Document pdf, String orderNumber) async {
    // Get directory for saving the file
    Directory directory;
    
    if (Platform.isAndroid) {
      directory = Directory("/storage/emulated/0/Download");
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory() ?? Directory("/storage/emulated/0/Download");
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      throw 'Platform not supported';
    }

    // Create folder if not exists
    final folder = Directory("${directory.path}/Invoices");
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    // Save the file
    final file = File("${folder.path}/invoice_$orderNumber.pdf");
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  pw.Widget _buildPdfSummaryRow(String label, num amount, {bool isTotal = false, bool isDiscount = false, required int fontSize}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 9,
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Text(
            isDiscount ? '-${currencyFormat.format(amount)}' : currencyFormat.format(amount),
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isDiscount ? PdfColors.red : null,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Invoice Pembelian',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF87CEEB),
        elevation: 0,
        actions: [
          FutureBuilder<Map<String, dynamic>>(
            future: _invoiceData,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return IconButton(
                  icon: const Icon(Icons.download, color: Colors.white, size: 22),
                  onPressed: () => _generateAndSavePdf(context, snapshot.data!),
                  tooltip: 'Unduh PDF',
                );
              }
              return Container();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE6F7FF),
              Colors.white,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF87CEEB)),
                ),
              )
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInvoiceData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF87CEEB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: const Text(
                              'Coba Lagi',
                              style: TextStyle(color: Colors.white, fontSize: 14),
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
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: Text('Data invoice tidak ditemukan', style: TextStyle(fontSize: 14)),
                        );
                      }

                      final data = snapshot.data!;
                      final order = data['order'] as Map<String, dynamic>;
                      final items = data['items'] as List<dynamic>;
                      final address = data['address'] as Map<String, dynamic>;
                      final payment = data['payment'] as Map<String, dynamic>;

                      final orderDate = DateTime.parse(order['created_at']).toLocal();
                      final formattedDate = DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(orderDate);
                      final currentYear = DateFormat('yyyy').format(DateTime.now());
                      final paymentStatus = _getPaymentStatusText(payment['status'] ?? 'pending');
                      final statusColor = _getPaymentStatusColor(payment['status'] ?? 'pending');

                      return Stack(
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header dengan logo dan info invoice
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100,
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Toko Citra Cosmetik',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2E86C1),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'INV/$currentYear/CTRCMTK/${order['order_number']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6F7FF),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.receipt,
                                          size: 30,
                                          color: Color(0xFF2E86C1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Informasi penjual dan pembeli
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              'DITERBITKAN OLEH:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                              Text(
                                              'Penjual:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Text('Toko Citra Cosmetik', style: TextStyle(fontSize: 12)),
                                            SizedBox(height: 6),
                                            Text(
                                              'Alamat:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Text('Jl. Muara Dua, Kota Lhokseumawe, Aceh Utara', 
                                              style: TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Pembeli:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Text(address['recipient_name'] ?? '-', style: const TextStyle(fontSize: 12)),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Tanggal Pesanan:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Text(formattedDate, style: const TextStyle(fontSize: 12)),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'No HP:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Text(address['phone_number'] ?? '-', style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Alamat pembeli
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Alamat Pengiriman:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                          '${address['recipient_name'] ?? '-'} (${address['phone_number'] ?? '-'})',
                                          style: const TextStyle(fontSize: 12)),
                                      Text(address['street_address'] ?? '-', style: const TextStyle(fontSize: 12)),
                                    
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Daftar produk
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Header daftar produk
                                      Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(3),
                                          1: FlexColumnWidth(1),
                                          2: FlexColumnWidth(1.5),
                                          3: FlexColumnWidth(1.5),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE6F7FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            children: const [
                                              Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Text(
                                                  'Produk',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Text(
                                                  'Jmh.',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Text(
                                                  'Harga',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Text(
                                                  'Total',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // Daftar produk
                                      ...items.map((item) {
                                        final product = item['products'] as Map<String, dynamic>? ?? {};
                                        final quantity = item['quantity'] as int? ?? 0;
                                        final price = item['price'] as num? ?? 0;
                                        final total = quantity * price;

                                        return Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(3),
                                            1: FlexColumnWidth(1),
                                            2: FlexColumnWidth(1.5),
                                            3: FlexColumnWidth(1.5),
                                          },
                                          children: [
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                  child: Text(product['name'] ?? 'Produk tidak ditemukan',
                                                      style: const TextStyle(fontSize: 12)),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                  child: Text(
                                                    quantity.toString(),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(fontSize: 11),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                  child: Text(
                                                    currencyFormat.format(price),
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(fontSize: 11),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                  child: Text(
                                                    currencyFormat.format(total),
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(fontSize: 11),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Ringkasan pembayaran
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      _buildSummaryRow(
                                        'Subtotal Harga Barang',
                                        (order['total_amount'] ?? 0) - 
                                        (order['shipping_cost'] ?? 0) - 
                                        (order['service_fee'] ?? 0) + 
                                        (order['discount'] ?? 0),
                                        fontSize: 12,
                                      ),
                                      _buildSummaryRow(
                                        'Subtotal Pengiriman',
                                        order['shipping_cost'] ?? 0,
                                        fontSize: 12,
                                      ),
                                      _buildSummaryRow(
                                        'Biaya Layanan',
                                        order['service_fee'] ?? 0,
                                        fontSize: 12,
                                      ),
                                      if ((order['discount'] ?? 0) > 0)
                                        _buildSummaryRow(
                                          'Subtotal Diskon',
                                          -(order['discount'] ?? 0),
                                          isDiscount: true,
                                          fontSize: 12,
                                        ),
                                      const SizedBox(height: 8),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      _buildSummaryRow(
                                        'Total Tagihan',
                                        order['total_amount'] ?? 0,
                                        isTotal: true,
                                        fontSize: 14,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Metode pembayaran dan status
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Metode Pembayaran:',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                             order['payment_method'] ?? 'Tidak diketahui',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Status Pembayaran:',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: statusColor,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              paymentStatus,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'Invoice diunduh pada ${DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(DateTime.now())}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),

                          // Watermark
                          IgnorePointer(
                            child: Center(
                              child: Transform.rotate(
                                angle: -0.8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.3),
                                      width: 3.5,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                                  child: Text(
                                    paymentStatus,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor.withOpacity(0.3
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, num amount, {
    bool isTotal = false, 
    bool isDiscount = false,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF2E86C1) : null,
            ),
          ),
          Text(
            isDiscount ? '-${currencyFormat.format(amount)}' : currencyFormat.format(amount),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.red : (isTotal ? const Color(0xFF2E86C1) : null),
            ),
          ),
        ],
      ),
    );
  }
}