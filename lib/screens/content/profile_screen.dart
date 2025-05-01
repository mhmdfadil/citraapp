import 'package:flutter/material.dart';
import '/screens/user_screen.dart';


class ProfileContent extends StatelessWidget {
  const ProfileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 45),
              color: Color(0xFFF273F0),
              child: Row(
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                         'assets/images/mitra_citra.png',
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
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