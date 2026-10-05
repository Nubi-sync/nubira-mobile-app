import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/workspace_hub_drawer.dart';
import 'enterprise_workspace_hub_screen.dart';
import 'company_profile_screen.dart';
import 'appoint_department_head_screen.dart';
import '../../cutting/screens/cutting_notifications_screen.dart';
import '../../cutting/screens/cutting_lay_floor_screen.dart';
import '../../design/screens/sa_design_approvals_screen.dart';
import '../services/supervisor_workers_service.dart';

class DepartmentHeadsScreen extends ConsumerStatefulWidget {
  const DepartmentHeadsScreen({super.key});

  @override
  ConsumerState<DepartmentHeadsScreen> createState() => _DepartmentHeadsScreenState();
}

class _DepartmentHeadsScreenState extends ConsumerState<DepartmentHeadsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _createButtonKey = GlobalKey();
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showQuickActionsMenu(BuildContext context) {
    final RenderBox? renderBox = _createButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(54, 34);
    final offset = renderBox?.localToGlobal(Offset.zero) ?? const Offset(200, 50);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx - 170,
        offset.dy + size.height + 8,
        MediaQuery.of(context).size.width - offset.dx - size.width,
        0,
      ),
      color: Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'QUICK ACTIONS',
            style: GoogleFonts.publicSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'appoint_head',
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (context.mounted) {
                final companyName = ref.read(supervisorWorkersProvider).companyName;
                final result = await AppointDepartmentHeadScreen.show(context, companyName: companyName);
                if (result == true) {
                  ref.read(supervisorWorkersProvider.notifier).fetchData();
                  _showToast('Department Head appointed successfully');
                }
              }
            });
          },
          child: Row(
            children: [
              const Icon(Icons.people_outline_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 10),
              Text(
                'Appoint Department Head',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'review_approvals',
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SADesignApprovalsScreen()),
                );
              }
            });
          },
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: Color(0xFF1D4ED8), size: 18),
              const SizedBox(width: 10),
              Text(
                'Review Design Approvals',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'cutting_floor',
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CuttingLayFloorScreen()),
                );
              }
            });
          },
          child: Row(
            children: [
              const Icon(Icons.content_cut_rounded, color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 10),
              Text(
                'Open Cutting Floor',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sewing_dashboard',
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                );
              }
            });
          },
          child: Row(
            children: [
              const Icon(Icons.layers_outlined, color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 10),
              Text(
                'Open Sewing Dashboard',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'company_profile',
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                );
              }
            });
          },
          child: Row(
            children: [
              const Icon(Icons.business_outlined, color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 10),
              Text(
                'Company Profile & Units',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B1220),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showResetPasswordDialog(String name, String phone) {
    final TextEditingController newPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.key_rounded, color: Color(0xFF1D4ED8), size: 22),
            const SizedBox(width: 8),
            Text(
              'Reset Password',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a new login password for $name (+91 $phone):',
              style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter new password (min 6 chars)',
                hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
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
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Save Password', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 22),
            const SizedBox(width: 8),
            Text(
              'Remove Member',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove access for $name? This action cannot be undone.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
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
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Remove Access', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Floor Worker',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                    ),
                    Text(
                      'Department: $departmentName',
                      style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Worker Full Name',
                hintText: 'e.g. Ramesh Kumar',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Phone Number',
                hintText: '10-digit number',
                prefixText: '+91 ',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleCtrl,
              decoration: InputDecoration(
                labelText: 'Role / Skill Classification',
                hintText: 'e.g. Master Tailor, Overlock Operator',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
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
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Add Worker to Roster', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorWorkersProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const WorkspaceHubDrawer(activeRoute: '/access-control'),
      appBar: _buildTopBar(context),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.headingObsidian))
          : RefreshIndicator(
              color: const Color(0xFF0B1220),
              onRefresh: () => ref.read(supervisorWorkersProvider.notifier).fetchData(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                children: [
                  // 1. Header Card
                  _buildHeaderCard(context, state),
                  const SizedBox(height: 14),

                  // 2. Staff Cards (Owner + Production Manager)
                  _buildOwnerCard(state),
                  const SizedBox(height: 14),

                  _buildProductionManagerCard(state),
                  const SizedBox(height: 18),

                  // 3. Factory Departments Section
                  _buildDepartmentsSection(state),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleSpacing: 0,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
      ),
      leading: Center(
        child: InkWell(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.menu_rounded, color: Color(0xFF0B1220), size: 20),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/icon.png',
            height: 26,
            width: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/z_i_g_z_a.png',
            height: 19,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              'ZIGZA',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0B1220),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Royal Blue + v Quick Action Button
        Center(
          child: InkWell(
            key: _createButtonKey,
            onTap: () => _showQuickActionsMenu(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Mint Tint Notification Bell
        Center(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CuttingNotificationsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.35)),
              ),
              child: const Center(
                child: Icon(Icons.notifications_none_rounded, color: Color(0xFF0B1220), size: 19),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Mint Tint Profile Avatar
        Center(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.35)),
                ),
                child: const Center(
                  child: Icon(Icons.person_outline_rounded, color: Color(0xFF0B1220), size: 19),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 1. Header Card with Live Search
  Widget _buildHeaderCard(BuildContext context, SupervisorWorkersState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.verified_user_outlined, color: Color(0xFF0B1220), size: 22),
                ),
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
                            text: 'Supervisor & ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                          TextSpan(
                            text: 'Workers',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${state.divisions.length} Departments',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0B1220),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Factory leadership hierarchy, department heads, and floor worker roster for ${state.companyName}.',
            style: GoogleFonts.publicSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
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
            decoration: InputDecoration(
              hintText: 'Search departments or staff...',
              hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0B1220), width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2A. Owner Card
  Widget _buildOwnerCard(SupervisorWorkersState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded, color: Color(0xFF0B1220), size: 22),
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
                          state.ownerName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0B1220),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(Company Owner)',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (state.ownerEmail.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.mail_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              state.ownerEmail,
                              style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          '+91 ${state.ownerPhone}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                const SizedBox(width: 5),
                Text(
                  'Full Factory Authority',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2B. Production Manager Card
  Widget _buildProductionManagerCard(SupervisorWorkersState state) {
    final pm = state.productionManagers.isNotEmpty ? state.productionManagers.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: pm != null
          ? Column(
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
                        border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Icon(Icons.factory_outlined, color: Color(0xFF0B1220), size: 22),
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
                                pm.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0B1220),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(Production Manager)',
                                style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: pm.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pm.isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3)),
                            ),
                            child: Text(
                              pm.isActive ? '• Active' : '• Inactive',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: pm.isActive ? const Color(0xFF059669) : const Color(0xFFE11D48),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                '+91 ${pm.phone}',
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showResetPasswordDialog(pm.name, pm.phone),
                        icon: const Icon(Icons.key_rounded, size: 14, color: Color(0xFF0B1220)),
                        label: Text(
                          'Reset Password',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final ok = await ref.read(supervisorWorkersProvider.notifier).toggleStaffStatus(pm.id, 'PRODUCTION_MANAGER', pm.isActive);
                        if (ok) {
                          _showToast('Status updated to ${pm.isActive ? 'Inactive' : 'Active'}');
                        }
                      },
                      icon: Icon(Icons.power_settings_new_rounded, size: 18, color: pm.isActive ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
                      tooltip: pm.isActive ? 'Deactivate' : 'Activate',
                    ),
                    IconButton(
                      onPressed: () => _showDeleteConfirmDialog(pm.id, pm.name, 'PRODUCTION_MANAGER'),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Production Manager',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                    ),
                    Text(
                      'No Production Manager appointed yet',
                      style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
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
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: Text('Appoint PM', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
    );
  }

  // 3. Factory Departments Section
  Widget _buildDepartmentsSection(SupervisorWorkersState state) {
    final query = _searchQuery.toLowerCase();
    final filteredDivisions = state.divisions.where((div) {
      if (query.isEmpty) return true;
      final nameMatch = div.name.toLowerCase().contains(query);
      final headMatch = state.departmentHeads.any((h) => h.allowedModules.contains(div.route) && (h.displayName.toLowerCase().contains(query) || h.phone.contains(query)));
      final workerMatch = state.workers.any((w) => w.departmentRoute == div.route && (w.name.toLowerCase().contains(query) || w.phone.contains(query)));
      return nameMatch || headMatch || workerMatch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Factory Departments',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B1220),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${filteredDivisions.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _expandedRoutes.addAll(state.divisions.map((d) => d.route));
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Expand All', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _expandedRoutes.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Collapse All', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Accordion Rows
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDFA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
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
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0B1220),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      div.defaultDesignation,
                                      style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  '${workersForDiv.length} ${workersForDiv.length == 1 ? 'Worker' : 'Workers'}',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: const Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'IN-CHARGE: ',
                                  style: GoogleFonts.publicSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                                ),
                                if (head != null) ...[
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF14C8B4), shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Text(
                                    head.displayName,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                                  ),
                                  if (head.phone.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '+91 ${head.phone}',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ] else ...[
                                  Text(
                                    'Not Assigned',
                                    style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expanded Roster Details
                  if (isExpanded) ...[
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Container(
                      padding: const EdgeInsets.all(14),
                      color: const Color(0xFFF8FAFC),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Department In-Charge Sub-Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Department In-Charge (${headsForDiv.length})',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
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
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 2),
                                    Text(
                                      head != null ? 'Edit Details' : 'Assign Head',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (headsForDiv.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: Center(
                                child: Text('No department head appointed for ${div.name}.', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                              ),
                            )
                          else
                            ...headsForDiv.map((h) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(h.displayName, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220))),
                                            Text('+91 ${h.phone} • ${h.designation}', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF64748B))),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _showResetPasswordDialog(h.displayName, h.phone),
                                        icon: const Icon(Icons.key_rounded, size: 16, color: Color(0xFF475569)),
                                        tooltip: 'Reset Password',
                                      ),
                                      IconButton(
                                        onPressed: () => _showDeleteConfirmDialog(h.id, h.displayName, 'DEPARTMENT_HEAD'),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                                        tooltip: 'Remove',
                                      ),
                                    ],
                                  ),
                                )),
                          const SizedBox(height: 14),

                          // Floor Workers Sub-Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Floor Workers Roster (${workersForDiv.length})',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220)),
                              ),
                              InkWell(
                                onTap: () => _showAddWorkerModal(div.route, div.name),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 2),
                                    Text('Add Worker', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (workersForDiv.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: Center(
                                child: Text('No floor workers registered under ${div.name}.', style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                              ),
                            )
                          else
                            ...workersForDiv.map((w) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(w.name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0B1220))),
                                          Text('${w.role}${w.phone.isNotEmpty ? " • +91 ${w.phone}" : ""}', style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFF64748B))),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('Active', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                                      ),
                                    ],
                                  ),
                                )),
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
