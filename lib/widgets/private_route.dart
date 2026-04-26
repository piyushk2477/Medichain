import 'package:flutter/material.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:medichain_beta/screens/auth/login_screen.dart';

class PrivateRoute extends StatelessWidget {
  final Widget child;
  final String requiredRole;

  const PrivateRoute({
    super.key,
    required this.child,
    required this.requiredRole,
  });

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isLoggedIn) {
      return const LoginScreen();
    }

    return FutureBuilder<String?>(
      future: SupabaseService.getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != requiredRole) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Access Denied', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 8),
                  const Text('You do not have permission to access this page.'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
