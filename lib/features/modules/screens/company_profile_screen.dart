import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../widgets/workspace_hub_drawer.dart';
import '../../auth/providers/auth_provider.dart';

class CompanyProfileScreen extends ConsumerWidget {
  const CompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
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
      key: scaffoldKey,
      backgroundColor: AppTheme.canvasCream,
      drawer: const WorkspaceHubDrawer(activeRoute: '/company-profile'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => scaffoldKey.currentState?.openDrawer(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Company Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.standardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.canvasCream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.standardBorder),
                  ),
                  child: const Center(
                    child: Icon(Icons.business_rounded, color: AppTheme.brandSteel, size: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  companyName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.foregroundInk,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppTheme.canvasCream,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.standardBorder),
                  ),
                  child: Text(
                    subscription,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandSteel,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Details List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.standardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Primary Plant Administrator',
                  value: adminName,
                ),
                const Divider(color: AppTheme.subtleDivider, height: 20),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  label: 'Registered Work Email',
                  value: adminEmail,
                ),
                const Divider(color: AppTheme.subtleDivider, height: 20),
                _buildInfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Factory Contact Number',
                  value: phone,
                ),
                const Divider(color: AppTheme.subtleDivider, height: 20),
                _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  label: 'Plant Location',
                  value: cityState,
                ),
                const Divider(color: AppTheme.subtleDivider, height: 20),
                _buildInfoTile(
                  icon: Icons.grid_view_outlined,
                  label: 'Authorized Operating Units',
                  value: '$operatingUnits Active Divisions',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Security & Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.badgeEmeraldBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.badgeEmeraldBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.badgeEmeraldText, size: 22),
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
                          color: AppTheme.badgeEmeraldText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enterprise multi-tenant isolated database partition secured.',
                        style: GoogleFonts.publicSans(
                          fontSize: 11.5,
                          color: AppTheme.mutedInk,
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
        Icon(icon, color: AppTheme.brandSteel, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.faintInk,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.publicSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foregroundInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
