import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../../core/widgets/zigza_section_header.dart';
import '../widgets/workspace_hub_drawer.dart';
import 'appoint_department_head_screen.dart';
import '../services/supervisor_workers_service.dart';

class DepartmentHeadsScreen extends ConsumerStatefulWidget {
  const DepartmentHeadsScreen({super.key});

  @override
  ConsumerState<DepartmentHeadsScreen> createState() => _DepartmentHeadsScreenState();
}

class _DepartmentHeadsScreenState extends ConsumerState<DepartmentHeadsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Set<String> _expandedRoutes = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: zigzaHeadingStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.headingObsidian,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatPhone(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('+')) return clean;
    return '+91 $clean';
  }

  Future<void> _openAppointHeadSheet() async {
    final state = ref.read(supervisorWorkersProvider);
    final result = await AppointDepartmentHeadScreen.show(
      context,
      companyName: state.companyName,
      allowedDivisions: state.divisions.map((d) => d.route).toList(),
    );
    if (!mounted) return;
    if (result == true) {
      ref.read(supervisorWorkersProvider.notifier).fetchData();
      _showToast('Department Head appointed successfully');
    }
  }

  void _showResetPasswordDialog(String name, String phone) {
    final TextEditingController newPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.mintSurface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppTheme.badgeMintBorder),
              ),
              child: const Icon(Icons.key_rounded, color: Color(0xFF0F766E), size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: zigzaHeadingStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                  children: [
                    const TextSpan(text: 'Reset '),
                    TextSpan(
                      text: 'Password',
                      style: zigzaHeadingStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandRoyalBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a new login password for $name (+91 $phone):',
              style: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.bodyInk, height: 1.4),
            ),
            const SizedBox(height: 14),
            Text(
              'NEW PASSWORD *',
              style: zigzaBodyStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedInk,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              style: zigzaBodyStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian),
              decoration: InputDecoration(
                hintText: 'Enter new password (min 6 chars)',
                hintStyle: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.faintInk),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.faintInk),
                filled: true,
                fillColor: AppTheme.bgCanvas,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.brandRoyalBlue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.bodyInk)),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPassCtrl.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters')),
                );
                return;
              }
              Navigator.pop(ctx);
              _showToast('Password updated for $name');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandRoyalBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            child: Text('Save Password', style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(String id, String name, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.badgeRoseBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppTheme.badgeRoseBorder),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppTheme.badgeRoseText, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Remove Member',
                style: zigzaHeadingStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove access for $name? This action cannot be undone.',
          style: zigzaBodyStyle(fontSize: 13, color: AppTheme.bodyInk, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.bodyInk)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(supervisorWorkersProvider.notifier).deleteStaff(id, type);
              if (ok) {
                _showToast('$name removed successfully');
              } else {
                _showToast('Failed to remove $name');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.badgeRoseText,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            child: Text('Remove Access', style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddWorkerModal(String departmentRoute, String departmentName) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController roleCtrl = TextEditingController(text: departmentRoute == '/cutting' ? 'Knife Cutter' : 'Tailor');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Modal Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.badgeMintBorder),
                      ),
                      child: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF0F766E), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  'ADD WORKER',
                                  style: zigzaBodyStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.brandRoyalBlue,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  departmentName,
                                  style: zigzaBodyStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.mutedInk,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          RichText(
                            text: TextSpan(
                              style: zigzaHeadingStyle(fontSize: 17, fontWeight: FontWeight.w800),
                              children: [
                                const TextSpan(text: 'Register '),
                                TextSpan(
                                  text: 'Floor Worker',
                                  style: zigzaHeadingStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.brandRoyalBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.mutedInk),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderLight),

              // Form Fields
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'WORKER FULL NAME *',
                      style: zigzaBodyStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mutedInk,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: zigzaBodyStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian),
                      decoration: InputDecoration(
                        hintText: 'e.g. Ramesh Kumar',
                        hintStyle: zigzaBodyStyle(fontSize: 13, color: AppTheme.faintInk),
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.faintInk),
                        filled: true,
                        fillColor: AppTheme.bgCanvas,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.brandRoyalBlue, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'MOBILE NUMBER *',
                      style: zigzaBodyStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mutedInk,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCanvas,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🇮🇳', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 5),
                              Text(
                                '+91',
                                style: zigzaHeadingStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.headingObsidian,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.headingObsidian),
                            decoration: InputDecoration(
                              hintText: '98765 43210',
                              hintStyle: zigzaBodyStyle(fontSize: 13, color: AppTheme.faintInk),
                              prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: AppTheme.faintInk),
                              filled: true,
                              fillColor: AppTheme.bgCanvas,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.brandRoyalBlue, width: 1.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'DESIGNATION / SKILL ROLE',
                      style: zigzaBodyStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mutedInk,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: roleCtrl,
                      style: zigzaBodyStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.headingObsidian),
                      decoration: InputDecoration(
                        hintText: 'e.g. Master Tailor, Overlock Operator',
                        hintStyle: zigzaBodyStyle(fontSize: 13, color: AppTheme.faintInk),
                        prefixIcon: const Icon(Icons.work_outline_rounded, size: 18, color: AppTheme.faintInk),
                        filled: true,
                        fillColor: AppTheme.bgCanvas,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.brandRoyalBlue, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: zigzaBodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.mutedInk),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              Navigator.pop(ctx);
                              final ok = await ref.read(supervisorWorkersProvider.notifier).addWorker(
                                    name: nameCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim(),
                                    departmentRoute: departmentRoute,
                                    role: roleCtrl.text.trim(),
                                  );
                              if (ok) {
                                _showToast('Worker ${nameCtrl.text.trim()} added to $departmentName');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandRoyalBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 46),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Add Worker to Roster',
                              style: zigzaHeadingStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white),
                            ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorWorkersProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgCanvas,
      drawer: const WorkspaceHubDrawer(activeRoute: '/access-control'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onAppointHead: _openAppointHeadSheet,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.headingObsidian))
          : RefreshIndicator(
              color: AppTheme.brandRoyalBlue,
              backgroundColor: Colors.white,
              onRefresh: () => ref.read(supervisorWorkersProvider.notifier).fetchData(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                children: [
                  // 1. Header Card
                  _buildHeaderCard(context, state),
                  const SizedBox(height: 14),

                  // 2. Factory Leadership Section Card (Owner + Production Manager)
                  _buildLeadershipSectionCard(state),
                  const SizedBox(height: 14),

                  // 3. Factory Departments Section Card (Screenshot 1 header-inside-card)
                  _buildDepartmentsSection(state),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }

  // 1. Header Card with Live Search
  Widget _buildHeaderCard(BuildContext context, SupervisorWorkersState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: const Center(
                  child: Icon(Icons.verified_user_outlined, color: Color(0xFF0F766E), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: zigzaHeadingStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        children: const [
                          TextSpan(text: 'Supervisor & '),
                          TextSpan(
                            text: 'Workers',
                            style: TextStyle(color: AppTheme.brandRoyalBlue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.badgeMintBorder),
                      ),
                      child: Text(
                        '${state.divisions.length} Departments',
                        style: zigzaHeadingStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            style: zigzaBodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.headingObsidian,
            ),
            decoration: InputDecoration(
              hintText: 'Search departments or staff...',
              hintStyle: zigzaBodyStyle(fontSize: 12.5, color: AppTheme.faintInk),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.faintInk, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: AppTheme.bodyInk),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.bgCanvas,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.headingObsidian, width: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Factory Leadership Section Card (Screenshot 1 box wrapping Owner + PM)
  Widget _buildLeadershipSectionCard(SupervisorWorkersState state) {
    final pm = state.productionManagers.isNotEmpty ? state.productionManagers.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZigzaSectionHeader(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Factory',
            accent: 'Leadership',
            badge: pm != null ? 'Owner & PM' : 'Owner',
          ),
          const SizedBox(height: 12),

          // Owner Inset Card
          _buildOwnerInsetCard(state),
          const SizedBox(height: 10),

          // Production Manager Inset Card
          _buildProductionManagerInsetCard(state, pm),
        ],
      ),
    );
  }

  // 2A. Owner Inset Card
  Widget _buildOwnerInsetCard(SupervisorWorkersState state) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.mintSurface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppTheme.badgeMintBorder),
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded, color: Color(0xFF0F766E), size: 20),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          state.ownerName,
                          style: zigzaHeadingStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '(Company Owner)',
                          style: zigzaBodyStyle(
                            fontSize: 12,
                            color: AppTheme.bodyInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (state.ownerEmail.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.mail_outline_rounded, size: 13, color: AppTheme.faintInk),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              state.ownerEmail,
                              style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (state.ownerPhone.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppTheme.faintInk),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatPhone(state.ownerPhone),
                              style: zigzaHeadingStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.headingObsidian,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.badgeEmeraldBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.badgeEmeraldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.badgeEmeraldText, size: 14),
                const SizedBox(width: 5),
                Text(
                  'Full Factory Authority',
                  style: zigzaHeadingStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.badgeEmeraldText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2B. Production Manager Inset Card
  Widget _buildProductionManagerInsetCard(SupervisorWorkersState state, ProductionManagerItem? pm) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: pm != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppTheme.badgeMintBorder),
                      ),
                      child: const Center(
                        child: Icon(Icons.factory_outlined, color: Color(0xFF0F766E), size: 20),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                pm.name,
                                style: zigzaHeadingStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '(Production Manager)',
                                style: zigzaBodyStyle(
                                  fontSize: 12,
                                  color: AppTheme.bodyInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: pm.isActive ? AppTheme.badgeEmeraldBg : AppTheme.badgeRoseBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pm.isActive ? AppTheme.badgeEmeraldBorder : AppTheme.badgeRoseBorder),
                            ),
                            child: Text(
                              pm.isActive ? '• Active' : '• Inactive',
                              style: zigzaHeadingStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: pm.isActive ? AppTheme.badgeEmeraldText : AppTheme.badgeRoseText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 13, color: AppTheme.faintInk),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatPhone(pm.phone),
                                  style: zigzaHeadingStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.headingObsidian,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showResetPasswordDialog(pm.name, pm.phone),
                        icon: const Icon(Icons.key_rounded, size: 14, color: AppTheme.headingObsidian),
                        label: Text(
                          'Reset Password',
                          style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.borderLight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        final ok = await ref.read(supervisorWorkersProvider.notifier).toggleStaffStatus(pm.id, 'PRODUCTION_MANAGER', pm.isActive);
                        if (ok) {
                          _showToast('Status updated to ${pm.isActive ? 'Inactive' : 'Active'}');
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Icon(
                          pm.isActive ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                          size: 18,
                          color: AppTheme.bodyInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showDeleteConfirmDialog(pm.id, pm.name, 'PRODUCTION_MANAGER'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.badgeRoseBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.badgeRoseBorder),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppTheme.badgeRoseText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Production Manager',
                        style: zigzaHeadingStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No Production Manager appointed yet',
                        style: zigzaBodyStyle(fontSize: 12, color: AppTheme.bodyInk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await AppointDepartmentHeadScreen.show(
                      context,
                      companyName: state.companyName,
                    );
                    if (result == true) {
                      ref.read(supervisorWorkersProvider.notifier).fetchData();
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: Text('Appoint PM', style: zigzaHeadingStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandRoyalBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ],
            ),
    );
  }

  // 3. Factory Departments Section Card (Screenshot 1 box wrapping header, controls, & list)
  Widget _buildDepartmentsSection(SupervisorWorkersState state) {
    final query = _searchQuery.toLowerCase();
    final filteredDivisions = state.divisions.where((div) {
      if (query.isEmpty) return true;
      final nameMatch = div.name.toLowerCase().contains(query);
      final headMatch = state.departmentHeads.any((h) => h.allowedModules.contains(div.route) && (h.displayName.toLowerCase().contains(query) || h.phone.contains(query)));
      final workerMatch = state.workers.any((w) => w.departmentRoute == div.route && (w.name.toLowerCase().contains(query) || w.phone.contains(query)));
      return nameMatch || headMatch || workerMatch;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZigzaSectionHeader(
            icon: Icons.layers_outlined,
            title: 'Factory',
            accent: 'Departments',
            badge: '${filteredDivisions.length}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _expandedRoutes.addAll(state.divisions.map((d) => d.route));
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.headingObsidian,
                    side: const BorderSide(color: AppTheme.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                  child: Text(
                    'Expand All',
                    style: zigzaBodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.headingObsidian),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _expandedRoutes.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.headingObsidian,
                    side: const BorderSide(color: AppTheme.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                  child: Text(
                    'Collapse All',
                    style: zigzaBodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.headingObsidian),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (filteredDivisions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.bgCanvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  const Icon(Icons.people_outline_rounded, size: 36, color: AppTheme.faintInk),
                  const SizedBox(height: 8),
                  Text(
                    'No Matching Departments',
                    style: zigzaHeadingStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No department, head, or worker matches "$_searchQuery".',
                    textAlign: TextAlign.center,
                    style: zigzaBodyStyle(fontSize: 12, color: AppTheme.bodyInk),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandRoyalBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Text('Clear Filter', style: zigzaHeadingStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: filteredDivisions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final div = filteredDivisions[index];
                final isExpanded = _expandedRoutes.contains(div.route);
                final headsForDiv = state.departmentHeads.where((h) => h.allowedModules.contains(div.route)).toList();
                final workersForDiv = state.workers.where((w) => w.departmentRoute == div.route).toList();
                final head = headsForDiv.isNotEmpty ? headsForDiv.first : null;

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCanvas,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isExpanded ? AppTheme.brandRoyalBlue.withValues(alpha: 0.45) : AppTheme.borderLight,
                      width: isExpanded ? 1.3 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Clickable Header Row
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedRoutes.remove(div.route);
                            } else {
                              _expandedRoutes.add(div.route);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppTheme.mintSurface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.badgeMintBorder),
                                    ),
                                    child: Center(
                                      child: _getDivisionIcon(div.iconName),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          div.name,
                                          style: zigzaHeadingStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          div.defaultDesignation,
                                          style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.bodyInk),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.borderLight),
                                    ),
                                    child: Text(
                                      '${workersForDiv.length} ${workersForDiv.length == 1 ? 'Worker' : 'Workers'}',
                                      style: zigzaHeadingStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.headingObsidian,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    color: AppTheme.bodyInk,
                                    size: 21,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'IN-CHARGE: ',
                                      style: zigzaBodyStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.faintInk,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (head != null) ...[
                                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.brandMint, shape: BoxShape.circle)),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          children: [
                                            Text(
                                              head.displayName,
                                              style: zigzaHeadingStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (head.phone.isNotEmpty)
                                              Text(
                                                _formatPhone(head.phone),
                                                style: zigzaHeadingStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.bodyInk,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'Not Assigned',
                                        style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.faintInk),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Expanded Roster Details (Single-surface clean drawer with hairline list dividers)
                      if (isExpanded) ...[
                        const Divider(height: 1, color: AppTheme.borderLight),
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sub-Section A: Department In-Charge
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Department In-Charge (${headsForDiv.length})',
                                            style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            final result = await AppointDepartmentHeadScreen.show(
                                              context,
                                              companyName: state.companyName,
                                              existingHead: head,
                                              allowedDivisions: [div.route],
                                            );
                                            if (result == true) {
                                              ref.read(supervisorWorkersProvider.notifier).fetchData();
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.add_rounded, size: 15, color: AppTheme.brandRoyalBlue),
                                                const SizedBox(width: 2),
                                                Text(
                                                  head != null ? 'Edit Details' : 'Assign Head',
                                                  style: zigzaHeadingStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.brandRoyalBlue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (headsForDiv.isEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgCanvas,
                                          borderRadius: BorderRadius.circular(11),
                                          border: Border.all(color: AppTheme.borderLight),
                                        ),
                                        child: Text(
                                          'No department head appointed for ${div.name}.',
                                          textAlign: TextAlign.center,
                                          style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.mutedInk),
                                        ),
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgCanvas,
                                          borderRadius: BorderRadius.circular(11),
                                          border: Border.all(color: AppTheme.borderLight),
                                        ),
                                        child: Column(
                                          children: [
                                            for (int i = 0; i < headsForDiv.length; i++) ...[
                                              if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            headsForDiv[i].displayName,
                                                            style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            headsForDiv[i].designation,
                                                            style: zigzaBodyStyle(
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppTheme.bodyInk,
                                                            ),
                                                          ),
                                                          if (headsForDiv[i].phone.isNotEmpty) ...[
                                                            const SizedBox(height: 4),
                                                            Row(
                                                              children: [
                                                                const Icon(Icons.phone_outlined, size: 13, color: AppTheme.faintInk),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  '+91 ${headsForDiv[i].phone}',
                                                                  style: zigzaHeadingStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: AppTheme.headingObsidian,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                          if (headsForDiv[i].phone2 != null && headsForDiv[i].phone2!.isNotEmpty) ...[
                                                            const SizedBox(height: 2),
                                                            Row(
                                                              children: [
                                                                const Icon(Icons.phone_outlined, size: 13, color: AppTheme.faintInk),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  headsForDiv[i].phone2!.startsWith('+')
                                                                      ? headsForDiv[i].phone2!
                                                                      : '+91 ${headsForDiv[i].phone2}',
                                                                  style: zigzaHeadingStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: AppTheme.headingObsidian,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    InkWell(
                                                      onTap: () => _showResetPasswordDialog(headsForDiv[i].displayName, headsForDiv[i].phone),
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: AppTheme.borderLight),
                                                        ),
                                                        child: const Icon(Icons.key_rounded, size: 15, color: AppTheme.brandRoyalBlue),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    InkWell(
                                                      onTap: () => _showDeleteConfirmDialog(headsForDiv[i].id, headsForDiv[i].displayName, 'DEPARTMENT_HEAD'),
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: AppTheme.badgeRoseBorder),
                                                        ),
                                                        child: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.badgeRoseText),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const Divider(height: 1, color: AppTheme.borderLight),

                              // Sub-Section B: Floor Workers Roster
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Floor Workers Roster (${workersForDiv.length})',
                                            style: zigzaHeadingStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _showAddWorkerModal(div.route, div.name),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.add_rounded, size: 15, color: AppTheme.brandRoyalBlue),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'Add Worker',
                                                  style: zigzaHeadingStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.brandRoyalBlue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (workersForDiv.isEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgCanvas,
                                          borderRadius: BorderRadius.circular(11),
                                          border: Border.all(color: AppTheme.borderLight),
                                        ),
                                        child: Text(
                                          'No floor workers registered under ${div.name}.',
                                          textAlign: TextAlign.center,
                                          style: zigzaBodyStyle(fontSize: 11.5, color: AppTheme.mutedInk),
                                        ),
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgCanvas,
                                          borderRadius: BorderRadius.circular(11),
                                          border: Border.all(color: AppTheme.borderLight),
                                        ),
                                        child: Column(
                                          children: [
                                            for (int i = 0; i < workersForDiv.length; i++) ...[
                                              if (i > 0) const Divider(height: 1, color: AppTheme.borderLight),
                                              Builder(
                                                builder: (context) {
                                                  final w = workersForDiv[i];
                                                  final isWorkerActive = w.status.toUpperCase() != 'INACTIVE';
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                w.name,
                                                                style: zigzaHeadingStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                                                              ),
                                                            ),
                                                            if (!isWorkerActive) ...[
                                                              const SizedBox(width: 8),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme.badgeRoseBg,
                                                                  borderRadius: BorderRadius.circular(999),
                                                                  border: Border.all(
                                                                    color: AppTheme.badgeRoseBorder,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  '• Inactive',
                                                                  style: zigzaHeadingStyle(
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: AppTheme.badgeRoseText,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        if (w.role.isNotEmpty || w.shift.isNotEmpty) ...[
                                                          const SizedBox(height: 2.5),
                                                          Text(
                                                            w.role.isNotEmpty && w.shift.isNotEmpty
                                                                ? '${w.role} • ${w.shift}'
                                                                : (w.role.isNotEmpty ? w.role : w.shift),
                                                            style: zigzaBodyStyle(
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppTheme.bodyInk,
                                                              height: 1.35,
                                                            ),
                                                          ),
                                                        ],
                                                        if (w.phone.isNotEmpty) ...[
                                                          const SizedBox(height: 5),
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.phone_outlined, size: 13, color: AppTheme.faintInk),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                '+91 ${w.phone}',
                                                                style: zigzaHeadingStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: AppTheme.headingObsidian,
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              InkWell(
                                                                onTap: () => _showResetPasswordDialog(w.name, w.phone),
                                                                borderRadius: BorderRadius.circular(8),
                                                                child: Container(
                                                                  width: 30,
                                                                  height: 30,
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.white,
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    border: Border.all(color: AppTheme.borderLight),
                                                                  ),
                                                                  child: const Icon(Icons.key_rounded, size: 14, color: AppTheme.brandRoyalBlue),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _getDivisionIcon(String name) {
    IconData icon;
    switch (name) {
      case 'Palette':
        icon = Icons.palette_outlined;
        break;
      case 'Briefcase':
        icon = Icons.business_center_outlined;
        break;
      case 'Store':
        icon = Icons.storefront_outlined;
        break;
      case 'Scissors':
        icon = Icons.content_cut_rounded;
        break;
      case 'Printer':
        icon = Icons.print_outlined;
        break;
      case 'Layers':
        icon = Icons.layers_outlined;
        break;
      case 'Sparkles':
        icon = Icons.auto_awesome_outlined;
        break;
      case 'Waves':
        icon = Icons.waves_outlined;
        break;
      case 'Flame':
        icon = Icons.local_fire_department_outlined;
        break;
      case 'Boxes':
        icon = Icons.inventory_2_outlined;
        break;
      case 'Wrench':
        icon = Icons.build_outlined;
        break;
      case 'Truck':
        icon = Icons.local_shipping_outlined;
        break;
      default:
        icon = Icons.apartment_outlined;
    }
    return Icon(icon, size: 18, color: const Color(0xFF0B1220));
  }
}
