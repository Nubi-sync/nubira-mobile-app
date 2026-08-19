import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/screens/login_screen.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://nnhzqvdmkarpwtkzjnra.supabase.co',
    publishableKey: 'sb_publishable_WRZgkU7XhqbK3HSGRFMfDQ_o2JLnTMF',
  );

  runApp(
    const ProviderScope(
      child: NubiraApp(),
    ),
  );
}

// Global Supabase client
final supabase = Supabase.instance.client;

class NubiraApp extends StatelessWidget {
  const NubiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nubira Mobile',
      theme: AppTheme.lightTheme,
      home: const LoginScreen(), // We will update this to check auth state next
      debugShowCheckedModeBanner: false,
    );
  }
}
