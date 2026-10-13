import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/screens/enterprise_workspace_hub_screen.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';
import '../providers/cutting_provider.dart';

class CuttingZigzaAiScreen extends ConsumerStatefulWidget {
  const CuttingZigzaAiScreen({super.key});

  @override
  ConsumerState<CuttingZigzaAiScreen> createState() => _CuttingZigzaAiScreenState();
}

class _CuttingZigzaAiScreenState extends ConsumerState<CuttingZigzaAiScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isGenerating = false;

  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': 'Hello! I am **Zigza AI Cutting Floor Intelligence**. I can analyze your fabric consumption, marker efficiency, roll end-loss, and vacuum auto-cutter scheduling. How can I assist you today?',
    },
  ];

  final List<Map<String, String>> _presetQueries = [
    {
      'title': 'Daily Cut Pieces & Lots',
      'desc': 'Review fabric lays completed and total pieces cut today.',
      'prompt': 'Show today\'s cutting logs, total fabric meters consumed, and pieces cut across styles.',
    },
    {
      'title': 'Bundle QR Allocations',
      'desc': 'Lineman bundle ticket generation and line handover.',
      'prompt': 'How many cutting bundles were issued to sewing lines today? Show line-wise breakdown.',
    },
    {
      'title': 'Marker Efficiency & Yield',
      'desc': 'Fabric utilization percentage and end-bit scrap tracking.',
      'prompt': 'What is our average marker efficiency and fabric wastage percentage for current cutting lots?',
    },
  ];

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendQuery(String prompt) {
    if (prompt.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': prompt.trim()});
      _isGenerating = true;
      _promptCtrl.clear();
    });

    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final cuttingState = ref.read(cuttingProvider);
      final totalPcs = cuttingState.totalContractedPieces;
      final completedPcs = cuttingState.completedCuttingPieces;
      final laysCount = cuttingState.laySheets.length;
      final bundleCount = cuttingState.bundles.length;

      String aiResponse;
      final q = prompt.toLowerCase();
      if (q.contains('marker') || q.contains('efficiency') || q.contains('yield')) {
        aiResponse = '### ✂️ CAD Marker & Nesting Efficiency Report\n\n'
            '- **Average Marker Efficiency:** 89.6% across active styles (Gerber AccuMark).\n'
            '- **Fabric Scrap / End-Bit Loss:** ~2.4% (well within 3.0% standard tolerance).\n'
            '- **Recommendation:** Increase ply nesting to 6-ratio layout on Style `TP-2026-8801` to gain an estimated +1.2% fabric yield savings.';
      } else if (q.contains('bundle') || q.contains('qr') || q.contains('sewing')) {
        aiResponse = '### 📦 Bundle QR Dispatch & Line Handover Summary\n\n'
            '- **Total Serialized Bundles Generated:** $bundleCount bundles ($completedPcs pieces).\n'
            '- **Current Line Allocations:**\n'
            '  - **04 Printing Division:** 2 bundles in transit (50 pcs).\n'
            '  - **06 Sewing Floor Line 01:** 1 bundle confirmed handover (25 pcs).\n'
            '- **Barcode Tracking:** 100% QR tickets scanned at vacuum table.';
      } else {
        aiResponse = '### 📊 Daily Cutting Floor Status & Output\n\n'
            '- **Total Contracted Pieces:** $totalPcs pcs.\n'
            '- **Completed Cut Output:** $completedPcs pcs.\n'
            '- **Active Spreading Lays:** $laysCount active lay sheets on Tables 01 & 02.\n'
            '- **Vacuum Knife Uptime:** 98.4% (Gerber Paragon HX online).';
      }

      setState(() {
        _messages.add({'role': 'assistant', 'content': aiResponse});
        _isGenerating = false;
      });

      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgCanvas,
      drawer: const WorkspaceHubDrawer(activeRoute: '/cutting/zigza-ai'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.headingObsidian),
          onPressed: () {
            setState(() {
              _messages.clear();
              _messages.add({
                'role': 'assistant',
                'content': 'Hello! I am **Zigza AI Cutting Floor Intelligence**. How can I assist you with marker yield, fabric consumption, and line dispatches today?',
              });
            });
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.cardSurface,
                border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const EnterpriseWorkspaceHubScreen()),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppTheme.bodyInk),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.mintSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppTheme.headingObsidian, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                children: const [
                                  TextSpan(text: 'Cutting Floor ', style: TextStyle(color: AppTheme.headingObsidian)),
                                  TextSpan(text: 'AI Copilot', style: TextStyle(color: AppTheme.brandRoyalBlue)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.badgeEmeraldBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.badgeEmeraldBorder),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.badgeEmeraldText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Yield optimizer & fabric consumption neural model',
                          style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.bodyInk),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Messages & Preset Prompts Area
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Preset Queries Carousel
                  Text(
                    'QUICK ASSISTANT QUERIES',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.bodyInk,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presetQueries.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final p = _presetQueries[i];
                        return InkWell(
                          onTap: () => _sendQuery(p['prompt']!),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 230,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['title']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.headingObsidian,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p['desc']!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.bodyInk),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.borderLight),
                  const SizedBox(height: 8),

                  // Chat Message List
                  ..._messages.map((m) {
                    final isUser = m['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                        decoration: BoxDecoration(
                          color: isUser ? AppTheme.brandRoyalBlue : AppTheme.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUser ? AppTheme.brandRoyalBlue : AppTheme.borderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 14, color: AppTheme.brandRoyalBlue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Zigza AI Cutting Engine',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.brandRoyalBlue,
                                    ),
                                  ),
                                ],
                              ),
                            if (!isUser) const SizedBox(height: 6),
                            Text(
                              m['content']!,
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                height: 1.4,
                                color: isUser ? Colors.white : AppTheme.headingObsidian,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  if (_isGenerating)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandRoyalBlue),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Analyzing cutting floor parameters...',
                              style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.bodyInk),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.cardSurface,
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptCtrl,
                      onSubmitted: _sendQuery,
                      style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.headingObsidian),
                      decoration: InputDecoration(
                        hintText: 'Ask about marker yield, roll consumption, bundles...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.bodyInk),
                        filled: true,
                        fillColor: AppTheme.bgCanvas,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.brandRoyalBlue, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.brandRoyalBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendQuery(_promptCtrl.text),
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
}
