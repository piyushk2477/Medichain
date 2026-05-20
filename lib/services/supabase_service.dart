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

  // ── Wallet helpers ─────────────────────────────────────────────────────────

  /// Persist [walletAddress] into the `profiles.wallet_address` column for
  /// the currently logged-in user.
  ///
  /// Call this once after generating the wallet on signup (and again if the
  /// user ever regenerates their wallet).
  static Future<void> saveWalletAddress(String walletAddress) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    await client
        .from('profiles')
        .update({'wallet_address': walletAddress})
        .eq('id', user.id);
  }

  /// Fetch the wallet address for a doctor identified by their `doctors.id`
  /// (the UUID in the `doctors` table, NOT the auth user ID).
  ///
  /// Returns `null` if the doctor has no wallet yet.
  static Future<String?> getDoctorWalletAddress(String doctorId) async {
    // doctors.profile_id  →  profiles.id  →  profiles.wallet_address
    final doctor = await client
        .from('doctors')
        .select('profile_id')
        .eq('id', doctorId)
        .maybeSingle();

    if (doctor == null) return null;
    final profileId = doctor['profile_id'] as String;

    final profile = await client
        .from('profiles')
        .select('wallet_address')
        .eq('id', profileId)
        .maybeSingle();

    return profile?['wallet_address'] as String?;
  }
}
