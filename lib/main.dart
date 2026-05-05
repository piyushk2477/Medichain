import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medichain_beta/screens/auth/login_screen.dart';
import 'package:medichain_beta/screens/patient/patient_dashboard.dart';
import 'package:medichain_beta/screens/patient/upload_screen.dart';
import 'package:medichain_beta/screens/patient/records_screen.dart';
import 'package:medichain_beta/screens/patient/profile_screen.dart';
import 'package:medichain_beta/screens/doctor/doctor_dashboard_screen.dart';
import 'package:medichain_beta/widgets/private_route.dart';
import 'package:medichain_beta/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pfrityglbthkyedoydos.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmcml0eWdsYnRoa3llZG95ZG9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NzY0ODUsImV4cCI6MjA5MTA1MjQ4NX0._12FVYoVV-6q6RqqYk31VJAIuj-Uv1_jzIKWIdMy9Ak',
  );

  runApp(const MedichainApp());
}

class MedichainApp extends StatelessWidget {
  const MedichainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medichain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/login': (_) => const LoginScreen(),
          '/patient/dashboard': (_) => const PrivateRoute(
                requiredRole: 'patient',
                child: PatientDashboard(),
              ),
          '/patient/upload': (_) => const PrivateRoute(
                requiredRole: 'patient',
                child: UploadScreen(),
              ),
          '/patient/records': (_) => const PrivateRoute(
                requiredRole: 'patient',
                child: RecordsScreen(),
              ),
          '/patient/profile': (_) => const PrivateRoute(
                requiredRole: 'patient',
                child: ProfileScreen(),
              ),
          '/doctor/dashboard': (_) => const PrivateRoute(
                requiredRole: 'doctor',
                child: DoctorDashboardScreen(),
              ),
        };

        final builder = routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(builder: builder, settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (mounted) {
        setState(() {
          _targetScreen = const LoginScreen();
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final role = await SupabaseService.getUserRole();
      if (!mounted) return;

      if (role == 'patient') {
        setState(() {
          _targetScreen = const PatientDashboard();
          _isLoading = false;
        });
      } else if (role == 'doctor') {
        setState(() {
          _targetScreen = const DoctorDashboardScreen();
          _isLoading = false;
        });
      } else {
        setState(() {
          _targetScreen = const LoginScreen();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _targetScreen = const LoginScreen();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _targetScreen ?? const LoginScreen();
  }
}
