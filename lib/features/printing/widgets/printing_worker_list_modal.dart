import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/printing_models.dart';
import '../providers/printing_provider.dart';

class PrintingWorkerListModal extends ConsumerStatefulWidget {
  const PrintingWorkerListModal({super.key});

  @override
  ConsumerState<PrintingWorkerListModal> createState() => _PrintingWorkerListModalState();
}

class _PrintingWorkerListModalState extends ConsumerState<PrintingWorkerListModal> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmDelete(PrintingWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Worker',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to remove "${worker.workerName}" from printing floor stations? Active credentials will be revoked.',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(printingProvider.notifier).deleteWorker(worker.id, worker.phoneNumber);
            },
            child: Text('Delete', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printingProvider);
    final filtered = state.workers.where((w) {
      final q = _query.toLowerCase();
      return w.workerName.toLowerCase().contains(q) ||
          w.phoneNumber.contains(q) ||
          w.role.toLowerCase().contains(q) ||
          w.shift.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(Icons.people_alt_outlined, color: Color(0xFF3A3564), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Printing Floor Workers',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${state.workers.length} registered station operators',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _query = val),
              style: GoogleFonts.publicSans(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or skill...',
                hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Workers List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_search_outlined, size: 40, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          'No printing workers found',
                          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final worker = filtered[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A3564),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  worker.workerName.isNotEmpty ? worker.workerName[0].toUpperCase() : 'W',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                            fontSize: 13.5,
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
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          worker.shift,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF3A3564),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    worker.role,
                                    style: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '+91 ${worker.phoneNumber}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 18),
                              onPressed: () => _confirmDelete(worker),
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
