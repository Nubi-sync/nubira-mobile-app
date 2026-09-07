import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../providers/admin_providers.dart';

class ArticlesScreen extends ConsumerStatefulWidget {
  const ArticlesScreen({super.key});

  @override
  ConsumerState<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends ConsumerState<ArticlesScreen> {
  void _showAddArticleDialog() {
    final artNoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '12.50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Article / Style Code',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: artNoCtrl,
              decoration: const InputDecoration(labelText: 'Article Number *', hintText: 'e.g. 9437'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description / Category', hintText: 'e.g. Boys Rib Collar Tee'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Stitching Rate (₹ / Piece) *'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.steel,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final artNo = artNoCtrl.text.trim();
              final rate = double.tryParse(rateCtrl.text.trim()) ?? 0.0;

              if (artNo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid Article Number.')),
                );
                return;
              }

              try {
                await supabase.from('articles').insert({
                  'art_no': artNo,
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'stitching_rate': rate,
                  'is_active': true,
                });

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ref.invalidate(adminArticlesListProvider);
                ref.invalidate(adminDashboardProvider);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.green,
                    content: Text('Article created successfully!'),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Save Article'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(adminArticlesListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        elevation: 0,
        title: Text(
          'Articles & Piece Rates',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.steel),
            tooltip: 'Add Article',
            onPressed: _showAddArticleDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.steel,
        onRefresh: () async {
          ref.invalidate(adminArticlesListProvider);
        },
        child: articlesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.steel),
          ),
          error: (err, stack) => Center(
            child: Text('Error: ${err.toString()}'),
          ),
          data: (articles) {
            if (articles.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sell_outlined, size: 48, color: AppTheme.inkFaint),
                      const SizedBox(height: 12),
                      Text(
                        'No Articles Defined',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              itemBuilder: (ctx, index) {
                final art = articles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.steelMist,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.tag, color: AppTheme.steel, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Art #${art.artNo}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                art.description ?? 'General Garment',
                                style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.inkSoft),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${art.stitchingRate.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.steel,
                            ),
                          ),
                          Text(
                            'per piece',
                            style: GoogleFonts.publicSans(fontSize: 11, color: AppTheme.inkFaint),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
