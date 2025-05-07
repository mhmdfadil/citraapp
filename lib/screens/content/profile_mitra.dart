import 'package:flutter/material.dart';
import '/screens/user_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ProfileMitraPage extends StatefulWidget {
  const ProfileMitraPage({super.key});

  @override
  State<ProfileMitraPage> createState() => _ProfileMitraPageState();
}

class _ProfileMitraPageState extends State<ProfileMitraPage> {
  // Coordinates for CITRA KOSMETIK using latlong
  final LatLng citraKosmetikLocation = const LatLng(5.2185628, 97.0507196);
  final MapController _mapController = MapController();
  bool _showMarkerInfo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 45),
              color: const Color(0xFFF273F0),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        'Profil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 400, // Increased height
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  center: citraKosmetikLocation,
                                  zoom: 15.0,
                                  interactiveFlags: InteractiveFlag.all, // Enable all interactions
                                  onTap: (_, __) {
                                    setState(() {
                                      _showMarkerInfo = false;
                                    });
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: citraKosmetikLocation,
                                        width: 80,
                                        height: 80,
                                        builder: (ctx) => GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _showMarkerInfo = true;
                                            });
                                          },
                                          child: const Icon(
                                            Icons.location_pin,
                                            color: Colors.red,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (_showMarkerInfo)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showMarkerInfo = false;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Citra Kosmetik',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          const Text(
                                            'Lokasi toko kosmetik',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.directions),
                                                onPressed: () {
                                                  // Open in maps app
                                                  // You can use url_launcher package for this
                                                },
                                              ),
                                              const Text('Buka di Maps'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Toko Citra Cosmetik',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Dibuat oleh kelompok 6 yang beranggotakan 5 orang sebagai berikut :\n\n'
                          'Ketua Kelompok : M. Fredyansyah Siregar\n'
                          'Anggota Kelompok : Alwi Hasyimi\n'
                          'Ramzy Shah\n'
                          'Wijayati Putri\n'
                          'Ariati',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1a1a1a),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom navigation
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserScreen()),
                );
              },
              child: Container(
                child: const Column(
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 90,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Kembali Ke Beranda',
                      style: TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}