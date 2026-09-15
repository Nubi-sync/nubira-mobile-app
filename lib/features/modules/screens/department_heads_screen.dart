import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/module_card_model.dart';

class DepartmentHeadsScreen extends ConsumerStatefulWidget {
  const DepartmentHeadsScreen({super.key});

  @override
  ConsumerState<DepartmentHeadsScreen> createState() => _DepartmentHeadsScreenState();
}

class _DepartmentHeadsScreenState extends ConsumerState<DepartmentHeadsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadHeads();
  }

  Future<void> _loadHeads() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('profiles')
          .select('id, username, role, is_head, designation, allowed_modules, phone')
          .order('username');

      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final allowedDivisions = authState.allowedDivisions;

    final visibleModules = (allowedDivisions.isNotEmpty && !allowedDivisions.contains('/modules'))
        ? allEnterpriseModules.where((m) => allowedDivisions.contains(m.route) || allowedDivisions.any((a) => a.startsWith(m.route) || m.route.startsWith(a))).toList()
        : allEnterpriseModules;

    return Scaffold(
      backgroundColor: AppTheme.canvasCream,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.foregroundInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Department Heads & Incharges',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.foregroundInk,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandSteel))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
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
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.canvasCream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.standardBorder),
                        ),
                        child: const Center(
                          child: Icon(Icons.shield_outlined, color: AppTheme.brandSteel, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Division Heads Catalog',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.foregroundInk,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Executive in-charges managing operating units across the apparel plant',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                color: AppTheme.mutedInk,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                ...visibleModules.map((mod) {
                  // Find profile assigned to this module
                  final assignedHead = _profiles.firstWhere(
                    (p) {
                      final mods = p['allowed_modules'];
                      if (mods is List && mods.contains(mod.route)) return true;
                      final r = (p['role'] ?? '').toString().toUpperCase();
                      if (mod.id == 'stitching-sewing' && (r == 'ADMIN' || r == 'PRODUCTION_MANAGER')) return true;
                      if (mod.id == 'store' && r == 'STORE') return true;
                      if (mod.id == 'ready-goods' && r == 'QC') return true;
                      if (mod.id == 'alter' && r == 'MENDING') return true;
                      if (mod.id == 'dispatch' && r == 'DISPATCH') return true;
                      return false;
                    },
                    orElse: () => {},
                  );

                  final hasHead = assignedHead.isNotEmpty;
                  final headName = assignedHead['username'] ?? 'Unassigned';
                  final headDesignation = assignedHead['designation'] ?? (assignedHead['role'] ?? 'Head Incharge');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.canvasCream,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.standardBorder),
                                  ),
                                  child: Icon(mod.icon, color: AppTheme.brandSteel, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mod.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.foregroundInk,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      mod.badge,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.faintInk,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasHead ? AppTheme.badgeEmeraldBg : AppTheme.canvasCream,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hasHead ? AppTheme.badgeEmeraldBorder : AppTheme.standardBorder,
                                ),
                              ),
                              child: Text(
                                hasHead ? 'APPOINTED' : 'UNASSIGNED',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: hasHead ? AppTheme.badgeEmeraldText : AppTheme.mutedInk,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppTheme.canvasCream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.standardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasHead ? Icons.account_circle : Icons.person_add_outlined,
                                size: 18,
                                color: hasHead ? AppTheme.brandSteel : AppTheme.faintInk,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasHead ? '$headName ($headDesignation)' : 'Plant Head overseeing directly',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: hasHead ? AppTheme.foregroundInk : AppTheme.mutedInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
