import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class CompanyProfileScreen extends ConsumerWidget {
  const CompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;

    final companyName = tenant?.companyName ?? 'Nubira Creation';
    final adminName = tenant?.adminDisplayName ?? 'Plant Admin';
    final adminEmail = tenant?.userEmail ?? authState.cachedUsername ?? 'admin@factory.local';
    final subscription = tenant?.subscriptionTier ?? 'FULL_PLANT_AI';
    final cityState = tenant?.cityState ?? 'India';
    final phone = tenant?.phone.isNotEmpty == true ? tenant!.phone : '+91 98765 43210';
    final operatingUnits = tenant?.allowedDivisions.length ?? 2;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Company Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Company Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(
                    child: Icon(Icons.business_rounded, color: AppTheme.steel, size: 32),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  companyName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.steelMist,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subscription,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.steel,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Primary Plant Administrator',
                  value: adminName,
                ),
                const Divider(color: AppTheme.border, height: 20),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  label: 'Registered Work Email',
                  value: adminEmail,
                ),
                const Divider(color: AppTheme.border, height: 20),
                _buildInfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Factory Contact Number',
                  value: phone,
                ),
                const Divider(color: AppTheme.border, height: 20),
                _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  label: 'Plant Location',
                  value: cityState,
                ),
                const Divider(color: AppTheme.border, height: 20),
                _buildInfoTile(
                  icon: Icons.grid_view_outlined,
                  label: 'Authorized Operating Units',
                  value: '$operatingUnits Active Divisions',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security & Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.greenMist,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.green, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Factory License Status: ACTIVE',
                        style: GoogleFonts.publicSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.green,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enterprise multi-tenant isolated database partition secured.',
                        style: GoogleFonts.publicSans(
                          fontSize: 11.5,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.steel, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.publicSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.inkFaint,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.publicSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
