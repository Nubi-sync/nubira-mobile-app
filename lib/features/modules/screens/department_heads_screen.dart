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
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Department Heads & Incharges',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.ink,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.steel))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Center(
                          child: Icon(Icons.shield_outlined, color: AppTheme.steel, size: 20),
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
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Executive in-charges managing operating units across the apparel plant',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
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
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Icon(mod.icon, color: AppTheme.steel, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mod.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.ink,
                                      ),
                                    ),
                                    Text(
                                      mod.badge,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasHead ? AppTheme.greenMist : AppTheme.bg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hasHead ? AppTheme.green.withValues(alpha: 0.3) : AppTheme.border,
                                ),
                              ),
                              child: Text(
                                hasHead ? 'APPOINTED' : 'UNASSIGNED',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: hasHead ? AppTheme.green : AppTheme.inkFaint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasHead ? Icons.account_circle : Icons.person_add_outlined,
                                size: 18,
                                color: hasHead ? AppTheme.steel : AppTheme.inkFaint,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasHead ? '$headName ($headDesignation)' : 'Plant Head overseeing directly',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: hasHead ? AppTheme.ink : AppTheme.inkSoft,
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
