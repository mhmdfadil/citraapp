import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInit {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://zruejbzikfilzlgtygfw.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpydWVqYnppa2ZpbHpsZ3R5Z2Z3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk1NTUwNjQsImV4cCI6MjA2NTEzMTA2NH0.lHVz9gThhoP4AYG5svKcV74vZMZMDvg-hAVCJPKjDak',
    );
  }
}