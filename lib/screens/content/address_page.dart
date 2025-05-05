import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'address_form_page.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final _supabase = Supabase.instance.client;
  List<AddressData> _addresses = [];
  bool _isLoading = true;
  String? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null) return;

      final response = await _supabase
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _addresses = (response as List)
            .map((e) => AddressData.fromJson(e))
            .toList();
        
        // Find the selected address
        final defaultAddress = _addresses.firstWhere(
          (addr) => addr.isPrimary,
          orElse: () => _addresses.isNotEmpty ? _addresses.first : AddressData.empty(),
        );
        _selectedAddressId = defaultAddress.id;
      });
    } catch (e) {
      print('Error loading addresses: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat alamat: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setPrimaryAddress(String addressId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null) return;

      // Reset all primary flags
      await _supabase
          .from('addresses')
          .update({'is_primary': false})
          .eq('user_id', userId);

      // Set new primary address
      await _supabase
          .from('addresses')
          .update({'is_primary': true})
          .eq('id', addressId);

      await _loadAddresses();
    } catch (e) {
      print('Error setting primary address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengatur alamat utama: $e')),
      );
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      await _supabase
          .from('addresses')
          .delete()
          .eq('id', addressId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat berhasil dihapus')),
      );
      
      await _loadAddresses();
    } catch (e) {
      print('Error deleting address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus alamat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Alamat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddressFormPage(),
                ),
              );
              await _loadAddresses();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Belum ada alamat tersimpan'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddressFormPage(),
                            ),
                          );
                          await _loadAddresses();
                        },
                        child: const Text('Buat Alamat Baru'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    return AddressCard(
                      address: address,
                      isSelected: address.id == _selectedAddressId,
                      onSelect: () => _setPrimaryAddress(address.id),
                      onEdit: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddressFormPage(
                              initialAddress: address,
                            ),
                          ),
                        );
                        await _loadAddresses();
                      },
                      onDelete: () => _deleteAddress(address.id),
                    );
                  },
                ),
    );
  }
}

class AddressCard extends StatelessWidget {
  final AddressData address;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AddressCard({
    super.key,
    required this.address,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.recipientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isSelected)
                  const Chip(
                    label: Text('Utama'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 3),
           Text('Telp. ${address.phoneNumber}'),
            const SizedBox(height: 3),
            Text(
              '${address.streetAddress}',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSelect,
                    child: Text(isSelected ? 'Dipilih' : 'Pilih sebagai utama'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddressData {
  final String id;
  final String recipientName;
  final String phoneNumber;
  final String province;
  final String city;
  final String district;
  final String village;
  final String postalCode;
  final String streetAddress;
  final bool isPrimary;

  AddressData({
    required this.id,
    required this.recipientName,
    required this.phoneNumber,
    required this.province,
    required this.city,
    required this.district,
    required this.village,
    required this.postalCode,
    required this.streetAddress,
    required this.isPrimary,
  });

  factory AddressData.fromJson(Map<String, dynamic> json) {
    return AddressData(
      id: json['id'].toString(),
      recipientName: json['recipient_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      province: json['province'] ?? '',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      village: json['village'] ?? '',
      postalCode: json['postal_code'] ?? '00000',
      streetAddress: json['street_address'] ?? '',
      isPrimary: json['is_primary'] ?? false,
    );
  }

  static AddressData empty() {
    return AddressData(
      id: '',
      recipientName: '',
      phoneNumber: '',
      province: '',
      city: '',
      district: '',
      village: '',
      postalCode: '',
      streetAddress: '',
      isPrimary: false,
    );
  }
}