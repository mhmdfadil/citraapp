import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 207, 242),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              color: Color(0xFFF273F0),
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

            // Content
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Address Card
                  Card(
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
                                RichText(
                                  text: const TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Alwi Hasyimi ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '(+62)82230319548',
                                        style: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Jln.Line Pipa Dusun Tengku Sematang, Lorong Sumatera, Desa Padang Sakti Lorong Samping Pupuk UD Nusa Tani.\n'
                                  'MUARA SATU, KOTA LHOKSEUMAWE, NANGGROE ACEH DARUSSALAM (NAD), ID 24354',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                    height: 1.4,
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

                  // Product Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WARDAH',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.blue[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.network(
                                  'assets/images/war1.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sunscreen Wardah',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Rp.40.000',
                                      style: TextStyle(
                                        color: Color(0xFFFF1E00),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Method
                  Row(
                    children: [
              Container(
  width: 24,
  height: 24,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(
      color: Color(0xFFFF1E00), // warna border
      width: 2,
    ),
  ),
  child: Center(
    child: FaIcon(
      FontAwesomeIcons.dollarSign,
      color: Color(0xFFFF1E00), // warna ikon
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
                      const SizedBox(width: 8),
                      Text(
                        'COD - Cek Dulu',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
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
                          _buildPaymentRow('Subtotal Untuk Produk', 'Rp. 35.000'),
                          _buildPaymentRow('Subtotal Pengiriman', 'Rp. 40.000'),
                          _buildPaymentRow('Biaya Layanan', 'Rp. 5.000'),
                          _buildPaymentRow(
                              'Total Diskon Pengiriman', '-Rp. 40.000',
                              isDiscount: true),
                          const Divider(height: 24),
                          _buildPaymentRow('Total Bayar', 'Rp. 40.000',
                              isTotal: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Bar
      bottomNavigationBar: Container(
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
                  children: const [
                    Text('Total '),
                    Text(
                      'Rp 40.000',
                      style: TextStyle(
                        color: Color(0xFFFF1E00),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Hemat '),
                    Text(
                      'Rp 40.000',
                      style: TextStyle(
                        color: Color(0xFFFF1E00),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor:  Color(0xFFFF1E00),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              color: isDiscount ? Color(0xFFFF1E00) : Colors.black,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.normal : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}