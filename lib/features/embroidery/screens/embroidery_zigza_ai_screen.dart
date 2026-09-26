import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/zigza_app_bar.dart';
import '../../modules/widgets/workspace_hub_drawer.dart';

class EmbroideryZigzaAiScreen extends ConsumerStatefulWidget {
  const EmbroideryZigzaAiScreen({super.key});

  @override
  ConsumerState<EmbroideryZigzaAiScreen> createState() => _EmbroideryZigzaAiScreenState();
}

class _EmbroideryZigzaAiScreenState extends ConsumerState<EmbroideryZigzaAiScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _chatCtrl = TextEditingController();

  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text': 'Hello! I am your Zigza AI Embroidery Assistant. I can help calculate thread cone consumption per 10,000 stitches, estimate multi-head machine run cycle times, optimize DST punch density, and calculate stitch rate billing.',
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
        'text': 'Analyzing embroidery parameters for "$txt"... \n\nRecommended: For 15,000 stitch chest emblem running on Tajima 20-Head at 850 RPM, cycle time is approx 22 minutes per 20 panels. Thread consumption: ~120m top thread (Polyester 40wt) + ~40m bobbin per panel. Backing: Tear-Away 40 GSM.',
      });
      _chatCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFAF7F0),
      drawer: const WorkspaceHubDrawer(activeRoute: '/embroidery/zigza-ai'),
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
                          'Embroidery Studio',
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
                final isAi = msg['role'] == 'ai';

                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isAi ? Colors.white : const Color(0xFF3A3564),
                      borderRadius: BorderRadius.circular(16),
                      border: isAi ? Border.all(color: Colors.black.withValues(alpha: 0.08)) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAi ? Icons.auto_awesome : Icons.person_outline,
                              size: 14,
                              color: isAi ? const Color(0xFF3A3564) : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAi ? 'Zigza AI Embroidery Copilot' : 'Floor Supervisor',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isAi ? const Color(0xFF3A3564) : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          msg['text']!,
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            color: isAi ? const Color(0xFF0F172A) : Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Chat Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0x14000000))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      onSubmitted: (_) => _sendMessage(),
                      style: GoogleFonts.publicSans(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ask about stitch rates, machine RPM, punch density...',
                        hintStyle: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3A3564), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3564),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
