import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

class MidtransService {
  // Gunakan endpoint API yang benar (v2)
  static const String _baseUrl = 'https://api.sandbox.midtrans.com';
  static const String _snapUrl = '$_baseUrl/v2/charge';
  static const String _midtransScriptUrl = 'https://app.sandbox.midtrans.com/snap/snap.js';
  
  // Pastikan kredensial sandbox Anda valid
  static const String _clientKey = 'SB-Mid-client-V_-jn7aJterYapWc'; // Ganti dengan client key Anda
  static const String _serverKey = 'SB-Mid-server-QOGAZkKJcUbOS1wHwJRORSDd'; // Ganti dengan server key Anda

  static Future<Map<String, dynamic>> createTransaction({
    required String orderId,
    required double grossAmount,
    String? paymentMethod,
      String? customerEmail,
  }) async {
    final url = Uri.parse(_snapUrl);
    
    // Basic auth header dengan encoding yang benar
    final auth = 'Basic ${base64Encode(utf8.encode('$_serverKey:'))}';
    
    final body = <String, dynamic>{
    'payment_type': 'bank_transfer',
    'transaction_details': {
      'order_id': orderId,
      'gross_amount': grossAmount.toInt(),
    },
    // Tambahkan customer details jika email tersedia
    if (customerEmail != null) 'customer_details': {
      'email': customerEmail,
    },
  };

    // Add specific payment method details
    if (paymentMethod != null) {
      switch (paymentMethod.toUpperCase()) {
        case 'BSI':
          body['payment_type'] = 'bank_transfer';
          body['bank_transfer'] = {'bank': 'bsi'};
          break;
        case 'SHOPEEPAY':
          body['payment_type'] = 'shopeepay';
          body['shopeepay'] = {
            'callback_url': 'citraapp://midtrans-callback' // Deep link ke aplikasi
          };
          break;
        case 'GOPAY':
          body['payment_type'] = 'gopay';
          break;
        default:
          body['payment_type'] = paymentMethod.toLowerCase();
      }
    }

    try {
      // Debug logging sebelum request
      developer.log('Midtrans Request to: $url');
      developer.log('Request Body: ${jsonEncode(body)}');

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': auth,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      // Debug logging setelah response
      developer.log('Midtrans Response: ${response.statusCode}');
      developer.log('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        // Coba parse error message
        try {
          final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
          throw Exception('Midtrans Error: ${errorResponse['error_messages'] ?? errorResponse['message'] ?? response.body}');
        } catch (_) {
          throw Exception('Failed to create transaction. Status: ${response.statusCode}');
        }
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: ${e.message}');
    } catch (e) {
      throw Exception('Error processing Midtrans payment: $e');
    }
  }

  static Future<Map<String, dynamic>> checkTransactionStatus(String orderId) async {
  final url = Uri.parse('$_baseUrl/v2/$orderId/status');
  
  final auth = 'Basic ${base64Encode(utf8.encode('$_serverKey:'))}';
  
  try {
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': auth,
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to check transaction status. Status: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error checking transaction status: $e');
  }
}
  
  static String get midtransScriptUrl => _midtransScriptUrl;
}