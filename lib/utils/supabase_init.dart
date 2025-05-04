import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInit {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://bvvgfnjbiyobjuxwnmjq.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dmdmbmpiaXlvYmp1eHdubWpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYzMzk2NTMsImV4cCI6MjA2MTkxNTY1M30.JVIrgOLJsEpDmuPtqC4Zh6p62y2xr8RlaKNDb3B-kFQ',
    );
  }
}