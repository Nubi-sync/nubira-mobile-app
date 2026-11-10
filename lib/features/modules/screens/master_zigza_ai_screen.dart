import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../widgets/workspace_hub_drawer.dart';
import '../../auth/providers/auth_provider.dart';

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

  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content':
          'Hello! I am **Zigza AI Master Copilot**. I provide executive cross-division intelligence across all 11 apparel manufacturing divisions, central fabric godown, and dispatch logistics. How can I assist you with floor operations today?',
    },
  ];

  final List<Map<String, String>> _quickQueries = [
    {
      'title': '📊 Enterprise Health Check',
      'prompt': 'Give me an overall factory health check across all operational divisions including total running orders, ready stock, and dispatches.',
    },
    {
      'title': '🧵 Fabric Store & Rolls',
      'prompt': 'Show current fabric store balance, active rolls in godown, and pending mill deliveries.',
    },
    {
      'title': '📦 Floor Output & Output',
      'prompt': 'What is today\'s floor production output across cutting, printing, and sewing lines?',
    },
    {
      'title': '✅ QC Rates & Clinic',
      'prompt': 'What is our first-time-through (FTT) quality pass rate and current alteration load?',
    },
    {
      'title': '🚚 Active Dispatches',
      'prompt': 'List all packed finished goods and pending buyer delivery challans for today.',
    },
  ];

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendQuery(String prompt) {
    if (prompt.trim().isEmpty || _isGenerating) return;

    final userQuery = prompt.trim();
    setState(() {
      _messages.add({'role': 'user', 'content': userQuery});
      _isGenerating = true;
      _promptCtrl.clear();
    });

    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      final authState = ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Demo Industries';
      final q = userQuery.toLowerCase();

      String response;
      if (q.contains('health') || q.contains('overall') || q.contains('enterprise')) {
        response = '### 🏭 $company Enterprise Health Check\n\n'
            '- **Operating Divisions:** 11 active units fully connected.\n'
            '- **Active Work Orders:** 8 active purchase orders across 4 major retail buyers.\n'
            '- **Daily Production Pace:** 1,420 / 1,600 target pieces (88.7% target efficiency).\n'
            '- **Material Fulfillment:** 94.2% fabric lots inspected and approved for lay floor.\n'
            '- **Executive Status:** All floor lines operating normally with zero critical bottlenecks.';
      } else if (q.contains('fabric') || q.contains('store') || q.contains('roll') || q.contains('mill')) {
        response = '### 🧵 Central Fabric Store & Godown Status\n\n'
            '- **Total Available Rolls:** 142 inspected rolls (~4,850 kg).\n'
            '- **Shade Continuity:** 100% 4-point system pass on current single-jersey lots.\n'
            '- **Allocated to Cutting:** 18 rolls staged on Spreading Table 01.\n'
            '- **Pending Inward Mill Gate-Passes:** 2 consignments expected before 4:00 PM.';
      } else if (q.contains('output') || q.contains('piece') || q.contains('cut') || q.contains('sew')) {
        response = '### ⚙️ Multi-Division Floor Output\n\n'
            '- **03 Cutting Floor:** 4 lays completed, 850 cut pieces bundled with QR tickets.\n'
            '- **04 Printing Studio:** 620 chest print impressions completed.\n'
            '- **06 Sewing Floor:** 12 active stations operating at 91% line balance efficiency.\n'
            '- **08 Finishing & Iron:** 490 pieces steam-pressed and tagged.';
      } else if (q.contains('qc') || q.contains('quality') || q.contains('defect') || q.contains('clinic')) {
        response = '### ✅ Quality Clinic & Inspection Audit\n\n'
            '- **First-Time-Through (FTT) Rate:** 96.8% (Target: >=95%).\n'
            '- **Top Minor Defects:** Uneven hem margin (1.2%), loose thread ends (0.9%).\n'
            '- **Alteration Queue:** 14 garments undergoing mending before secondary sign-off.\n'
            '- **Export Carton Audit:** 100% pre-shipment AQL 2.5 pass.';
      } else if (q.contains('dispatch') || q.contains('challan') || q.contains('delivery') || q.contains('truck')) {
        response = '### 🚚 Dispatch Logistics & Shipments\n\n'
            '- **Ready for Dispatch:** 320 packed export master cartons.\n'
            '- **Active Outward Challans:** DC-2026-0881 confirmed gate-out to port godown.\n'
            '- **Vehicle Manifest:** Logistics truck assigned and loading dock active.';
      } else {
        response = '### 💡 Zigza AI Master Intelligence\n\n'
            'I have cross-referenced live data across your divisions for "$userQuery":\n\n'
            '- **Factory Floor:** Connected to all 11 stations for $company.\n'
            '- **Live ERP Sync:** Floor logs, supervisor challans, and QR bundle events are current.\n'
            '- **Recommendation:** Check the specific department module if you need detailed machine-level telemetry.';
      }

      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isGenerating = false;
      });

      _scrollToBottom();
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawerScrimColor: const Color(0x66000000),
      drawer: const WorkspaceHubDrawer(activeRoute: '/zigza-ai'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        trailing: IconButton(
          tooltip: 'Reset Conversation',
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0B1220), size: 20),
          onPressed: () {
            setState(() {
              _messages.clear();
              _messages.add({
                'role': 'assistant',
                'content':
                    'Conversation reset. I am **Zigza AI Master Copilot**. How can I assist your factory floor operations today?',
              });
            });
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Sleek, Decluttered Executive Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      child: Icon(Icons.auto_awesome, color: Color(0xFF0B1220), size: 17),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w800,
                            ),
                            children: const [
                              TextSpan(text: 'Zigza AI • ', style: TextStyle(color: Color(0xFF0B1220))),
                              TextSpan(text: 'Master Copilot', style: TextStyle(color: Color(0xFF1D4ED8))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF14C8B4).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'OWNER AI',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B1220),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Streamlined Quick Query Chips
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.white,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _quickQueries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final q = _quickQueries[i];
                  return InkWell(
                    onTap: _isGenerating ? null : () => _sendQuery(q['prompt']!),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          q['title']!,
                          style: GoogleFonts.publicSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),

            // 3. Conversation Message Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (ctx, idx) {
                  final msg = _messages[idx];
                  final isUser = msg['role'] == 'user';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: isUser ? const Color(0xFFF0FDFA) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: isUser ? const Radius.circular(14) : const Radius.circular(2),
                                bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(14),
                              ),
                              border: Border.all(
                                color: isUser ? const Color(0xFF14C8B4).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x05000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: _buildFormattedMessage(msg['content']!, isUser),
                          ),
                        ),
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

            // 4. Pinned Input Bar
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

  Widget _buildFormattedMessage(String content, bool isUser) {
    if (isUser) {
      return Text(
        content,
        style: GoogleFonts.publicSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
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
        style: GoogleFonts.publicSans(
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
