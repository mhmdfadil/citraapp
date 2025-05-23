import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'login.dart'; // Import halaman Login

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _hpController = TextEditingController();
  
  // Inisialisasi Supabase client
  final supabase = Supabase.instance.client;

  void _showSuccessNotification(BuildContext context) {
    OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 42,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Registration Successful',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    Future.delayed(Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  void _showErrorNotification(BuildContext context, String message) {
    OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 42,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  message,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    Future.delayed(Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  // Function to hash password using SHA-256
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Function to check if username exists
  Future<bool> _isUsernameAvailable(String username) async {
    final response = await supabase
        .from('users')
        .select()
        .eq('username', username)
        .maybeSingle();

    return response == null;
  }

  Future<void> _register(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      try {
        // Check if username is available
        final isAvailable = await _isUsernameAvailable(_usernameController.text);
        if (!isAvailable) {
          _showErrorNotification(context, 'Username already exists');
          return;
        }

        // Hash the password
        final hashedPassword = _hashPassword(_passwordController.text);

        // Insert data to users table
        await supabase.from('users').insert({
          'username': _usernameController.text,
          'password': hashedPassword,
          'roles': 'User',
          'no_hp': _hpController.text,
          'created_at': DateTime.now().toIso8601String(),
        });

        _showSuccessNotification(context);

        // Navigasi ke halaman Login setelah registrasi berhasil
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        });
      } catch (e) {
        _showErrorNotification(context, 'Registration failed: ${e.toString()}');
      }
    }
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset('assets/images/logo.png', width: 350, height: 280),
                ),
                SizedBox(height: 30),
                Text(
                  'Register',
                  style: TextStyle(
                    fontSize: 23,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Please Register to login',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _usernameController,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person, color: Colors.black),
                    filled: true,
                    fillColor: Color(0xFFD9D9D9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  validator: (value) => value!.isEmpty ? 'Username cannot be empty' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _hpController,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone, color: Colors.black), // Ganti icon ke phone
                    filled: true,
                    fillColor: Color(0xFFD9D9D9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  keyboardType: TextInputType.phone, // Ganti ke phone untuk nomor HP
                  validator: (value) {
                    if (value!.isEmpty) return 'Mobile number cannot be empty';
                    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'Only numbers allowed';
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: Colors.black),
                    filled: true,
                    fillColor: Color(0xFFD9D9D9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return 'Password cannot be empty';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                
                SizedBox(height: 38),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _register(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF273F0),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Sign up', style: TextStyle(fontSize: 16)),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => _navigateToLogin(context),
                    child: Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        children: [
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _hpController.dispose();
    super.dispose();
  }
}