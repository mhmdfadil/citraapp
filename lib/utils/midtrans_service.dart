import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class MidtransService {
  static const String _sandboxUrl = 'https://api.sandbox.midtrans.com/v2/charge';
  static const String _productionUrl = 'https://api.midtrans.com/v2/charge';
  
  // Ganti dengan server key Anda yang benar
  static const String _serverKey = 'SB-Mid-server-3VhdO-VCz8m-XZw9YF5GVwiV';
  
  static Future<Map<String, dynamic>> createTransaction({
    required String orderId,
    required double amount,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerDetails,
    required String paymentMethod,
  }) async {
    try {
      final isSandbox = true; // Set false untuk production
      final url = isSandbox ? _sandboxUrl : _productionUrl;
      
      // Validasi payment method
      if (!_isValidPaymentMethod(paymentMethod)) {
        throw Exception('Payment method $paymentMethod not supported');
      }

      // Prepare transaction details
      final transactionDetails = {
        'order_id': orderId,
        'gross_amount': amount.toInt(),
      };

      // Prepare payment-specific parameters
      final paymentConfig = _getPaymentConfig(paymentMethod, amount);
      
      // Prepare complete request body
      final requestBody = {
        'payment_type': paymentConfig['payment_type'],
        'transaction_details': transactionDetails,
        'item_details': items,
        'customer_details': customerDetails,
        ...paymentConfig['params'],
      };

      debugPrint('Midtrans Request: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_serverKey:'))}',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Midtrans Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to charge: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Midtrans Error: $e');
      rethrow;
    }
  }

  static bool _isValidPaymentMethod(String paymentMethod) {
    final supportedMethods = ['BSI', 'DANA', 'COD', 'BCA', 'BRI', 'BNI', 'MANDIRI', 'PERMATA', 'QRIS'];
    return supportedMethods.contains(paymentMethod.toUpperCase());
  }

  static Map<String, dynamic> _getPaymentConfig(String paymentMethod, double amount) {
    switch (paymentMethod.toUpperCase()) {
      case 'BSI':
        return {
          'payment_type': 'bank_transfer',
          'params': {
            'bank_transfer': {
              'bank': 'bsi',
              'va_number': _generateVirtualAccountNumber(),
            }
          }
        };
      case 'DANA':
        return {
          'payment_type': 'qris',
          'params': {
            'qris': {
              'acquirer': 'dana',
            }
          }
        };
      case 'BCA':
        return {
          'payment_type': 'bank_transfer',
          'params': {
            'bank_transfer': {
              'bank': 'bca',
              'va_number': _generateVirtualAccountNumber(),
            }
          }
        };
      case 'COD':
        throw Exception('COD payments should be handled locally');
      default:
        throw Exception('Payment method $paymentMethod not supported');
    }
  }

  static String _generateVirtualAccountNumber() {
    // Generate random VA number (8 digits)
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return random.substring(random.length - 8);
  }
}