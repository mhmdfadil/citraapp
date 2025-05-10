import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import 'address_page.dart';

class AddressFormPage extends StatefulWidget {
  final AddressData? initialAddress;

  const AddressFormPage({super.key, this.initialAddress});

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _streetController;
  late TextEditingController _postalCodeController;
  
  String? _selectedProvince;
  String? _selectedProvinceId;
  String? _selectedCity;
  String? _selectedCityId;
  String? _selectedDistrict;
  String? _selectedDistrictId;
  String? _selectedVillage;
  String? _selectedVillageId;
  
  List<Map<String, dynamic>> provinces = [];
  List<Map<String, dynamic>> cities = [];
  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> villages = [];
  
  bool _isLoading = false;
  bool _isSaving = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialAddress?.recipientName ?? '');
    _phoneController = TextEditingController(text: widget.initialAddress?.phoneNumber ?? '');
    _streetController = TextEditingController(text: widget.initialAddress?.streetAddress ?? '');
    _postalCodeController = TextEditingController(text: widget.initialAddress?.postalCode ?? '');

     // Add listeners to all relevant controllers
  _postalCodeController.addListener(_updateFullAddress);
  _streetController.addListener(_updateFullAddress);
    
    _loadProvinces();
  }

  void _updateFullAddress() {
  if (_selectedProvince != null &&
      _selectedCity != null &&
      _selectedDistrict != null &&
      _selectedVillage != null &&
      _postalCodeController.text.isNotEmpty) {
    
    // Get the current street address
    String currentAddress = _streetController.text;
    
   // Split the address into parts if it already follows the format
List<String> addressParts = currentAddress.split(', ');

// The first part is always the street address (with null safety)
String streetPart = addressParts.isNotEmpty ? addressParts[0].trim() : currentAddress.trim();

// Hapus bagian administratif yang sudah ada (jika ada) dari streetPart
streetPart = streetPart.replaceAll(RegExp(r',\s*\|\|\|\d+.*$'), '');

// Bangun alamat lengkap dengan interpolasi string dan pemformatan yang baik
final fullAddress = 'Jln. ${_selectedVillage?.trim() ?? ''}, '
    '${_selectedDistrict?.trim() ?? ''}, '
    '${_selectedCity?.trim() ?? ''}, '
    '${_selectedProvince?.trim() ?? ''}. '
    'Kode Pos: ${_postalCodeController.text.trim()}.';

// Perbarui hanya jika alamat saat ini berbeda
if (currentAddress != fullAddress) {
  _streetController.text = fullAddress;
}

  }
}

  Future<void> _loadProvinces() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://www.emsifa.com/api-wilayah-indonesia/api/provinces.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          // Filter to only show Aceh (ID 11)
          provinces = data.where((e) => e['id'].toString() == '11')
              .map((e) => {
                'id': e['id'].toString(),
                'name': e['name'],
              }).toList();
          
          // If we have provinces, select the first one by default
          if (provinces.isNotEmpty) {
            _selectedProvince = provinces.first['name'];
            _selectedProvinceId = provinces.first['id'];
            _loadCities(_selectedProvinceId!);
          }
          
          // Handle initial address if exists
          if (widget.initialAddress != null) {
            final initialProvince = provinces.firstWhere(
              (p) => p['name'] == widget.initialAddress?.province,
              orElse: () => {'id': null, 'name': null},
            );
            
            if (initialProvince['id'] != null) {
              _selectedProvince = initialProvince['name'];
              _selectedProvinceId = initialProvince['id'];
              _loadCities(initialProvince['id']);
            }
          }
        });
      } else {
        throw Exception('Failed to load provinces: ${response.statusCode}');
      }
    } catch (e) {
     
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data provinsi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCities(String provinceId) async {
    print('Loading cities for province: $provinceId');
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://www.emsifa.com/api-wilayah-indonesia/api/regencies/$provinceId.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Received ${data.length} cities');
        setState(() {
          cities = data.map((e) => {
            'id': e['id'].toString(),
            'name': e['name'],
          }).toList();
          print('Cities list updated with ${cities.length} items');
          
          if (widget.initialAddress != null) {
            final initialCity = cities.firstWhere(
              (c) => c['name'] == widget.initialAddress?.city,
              orElse: () => {'id': null, 'name': null},
            );
            if (initialCity['id'] != null) {
              _selectedCity = initialCity['name'];
              _selectedCityId = initialCity['id'];
              print('Setting initial city: ${initialCity['name']}');
              _loadDistricts(initialCity['id']);
            }
          }
        });
      } else {
        throw Exception('Failed to load cities: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading cities: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data kota/kabupaten: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDistricts(String cityId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://www.emsifa.com/api-wilayah-indonesia/api/districts/$cityId.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          districts = data.map((e) => {
            'id': e['id'].toString(),
            'name': e['name'],
          }).toList();
          
          if (widget.initialAddress != null) {
            final initialDistrict = districts.firstWhere(
              (d) => d['name'] == widget.initialAddress?.district,
              orElse: () => {'id': null, 'name': null},
            );
            if (initialDistrict['id'] != null) {
              _selectedDistrict = initialDistrict['name'];
              _selectedDistrictId = initialDistrict['id'];
              _loadVillages(initialDistrict['id']);
            }
          }
        });
      } else {
        throw Exception('Failed to load districts: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading districts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data kecamatan: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVillages(String districtId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://www.emsifa.com/api-wilayah-indonesia/api/villages/$districtId.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          villages = data.map((e) => {
            'id': e['id'].toString(),
            'name': e['name'],
          }).toList();
          
          if (widget.initialAddress != null) {
            final initialVillage = villages.firstWhere(
              (v) => v['name'] == widget.initialAddress?.village,
              orElse: () => {'id': null, 'name': null},
            );
            if (initialVillage['name'] != null) {
              _selectedVillage = initialVillage['name'];
              _selectedVillageId = initialVillage['id'];
            }
          }
          _updateFullAddress();
        });
      } else {
        throw Exception('Failed to load villages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading villages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data desa/kelurahan: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null || _selectedCity == null || 
        _selectedDistrict == null || _selectedVillage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data alamat')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final addressData = {
        'user_id': userId,
        'recipient_name': _nameController.text,
        'phone_number': _phoneController.text,
        'province': _selectedProvince,
        'city': _selectedCity,
        'district': _selectedDistrict,
        'village': _selectedVillage,
        'postal_code': _postalCodeController.text,
        'street_address': _streetController.text,
        'is_primary': widget.initialAddress?.isPrimary ?? false,
      };

      if (widget.initialAddress == null) {
        await _supabase.from('addresses').insert(addressData);
      } else {
        await _supabase.from('addresses')
          .update(addressData)
          .eq('id', widget.initialAddress!.id);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat berhasil disimpan')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error saving address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan alamat: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialAddress == null ? 'Tambah Alamat' : 'Edit Alamat'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Penerima',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Masukkan nama penerima';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Handphone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Masukkan nomor handphone';
                        }
                        if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                          return 'Masukkan nomor yang valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedProvince,
                      decoration: const InputDecoration(
                        labelText: 'Provinsi',
                        border: OutlineInputBorder(),
                      ),
                      items: provinces.map((province) {
                        return DropdownMenuItem<String>(
                          value: province['name'],
                          child: Text(province['name']),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedProvince = value;
                          _selectedProvinceId = provinces.firstWhere(
                            (p) => p['name'] == value,
                            orElse: () => {'id': null},
                          )['id'];
                          _selectedCity = null;
                          _selectedDistrict = null;
                          _selectedVillage = null;
                          cities = [];
                          districts = [];
                          villages = [];
                        });
                        if (_selectedProvinceId != null) {
                          _loadCities(_selectedProvinceId!);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCity,
                      decoration: const InputDecoration(
                        labelText: 'Kabupaten/Kota',
                        border: OutlineInputBorder(),
                      ),
                      items: cities.map((city) {
                        return DropdownMenuItem<String>(
                          value: city['name'],
                          child: Text(city['name']),
                        );
                      }).toList(),
                      onChanged: cities.isEmpty 
                          ? null  // Disable if no cities
                          : (String? value) {
                              setState(() {
                                _selectedCity = value;
                                _selectedCityId = cities.firstWhere(
                                  (c) => c['name'] == value,
                                  orElse: () => {'id': null},
                                )['id'];
                                _selectedDistrict = null;
                                _selectedVillage = null;
                                districts = [];
                                villages = [];
                              });
                              if (_selectedCityId != null) {
                                _loadDistricts(_selectedCityId!);
                              }
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Pilih kabupaten/kota';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedDistrict,
                      decoration: const InputDecoration(
                        labelText: 'Kecamatan',
                        border: OutlineInputBorder(),
                      ),
                      items: districts.map((district) {
                        return DropdownMenuItem<String>(
                          value: district['name'],
                          child: Text(district['name']),
                        );
                      }).toList(),
                      onChanged: districts.isEmpty
                          ? null
                          : (String? value) {
                              setState(() {
                                _selectedDistrict = value;
                                _selectedDistrictId = districts.firstWhere(
                                  (d) => d['name'] == value,
                                  orElse: () => {'id': null},
                                )['id'];
                                _selectedVillage = null;
                                villages = [];
                              });
                              if (_selectedDistrictId != null) {
                                _loadVillages(_selectedDistrictId!);
                              }
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Pilih kecamatan';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedVillage,
                      decoration: const InputDecoration(
                        labelText: 'Desa/Kelurahan',
                        border: OutlineInputBorder(),
                      ),
                      items: villages.map((village) {
                        return DropdownMenuItem<String>(
                          value: village['name'],
                          child: Text(village['name']),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedVillage = value;
                          _selectedVillageId = villages.firstWhere(
                            (v) => v['name'] == value,
                            orElse: () => {'id': null},
                          )['id'];
                        });
                        _updateFullAddress();
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Pilih desa/kelurahan';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Kode Pos',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Masukkan kode pos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Lengkap (Jalan, Nomor Rumah, dll)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Masukkan alamat lengkap';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveAddress,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : const Text('Simpan Alamat'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
void dispose() {
  _postalCodeController.removeListener(_updateFullAddress);
  _streetController.removeListener(_updateFullAddress);
  _nameController.dispose();
  _phoneController.dispose();
  _streetController.dispose();
  _postalCodeController.dispose();
  super.dispose();
}
}