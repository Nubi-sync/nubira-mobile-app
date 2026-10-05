import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../widgets/workspace_hub_drawer.dart';
import '../../auth/providers/auth_provider.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _formatDate(String? isoString, {String format = 'd MMM yyyy', String fallback = 'Active Cycle'}) {
    if (isoString == null || isoString.isEmpty) return fallback;
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat(format).format(dt);
    } catch (_) {
      return fallback;
    }
  }

  void _showRenewModal(BuildContext context, String companyName, String tier, double monthlyInr) {
    int selectedDuration = 1;
    final basePrice = monthlyInr > 0 ? monthlyInr.toInt() : (tier == 'FULL_PLANT_AI' ? 4999 : 1999);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final totalAmount = selectedDuration == 12
                ? basePrice * 10
                : (selectedDuration == 3 ? (basePrice * 3 * 0.9).round() : basePrice * selectedDuration);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x26000000)),
                            ),
                            child: const Icon(Icons.credit_card_rounded, color: Color(0xFF0B1220), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Renew Subscription',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Select subscription duration for $companyName:',
                    style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  // Duration Options
                  Row(
                    children: [
                      Expanded(
                        child: _buildDurationOption(
                          label: '1 Month',
                          sub: 'Standard',
                          isSelected: selectedDuration == 1,
                          onTap: () => setModalState(() => selectedDuration = 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDurationOption(
                          label: '3 Months',
                          sub: '10% Off',
                          isSelected: selectedDuration == 3,
                          onTap: () => setModalState(() => selectedDuration = 3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDurationOption(
                          label: '12 Months',
                          sub: '2 Mos Free',
                          isSelected: selectedDuration == 12,
                          onTap: () => setModalState(() => selectedDuration = 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Payable Amount:',
                          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                        Text(
                          '₹${NumberFormat('#,##,###').format(totalAmount)}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0B1220)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF047857),
                          content: Text(
                            'Subscription renewal request recorded for $companyName!',
                            style: GoogleFonts.publicSans(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Confirm & Proceed to Payment',
                      style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDurationOption({
    required String label,
    required String sub,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF14C8B4) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0B1220),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountModal(BuildContext context, String companyName, String userEmail, String adminName, String adminPhone) {
    final confirmController = TextEditingController();
    final reasonController = TextEditingController();
    bool isConfirmed = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECDD3)),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Request Account Deletion',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0B1220),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        'Target Mail: support@zigza.in\nDecommissioning request will be officially registered with our administrative desk to archive records.',
                        style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF9F1239), height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Reason for Decommissioning:',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Closing manufacturing unit...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      style: GoogleFonts.publicSans(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Type "DELETE" to confirm:',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmController,
                      onChanged: (val) {
                        setModalState(() {
                          isConfirmed = val.trim().toUpperCase() == 'DELETE';
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'DELETE',
                        hintStyle: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConfirmed ? const Color(0xFFE11D48) : const Color(0xFFCBD5E1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                      onPressed: isConfirmed
                          ? () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFFE11D48),
                                  content: Text(
                                    'Account deletion request forwarded to support@zigza.in',
                                    style: GoogleFonts.publicSans(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(
                        'Submit Decommission Request',
                        style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParameterCard({
    required IconData icon,
    required String label,
    required String title,
    required String subtext,
    Color? titleColor,
    bool isStatus = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x26000000)),
            ),
            child: Icon(icon, color: const Color(0xFF0B1220), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                if (isStatus)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor ?? const Color(0xFF0B1220),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenantProfile;

    final companyName = (tenant?.companyName.isNotEmpty == true ? tenant!.companyName : 'Nubira Creation').trim();
    final adminName = (tenant?.adminDisplayName.isNotEmpty == true ? tenant!.adminDisplayName : 'AJ').trim();
    final adminEmail = (tenant?.userEmail.isNotEmpty == true ? tenant!.userEmail : (authState.cachedUsername ?? 'aj@nubiracreation.com')).trim();
    final adminPhone = (tenant?.phone.isNotEmpty == true ? tenant!.phone : '+91 85839 87997').trim();
    final subscriptionTier = tenant?.subscriptionTier ?? 'FULL_PLANT_AI';
    final monthlyInr = tenant?.monthlyBillingInr ?? 1999;
    final isSuperAdmin = tenant?.isSuperAdmin ?? true;
    final isTrial = tenant?.accessType == 'DEMO_TRIAL';

    final tierDisplay = subscriptionTier == 'FULL_PLANT_AI'
        ? 'Full Plant AI (12 Div)'
        : (subscriptionTier == 'MODULAR' ? 'Modular Plan' : 'Enterprise Custom');

    final startDateStr = _formatDate(tenant?.provisionedAt, format: 'd MMM yyyy', fallback: '19 Sept 2026');
    final validUntilStr = _formatDate(tenant?.expiresAt, format: 'd MMM yyyy', fallback: '14 Sept 2027');
    final memberSinceStr = _formatDate(tenant?.provisionedAt, format: 'MMM yyyy', fallback: 'Sep 2026');

    final initials = (adminName.length >= 2 ? adminName.substring(0, 2) : (companyName.length >= 2 ? companyName.substring(0, 2) : 'AJ')).toUpperCase();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const WorkspaceHubDrawer(activeRoute: '/company-profile'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: Colors.white),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 16, color: Color(0xFF0F766E)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF0F766E)),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Page Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x26000000)),
                      ),
                      child: const Icon(Icons.apartment_rounded, color: Color(0xFF0B1220), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Company Profile & ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B1220),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Settings',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1D4ED8),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDFA),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0x26000000)),
                                ),
                                child: Text(
                                  companyName.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0B1220),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Text(
                                  isSuperAdmin ? 'ENTERPRISE MASTER' : (tenant?.role.toUpperCase() ?? 'PLANT ADMIN'),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF047857),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Factory organization identity, master admin credentials, and live multi-division subscription entitlement.',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Active Subscription & License Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x26000000)),
                      ),
                      child: const Icon(Icons.credit_card_rounded, color: Color(0xFF0B1220), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Active Subscription &\n',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B1220),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                TextSpan(
                                  text: 'License Status',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1D4ED8),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              isTrial ? '7-DAY TRIAL' : 'ACTIVE PLAN',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0B1220),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'License entitlement, validity cycle, and operational module coverage for $companyName',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Renew Subscription Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _showRenewModal(context, companyName, subscriptionTier, monthlyInr),
                    child: Text(
                      isTrial ? 'Activate Subscription' : 'Renew Subscription',
                      style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4 Parameter Cards
                _buildParameterCard(
                  icon: Icons.credit_card_rounded,
                  label: 'PLAN TIER',
                  title: tierDisplay,
                  subtext: '₹${NumberFormat('#,##,###').format(monthlyInr.toInt())}/month',
                ),
                const SizedBox(height: 10),
                _buildParameterCard(
                  icon: Icons.calendar_today_rounded,
                  label: 'START DATE',
                  title: startDateStr,
                  subtext: 'Account Initialized',
                ),
                const SizedBox(height: 10),
                _buildParameterCard(
                  icon: Icons.access_time_rounded,
                  label: 'VALID UNTIL',
                  title: validUntilStr,
                  subtext: isTrial ? '7-Day Evaluation' : 'Active Cycle',
                ),
                const SizedBox(height: 10),
                _buildParameterCard(
                  icon: Icons.verified_user_outlined,
                  label: 'ACCOUNT STATUS',
                  title: 'Active',
                  subtext: 'All Divisions Active',
                  isStatus: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Executive Administrator Credentials Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                adminName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0B1220),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDFA),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF0B1220)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'SUPER ADMIN',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0B1220),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Primary factory administrator credentials and master root account holder',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3 Parameters
                _buildParameterCard(
                  icon: Icons.mail_outline_rounded,
                  label: 'PRIMARY LOGIN EMAIL',
                  title: adminEmail,
                  subtext: 'Root Authentication',
                ),
                const SizedBox(height: 10),
                _buildParameterCard(
                  icon: Icons.phone_outlined,
                  label: 'DIRECT MOBILE NUMBER',
                  title: adminPhone,
                  subtext: 'Verified OTP Contact',
                ),
                const SizedBox(height: 10),
                _buildParameterCard(
                  icon: Icons.calendar_today_rounded,
                  label: 'ACCOUNT ESTABLISHED',
                  title: memberSinceStr,
                  subtext: 'Registration Date',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Danger Zone: Account Decommission Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Danger Zone: ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B1220),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Account Decommission',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE11D48),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Text(
                              'IRREVERSIBLE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFBE123C),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Need to decommission or close this company account? Submit an official deletion request. Our administration desk at ',
                                ),
                                TextSpan(
                                  text: 'support@zigza.in',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0B1220),
                                  ),
                                ),
                                const TextSpan(
                                  text: ' will verify your company credentials and securely archive all production records.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Request Deletion Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _showDeleteAccountModal(context, companyName, adminEmail, adminName, adminPhone),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      'Request Account Deletion',
                      style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
