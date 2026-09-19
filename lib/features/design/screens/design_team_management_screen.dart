import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';
import 'design_studio_screen.dart';

class DesignTeamManagementScreen extends ConsumerStatefulWidget {
  const DesignTeamManagementScreen({super.key});

  @override
  ConsumerState<DesignTeamManagementScreen> createState() => _DesignTeamManagementScreenState();
}

class _DesignTeamManagementScreenState extends ConsumerState<DesignTeamManagementScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(designerProvider.notifier).fetchStudioData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final studioState = ref.watch(designerProvider);
    final allMembers = studioState.teamMembers;

    final activeMembers = allMembers.where((m) => m.isActive).toList();
    final suspendedMembers = allMembers.where((m) => !m.isActive).toList();

    final filteredMembers = allMembers.where((m) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = m.designerName.toLowerCase();
      final username = m.safeUsername.toLowerCase();
      final phone = m.safePhone.replaceAll(RegExp(r'\D'), '');
      final queryClean = q.replaceAll(RegExp(r'\D'), '');

      final matchesName = name.contains(q);
      final matchesUsername = username.contains(q);
      final matchesPhone = phone.contains(q) || (queryClean.isNotEmpty && phone.contains(queryClean));

      return matchesName || matchesUsername || matchesPhone;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: const WorkspaceHubDrawer(activeRoute: '/design/team'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(designerProvider.notifier).fetchStudioData();
        },
        color: const Color(0xFF332B6B),
        backgroundColor: Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ==========================================
            // 1. BREADCRUMB TRAIL
            // ==========================================
            Row(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DesignStudioScreen()),
                    );
                  },
                  child: Text(
                    'Design Studio',
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  'Administration',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Team Management',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ==========================================
            // 2. HERO / HEADER CARD (#FAFAF8)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x1A000000)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF0DC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x18000000)),
                        ),
                        child: const Icon(
                          Icons.people_alt_outlined,
                          color: Color(0xFF332B6B),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Design Team Management',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9F7EE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    '${activeMembers.length} Active',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1B7A43),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Onboard creative designers with 10-digit phone login and allocate apparel briefs',
                              style: GoogleFonts.publicSans(
                                fontSize: 12.5,
                                color: const Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Full-width "+ Onboard designer" primary button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () => _openOnboardDesignerModal(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 17, color: Colors.white),
                      label: Text(
                        '+ Onboard Designer',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF332B6B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 3. STATS GRID (2x2 UNIFIED METRICS)
            // ==========================================
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                _buildStatCard(
                  tag: 'ACTIVE',
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Active Designers',
                  value: '${activeMembers.length}',
                  iconColor: const Color(0xFF1B7A43),
                ),
                _buildStatCard(
                  tag: 'SUSPENDED',
                  icon: Icons.cancel_outlined,
                  label: 'Suspended Accounts',
                  value: '${suspendedMembers.length}',
                  iconColor: const Color(0xFFBE123C),
                ),
                _buildStatCard(
                  tag: 'ROSTER',
                  icon: Icons.people_outline_rounded,
                  label: 'Total Roster',
                  value: '${allMembers.length}',
                  iconColor: const Color(0xFF332B6B),
                ),
                _buildStatCard(
                  tag: 'AUTH',
                  icon: Icons.phone_android_rounded,
                  label: 'Phone Logins',
                  value: '${activeMembers.length}',
                  iconColor: const Color(0xFF332B6B),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 4. SEARCH & STUDIO DASHBOARD LINK
            // ==========================================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search by name, username, phone...',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Full-width outline button: "View studio dashboard"
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DesignStudioScreen()),
                );
              },
              icon: const Icon(Icons.dashboard_outlined, size: 16, color: Color(0xFF332B6B)),
              label: Text(
                'View Studio Dashboard',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF332B6B),
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: const Color(0xFFFAFAF8),
                side: const BorderSide(color: Color(0x1A000000)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // 5. DESIGNERS SECTION LABEL & ROSTER LIST
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DESIGNERS (${filteredMembers.length})',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: Text(
                      'Clear Filter',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF332B6B),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (studioState.isLoading && allMembers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Color(0xFF332B6B)),
                ),
              )
            else if (filteredMembers.isEmpty)
              _buildEmptyState()
            else
              ...filteredMembers.map((member) => _buildDesignerRosterCard(member)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // METRIC / STAT CARD COMPONENT
  // ==========================================================================
  Widget _buildStatCard({
    required String tag,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x03000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x14000000)),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x14000000)),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DESIGNER ROSTER CARD COMPONENT
  // ==========================================================================
  Widget _buildDesignerRosterCard(DesignTeamMemberModel member) {
    final bool isActive = member.isActive;
    String formattedDate = '';
    try {
      formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(member.createdAt));
    } catch (_) {
      formattedDate = member.createdAt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Name + Username tag + Status badge & Menu
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar Tile: Initials on Amber Tint (#FDF0DC bg, #8A6D2F text)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0DC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x18000000)),
                  ),
                  child: Center(
                    child: Text(
                      member.initials,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF8A6D2F),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Username Handle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.designerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x14000000)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tag_rounded, size: 11, color: Color(0xFF332B6B)),
                            const SizedBox(width: 2),
                            Text(
                              member.safeUsername,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF332B6B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge ("Active" / "Suspended")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFE9F7EE) : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                    ),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Suspended',
                    style: GoogleFonts.publicSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? const Color(0xFF1B7A43) : const Color(0xFFBE123C),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Action Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) => _handleCardAction(val, member),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'TOGGLE_STATUS',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                            size: 16,
                            color: isActive ? const Color(0xFFBE123C) : const Color(0xFF1B7A43),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isActive ? 'Suspend Account' : 'Activate Account',
                            style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'DELETE',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Text(
                            'Remove Designer',
                            style: GoogleFonts.publicSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
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

          // Thin Divider before Phone & Metadata Row
          const Divider(height: 1, thickness: 1, color: Color(0x14000000)),

          // Bottom Metadata Row: Phone Number + Onboarded Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      '+91 ${member.safePhone}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (formattedDate.isNotEmpty)
                  Text(
                    'Onboarded $formattedDate',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ACTIONS: STATUS TOGGLE & DELETE CONFIRMATION
  // ==========================================================================
  Future<void> _handleCardAction(String action, DesignTeamMemberModel member) async {
    final notifier = ref.read(designerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (action == 'TOGGLE_STATUS') {
      final nextStatus = member.isActive ? 'SUSPENDED' : 'ACTIVE';
      final ok = await notifier.updateDesignerStatus(member.id, nextStatus);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? '${member.designerName} status updated to ${nextStatus.toLowerCase()}'
                  : 'Failed to update designer status',
            ),
            backgroundColor: ok ? const Color(0xFF332B6B) : const Color(0xFFDC2626),
          ),
        );
      }
    } else if (action == 'DELETE') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Remove Designer "${member.designerName}"?',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          content: Text(
            'Are you sure you want to remove this designer? They will no longer be able to log in with +91 ${member.safePhone} or access allocated briefs.',
            style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Remove', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final ok = await notifier.deleteDesigner(member.id);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(ok ? '${member.designerName} removed from team' : 'Failed to remove designer'),
              backgroundColor: ok ? const Color(0xFF332B6B) : const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  // ==========================================================================
  // EMPTY STATE COMPONENT
  // ==========================================================================
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: const Icon(Icons.people_outline_rounded, color: Color(0xFF332B6B), size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty ? 'No matching team members' : 'No designers onboarded yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try searching with a different name, handle, or mobile number.'
                : 'Add your first creative apparel designer with their phone number and login credentials.',
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.35),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openOnboardDesignerModal(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
            label: const Text('Onboard Designer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF332B6B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ONBOARD DESIGNER MODAL / SHEET (Matching Web Add Designer Dialog)
  // ==========================================================================
  void _openOnboardDesignerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _OnboardDesignerSheet(),
    );
  }
}

class _OnboardDesignerSheet extends ConsumerStatefulWidget {
  const _OnboardDesignerSheet();

  @override
  ConsumerState<_OnboardDesignerSheet> createState() => _OnboardDesignerSheetState();
}

class _OnboardDesignerSheetState extends ConsumerState<_OnboardDesignerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  late final TextEditingController _passCtrl;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final randomNum = 1000 + Random().nextInt(9000);
    _passCtrl = TextEditingController(text: 'Designer@$randomNum!');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String get _handlePreview {
    final name = _nameCtrl.text.trim();
    final authState = ref.read(authProvider);
    final company = authState.tenantProfile?.companyName.trim() ?? 'Nubira Creation';
    final companySlug = company.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').split('_').first;
    if (name.isEmpty) return 'name_$companySlug';
    final nameSlug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').split('_').first;
    return '${nameSlug}_$companySlug';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final pass = _passCtrl.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final res = await ref.read(designerProvider.notifier).onboardDesigner(
          designerName: name,
          phoneNumber: phone,
          password: pass,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Designer "$name" onboarded successfully! Login: $phone'),
          backgroundColor: const Color(0xFF1B7A43),
        ),
      );
      nav.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Failed to onboard designer.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 14,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF332B6B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Onboard creative designer',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Creates credentials for web & mobile designer portal login',
                          style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),

              // 1. Designer Full Name
              Text(
                'Designer full name *',
                style: GoogleFonts.publicSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Rahul Sharma',
                  hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Mobile Number (Login ID)
              Text(
                'Mobile number (login ID) *',
                style: GoogleFonts.publicSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (v) {
                  final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (clean.length != 10) return 'Enter a valid 10-digit mobile number';
                  return null;
                },
                style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAF8),
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                      border: Border(right: BorderSide(color: Color(0xFFDAD9D3))),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF332B6B)),
                        const SizedBox(width: 4),
                        Text(
                          '+91',
                          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF332B6B)),
                        ),
                      ],
                    ),
                  ),
                  hintText: '8010993993',
                  hintStyle: GoogleFonts.jetBrainsMono(fontSize: 13, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter 10 digits without +91. The designer will log in with this 10-digit number.',
                style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF6B6A65)),
              ),
              const SizedBox(height: 14),

              // 3. Login Password
              Text(
                'Login password *',
                style: GoogleFonts.publicSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePassword,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Password is required';
                  if (v.trim().length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
                style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Set designer password',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD9D3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF332B6B), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Creative Handle Generation Callout (#FDF6E7 bg / #F0E3C0 border / #8A6D2F label)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF6E7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF0E3C0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF8A6D2F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Creative handle generation:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF8A6D2F),
                            ),
                          ),
                          const SizedBox(height: 3),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF6B6A65), height: 1.35),
                              children: [
                                const TextSpan(text: 'A unique handle like '),
                                TextSpan(
                                  text: _handlePreview,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF332B6B),
                                  ),
                                ),
                                const TextSpan(text: ' will be automatically assigned to avoid collisions.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Actions: Cancel & Create designer account
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFDAD9D3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF6B6A65)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                      label: Text(
                        _isSubmitting ? 'Onboarding...' : 'Create designer account',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF332B6B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
