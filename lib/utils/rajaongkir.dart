import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RajaOngkirService {
  static const String _baseUrl = 'https://rajaongkir.komerce.id/api/v1';
  static const String _apiKey = 'C9tVSHobc55150227976fb1eaTcFhXyG';

  
 static Future<Map<String, dynamic>> getShippingCost({
  required String origin,
  required String destination,
  required int weight,
  required String courier,
}) async {
  try {
    final url = Uri.parse('$_baseUrl/calculate/domestic-cost');
    
    final response = await http.post(
      url,
      headers: {
        'key': _apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'origin': origin,
        'destination': destination,
        'weight': weight.toString(),
        'courier': courier.toLowerCase(),
      },
    );

    // Handle 404 specifically
    if (response.statusCode == 404) {
      throw Exception('Layanan pengiriman ${courier.toUpperCase()} tidak tersedia untuk rute ini');
    }

    final result = json.decode(response.body);
    
    if (response.statusCode == 200) {
      if (result['data'] != null && result['data'] is List && result['data'].isNotEmpty) {
        // Find the regular service
        final regularService = (result['data'] as List).firstWhere(
          (service) => service['service']?.toLowerCase() == 'reg',
          orElse: () => result['data'][0], // Fallback to first service if regular not found
        );

        return {
          'code': courier.toLowerCase(),
          'name': courier.toUpperCase(),
          'costs': [
            {
              'service': regularService['service'] ?? 'REG',
              'description': regularService['description'] ?? '',
              'cost': [
                {
                  'value': regularService['cost'] ?? 0,
                  'etd': regularService['etd'] ?? '3',
                  'note': regularService['note'] ?? '',
                }
              ]
            }
          ],
        };
      } else {
        throw Exception('Tidak ada layanan pengiriman tersedia untuk rute ini');
      }
    } else {
      final errorMsg = result['meta']['message'] ?? 'Unknown error';
      throw Exception('$errorMsg (${response.statusCode})');
    }
  } catch (e) {
    debugPrint('Error in getShippingCost: $e');
    throw Exception('Gagal mendapatkan ongkos kirim: ${e.toString()}');
  }
}
}