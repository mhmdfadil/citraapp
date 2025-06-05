import 'dart:convert';
import 'package:http/http.dart' as http;

class BinderByte2 {
  static const String _apiKey = '4376c9850a792a14bc0fe3e7659684ff580e7aacf468ec9fd24c95d45bd6821b';
  static const String _baseUrl = 'https://api.binderbyte.com/v1/track';

  static Future<Map<String, dynamic>> trackPackage({
    required String courier,
    required String awb,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?api_key=$_apiKey&courier=$courier&awb=$awb'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _formatResponse(data);
      } else {
        throw Exception('Failed to track package: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error tracking package: $e');
    }
  }

  static Map<String, dynamic> _formatResponse(Map<String, dynamic> data) {
    if (data['status'] != 200) {
      throw Exception(data['message'] ?? 'Failed to track package');
    }

    final summary = data['data']['summary'];
    final detail = data['data']['detail'];
    final history = data['data']['history'] as List<dynamic>;

    return {
      'status': true,
      'message': data['message'] ?? 'Successfully tracked package',
      'summary': {
        'waybill': summary['awb'],
        'courier': summary['courier'],
        'service': summary['service'],
        'status': summary['status'],
        'date': summary['date'],
        'desc': summary['desc'],
        'amount': summary['amount'],
        'weight': summary['weight'],
      },
      'details': {
        'origin': detail['origin'],
        'destination': detail['destination'],
        'shipper': detail['shipper'],
        'receiver': detail['receiver'],
      },
      'manifest': history.map((item) {
        final dateTime = item['date']?.split(' ') ?? ['', ''];
        return {
          'manifest_date': dateTime[0],
          'manifest_time': dateTime.length > 1 ? dateTime[1] : '',
          'manifest_description': item['desc'],
          'city_name': item['location'],
        };
      }).toList(),
    };
  }
}