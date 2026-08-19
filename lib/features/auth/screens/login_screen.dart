import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../dashboard/lineman_dashboard.dart';
import '../../dashboard/qc_dashboard.dart';
import '../../dashboard/store_dashboard.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && next.userRole != null) {
        Widget destination;
        switch (next.userRole) {
          case 'STORE':
            destination = const StoreDashboard();
            break;
          case 'PRODUCTION':
            destination = const QcDashboard();
            break;
          case 'LINEMAN':
          default:
            destination = const LinemanDashboard();
            break;
        }

        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => destination),
        );
      }
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Logo/Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.factory_rounded, size: 64, color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 32),
                Text(
                  'Nubira Floor',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlueDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure Login for Factory Operators',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: 'Enter your ID',
                          prefixIcon: Icon(Icons.badge_rounded, color: AppTheme.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock_rounded, color: AppTheme.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: authState.isLoading
                              ? null
                              : () {
                                  ref.read(authProvider.notifier).login(
                                    _usernameController.text,
                                    _passwordController.text,
                                  );
                                },
                          child: authState.isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Login to Dashboard'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

