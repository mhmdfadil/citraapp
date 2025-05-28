// import 'package:citraapp/screens/content/co_buy.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class RajaOngkirService {
//   static const String _baseUrl = 'https://api.rajaongkir.com/starter';
//   static const String _sandboxApiKey = 'C9tVSHobc55150227976fb1eaTcFhXyG'; // Sandbox API key
//   static const String _productionApiKey = 'YOUR_PRODUCTION_KEY'; // Add your production key

//   // Default origin address (Toko Citra Cosmetic)
//   static const Map<String, dynamic> defaultOrigin = {
//     'city_id': '1172', // ID Kota Lhokseumawe
//     'province_id': '11', // ID Provinsi Aceh
//   };

//   // Get shipping cost
//   static Future<Map<String, dynamic>> getShippingCost({
//     required String destinationCityId,
//     required int weight,
//     String courier = 'jne',
//     required bool sandboxMode,
//   }) async {
//     try {
//       final apiKey = sandboxMode ? _sandboxApiKey : _productionApiKey;
      
//       // Prepare the request body as a Map
//       final body = {
//         'origin': defaultOrigin['city_id'],
//         'destination': destinationCityId,
//         'weight': weight.toString(),
//         'courier': courier.toLowerCase(),
//       };

//       // Convert the Map to x-www-form-urlencoded format
//       final encodedBody = body.keys.map((key) => 
//         '${Uri.encodeComponent(key)}=${Uri.encodeComponent(body[key]!)}').join('&');

//       final response = await http.post(
//         Uri.parse('$_baseUrl/cost'),
//         headers: {
//           'key': apiKey,
//           'content-type': 'application/x-www-form-urlencoded',
//         },
//         body: encodedBody,
//       );


//       if (response.statusCode == 200) {
//         final result = json.decode(response.body);
//         if (result['rajaongkir']['status']['code'] == 200) {
//           return {
//             'success': true,
//             'results': result['rajaongkir']['results'],
//           };
//         } else {
//           return {
//             'success': false,
//             'message': result['rajaongkir']['status']['description'],
//             'api_error': true,
//           };
//         }
//       } else {
//         // Handle specific HTTP error codes
//         String errorMessage = 'Failed to connect to RajaOngkir API: ${response.statusCode}';
//         if (response.statusCode == 400) {
//           errorMessage = 'Bad request - please check your parameters';
//         } else if (response.statusCode == 401) {
//           errorMessage = 'Unauthorized - invalid API key';
//         } else if (response.statusCode == 404) {
//           errorMessage = 'API endpoint not found';
//         } else if (response.statusCode == 500) {
//           errorMessage = 'Server error - please try again later';
//         }

//         return {
//           'success': false,
//           'message': errorMessage,
//           'status_code': response.statusCode,
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'message': 'Network error: ${e.toString()}',
//       };
//     }
//   }

//   static getCityId(AddressData addressData) {}
// }