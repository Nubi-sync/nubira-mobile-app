import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/embroidery_models.dart';
import '../providers/embroidery_provider.dart';
import 'add_embroidery_worker_modal.dart';

class EmbroideryWorkerListModal extends ConsumerStatefulWidget {
  const EmbroideryWorkerListModal({super.key});

  @override
  ConsumerState<EmbroideryWorkerListModal> createState() => _EmbroideryWorkerListModalState();
}

class _EmbroideryWorkerListModalState extends ConsumerState<EmbroideryWorkerListModal> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmDelete(EmbroideryWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Embroidery Worker',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to remove worker "${worker.workerName}" (+91 ${worker.phoneNumber}) from the embroidery floor database and revoke portal access?',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(embroideryProvider.notifier).deleteWorker(worker.id, worker.phoneNumber);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Worker "${worker.workerName}" removed.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(embroideryProvider);
    final workers = state.workers.where((w) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return w.workerName.toLowerCase().contains(query) ||
          w.phoneNumber.contains(query) ||
          w.role.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        margin: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.people_outline, color: Color(0xFF3A3564), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registered Embroidery Workers',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${state.workers.length} active machine operators & framing specialists',
                        style: GoogleFonts.publicSans(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: GoogleFonts.publicSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search worker by name, phone, or role...',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Workers List
            Expanded(
              child: workers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined, size: 42, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No matching embroidery workers found',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Register new machine operators using the button below.',
                            style: GoogleFonts.publicSans(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: workers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final worker = workers[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                                ),
                                child: Center(
                                  child: Text(
                                    worker.workerName.isNotEmpty ? worker.workerName[0].toUpperCase() : 'E',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF3A3564),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          worker.workerName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: Text(
                                            worker.status,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF047857),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      worker.role,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+91 ${worker.phoneNumber}',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        if (worker.assignedPieces > 0) ...[
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFAF7F0),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                                            ),
                                            child: Text(
                                              '${worker.assignedPieces} pcs assigned',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF3A3564),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Delete Button
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                onPressed: () => _confirmDelete(worker),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 14),

            // Bottom Add Worker CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddEmbroideryWorkerModal(),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: Text(
                  '+ Register New Embroidery Worker',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A3564),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
