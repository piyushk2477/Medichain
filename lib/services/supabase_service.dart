import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // Sign up with email, password, full name, and role
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
      },
    );
    return response;
  }

  // Login with email and password
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  // Get current user's role from profiles table
  static Future<String?> getUserRole() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final data = await client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

    return data['role'] as String?;
  }

  // Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Check if user is logged in
  static bool get isLoggedIn => client.auth.currentUser != null;

  // Get current user
  static User? get currentUser => client.auth.currentUser;
}
