import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import 'allotment_form_state.dart';
import 'allotment_step2_screen.dart';
import 'widgets/allotment_step_indicator.dart';

class AllotmentStep1Screen extends ConsumerStatefulWidget {
  const AllotmentStep1Screen({super.key});

  @override
  ConsumerState<AllotmentStep1Screen> createState() => _AllotmentStep1ScreenState();
}

class _AllotmentStep1ScreenState extends ConsumerState<AllotmentStep1Screen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _challanNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final formData = ref.read(allotmentFormProvider);
    _challanNoController.text = formData.clientChallanNo;
  }

  @override
  void dispose() {
    _challanNoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) {
    return _picker.pickImage(source: source, imageQuality: 70).then((file) {
      if (file != null) {
        final current = List<String>.from(ref.read(allotmentFormProvider).samplePhotos);
        if (current.length < 4) {
          current.add(file.path);
          ref.read(allotmentFormProvider.notifier).setSamplePhotos(current);
        }
      }
    });
  }

  void _openTargetSelectorModal(
    List<AdminArticle> articles,
    List<AdminChallan> challans,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TargetPickerSheet(
        articles: articles,
        challans: challans,
        onArticleSelected: (art) {
          ref.read(allotmentFormProvider.notifier).setArticle(
                articleId: art.id,
                articleNo: art.artNo,
                articleDesc: art.description,
              );
          Navigator.pop(ctx);
        },
        onChallanSelected: (ch, colorName) {
          final artDesc = (ch.description != null && ch.description!.isNotEmpty)
              ? ch.description
              : 'Challan #${ch.challanNo} (${ch.brand})';
          ref.read(allotmentFormProvider.notifier).setArticle(
                articleId: articles.isNotEmpty ? articles.first.id : ch.id,
                articleNo: ch.challanNo,
                articleDesc: colorName != null ? '$artDesc • $colorName LINE' : artDesc,
                challanId: ch.id,
                challanNo: ch.challanNo,
                brand: ch.brand,
                fabricType: ch.fabricType,
              );
          if (colorName != null) {
            ref.read(allotmentFormProvider.notifier).setCustomColorRows([
              ColorMatrixRow(
                id: '1',
                color: colorName,
                quantities: {for (var s in ref.read(allotmentFormProvider).selectedSizes) s: 0},
              )
            ]);
          }
          _challanNoController.text = ch.challanNo.startsWith('JOB-') ? ch.challanNo : 'JOB-${ch.challanNo}';
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(allotmentFormProvider);
    final employeesAsync = ref.watch(adminEmployeesListProvider);
    final articlesAsync = ref.watch(adminArticlesListProvider);
    final challansAsync = ref.watch(adminChallansListProvider);

    final employees = employeesAsync.value ?? [];
    final articles = articlesAsync.value ?? [];
    final challans = challansAsync.value ?? [];

    final linemen = employees.where((e) => e.role == 'LINEMAN' && e.isActive).toList();
    final managers = employees
        .where((e) => (e.role == 'PRODUCTION_MANAGER' || e.role == 'ADMIN') && e.isActive)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'New allotment',
          style: TextStyle(
            color: Color(0xFF1C1C1A),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1C1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Step progress indicator
          const AllotmentStepIndicator(
            currentStep: 1,
            subtitle: 'Step 1 of 3 - Target & lineman assignment',
          ),

          // Scrollable Form Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.steelMist,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.steel,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step 1: Lineman & Target Style',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select the floor lineman, production order, and target delivery parameters.',
                              style: TextStyle(
                                color: AppTheme.inkSoft,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 1. Production Manager (Allotted By)
                _buildFieldLabel('Production Manager (Allotted By)'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: managers.any((m) => m.username == form.managerName)
                          ? form.managerName
                          : (managers.isNotEmpty ? managers.first.username : form.managerName),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.inkSoft),
                      items: [
                        if (managers.isEmpty)
                          DropdownMenuItem(
                            value: form.managerName,
                            child: Text(form.managerName),
                          ),
                        ...managers.map(
                          (m) => DropdownMenuItem(
                            value: m.username,
                            child: Text(
                              '${m.username} (${m.role})',
                              style: const TextStyle(color: AppTheme.ink, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(allotmentFormProvider.notifier).setManagerName(val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Assign to Lineman
                _buildFieldLabel('Assign to Lineman *'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: form.linemanId == null ? AppTheme.border : AppTheme.steel,
                      width: form.linemanId == null ? 1 : 1.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Select floor lineman...', style: TextStyle(color: AppTheme.inkFaint, fontSize: 14)),
                      value: linemen.any((l) => l.id == form.linemanId) ? form.linemanId : null,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.inkSoft),
                      items: linemen.map(
                        (l) => DropdownMenuItem(
                          value: l.id,
                          child: Text(
                            l.username,
                            style: const TextStyle(color: AppTheme.ink, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final selected = linemen.firstWhere((l) => l.id == val);
                          ref.read(allotmentFormProvider.notifier).setLineman(selected.id, selected.username);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Style Article / Target Picker
                _buildFieldLabel('Target Style Article / Job Color Line *'),
                InkWell(
                  onTap: () => _openTargetSelectorModal(articles, challans),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: form.articleId == null ? AppTheme.border : AppTheme.steel,
                        width: form.articleId == null ? 1 : 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: form.articleId != null ? AppTheme.steelMist : AppTheme.bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.checkroom_outlined,
                            color: form.articleId != null ? AppTheme.steel : AppTheme.inkFaint,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: form.articleId != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Art #${form.articleNo ?? 'N/A'}',
                                      style: const TextStyle(
                                        color: AppTheme.ink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (form.articleDesc != null && form.articleDesc!.isNotEmpty)
                                      Text(
                                        form.articleDesc!,
                                        style: const TextStyle(color: AppTheme.inkSoft, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (form.brand != null || form.fabricType != null)
                                      Text(
                                        '${form.brand ?? 'OLLYPOP'}${form.fabricType != null ? ' • ${form.fabricType}' : ''}',
                                        style: const TextStyle(color: AppTheme.steel, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                  ],
                                )
                              : const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Browse Challans & Articles',
                                      style: TextStyle(
                                        color: AppTheme.ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Tap to select a Job work challan or catalog article',
                                      style: TextStyle(color: AppTheme.inkFaint, fontSize: 12),
                                    ),
                                  ],
                                ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.inkSoft),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Priority Segmented Control
                _buildFieldLabel('Production Priority'),
                Row(
                  children: [
                    _buildPriorityChip('NORMAL', 'Normal', AppTheme.steel, form.priority == 'NORMAL'),
                    const SizedBox(width: 8),
                    _buildPriorityChip('RUSH', 'Rush Order', AppTheme.amber, form.priority == 'RUSH'),
                    const SizedBox(width: 8),
                    _buildPriorityChip('CRITICAL', 'Critical-Export', AppTheme.red, form.priority == 'CRITICAL'),
                  ],
                ),
                const SizedBox(height: 18),

                // 5. Target Due Date & Shift Hours Row
                Row(
                  children: [
                    // Due Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Target Due Date'),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: form.dueDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                ref.read(allotmentFormProvider.notifier).setDueDate(picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.inkSoft),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(form.dueDate),
                                    style: const TextStyle(color: AppTheme.ink, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Shift Hours
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Allocated Hours'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: form.targetHours > 4
                                      ? () => ref.read(allotmentFormProvider.notifier).setTargetHours(form.targetHours - 4)
                                      : null,
                                ),
                                Text(
                                  '${form.targetHours} hrs',
                                  style: const TextStyle(color: AppTheme.ink, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () => ref.read(allotmentFormProvider.notifier).setTargetHours(form.targetHours + 4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 6. PPC Speed Rate Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed, color: AppTheme.steel, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Target Line Speed (PPC)',
                              style: TextStyle(color: AppTheme.ink, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${form.pcsPerHour.toStringAsFixed(1)} pcs/hr  •  ${form.pcsPerShift.toStringAsFixed(0)} pcs/8hr shift',
                              style: const TextStyle(color: AppTheme.inkSoft, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${form.totalPieces} pcs',
                        style: const TextStyle(color: AppTheme.steel, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 7. Buyer Delivery Challan Number
                _buildFieldLabel('Buyer Delivery Challan / Job Reference'),
                TextField(
                  controller: _challanNoController,
                  decoration: InputDecoration(
                    hintText: 'e.g. JOB-458 or DC-2026-09',
                    prefixIcon: const Icon(Icons.receipt_long_outlined, size: 20, color: AppTheme.inkSoft),
                    filled: true,
                    fillColor: AppTheme.card,
                  ),
                  onChanged: (val) {
                    ref.read(allotmentFormProvider.notifier).setClientChallanNo(val);
                  },
                ),
                const SizedBox(height: 18),

                // 8. Sample Photos Picker (0/4)
                _buildFieldLabel('Buyer Sample Photos (${form.samplePhotos.length}/4)'),
                Row(
                  children: [
                    ...form.samplePhotos.map((path) => _buildPhotoThumbnail(path)),
                    if (form.samplePhotos.length < 4)
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt),
                                    title: const Text('Take Photo'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Choose from Gallery'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _pickImage(ImageSource.gallery);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 68,
                          height: 68,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 20, color: AppTheme.inkSoft),
                              SizedBox(height: 2),
                              Text('Add', style: TextStyle(color: AppTheme.inkSoft, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),

          // Sticky Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              border: const Border(top: BorderSide(color: AppTheme.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.inkSoft)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: form.isStep1Valid
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AllotmentStep2Screen(),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.steel,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.border,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue to Size Matrix', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String key, String label, Color color, bool isSelected) {
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(allotmentFormProvider.notifier).setPriority(key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppTheme.border,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String path) {
    return Stack(
      children: [
        Container(
          width: 68,
          height: 68,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
            image: DecorationImage(
              image: FileImage(File(path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 10,
          child: InkWell(
            onTap: () {
              final current = List<String>.from(ref.read(allotmentFormProvider).samplePhotos);
              current.remove(path);
              ref.read(allotmentFormProvider.notifier).setSamplePhotos(current);
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetPickerSheet extends StatefulWidget {
  final List<AdminArticle> articles;
  final List<AdminChallan> challans;
  final Function(AdminArticle) onArticleSelected;
  final Function(AdminChallan, String?) onChallanSelected;

  const _TargetPickerSheet({
    required this.articles,
    required this.challans,
    required this.onArticleSelected,
    required this.onChallanSelected,
  });

  @override
  State<_TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<_TargetPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredChallans = widget.challans.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.challanNo.toLowerCase().contains(q) ||
          c.brand.toLowerCase().contains(q) ||
          (c.fabricType?.toLowerCase().contains(q) ?? false) ||
          (c.description?.toLowerCase().contains(q) ?? false);
    }).toList();

    final filteredArticles = widget.articles.where((a) {
      final q = _searchQuery.toLowerCase();
      return a.artNo.toLowerCase().contains(q) ||
          (a.description?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Select Target Style Article or Challan',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by art no, brand, challan...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.inkSoft),
              filled: true,
              fillColor: AppTheme.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
            },
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.steel,
            unselectedLabelColor: AppTheme.inkSoft,
            indicatorColor: AppTheme.steel,
            tabs: [
              Tab(text: 'Challans / Job Orders (${filteredChallans.length})'),
              Tab(text: 'Catalog Articles (${filteredArticles.length})'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Challans
                filteredChallans.isEmpty
                    ? const Center(child: Text('No matching challans found', style: TextStyle(color: AppTheme.inkFaint)))
                    : ListView.builder(
                        itemCount: filteredChallans.length,
                        itemBuilder: (context, i) {
                          final ch = filteredChallans[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.steelMist,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_outlined, color: AppTheme.steel, size: 20),
                              ),
                              title: Text(
                                '${ch.brand} • Challan #${ch.challanNo}',
                                style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text(
                                '${ch.totalQty} pcs • ${ch.fabricType ?? 'Fabric'}',
                                style: const TextStyle(color: AppTheme.inkSoft, fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.inkSoft),
                              onTap: () => widget.onChallanSelected(ch, null),
                            ),
                          );
                        },
                      ),

                // Tab 2: Articles
                filteredArticles.isEmpty
                    ? const Center(child: Text('No matching articles found', style: TextStyle(color: AppTheme.inkFaint)))
                    : ListView.builder(
                        itemCount: filteredArticles.length,
                        itemBuilder: (context, i) {
                          final art = filteredArticles[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.steelMist,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.checkroom_outlined, color: AppTheme.steel, size: 20),
                              ),
                              title: Text(
                                'Art #${art.artNo}',
                                style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text(
                                art.description ?? 'Catalog Article',
                                style: const TextStyle(color: AppTheme.inkSoft, fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.inkSoft),
                              onTap: () => widget.onArticleSelected(art),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
