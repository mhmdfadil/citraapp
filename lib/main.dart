import 'package:flutter/material.dart';
import 'screens/user_screen.dart'; 
import '/utils/supabase_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInit.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      title: 'Cira Cosmestic',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: UserScreen(), 
    );
  }
}