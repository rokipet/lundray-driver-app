import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://auqmslopnoqjeskcejvp.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1cW1zbG9wbm9xamVza2NlanZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5MzgwNjEsImV4cCI6MjA4NjUxNDA2MX0.-Yd4UWPBc-CUdDFLjLl0X3vG11iiiQCBnwIYpAfn6VE';

const String siteUrl = 'https://lundray.com';

SupabaseClient get supabase => Supabase.instance.client;

Map<String, String> getAuthHeaders() {
  final session = supabase.auth.currentSession;
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${session?.accessToken ?? ''}',
  };
}
