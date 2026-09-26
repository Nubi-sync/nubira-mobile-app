import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/iron_models.dart';
import '../providers/iron_provider.dart';
import 'add_iron_worker_modal.dart';

class IronWorkerListModal extends ConsumerStatefulWidget {
  const IronWorkerListModal({super.key});

  @override
  ConsumerState<IronWorkerListModal> createState() => _IronWorkerListModalState();
}

class _IronWorkerListModalState extends ConsumerState<IronWorkerListModal> {
  final _searchController = TextEditingController();
  String _roleFilter = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteWorker(IronWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Iron Presser',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF232028)),
        ),
        content: Text(
          'Are you sure you want to remove ${worker.workerName} (+91 ${worker.phoneNumber}) from the steam ironing floor roster?',
          style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF7A7488)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: const Color(0xFF7A7488))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(ironProvider.notifier).deleteWorker(worker.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Presser "${worker.workerName}" removed.')),
                );
              }
            },
            child: Text('Remove', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ironState = ref.watch(ironProvider);
    final workers = ironState.workers;

    final filteredWorkers = workers.where((w) {
      final q = _searchController.text.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          w.workerName.toLowerCase().contains(q) ||
          w.phoneNumber.contains(q) ||
          w.assignedTable.toLowerCase().contains(q) ||
          w.role.toLowerCase().contains(q);

      final matchesRole = _roleFilter == 'ALL' || w.roles.contains(_roleFilter);

      return matchesSearch && matchesRole;
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0x1A000000))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Icon(Icons.people_alt_outlined, color: Color(0xFF3A3564), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ironing Floor Pressers & Roster',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF232028),
                          ),
                        ),
                        Text(
                          '${workers.length} registered steam iron & vacuum buck pressers',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: const Color(0xFF7A7488),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF7A7488), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Controls Bar (Search + Role Filter + Add Worker)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                border: Border(bottom: BorderSide(color: Color(0x1A000000))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search field
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.publicSans(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search name, phone, table...',
                            hintStyle: GoogleFonts.publicSans(color: const Color(0xFFA09BAA), fontSize: 12),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF7A7488)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0x1A000000)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0x1A000000)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add Worker Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A3564),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'Add Presser',
                          style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const AddIronWorkerModal(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Role Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('ALL', 'All Roles (${workers.length})'),
                        const SizedBox(width: 6),
                        _buildFilterChip('FINISHING_PRESSER', 'Finishing Pressers'),
                        const SizedBox(width: 6),
                        _buildFilterChip('VACUUM_TABLE_PRESSER', 'Vacuum Pressers'),
                        const SizedBox(width: 6),
                        _buildFilterChip('STEAM_OPERATOR', 'Steam Operators'),
                        const SizedBox(width: 6),
                        _buildFilterChip('HEAD_PRESSER', 'Head Pressers'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Worker List
            Expanded(
              child: filteredWorkers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline, size: 48, color: Color(0xFFA09BAA)),
                            const SizedBox(height: 12),
                            Text(
                              'No iron pressers found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF232028),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Click "+ Add Presser" to register your first iron presser.',
                              style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF7A7488)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredWorkers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final worker = filteredWorkers[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x1A000000)),
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
                                  border: Border.all(color: const Color(0x1A000000)),
                                ),
                                child: Center(
                                  child: Text(
                                    worker.workerName.isNotEmpty ? worker.workerName[0].toUpperCase() : 'P',
                                    style: GoogleFonts.plusJakartaSans(
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
                                            color: const Color(0xFF232028),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: worker.isActive ? const Color(0xFFE3F3EA) : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            worker.isActive ? 'ACTIVE' : 'INACTIVE',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: worker.isActive ? const Color(0xFF1F8A5A) : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '+91 ${worker.phoneNumber} • ${worker.assignedTable} • ${worker.shift.replaceAll('_', ' ')}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        color: const Color(0xFF7A7488),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: worker.roles.map((r) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE5EDF9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            r.replaceAll('_', ' '),
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2E5AA8),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),

                              // Actions
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      worker.isActive ? Icons.toggle_on : Icons.toggle_off,
                                      color: worker.isActive ? const Color(0xFF1F8A5A) : const Color(0xFF7A7488),
                                      size: 26,
                                    ),
                                    tooltip: worker.isActive ? 'Mark Inactive' : 'Mark Active',
                                    onPressed: () {
                                      ref.read(ironProvider.notifier).toggleWorkerStatus(worker);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48), size: 18),
                                    tooltip: 'Remove presser',
                                    onPressed: () => _confirmDeleteWorker(worker),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _roleFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _roleFilter = filterKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF3A3564) : const Color(0x1A000000)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF7A7488),
          ),
        ),
      ),
    );
  }
}
