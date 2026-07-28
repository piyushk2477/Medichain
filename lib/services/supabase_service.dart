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

    // Step 2 — ensure session is active (auto-sign in after signup)
    if (client.auth.currentUser == null) {
      await client.auth.signInWithPassword(
          email: email, password: password);
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
    final response = await client.auth.signInWithPassword(
        email: email, password: password);

    // Sync profile: ensure current user ID has a profiles row
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      // Check if a profile with this email already has wallet data
      final existing = await client
          .from('profiles')
          .select('wallet_address, private_key, full_name, role')
          .eq('email', email)
          .not('private_key', 'is', null)
          .limit(1)
          .maybeSingle();

      await client.from('profiles').upsert(
        {
          'id': uid,
          'email': email,
          if (existing != null) ...{
            'wallet_address': existing['wallet_address'],
            'private_key': existing['private_key'],
            'full_name': existing['full_name'],
            'role': existing['role'],
          },
        },
        onConflict: 'id',
      );
    }

    return response;
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

  static Future<void> saveWalletData({
    required String walletAddress,
    required String privateKey,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    await client
        .from('profiles')
        .update({
          'wallet_address': walletAddress,
          'private_key': privateKey,
        })
        .eq('id', user.id);

    if (user.email != null) {
      await client
          .from('profiles')
          .update({
            'wallet_address': walletAddress,
            'private_key': privateKey,
          })
          .eq('email', user.email!);
    }
  }

  static Future<void> saveWalletAddress(String walletAddress) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await client
        .from('profiles')
        .update({'wallet_address': walletAddress})
        .eq('id', user.id);
  }

  static Future<Map<String, String?>?> getWalletData() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    // Try current user ID first
    var profile = await client
        .from('profiles')
        .select('wallet_address, private_key')
        .eq('id', user.id)
        .maybeSingle();

    if (profile != null &&
        profile['private_key'] != null &&
        (profile['private_key'] as String).isNotEmpty) {
      return {
        'wallet_address': profile['wallet_address'] as String?,
        'private_key': profile['private_key'] as String?,
      };
    }

    // Fallback: check by email
    if (user.email != null) {
      profile = await client
          .from('profiles')
          .select('wallet_address, private_key')
          .eq('email', user.email!)
          .not('private_key', 'is', null)
          .limit(1)
          .maybeSingle();
      if (profile != null) {
        return {
          'wallet_address': profile['wallet_address'] as String?,
          'private_key': profile['private_key'] as String?,
        };
      }
    }

    return null;
  }

  static Future<String?> getDoctorWalletAddress(String doctorId) async {
    final doctor = await client
        .from('doctors')
        .select('profile_id')
        .eq('id', doctorId)
        .maybeSingle();
    if (doctor == null) return null;

    // Try by profile_id first
    final profile = await client
        .from('profiles')
        .select('wallet_address')
        .eq('id', doctor['profile_id'] as String)
        .maybeSingle();
    final addr = profile?['wallet_address'] as String?;
    if (addr != null && addr.isNotEmpty) return addr;

    // Fallback: look up doctor's email from profiles, then find
    // any profile row with that email that has a wallet
    final profileWithEmail = await client
        .from('profiles')
        .select('email')
        .eq('id', doctor['profile_id'] as String)
        .maybeSingle();
    if (profileWithEmail == null) return null;
    final email = profileWithEmail['email'] as String?;
    if (email == null || email.isEmpty) return null;

    final byEmail = await client
        .from('profiles')
        .select('wallet_address')
        .eq('email', email)
        .not('wallet_address', 'is', null)
        .limit(1)
        .maybeSingle();
    return byEmail?['wallet_address'] as String?;
  }

  /// Reverse-lookup: given a wallet address, find the doctor's info.
  /// Returns `{id, name, specialization, wallet}` or `null`.
  static Future<Map<String, dynamic>?> getDoctorByWallet(
      String walletAddress) async {
    // Direct query — profiles stores wallet_address
    final profile = await client
        .from('profiles')
        .select('id, full_name, role')
        .eq('wallet_address', walletAddress)
        .maybeSingle();

    if (profile == null) return null;

    final profileId = profile['id'] as String;

    // Find linked doctor row
    final doctor = await client
        .from('doctors')
        .select('id, name, specialization, hospital_name')
        .eq('profile_id', profileId)
        .maybeSingle();

    if (doctor != null) {
      return {
        ...doctor,
        'wallet': walletAddress,
      };
    }

    // Fallback: return profile info
    return {
      'id': profileId,
      'name': profile['full_name'] ?? 'Unknown',
      'specialization': null,
      'wallet': walletAddress,
    };
  }
}