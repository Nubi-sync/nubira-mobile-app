import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../widgets/workspace_hub_drawer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../main.dart';

class ChatSession {
  final String id;
  String title;
  final List<Map<String, dynamic>> messages;
  int updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages,
        'updatedAt': updatedAt,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id']?.toString() ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'New Conversation',
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList(),
      updatedAt: (json['updatedAt'] is int)
          ? json['updatedAt'] as int
          : (int.tryParse(json['updatedAt']?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch),
    );
  }
}

class MasterZigzaAiScreen extends ConsumerStatefulWidget {
  const MasterZigzaAiScreen({super.key});

  @override
  ConsumerState<MasterZigzaAiScreen> createState() => _MasterZigzaAiScreenState();
}

class _MasterZigzaAiScreenState extends ConsumerState<MasterZigzaAiScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isGenerating = false;

  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _isHistoryOpen = false;
  int _historyPage = 1;
  static const int _itemsPerPage = 5;

  final List<Map<String, dynamic>> _practicalCards = [
    {
      'icon': Icons.layers_outlined,
      'title': "Today's Floor Production",
      'subtitle': "Stitched piece count, line speed, and today's target.",
      'prompt': "What is today's total production output across all sewing lines, and how are we tracking against target?",
    },
    {
      'icon': Icons.store_mall_directory_outlined,
      'title': "Fabric Rolls & Godown Stock",
      'subtitle': "Cloth meters available, roll counts, and pending mill arrivals.",
      'prompt': "Show current fabric store balance, available rolls in godown, and pending mill deliveries.",
    },
    {
      'icon': Icons.business_center_outlined,
      'title': "Running Orders & Ship Dates",
      'subtitle': "Active buyer orders, completion status, and delivery deadlines.",
      'prompt': "List all active buyer purchase orders, quantities stitched so far, and upcoming delivery deadlines.",
    },
    {
      'icon': Icons.check_circle_outline_rounded,
      'title': "Alterations & Quality Rejections",
      'subtitle': "First-time pass rate, repair queue, and defect issues.",
      'prompt': "What is our quality pass rate today? Show alteration pieces in mending and common defect types.",
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistoryFromCloudAndLocal();
    });
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _getStoragePath(String email, [String portal = 'modules']) {
    final sanitizedEmail = email.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9@._-]'), '_');
    final sanitizedPortal = portal.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    return '${sanitizedEmail}_$sanitizedPortal.json';
  }

  Future<void> _loadHistoryFromCloudAndLocal() async {
    final authState = ref.read(authProvider);
    final email = (authState.tenantProfile?.userEmail ??
            supabase.auth.currentUser?.email ??
            authState.cachedUsername ??
            '')
        .trim();

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'zigza_ai_sessions_modules_${email.isNotEmpty ? email : "default"}';

    // 1. Instant display from local cache
    final cachedStr = prefs.getString(cacheKey);
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(cachedStr) as List;
        final cachedSessions = decoded
            .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (cachedSessions.isNotEmpty && mounted) {
          setState(() {
            _sessions = cachedSessions;
            _currentSessionId = cachedSessions.first.id;
          });
        }
      } catch (_) {}
    }

    // 2. Multi-Candidate Supabase Cloud Storage lookups
    final candidatePaths = <String>[];
    if (email.isNotEmpty) {
      final sanitized = email.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9@._-]'), '_');
      candidatePaths.add('${sanitized}_modules.json');
      candidatePaths.add('${sanitized}_stitching-sewing.json');
      candidatePaths.add('$sanitized.json');
    }
    candidatePaths.add('admin@demo.com_modules.json');
    candidatePaths.add('admin@demo.com_stitching-sewing.json');
    candidatePaths.add('admin@demo.com.json');

    List<dynamic>? cloudList;

    for (final path in candidatePaths) {
      if (cloudList != null && cloudList.isNotEmpty) break;
      try {
        final bytes = await supabase.storage.from('ai_chat_history').download(path);
        if (bytes.isNotEmpty) {
          final parsed = jsonDecode(utf8.decode(bytes));
          if (parsed is List && parsed.isNotEmpty) {
            cloudList = parsed;
            debugPrint('Loaded cloud history from: $path');
            break;
          }
        }
      } catch (_) {}

      if (cloudList == null || cloudList.isEmpty) {
        try {
          final publicUrl =
              'https://nnhzqvdmkarpwtkzjnra.supabase.co/storage/v1/object/public/ai_chat_history/$path';
          final response = await http.get(
            Uri.parse(publicUrl),
            headers: {
              'apikey': 'sb_publishable_WRZgkU7XhqbK3HSGRFMfDQ_o2JLnTMF',
              'Authorization': 'Bearer sb_publishable_WRZgkU7XhqbK3HSGRFMfDQ_o2JLnTMF',
            },
          );
          if (response.statusCode == 200 && response.body.isNotEmpty) {
            final parsed = jsonDecode(response.body);
            if (parsed is List && parsed.isNotEmpty) {
              cloudList = parsed;
              debugPrint('Loaded cloud history via HTTP from: $path');
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 3. Fallback: inspect bucket list for any matching file
    if (cloudList == null || cloudList.isEmpty) {
      try {
        final fileObjects = await supabase.storage.from('ai_chat_history').list();
        for (final file in fileObjects) {
          final fname = file.name.toLowerCase();
          if (fname.endsWith('.json') &&
              (fname.contains('demo') || (email.isNotEmpty && fname.contains(email.split('@').first.toLowerCase())))) {
            try {
              final bytes = await supabase.storage.from('ai_chat_history').download(file.name);
              if (bytes.isNotEmpty) {
                final parsed = jsonDecode(utf8.decode(bytes));
                if (parsed is List && parsed.isNotEmpty) {
                  cloudList = parsed;
                  debugPrint('Found matched history file from bucket list: ${file.name}');
                  break;
                }
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Bucket list check: $e');
      }
    }

    if (cloudList != null && cloudList.isNotEmpty) {
      final cloudSessions = cloudList
          .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (mounted && cloudSessions.isNotEmpty) {
        setState(() {
          _sessions = cloudSessions;
          if (_currentSessionId == null || !_sessions.any((s) => s.id == _currentSessionId)) {
            _currentSessionId = cloudSessions.first.id;
          }
        });
        await prefs.setString(cacheKey, jsonEncode(_sessions.map((s) => s.toJson()).toList()));
      }
    }

    if (_sessions.isEmpty && mounted) {
      _createNewSession(persist: false);
    }
  }

  Future<void> _persistSessions() async {
    final authState = ref.read(authProvider);
    final email = (authState.tenantProfile?.userEmail ??
            supabase.auth.currentUser?.email ??
            authState.cachedUsername ??
            '')
        .trim();

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'zigza_ai_sessions_modules_${email.isNotEmpty ? email : "default"}';
    final jsonString = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString(cacheKey, jsonString);

    final pathsToUpload = <String>[];
    if (email.isNotEmpty) {
      pathsToUpload.add(_getStoragePath(email, 'modules'));
    }
    pathsToUpload.add('admin@demo.com_modules.json');

    for (final path in pathsToUpload) {
      try {
        await supabase.storage.from('ai_chat_history').uploadBinary(
              path,
              Uint8List.fromList(utf8.encode(jsonString)),
              fileOptions: const FileOptions(upsert: true),
            );
      } catch (err) {
        debugPrint('Supabase persist error: $err');
      }
    }
  }

  void _createNewSession({bool persist = true}) {
    final fresh = ChatSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Conversation',
      messages: [],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _sessions.insert(0, fresh);
      _currentSessionId = fresh.id;
      _isHistoryOpen = false;
      _historyPage = 1;
    });

    if (persist) {
      _persistSessions();
    }
  }

  void _deleteSession(String id) {
    setState(() {
      _sessions.removeWhere((s) => s.id == id);
      if (_sessions.isEmpty) {
        _createNewSession(persist: true);
      } else {
        if (_currentSessionId == id) {
          _currentSessionId = _sessions.first.id;
        }
        final totalPages = math.max(1, (_sessions.length / _itemsPerPage).ceil());
        if (_historyPage > totalPages) {
          _historyPage = totalPages;
        }
      }
    });
    _persistSessions();
  }

  void _sendQuery(String prompt) {
    if (prompt.trim().isEmpty || _isGenerating) return;

    final userQuery = prompt.trim();
    final nowStr = DateFormat('hh:mm a').format(DateTime.now());

    ChatSession currentSession;
    final foundIndex = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (foundIndex != -1) {
      currentSession = _sessions[foundIndex];
    } else {
      currentSession = ChatSession(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        title: userQuery.length > 32 ? '${userQuery.substring(0, 32)}...' : userQuery,
        messages: [],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _sessions.insert(0, currentSession);
      _currentSessionId = currentSession.id;
    }

    if (currentSession.title == 'New Conversation' || currentSession.messages.isEmpty) {
      currentSession.title = userQuery.length > 32 ? '${userQuery.substring(0, 32)}...' : userQuery;
    }

    setState(() {
      currentSession.messages.add({
        'id': 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
        'role': 'user',
        'content': userQuery,
        'timestamp': nowStr,
      });
      currentSession.updatedAt = DateTime.now().millisecondsSinceEpoch;
      _isGenerating = true;
      _promptCtrl.clear();
    });

    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      final authState = ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Demo Industries';
      final q = userQuery.toLowerCase();

      String response;
      if (q.contains('health') || q.contains('overall') || q.contains('enterprise')) {
        response = '### $company Enterprise Health Check\n\n'
            '- **Operating Divisions:** 11 active units fully connected.\n'
            '- **Active Work Orders:** 8 active purchase orders across 4 major retail buyers.\n'
            '- **Daily Production Pace:** 1,420 / 1,600 target pieces (88.7% target efficiency).\n'
            '- **Material Fulfillment:** 94.2% fabric lots inspected and approved for lay floor.\n'
            '- **Executive Status:** All floor lines operating normally with zero critical bottlenecks.';
      } else if (q.contains('fabric') || q.contains('store') || q.contains('roll') || q.contains('mill')) {
        response = '### Central Fabric Store & Godown Status\n\n'
            '- **Total Available Rolls:** 142 inspected rolls (~4,850 kg).\n'
            '- **Shade Continuity:** 100% 4-point system pass on current single-jersey lots.\n'
            '- **Allocated to Cutting:** 18 rolls staged on Spreading Table 01.\n'
            '- **Pending Inward Mill Gate-Passes:** 2 consignments expected before 4:00 PM.';
      } else if (q.contains('output') || q.contains('piece') || q.contains('cut') || q.contains('sew')) {
        response = '### Multi-Division Floor Output\n\n'
            '- **03 Cutting Floor:** 4 lays completed, 850 cut pieces bundled with QR tickets.\n'
            '- **04 Printing Studio:** 620 chest print impressions completed.\n'
            '- **06 Sewing Floor:** 12 active stations operating at 91% line balance efficiency.\n'
            '- **08 Finishing & Iron:** 490 pieces steam-pressed and tagged.';
      } else if (q.contains('qc') || q.contains('quality') || q.contains('defect') || q.contains('clinic')) {
        response = '### Quality Clinic & Inspection Audit\n\n'
            '- **First-Time-Through (FTT) Rate:** 96.8% (Target: >=95%).\n'
            '- **Top Minor Defects:** Uneven hem margin (1.2%), loose thread ends (0.9%).\n'
            '- **Alteration Queue:** 14 garments undergoing mending before secondary sign-off.\n'
            '- **Export Carton Audit:** 100% pre-shipment AQL 2.5 pass.';
      } else if (q.contains('dispatch') || q.contains('challan') || q.contains('delivery') || q.contains('truck')) {
        response = '### Dispatch Logistics & Shipments\n\n'
            '- **Ready for Dispatch:** 320 packed export master cartons.\n'
            '- **Active Outward Challans:** DC-2026-0881 confirmed gate-out to port godown.\n'
            '- **Vehicle Manifest:** Logistics truck assigned and loading dock active.';
      } else {
        response = '### Zigza AI Master Intelligence\n\n'
            'I have cross-referenced live data across your divisions for "$userQuery":\n\n'
            '- **Factory Floor:** Connected to all 11 stations for $company.\n'
            '- **Live ERP Sync:** Floor logs, supervisor challans, and QR bundle events are current.\n'
            '- **Recommendation:** Check the specific department module if you need detailed machine-level telemetry.';
      }

      setState(() {
        currentSession.messages.add({
          'id': 'msg_bot_${DateTime.now().millisecondsSinceEpoch}',
          'role': 'assistant',
          'content': response,
          'timestamp': DateFormat('hh:mm a').format(DateTime.now()),
        });
        currentSession.updatedAt = DateTime.now().millisecondsSinceEpoch;
        _isGenerating = false;
      });

      _scrollToBottom();
      _persistSessions();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final company = authState.tenantProfile?.companyName ?? 'Demo Industries';

    final rawEmail = authState.tenantProfile?.userEmail ??
        supabase.auth.currentUser?.email ??
        authState.cachedUsername ??
        'AD';
    final userInitials = rawEmail.trim().isNotEmpty
        ? (rawEmail.trim().length >= 2
            ? rawEmail.trim().substring(0, 2).toUpperCase()
            : rawEmail.trim().toUpperCase())
        : 'AD';

    final currentSession = _sessions.firstWhere(
      (s) => s.id == _currentSessionId,
      orElse: () => _sessions.isNotEmpty
          ? _sessions.first
          : ChatSession(
              id: 'fallback',
              title: 'New Conversation',
              messages: [],
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
    );

    final totalPages = math.max(1, (_sessions.length / _itemsPerPage).ceil());
    final startIndex = (_historyPage - 1) * _itemsPerPage;
    final paginatedSessions = _sessions.skip(startIndex).take(_itemsPerPage).toList();

    if (_sessions.isEmpty && !authState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sessions.isEmpty && mounted) {
          _loadHistoryFromCloudAndLocal();
        }
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawerScrimColor: const Color(0x66000000),
      drawer: const WorkspaceHubDrawer(activeRoute: '/zigza-ai'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Box Top Header: Zigza AI + Beside it History / Collapse Button (No tags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x26000000)),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: Color(0xFF0B1220), size: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Zigza AI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                  ),

                  // New Chat Button
                  InkWell(
                    onTap: () => _createNewSession(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.add, size: 18, color: Color(0xFF0B1220)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // History / Collapse Button with Transition
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isHistoryOpen = !_isHistoryOpen;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isHistoryOpen ? const Color(0xFFF0FDFA) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isHistoryOpen
                              ? const Color(0xFF1D4ED8).withValues(alpha: 0.4)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isHistoryOpen ? Icons.keyboard_arrow_up_rounded : Icons.history_rounded,
                            size: 16,
                            color: _isHistoryOpen ? const Color(0xFF1D4ED8) : const Color(0xFF0B1220),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isHistoryOpen ? 'Collapse' : 'History (${_sessions.length})',
                            style: GoogleFonts.publicSans(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              color: _isHistoryOpen ? const Color(0xFF1D4ED8) : const Color(0xFF0B1220),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Expandable History Panel with Pagination of 5
            if (_isHistoryOpen) ...[
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 14, color: Color(0xFF0B1220)),
                            const SizedBox(width: 6),
                            Text(
                              'PREVIOUS CHATS (${_sessions.length})',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0B1220),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _createNewSession(),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'New Chat',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 5 Paginated Sessions
                    ...paginatedSessions.map((s) {
                      final isActive = s.id == _currentSessionId;
                      final dateStr = DateFormat('MMM dd').format(
                        DateTime.fromMillisecondsSinceEpoch(s.updatedAt),
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive ? const Color(0xFF14C8B4) : const Color(0xFFE2E8F0),
                            width: isActive ? 1.2 : 1.0,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF14C8B4).withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  )
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _currentSessionId = s.id;
                                _isHistoryOpen = false;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive ? const Color(0xFF14C8B4) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s.title.isNotEmpty ? s.title : 'New Conversation',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 12.0,
                                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                        color: isActive ? const Color(0xFF0B1220) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => _deleteSession(s.id),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 15,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Pagination Controls (5 per page)
                    if (totalPages > 1) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(60, 30),
                              backgroundColor: Colors.white,
                            ),
                            onPressed: _historyPage > 1 ? () => setState(() => _historyPage--) : null,
                            icon: const Icon(Icons.chevron_left, size: 16),
                            label: const Text('Prev', style: TextStyle(fontSize: 11)),
                          ),
                          Text(
                            'Page $_historyPage of $totalPages',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(60, 30),
                              backgroundColor: Colors.white,
                            ),
                            onPressed: _historyPage < totalPages ? () => setState(() => _historyPage++) : null,
                            icon: const Icon(Icons.chevron_right, size: 16),
                            label: const Text('Next', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
            ],

            // 3. Conversation Message Stream or New Conversation Welcome Screen
            Expanded(
              child: currentSession.messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      itemCount: currentSession.messages.length,
                      itemBuilder: (ctx, idx) {
                        final msg = currentSession.messages[idx];
                        final isUser = msg['role'] == 'user';
                        final timestamp = (msg['timestamp'] as String?)?.isNotEmpty == true
                            ? msg['timestamp'] as String
                            : DateFormat('hh:mm a').format(DateTime.now());

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Assistant Avatar (Left)
                              if (!isUser) ...[
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0x1F000000)),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0B1220)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // Message Bubble + Meta (Timestamp & Copy)
                              Column(
                                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.74 : 0.78),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: isUser ? const Color(0xFFF0FDFA) : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: Radius.circular(isUser ? 4 : 16),
                                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                                          bottomRight: const Radius.circular(16),
                                        ),
                                        border: Border.all(
                                          color: isUser
                                              ? const Color(0xFF14C8B4).withValues(alpha: 0.4)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x05000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: _buildFormattedMessage(msg['content']?.toString() ?? '', isUser),
                                    ),
                                  ),

                                  // Timestamp & Copy row below bubble
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: 4,
                                      left: isUser ? 0 : 2,
                                      right: isUser ? 2 : 0,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          timestamp,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        if (!isUser) ...[
                                          const SizedBox(width: 12),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: msg['content']?.toString() ?? ''));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Copied to clipboard'),
                                                  duration: Duration(seconds: 1),
                                                ),
                                              );
                                            },
                                            child: Row(
                                              children: [
                                                const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Copy',
                                                  style: GoogleFonts.publicSans(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // User Avatar Badge (Right)
                              if (isUser) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF14C8B4).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      userInitials,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0B1220),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),

            if (_isGenerating)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analyzing factory divisions...',
                      style: GoogleFonts.publicSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

            // 5. Pinned Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _promptCtrl,
                        onSubmitted: _sendQuery,
                        enabled: !_isGenerating,
                        style: GoogleFonts.publicSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0B1220),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask about $company orders, stock, floor...',
                          hintStyle: GoogleFonts.publicSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF94A3B8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isGenerating ? null : () => _sendQuery(_promptCtrl.text),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x331D4ED8),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'What would you like to check in your factory?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19.0,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0B1220),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Ask anything about today\'s production, fabric rolls in godown, buyer orders, and quality inspection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 4 Actionable Cards
          ..._practicalCards.map((card) {
            return Container(
              margin: const EdgeInsets.only(bottom: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isGenerating ? null : () => _sendQuery(card['prompt'] as String),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x1F000000)),
                          ),
                          child: Center(
                            child: Icon(
                              card['icon'] as IconData,
                              size: 18,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card['title'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0B1220),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                card['subtitle'] as String,
                                style: GoogleFonts.publicSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFormattedMessage(String content, bool isUser) {
    if (isUser) {
      return Text(
        content,
        style: GoogleFonts.publicSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0B1220),
          height: 1.35,
        ),
      );
    }

    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              trimmed.replaceFirst('### ', ''),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B1220),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('- ')) {
        final bulletText = trimmed.replaceFirst('- ', '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5, right: 6),
                  child: Icon(Icons.circle, size: 4.5, color: Color(0xFF0B1220)),
                ),
                Expanded(
                  child: _buildMarkdownRichText(bulletText),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildMarkdownRichText(trimmed),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildMarkdownRichText(String text) {
    final spans = <TextSpan>[];
    final reg = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in reg.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: GoogleFonts.publicSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
            height: 1.35,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0B1220),
          height: 1.35,
        ),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: GoogleFonts.publicSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1E293B),
          height: 1.35,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
