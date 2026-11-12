import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../../core/widgets/zigza_section_header.dart';
import '../widgets/workspace_hub_drawer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../main.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _companyProfile;
  bool _isLoadingCompany = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCompanyProfile();
    });
  }

  Future<void> _fetchCompanyProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingCompany = true);

    try {
      final tenant = ref.read(authProvider).tenantProfile;
      final companyName = tenant?.companyName ?? 'Nubira Creation';

      dynamic res;
      try {
        res = await supabase
            .from('company_profile')
            .select('*')
            .ilike('company_name', companyName)
            .limit(1)
            .maybeSingle();
      } catch (_) {}

      if (res == null && (companyName.isEmpty || companyName.toLowerCase().contains('nubira'))) {
        try {
          res = await supabase
              .from('company_profile')
              .select('*')
              .eq('id', 'default')
              .maybeSingle();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _companyProfile = res;
          _isLoadingCompany = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCompany = false);
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(authProvider.notifier).refreshProfile();
    await _fetchCompanyProfile();
  }

  String _formatDate(String? isoString, {String format = 'd MMM yyyy', String fallback = 'Active Cycle'}) {
    if (isoString == null || isoString.isEmpty) return fallback;
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat(format).format(dt);
    } catch (_) {
      return fallback;
    }
  }

  // -------------------------------------------------------------
  // MODAL 1: Edit Factory Identity Info
  // -------------------------------------------------------------
  void _showEditFactoryModal(
    BuildContext context,
    String initialCompany,
    String initialAddress,
    String initialGstin,
    String initialPhone,
    String initialEmail,
  ) {
    final companyController = TextEditingController(text: initialCompany);
    final addressController = TextEditingController(
        text: initialAddress == 'Address not configured' ? '' : initialAddress);
    final gstinController = TextEditingController(
        text: initialGstin == 'Not configured' ? '' : initialGstin);
    final phoneController = TextEditingController(
        text: initialPhone == 'Not configured' ? '' : initialPhone);
    final emailController = TextEditingController(
        text: initialEmail == 'Not configured' ? '' : initialEmail);

    bool isSubmitting = false;
    String? modalError;

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
                    // Modal Header
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
                                border: Border.all(color: const Color(0x3314C8B4)),
                              ),
                              child: const Icon(Icons.apartment_rounded, color: Color(0xFF0B1220), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Edit Factory Information',
                              style: zigzaHeadingStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (modalError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Text(
                          modalError!,
                          style: zigzaBodyStyle(fontSize: 12, color: const Color(0xFFE11D48), fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Company Name
                    Text('Company / Unit Name *', style: zigzaBodyStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: companyController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Factory or Company Name',
                        hintStyle: zigzaBodyStyle(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),

                    // Factory Address
                    Text('Factory Address', style: zigzaBodyStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Factory premises, plot no, street, city...',
                        hintStyle: zigzaBodyStyle(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.headingObsidian),
                    ),
                    const SizedBox(height: 12),

                    // GSTIN
                    Text('GSTIN / Tax ID', style: zigzaBodyStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: gstinController,
                      decoration: InputDecoration(
                        hintText: 'e.g. 19AADCO1064C1ZK',
                        hintStyle: zigzaBodyStyle(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),

                    // Direct Contact Phone
                    Text('Direct Helpline / Phone', style: zigzaBodyStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        hintText: '+91 98765 43210',
                        hintStyle: zigzaBodyStyle(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),

                    // Official Email
                    Text('Official Contact Email', style: zigzaBodyStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'admin@company.com',
                        hintStyle: zigzaBodyStyle(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),

                    // Save Button
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final compName = companyController.text.trim();
                                if (compName.isEmpty) {
                                  setModalState(() => modalError = 'Company name is required');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  modalError = null;
                                });

                                try {
                                  final isNubira = compName.toLowerCase().contains('nubira');
                                  final targetId = _companyProfile?['id'] ?? (isNubira ? 'default' : 'comp_${DateTime.now().millisecondsSinceEpoch}');

                                  await supabase.from('company_profile').upsert({
                                    'id': targetId,
                                    'company_name': compName,
                                    'factory_address': addressController.text.trim(),
                                    'gstin': gstinController.text.trim(),
                                    'contact_phone': phoneController.text.trim(),
                                    'contact_email': emailController.text.trim(),
                                    'updated_at': DateTime.now().toIso8601String(),
                                  });

                                  // Sync phone to platform_tenant_factories if matching tenant
                                  final tenant = ref.read(authProvider).tenantProfile;
                                  if (tenant?.userEmail != null && phoneController.text.trim().isNotEmpty) {
                                    try {
                                      await supabase
                                          .from('platform_tenant_factories')
                                          .update({'phone': phoneController.text.trim()})
                                          .ilike('admin_email', tenant!.userEmail);
                                    } catch (_) {}
                                  }

                                  await _fetchCompanyProfile();
                                  if (ctx.mounted) Navigator.pop(ctx);

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF047857),
                                        content: Text(
                                          'Factory information successfully updated!',
                                          style: zigzaBodyStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    modalError = 'Failed to save changes: ${e.toString()}';
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Save Changes', style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // MODAL 2: Renew / Upgrade Subscription
  // -------------------------------------------------------------
  void _showRenewModal(BuildContext context, String companyName, String tier, double monthlyInr, String userEmail) {
    int selectedDuration = 1;
    final basePrice = monthlyInr > 0 ? monthlyInr.toInt() : (tier == 'FULL_PLANT_AI' ? 4999 : 1999);
    bool isActivating = false;
    String? modalError;

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
                              border: Border.all(color: const Color(0x3314C8B4)),
                            ),
                            child: const Icon(Icons.credit_card_rounded, color: Color(0xFF0B1220), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Renew Subscription',
                            style: zigzaHeadingStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: isActivating ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (modalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        modalError!,
                        style: zigzaBodyStyle(fontSize: 12, color: const Color(0xFFE11D48), fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    'Select subscription validity period for $companyName:',
                    style: zigzaBodyStyle(fontSize: 12.5, color: const Color(0xFF64748B)),
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
                          sub: 'Save 10%',
                          isSelected: selectedDuration == 3,
                          onTap: () => setModalState(() => selectedDuration = 3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDurationOption(
                          label: '1 Year',
                          sub: '2 Mos Free',
                          isSelected: selectedDuration == 12,
                          onTap: () => setModalState(() => selectedDuration = 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

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
                          style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                        Text(
                          '₹${NumberFormat('#,##,###').format(totalAmount)}',
                          style: zigzaHeadingStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isActivating
                          ? null
                          : () async {
                              setModalState(() {
                                isActivating = true;
                                modalError = null;
                              });

                              try {
                                final daysToAdd = selectedDuration * 30;
                                final newExpiresAt = DateTime.now().add(Duration(days: daysToAdd)).toIso8601String();
                                final monthlyRate = tier == 'MODULAR' ? 1999 : (tier == 'FULL_PLANT_AI' ? 4999 : 9999);

                                // Live update platform_tenant_factories
                                await supabase
                                    .from('platform_tenant_factories')
                                    .update({
                                      'access_type': 'FULL_ACCESS',
                                      'subscription_tier': tier,
                                      'monthly_billing_inr': monthlyRate,
                                      'status': 'ACTIVE',
                                      'expires_at': newExpiresAt,
                                      'revoked_at': null,
                                      'last_active_at': DateTime.now().toIso8601String(),
                                    })
                                    .ilike('admin_email', userEmail);

                                // Audit log
                                try {
                                  await supabase.from('platform_audit_logs').insert({
                                    'log_code': 'SUB-UPG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                    'actor': userEmail,
                                    'action': 'Tenant Subscription Activated / Renewed',
                                    'category': 'CONFIG_CHANGE',
                                    'details': '$companyName activated $tier for $selectedDuration month(s). New expiry: ${DateFormat('d MMM yyyy').format(DateTime.parse(newExpiresAt))}',
                                    'ip_address': '127.0.0.1',
                                    'location': 'India',
                                    'status': 'SUCCESS',
                                  });
                                } catch (_) {}

                                await ref.read(authProvider.notifier).refreshProfile();
                                if (ctx.mounted) Navigator.pop(ctx);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF047857),
                                      content: Text(
                                        'License activated! Valid until ${DateFormat('d MMM yyyy').format(DateTime.parse(newExpiresAt))}',
                                        style: zigzaBodyStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isActivating = false;
                                  modalError = 'Activation failed: ${e.toString()}';
                                });
                              }
                            },
                      child: isActivating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Confirm & Activate License', style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 8),
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
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
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
              style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: zigzaBodyStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MODAL 3: Decommission Account Request
  // -------------------------------------------------------------
  void _showDeleteAccountModal(BuildContext context, String companyName, String userEmail, String adminName, String adminPhone) {
    final confirmController = TextEditingController();
    final reasonController = TextEditingController();
    final phoneController = TextEditingController(text: adminPhone);

    bool isConfirmed = false;
    bool isSubmitting = false;
    String? modalError;

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
                              style: zigzaHeadingStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (modalError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Text(
                          modalError!,
                          style: zigzaBodyStyle(fontSize: 12, color: const Color(0xFFE11D48), fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(
                        'Target Mail: support@zigza.in\nDecommissioning request will be officially registered with our administrative desk to verify credentials and archive records.',
                        style: zigzaBodyStyle(fontSize: 11.5, color: const Color(0xFF9F1239), height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('Contact Phone (for verification):', style: zigzaBodyStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        hintText: '+91 98765 43210',
                        hintStyle: zigzaBodyStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),

                    Text('Reason for Decommissioning (Optional):', style: zigzaBodyStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Unit closure or factory relocation...',
                        hintStyle: zigzaBodyStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: zigzaBodyStyle(fontSize: 12, color: AppTheme.headingObsidian),
                    ),
                    const SizedBox(height: 10),

                    Text('Type "DELETE" to confirm:', style: zigzaBodyStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: confirmController,
                      onChanged: (val) {
                        setModalState(() {
                          isConfirmed = val.trim().toUpperCase() == 'DELETE';
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'DELETE',
                        hintStyle: zigzaHeadingStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConfirmed ? const Color(0xFFE11D48) : const Color(0xFFCBD5E1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isConfirmed && !isSubmitting
                            ? () async {
                                setModalState(() {
                                  isSubmitting = true;
                                  modalError = null;
                                });

                                try {
                                  await supabase.from('account_deletion_requests').insert({
                                    'company_name': companyName,
                                    'admin_name': adminName,
                                    'email': userEmail,
                                    'phone': phoneController.text.trim(),
                                    'reason': reasonController.text.trim().isNotEmpty
                                        ? reasonController.text.trim()
                                        : 'Admin initiated account deletion from Mobile App',
                                    'status': 'PENDING',
                                  });

                                  if (ctx.mounted) Navigator.pop(ctx);

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFFE11D48),
                                        content: Text(
                                          'Deletion request dispatched to support@zigza.in',
                                          style: zigzaBodyStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    modalError = 'Submission failed: ${e.toString()}';
                                  });
                                }
                              }
                            : null,
                        icon: isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.delete_outline_rounded, size: 18),
                        label: Text(
                          isSubmitting ? 'Submitting...' : 'Submit Decommission Request',
                          style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
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
    Color? statusColor,
  }) {
    final effectiveStatusColor = statusColor ?? const Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x3314C8B4)),
            ),
            child: Icon(icon, color: const Color(0xFF0B1220), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: zigzaBodyStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.faintInk,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                if (isStatus)
                  Row(
                    children: [
                      Container(
                        width: 7.5,
                        height: 7.5,
                        decoration: BoxDecoration(
                          color: effectiveStatusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: zigzaHeadingStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: effectiveStatusColor,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    title,
                    style: zigzaHeadingStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: titleColor ?? const Color(0xFF0B1220),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 1),
                Text(
                  subtext,
                  style: zigzaBodyStyle(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
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

    // Dynamically resolved values from Supabase company_profile & tenant
    final companyName = (_companyProfile?['company_name'] as String?)?.trim().isNotEmpty == true
        ? (_companyProfile!['company_name'] as String).trim()
        : (tenant?.companyName.isNotEmpty == true ? tenant!.companyName : 'Nubira Creation').trim();

    final factoryAddress = (_companyProfile?['factory_address'] as String?)?.trim().isNotEmpty == true
        ? (_companyProfile!['factory_address'] as String).trim()
        : 'Address not configured';

    final gstin = (_companyProfile?['gstin'] as String?)?.trim().isNotEmpty == true
        ? (_companyProfile!['gstin'] as String).trim()
        : 'Not configured';

    final contactPhone = (_companyProfile?['contact_phone'] as String?)?.trim().isNotEmpty == true
        ? (_companyProfile!['contact_phone'] as String).trim()
        : (tenant?.phone.isNotEmpty == true ? tenant!.phone : '');

    final contactEmail = (_companyProfile?['contact_email'] as String?)?.trim().isNotEmpty == true
        ? (_companyProfile!['contact_email'] as String).trim()
        : (tenant?.userEmail.isNotEmpty == true ? tenant!.userEmail : '');

    final adminName = (_companyProfile?['admin_display_name'] as String?)?.trim().isNotEmpty == true
        ? (_companyProfile!['admin_display_name'] as String).trim()
        : (tenant?.adminDisplayName.isNotEmpty == true ? tenant!.adminDisplayName : 'Enterprise Owner').trim();

    final adminEmail = (tenant?.userEmail.isNotEmpty == true
        ? tenant!.userEmail
        : (authState.cachedUsername ?? 'admin@company.com')).trim();

    final adminPhone = contactPhone.isNotEmpty
        ? contactPhone
        : (tenant?.phone.isNotEmpty == true ? tenant!.phone : 'Not configured');

    final subscriptionTier = tenant?.subscriptionTier ?? 'FULL_PLANT_AI';
    final monthlyInr = tenant?.monthlyBillingInr ?? 4999;
    final isSuperAdmin = tenant?.isSuperAdmin ?? true;
    final isTrial = tenant?.accessType == 'DEMO_TRIAL';

    // Comprehensive expiration and days-left evaluation exactly matching web
    final baseProvisioned = tenant?.provisionedAt != null ? DateTime.tryParse(tenant!.provisionedAt) : null;
    final baseTime = baseProvisioned ?? DateTime(2026, 9, 15);
    final effectiveExpiry = tenant?.expiresAt != null ? DateTime.tryParse(tenant!.expiresAt!) : null;
    final effectiveExpiresAt = effectiveExpiry ?? (isTrial ? baseTime.add(const Duration(days: 7)) : baseTime.add(const Duration(days: 30)));
    final now = DateTime.now();
    final daysLeft = effectiveExpiresAt.difference(now).inDays;

    final isAccountExpired = tenant?.isActuallyExpired == true ||
        tenant?.isExpired == true ||
        now.isAfter(effectiveExpiresAt) ||
        tenant?.tenantStatus == 'SUSPENDED' ||
        tenant?.tenantStatus == 'EXPIRED' ||
        (isTrial && daysLeft <= 0);

    final isExpiringSoon = !isAccountExpired && isTrial && daysLeft <= 3;

    final tierDisplay = subscriptionTier == 'FULL_PLANT_AI'
        ? 'Full Plant AI (12 Div)'
        : (subscriptionTier == 'MODULAR' ? 'Modular Plan' : 'Enterprise Custom');

    final startDateStr = _formatDate(tenant?.provisionedAt, format: 'd MMM yyyy', fallback: '15 Sept 2026');
    final validUntilStr = _formatDate(effectiveExpiresAt.toIso8601String(), format: 'd MMM yyyy', fallback: isTrial ? '7-Day Trial' : 'Active Cycle');
    final memberSinceStr = _formatDate(tenant?.provisionedAt, format: 'MMM yyyy', fallback: 'Sep 2026');

    final initials = (adminName.length >= 2 ? adminName.substring(0, 2) : (companyName.length >= 2 ? companyName.substring(0, 2) : 'EA')).toUpperCase();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const WorkspaceHubDrawer(activeRoute: '/company-profile'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1D4ED8),
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // 1. Page Header Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x3314C8B4)),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Color(0xFF0B1220), size: 20),
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
                                style: zigzaHeadingStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                              ),
                              TextSpan(
                                text: 'Settings',
                                style: zigzaHeadingStyle(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1D4ED8), letterSpacing: -0.3),
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
                                color: AppTheme.mintSurface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0x3314C8B4)),
                              ),
                              child: Text(
                                companyName.toUpperCase(),
                                style: zigzaHeadingStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.3),
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
                                isSuperAdmin ? 'OWNER' : (tenant?.role.toUpperCase() == 'ADMIN' ? 'MANAGER' : (tenant?.role.toUpperCase() ?? 'STAFF')),
                                style: zigzaHeadingStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF047857), letterSpacing: 0.3),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isAccountExpired ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDFA),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isAccountExpired ? const Color(0xFFFECDD3) : const Color(0x3314C8B4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isAccountExpired
                                          ? const Color(0xFFE11D48)
                                          : (isExpiringSoon ? const Color(0xFFD97706) : const Color(0xFF10B981)),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAccountExpired
                                        ? 'Expired'
                                        : (isTrial ? '$daysLeft Days Trial' : 'Active'),
                                    style: zigzaHeadingStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: isAccountExpired ? const Color(0xFFE11D48) : const Color(0xFF0B1220),
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
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Factory Profile & Registration Card (Organization Identity - All Web Fields)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZigzaSectionHeader(
                    icon: Icons.apartment_rounded,
                    title: 'Factory',
                    accent: 'Identity',
                    badge: 'ACTIVE',
                    action: InkWell(
                      onTap: () => _showEditFactoryModal(context, companyName, factoryAddress, gstin, contactPhone, contactEmail),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x3314C8B4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF0B1220)),
                            const SizedBox(width: 4),
                            Text('Edit', style: zigzaHeadingStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Factory Address
                  _buildParameterCard(
                    icon: Icons.location_on_outlined,
                    label: 'FACTORY ADDRESS',
                    title: factoryAddress,
                    subtext: 'Primary Production Facility',
                  ),
                  const SizedBox(height: 8),

                  // GSTIN
                  _buildParameterCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'GSTIN / TAX ID',
                    title: gstin,
                    subtext: 'Registered Corporate Identifier',
                  ),
                  const SizedBox(height: 8),

                  // Helpline (Always visible as on Web)
                  _buildParameterCard(
                    icon: Icons.support_agent_outlined,
                    label: 'FACILITY HELPLINE',
                    title: contactPhone.isNotEmpty ? contactPhone : 'Not configured',
                    subtext: 'Direct Inward Floor Desk',
                  ),
                  const SizedBox(height: 8),

                  // Official Email (Always visible as on Web & screenshot)
                  _buildParameterCard(
                    icon: Icons.mail_outline_rounded,
                    label: 'OFFICIAL EMAIL',
                    title: contactEmail.isNotEmpty ? contactEmail : adminEmail,
                    subtext: 'Corporate Dispatch & Inward Mail',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Active Subscription & License Status Card (Matching Screenshot exactly!)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Expired / Warning Red Banner (Displayed when isAccountExpired is true)
                  if (isAccountExpired)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: Color(0xFFFECDD3))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE4E6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE11D48), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Evaluation / Subscription Expired',
                                      style: zigzaHeadingStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF9F1239),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Access to operational manufacturing divisions is paused. Please renew or upgrade to continue.',
                                      style: zigzaBodyStyle(
                                        fontSize: 11.5,
                                        color: const Color(0xFFBE123C),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 38,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: () => _showRenewModal(context, companyName, subscriptionTier, monthlyInr, adminEmail),
                              child: Text(
                                'Pay Now',
                                style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ZigzaSectionHeader(
                          icon: Icons.credit_card_rounded,
                          title: 'Subscription &',
                          accent: 'License',
                          badge: isAccountExpired
                              ? 'EXPIRED'
                              : (isTrial ? '7-DAY TRIAL' : 'ACTIVE PLAN'),
                          badgeColor: isAccountExpired ? const Color(0xFFFFF1F2) : null,
                          badgeTextColor: isAccountExpired ? const Color(0xFFE11D48) : null,
                          badgeBorderColor: isAccountExpired ? const Color(0xFFFECDD3) : null,
                        ),
                        const SizedBox(height: 10),

                        // Renew Subscription Button
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () => _showRenewModal(context, companyName, subscriptionTier, monthlyInr, adminEmail),
                            child: Text(
                              isTrial ? 'Activate Subscription' : 'Renew Subscription',
                              style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 4 Parameter Cards (Full-width stacked exactly like screenshot)
                        _buildParameterCard(
                          icon: Icons.credit_card_rounded,
                          label: 'PLAN TIER',
                          title: tierDisplay,
                          subtext: '₹${NumberFormat('#,##,###').format(monthlyInr.toInt())}/month',
                        ),
                        const SizedBox(height: 8),

                        _buildParameterCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'START DATE',
                          title: startDateStr,
                          subtext: 'Account Initialized',
                        ),
                        const SizedBox(height: 8),

                        _buildParameterCard(
                          icon: Icons.access_time_rounded,
                          label: 'VALID UNTIL',
                          title: validUntilStr,
                          titleColor: isAccountExpired ? const Color(0xFFE11D48) : null,
                          subtext: isTrial ? '7-Day Evaluation' : 'Active Cycle',
                        ),
                        const SizedBox(height: 8),

                        _buildParameterCard(
                          icon: Icons.verified_user_outlined,
                          label: 'ACCOUNT STATUS',
                          title: isAccountExpired
                              ? 'Expired (Locked)'
                              : (isExpiringSoon
                                  ? '$daysLeft ${daysLeft == 1 ? 'Day' : 'Days'} Left'
                                  : (isTrial ? '$daysLeft Days Trial Left' : 'Active')),
                          subtext: isAccountExpired ? 'Renewal Required' : 'All Divisions Active',
                          isStatus: true,
                          statusColor: isAccountExpired
                              ? const Color(0xFFE11D48)
                              : (isExpiringSoon ? const Color(0xFFD97706) : const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Executive Administrator Credentials Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZigzaSectionHeader(
                    icon: Icons.shield_outlined,
                    title: 'Executive',
                    accent: 'Credentials',
                    badge: isSuperAdmin ? 'OWNER' : 'ADMIN',
                  ),
                  const SizedBox(height: 10),

                  // Avatar & Admin summary box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1220),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: zigzaHeadingStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(adminName, style: zigzaHeadingStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text('Primary Master Account Holder', style: zigzaBodyStyle(fontSize: 11, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 3 Parameters
                  _buildParameterCard(
                    icon: Icons.mail_outline_rounded,
                    label: 'PRIMARY LOGIN EMAIL',
                    title: adminEmail,
                    subtext: 'Root Authentication',
                  ),
                  const SizedBox(height: 8),
                  _buildParameterCard(
                    icon: Icons.phone_outlined,
                    label: 'DIRECT MOBILE NUMBER',
                    title: adminPhone,
                    subtext: 'Verified OTP Contact',
                  ),
                  const SizedBox(height: 8),
                  _buildParameterCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'ACCOUNT ESTABLISHED',
                    title: memberSinceStr,
                    subtext: 'Registration Date',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 5. Danger Zone: Account Decommission Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZigzaSectionHeader(
                    icon: Icons.warning_amber_rounded,
                    title: 'Danger Zone:',
                    accent: 'Decommission',
                    badge: 'IRREVERSIBLE',
                    iconColor: const Color(0xFFE11D48),
                    iconBgColor: const Color(0xFFFFF1F2),
                    accentColor: const Color(0xFFE11D48),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: zigzaBodyStyle(fontSize: 12, color: const Color(0xFF475569), height: 1.4),
                            children: [
                              const TextSpan(text: 'Submit an official decommission request to '),
                              TextSpan(
                                text: 'support@zigza.in',
                                style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(text: ' to securely archive records and close this company account.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Request Deletion Button
                        SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: () => _showDeleteAccountModal(context, companyName, adminEmail, adminName, adminPhone),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: Text(
                              'Request Account Deletion',
                              style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
