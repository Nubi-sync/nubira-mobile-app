import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/connectivity_indicator.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../../../main.dart';

class MendingDashboard extends ConsumerStatefulWidget {
  const MendingDashboard({super.key});

  @override
  ConsumerState<MendingDashboard> createState() => _MendingDashboardState();
}

class _MendingDashboardState extends ConsumerState<MendingDashboard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingLots = [];
  Map<String, dynamic>? _selectedLot;
  Map<String, int> _countedPieces = {}; // key: variant_id, value: counted_qty
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchMendingLots();
  }

  Future<void> _fetchMendingLots() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('allotments')
          .select('''
            id,
            challan_id,
            article_id,
            lineman_id,
            status,
            created_at,
            article:articles ( id, art_no, description, color_pattern, size_range, pattern_no ),
            lineman:profiles!allotments_lineman_id_fkey ( id, username )
          ''')
          .order('created_at', ascending: false)
          .limit(50);

      // Fetch variants
      final variantsRes = await supabase
          .from('allotment_variants')
          .select('id, allotment_id, color, size, quantity');

      final List<Map<String, dynamic>> lots = [];
      for (var a in res) {
        final aId = a['id'];
        final vars = (variantsRes as List).where((v) => v['allotment_id'] == aId).toList();
        int totalTarget = 0;
        for (var v in vars) {
          totalTarget += (v['quantity'] as int? ?? 0);
        }

        lots.add({
          ...a,
          'variants': vars,
          'target_qty': totalTarget,
        });
      }

      if (mounted) {
        setState(() {
          _pendingLots = lots;
          _isLoading = false;
          if (_selectedLot == null && lots.isNotEmpty) {
            _selectLot(lots.first);
          }
        });
      }
    } catch (e) {
      debugPrint('Mending lots fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectLot(Map<String, dynamic> lot) {
    final Map<String, int> counts = {};
    final vars = lot['variants'] as List<dynamic>? ?? [];
    for (var v in vars) {
      final vId = v['id'].toString();
      // default counted to target quantity
      counts[vId] = (v['quantity'] as int? ?? 0);
    }

    setState(() {
      _selectedLot = lot;
      _countedPieces = counts;
    });
  }

  Future<void> _handoverToQc() async {
    if (_selectedLot == null) return;
    setState(() => _isSubmitting = true);

    try {
      final lotId = _selectedLot!['id'];
      final articleId = _selectedLot!['article_id'];
      final linemanId = _selectedLot!['lineman_id'];

      int totalCounted = 0;
      _countedPieces.forEach((_, qty) => totalCounted += qty);

      // Record counting reconciliation into qc_logs / audit
      await supabase.from('qc_logs').insert({
        'allotment_id': lotId,
        'article_id': articleId,
        'from_lineman_id': linemanId,
        'qty_checked': totalCounted,
        'qty_passed': totalCounted,
        'qty_rejected': 0,
        'defect_type': 'NONE',
        'remarks': 'Mending Counting Verified: $totalCounted pieces forwarded to QC',
        'mending_status': 'COUNTING_VERIFIED',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.green,
            content: Text(
              'Lot verified! $totalCounted pcs forwarded to QC Floor.',
              style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );
        _fetchMendingLots();
      }
    } catch (e) {
      debugPrint('Handover to QC error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.red,
            content: Text('Error forwarding to QC: $e', style: GoogleFonts.publicSans(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppTheme.amberMist, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.table_view_rounded, size: 20, color: AppTheme.amber),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MENDING & COUNTING',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink),
                ),
                Text(
                  'Challan Piece Count Reconciliation',
                  style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkSoft, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppTheme.inkSoft),
            onPressed: _fetchMendingLots,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.red),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ConnectivityIndicator(),
                  const SizedBox(height: 10),

                  // Section Title: Select Active Lot
                  Text(
                    'SELECT LOT FOR COUNTING',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.ink, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),

                  // Horizontal Lot Selector Cards
                  SizedBox(
                    height: 85,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingLots.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final lot = _pendingLots[i];
                        final isSelected = _selectedLot?['id'] == lot['id'];
                        final art = lot['article']?['art_no'] ?? 'N/A';
                        final color = lot['article']?['color_pattern'] ?? 'Std';
                        final pcs = lot['target_qty'] ?? 0;

                        return InkWell(
                          onTap: () => _selectLot(lot),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.steel : AppTheme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? AppTheme.steel : AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Art $art',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : AppTheme.ink,
                                  ),
                                ),
                                Text(
                                  '$color',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppTheme.inkSoft,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$pcs pcs expected',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    color: isSelected ? AppTheme.greenMist : AppTheme.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_selectedLot != null) ...[
                    // Exact Challan Article Reference Sheet Header
                    _buildActiveLotDetailCard(),
                    const SizedBox(height: 14),

                    // Exact Colour x Size Matrix Breakdown Table
                    _buildPieceCountingTable(),
                    const SizedBox(height: 20),

                    // Big Action: Forward to QC
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.steel,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _handoverToQc,
                        child: _isSubmitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.verified_outlined, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Forward Verified Lot to QC Floor',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildActiveLotDetailCard() {
    final article = _selectedLot!['article'] ?? {};
    final artNo = article['art_no'] ?? 'N/A';
    final color = article['color_pattern'] ?? 'Standard';
    final sizeRange = article['size_range'] ?? 'STD';
    final linemanName = _selectedLot!['lineman']?['username'] ?? 'Unassigned';
    final target = _selectedLot!['target_qty'] ?? 0;

    int totalCounted = 0;
    _countedPieces.forEach((_, qty) => totalCounted += qty);
    final variance = totalCounted - target;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CHALLAN SPECIFICATION',
                style: GoogleFonts.publicSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.inkFaint, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: variance == 0 ? AppTheme.greenMist : AppTheme.amberMist,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  variance == 0
                      ? 'Exact Match ($totalCounted pcs)'
                      : variance > 0
                          ? '+$variance pcs excess'
                          : '$variance pcs short',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: variance == 0 ? AppTheme.green : AppTheme.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Art No: ', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
              Text('$artNo', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const SizedBox(width: 16),
              Text('Colour: ', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
              Text('$color', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Lineman: ', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
              Text('$linemanName', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.steel)),
              const SizedBox(width: 16),
              Text('Size Tier: ', style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft)),
              Text('$sizeRange', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieceCountingTable() {
    final variants = _selectedLot!['variants'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'COLOUR × SIZE PIECE COUNTER',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.ink, letterSpacing: 0.5),
                ),
                Text(
                  'Physical Count Reconciliation',
                  style: GoogleFonts.publicSans(fontSize: 10.5, color: AppTheme.inkFaint),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: variants.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
            itemBuilder: (ctx, i) {
              final v = variants[i];
              final vId = v['id'].toString();
              final color = v['color'] ?? 'Standard';
              final size = v['size'] ?? 'STD';
              final target = v['quantity'] as int? ?? 0;
              final counted = _countedPieces[vId] ?? target;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.steel, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$color • Size $size', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                          Text('Expected: $target pcs', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.inkFaint)),
                        ],
                      ),
                    ),
                    // Quick Increment / Decrement Counter
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 22, color: AppTheme.inkSoft),
                          onPressed: () {
                            if (counted > 0) {
                              setState(() {
                                _countedPieces[vId] = counted - 1;
                              });
                            }
                          },
                        ),
                        Container(
                          width: 48,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            '$counted',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: AppTheme.steel),
                          onPressed: () {
                            setState(() {
                              _countedPieces[vId] = counted + 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
