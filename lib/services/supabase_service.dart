import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    // Step 1 — create auth user
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );

    // Step 2 — ensure session is active
    if (client.auth.currentUser == null) {
      try {
        await client.auth.signInWithPassword(
            email: email, password: password);
      } catch (_) {
        throw Exception(
            'Account created! Please confirm your email then sign in.');
      }
    }

    // Step 3 — guarantee profiles row exists
    // IMPORTANT: email is NOT NULL in profiles table — must be included
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      await client.from('profiles').upsert(
        {
          'id':        uid,
          'email':     email,     // ← required, NOT NULL column
          'full_name': fullName,
          'role':      role,
        },
        onConflict: 'id',
      );
    }

    return response;
  }

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
        email: email, password: password);
  }

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

  static Future<void> signOut() async => client.auth.signOut();

  static bool get isLoggedIn => client.auth.currentUser != null;
  static User? get currentUser => client.auth.currentUser;

  static Future<void> saveWalletAddress(String walletAddress) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await client
        .from('profiles')
        .update({'wallet_address': walletAddress})
        .eq('id', user.id);
  }

  static Future<String?> getDoctorWalletAddress(String doctorId) async {
    final doctor = await client
        .from('doctors')
        .select('profile_id')
        .eq('id', doctorId)
        .maybeSingle();
    if (doctor == null) return null;
    final profile = await client
        .from('profiles')
        .select('wallet_address')
        .eq('id', doctor['profile_id'] as String)
        .maybeSingle();
    return profile?['wallet_address'] as String?;
  }
}