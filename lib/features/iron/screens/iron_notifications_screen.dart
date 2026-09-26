import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';

class IronNotificationsScreen extends ConsumerStatefulWidget {
  const IronNotificationsScreen({super.key});

  @override
  ConsumerState<IronNotificationsScreen> createState() => _IronNotificationsScreenState();
}

class _IronNotificationsScreenState extends ConsumerState<IronNotificationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  int _activeTab = 0; // 0 -> Ironing Division Events, 1 -> All Floor Activity, 2 -> Unread
  String _searchQuery = '';
  final List<Map<String, dynamic>> _notifications = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _markAllAsRead() {
    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: Color(0xFF047857),
      ),
    );
  }

  void _clearHistory() {
    setState(() {
      _notifications.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification history cleared'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moduleEvents = _notifications.where((n) => n['module'] == 'iron' || n['targetModule'] == 'iron').toList();
    final unreadEvents = _notifications.where((n) => n['isRead'] == false).toList();

    List<Map<String, dynamic>> currentList;
    if (_activeTab == 0) {
      currentList = moduleEvents;
    } else if (_activeTab == 1) {
      currentList = _notifications;
    } else {
      currentList = unreadEvents;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      currentList = currentList.where((n) {
        final title = (n['title'] ?? '').toString().toLowerCase();
        final message = (n['message'] ?? '').toString().toLowerCase();
        final article = (n['articleNumber'] ?? '').toString().toLowerCase();
        final worker = (n['workerName'] ?? '').toString().toLowerCase();
        return title.contains(q) || message.contains(q) || article.contains(q) || worker.contains(q);
      }).toList();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/iron/notifications'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Breadcrumbs + Live WebSocket Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Workspace Hub',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Steam Ironing Floor',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('/', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          'Notifications',
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Boiler & Vacuum Sync Active',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Encapsulated Top Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1A000000)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
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
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF3A3564),
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
                                Text(
                                  'Division 08 Feed',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5EDF9),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: const Color(0xFF2E5AA8).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${unreadEvents.length} Unread',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2E5AA8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live stream of boiler telemetry alerts, vacuum buck batch completions, and thermal QC passing logs.',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A3564),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.done_all_rounded, size: 14),
                        label: Text(
                          'Mark All Read',
                          style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _notifications.isEmpty ? null : _markAllAsRead,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0x1A000000)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        label: Text(
                          'Clear History',
                          style: GoogleFonts.publicSans(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _notifications.isEmpty ? null : _clearHistory,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.publicSans(fontSize: 13, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Filter notifications by title, article, or presser...',
                  hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 4. Tab Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton(0, 'Steam Ironing Floor (${moduleEvents.length})'),
                  const SizedBox(width: 8),
                  _buildTabButton(1, 'All Floor Activity (${_notifications.length})'),
                  const SizedBox(width: 8),
                  _buildTabButton(2, 'Unread (${unreadEvents.length})'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. Notifications List / Empty State
            if (currentList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x1A000000)),
                      ),
                      child: const Icon(
                        Icons.notifications_off_outlined,
                        color: Color(0xFF94A3B8),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Notifications to Display',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No events match your current filter "$_searchQuery".'
                          : 'Live steam ironing telemetry and finished garment QC updates will appear here in real-time.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final notif = currentList[idx];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              notif['title'] ?? 'Floor Update',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              notif['time'] ?? 'Just now',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notif['message'] ?? '',
                          style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3564) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A3564) : const Color(0x1A000000),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
