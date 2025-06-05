import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:citraapp/utils/binderbyte2.dart';

class CekResiContent extends StatefulWidget {
  final String awb;
  final String courier;

  const CekResiContent({
    Key? key,
    required this.awb,
    required this.courier,
  }) : super(key: key);

  @override
  _CekResiContentState createState() => _CekResiContentState();
}

class _CekResiContentState extends State<CekResiContent> {
  bool _isLoading = false;
  Map<String, dynamic>? _trackingResult;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _trackResi();
  }

  Future<void> _trackResi() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _trackingResult = null;
    });

    try {
      final result = await BinderByte2.trackPackage(
        courier: widget.courier,
        awb: widget.awb,
      );

      setState(() {
        _trackingResult = result;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
    appBar: AppBar(
  title: const Text('Lacak Pengiriman',
      style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white)),
  centerTitle: true,
  elevation: 0,
  backgroundColor: const Color(0xFF4DA8E0),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      bottom: Radius.circular(16),
    ),
  ),
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () {
      Navigator.of(context).pop();
    },
  ),
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            if (_isLoading) _buildLoadingIndicator(),
            if (_hasError) _buildErrorWidget(),
            if (_trackingResult != null) _buildTrackingResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4DA8E0),
            Color(0xFF7EC8F3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nomor Resi',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9), 
                            fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.awb,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kurir',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9), 
                            fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.courier.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
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
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: List.generate(
                    3,
                    (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                      color: Colors.grey[300]!, width: 2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 200,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ]),
                              ),
                            ],
                          ),
                        )),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF4DA8E0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F0FA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh, color: Color(0xFF4DA8E0)),
              ),
              onPressed: _trackResi,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingResult() {
    final summary = _trackingResult!['summary'];
    final details = _trackingResult!['details'];
    final manifest = _trackingResult!['manifest'] as List<dynamic>;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatusRow(summary),
                const SizedBox(height: 24),
                _buildDetailRow('Asal', details['origin']),
                const Divider(height: 24),
                _buildDetailRow('Tujuan', details['destination']),
                const Divider(height: 24),
                _buildDetailRow('Pengirim', details['shipper']),
                const Divider(height: 24),
                _buildDetailRow('Penerima', details['receiver']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 20, color: Color(0xFF4DA8E0)),
                    const SizedBox(width: 8),
                    const Text(
                      'Riwayat Pengiriman',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${manifest.length} Aktivitas',
                      style: const TextStyle(
                        color: Color(0xFF7F8C8D),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTimeline(manifest),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(Map<String, dynamic> summary) {
    final statusColor = _getStatusColor(summary['status']);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(summary['status']),
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Pengiriman',
                  style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  summary['status'] ?? '-',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 16,
                  ),
                ),
                if (summary['desc'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      summary['desc'],
                      style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            title,
            style: const TextStyle(
                color: Color(0xFF7F8C8D),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value ?? '-',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(List<dynamic> manifest) {
    return Column(
      children: List.generate(manifest.length, (index) {
        final item = manifest[index];
        final isFirst = index == 0;
        final isLast = index == manifest.length - 1;
        final isDelivered = _trackingResult!['summary']['status']
            .toString()
            .toLowerCase()
            .contains('delivered');

        // Check if this step is completed (all steps below the current one are completed)
        bool isCompleted = false;
        if (isDelivered) {
          isCompleted = true;
        } else {
          // For non-delivered status, mark steps as completed from bottom up
          isCompleted = index > 0;
        }

        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? const Color(0xFF4DA8E0) : Colors.grey[300],
                      border: Border.all(
                        color: isCompleted ? const Color(0xFF4DA8E0) : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 60,
                      color: isCompleted ? const Color(0xFF4DA8E0) : Colors.grey[300],
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? const Color(0xFFE1F0FA)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['manifest_description'] ?? '-',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isCompleted
                              ? const Color(0xFF2C3E50)
                              : const Color(0xFF7F8C8D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 14, color: Color(0xFF7F8C8D)),
                          const SizedBox(width: 4),
                          Text(
                            item['manifest_date'] ?? '-',
                            style: const TextStyle(
                                color: Color(0xFF7F8C8D), fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time,
                              size: 14, color: Color(0xFF7F8C8D)),
                          const SizedBox(width: 4),
                          Text(
                            item['manifest_time'] ?? '-',
                            style: const TextStyle(
                                color: Color(0xFF7F8C8D), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return const Color(0xFF7F8C8D);

    if (status.toLowerCase().contains('delivered') ||
        status.toLowerCase().contains('terkirim')) {
      return const Color(0xFF27AE60);
    } else if (status.toLowerCase().contains('failed') ||
        status.toLowerCase().contains('gagal')) {
      return const Color(0xFFE74C3C);
    } else if (status.toLowerCase().contains('process') ||
        status.toLowerCase().contains('proses')) {
      return const Color(0xFFF39C12);
    } else {
      return const Color(0xFF4DA8E0);
    }
  }

  IconData _getStatusIcon(String? status) {
    if (status == null) return Icons.help_outline;

    if (status.toLowerCase().contains('delivered')) {
      return Icons.check_circle;
    } else if (status.toLowerCase().contains('failed')) {
      return Icons.error_outline;
    } else if (status.toLowerCase().contains('process')) {
      return Icons.autorenew;
    } else {
      return Icons.info_outline;
    }
  }
}