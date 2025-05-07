import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddressProvider with ChangeNotifier {
  final SupabaseClient _supabase;
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = false;

  AddressProvider(this._supabase);

  List<Map<String, dynamic>> get addresses => _addresses;
  bool get isLoading => _isLoading;

  Future<void> loadAddresses(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _addresses = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading addresses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAddress(Map<String, dynamic> addressData) async {
    try {
      await _supabase.from('addresses').insert(addressData);
      // Data akan diupdate via realtime subscription
    } catch (e) {
      print('Error adding address: $e');
      rethrow;
    }
  }

  Future<void> updateAddress(int id, Map<String, dynamic> addressData) async {
    try {
      await _supabase
          .from('addresses')
          .update(addressData)
          .eq('id', id);
      // Data akan diupdate via realtime subscription
    } catch (e) {
      print('Error updating address: $e');
      rethrow;
    }
  }

  void setupRealtimeUpdates(String userId) {
    // Setup realtime subscription
    _supabase
        .from('addresses')
        .on(SupabaseEventTypes.all, (payload) {
          // Reload addresses when there's any change
          loadAddresses(userId);
        })
        .subscribe();
  }
}

extension on SupabaseQueryBuilder {
  on(SupabaseEventTypes all, Null Function(dynamic payload) param1) {}
}