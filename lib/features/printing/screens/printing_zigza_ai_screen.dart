import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';

class PrintingZigzaAiScreen extends ConsumerStatefulWidget {
  const PrintingZigzaAiScreen({super.key});

  @override
  ConsumerState<PrintingZigzaAiScreen> createState() => _PrintingZigzaAiScreenState();
}

class _PrintingZigzaAiScreenState extends ConsumerState<PrintingZigzaAiScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _chatCtrl = TextEditingController();

  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text': 'Hello! I am your Zigza AI Printing Assistant. I can help calculate ink consumption per 1,000 impressions, verify curing conveyor temperature curves, and evaluate strike-off color delta-E ratings.',
    },
  ];

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final txt = _chatCtrl.text.trim();
    if (txt.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': txt});
      _messages.add({
        'role': 'ai',
        'text': 'Analyzing print specifications for "$txt"... \n\nRecommended: For 100% cotton with plastisol ink, maintain 162°C–165°C conveyor chamber temp with 2.5 min dwell. Strike-off color tolerance Delta E < 0.5 meets standard international AQL buyer sign-off.',
      });
      _chatCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/printing/zigza-ai'),
      appBar: ZigzaAppBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: Column(
        children: [
          // Breadcrumb Header Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, size: 13, color: Color(0xFF3A3564)),
                        const SizedBox(width: 4),
                        Text(
                          'Printing Studio',
                          style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3A3564)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ Zigza AI Copilot',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final msg = _messages[idx];
                final isUser = msg['role'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF3A3564) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isUser ? Colors.transparent : Colors.black.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Text(
                      msg['text']!,
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        color: isUser ? Colors.white : const Color(0xFF0F172A),
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    child: TextField(
                      controller: _chatCtrl,
                      onSubmitted: (_) => _sendMessage(),
                      style: GoogleFonts.publicSans(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ask about ink mesh, oven temps, pantones...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3564),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
