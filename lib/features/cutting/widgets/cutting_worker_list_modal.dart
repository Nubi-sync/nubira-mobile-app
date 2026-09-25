import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cutting_models.dart';
import '../providers/cutting_provider.dart';
import 'add_cutting_worker_modal.dart';

class CuttingWorkerListModal extends ConsumerStatefulWidget {
  const CuttingWorkerListModal({super.key});

  @override
  ConsumerState<CuttingWorkerListModal> createState() => _CuttingWorkerListModalState();
}

class _CuttingWorkerListModalState extends ConsumerState<CuttingWorkerListModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAddWorkerModal() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddCuttingWorkerModal(),
    );
  }

  Future<void> _confirmDeleteWorker(CuttingWorker worker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Worker',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${worker.workerName} (${worker.phoneNumber}) from the active floor registry?',
          style: GoogleFonts.publicSans(
            fontSize: 13,
            color: const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete Worker',
              style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(cuttingProvider.notifier).deleteWorker(worker.id, worker.phoneNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Worker removed successfully' : 'Failed to remove worker',
              style: GoogleFonts.publicSans(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: success ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cuttingProvider);
    final workers = state.workers.where((w) {
      final q = _search.trim().toLowerCase();
      if (q.isEmpty) return true;
      return w.workerName.toLowerCase().contains(q) ||
          w.phoneNumber.contains(q) ||
          w.roles.any((r) => r.toLowerCase().contains(q));
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.badge_outlined, color: Color(0xFF3A3564), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cutting Floor Workers',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${state.workers.length} registered floor operators',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                ),
              ],
            ),
          ),

          // Search & Action bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _search = val),
                      style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search worker or phone...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3564),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: _openAddWorkerModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Add',
                    style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Worker list
          Expanded(
            child: workers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_off_outlined, size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _search.isNotEmpty ? 'No matching workers found' : 'No workers registered yet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add cutting operators to allocate floor tasks',
                            style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: workers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final worker = workers[index];
                      final initials = worker.workerName.isNotEmpty
                          ? worker.workerName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                          : 'W';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFFAF7F0),
                              child: Text(
                                initials,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF3A3564),
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
                                      Expanded(
                                        child: Text(
                                          worker.workerName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFA7F3D0)),
                                        ),
                                        child: Text(
                                          worker.status.toUpperCase(),
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        worker.phoneNumber,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          worker.role,
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11,
                                            color: const Color(0xFF3A3564),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (worker.roles.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: worker.roles.map((r) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            r.replaceAll('_', ' '),
                                            style: GoogleFonts.publicSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF475569),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => _confirmDeleteWorker(worker),
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
