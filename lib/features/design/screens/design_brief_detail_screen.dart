import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/design_brief_model.dart';
import '../providers/designer_provider.dart';

class DesignBriefDetailScreen extends ConsumerStatefulWidget {
  final DesignBriefModel brief;

  const DesignBriefDetailScreen({super.key, required this.brief});

  @override
  ConsumerState<DesignBriefDetailScreen> createState() => _DesignBriefDetailScreenState();
}

class _DesignBriefDetailScreenState extends ConsumerState<DesignBriefDetailScreen> {
  final _picker = ImagePicker();
  final _photo1Controller = TextEditingController();
  final _photo2Controller = TextEditingController();
  final _notesController = TextEditingController();

  File? _imageFile1;
  File? _imageFile2;
  bool _isUploading = false;

  @override
  void dispose() {
    _photo1Controller.dispose();
    _photo2Controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int slot, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final file = File(picked.path);
        setState(() {
          if (slot == 1) _imageFile1 = file;
          if (slot == 2) _imageFile2 = file;
          _isUploading = true;
        });

        final url = await ref.read(designerProvider.notifier).uploadPhotoFile(file);
        setState(() {
          _isUploading = false;
          if (url != null) {
            if (slot == 1) _photo1Controller.text = url;
            if (slot == 2) _photo2Controller.text = url;
          }
        });
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog(int slot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Concept Photo $slot',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.brandSteel),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(slot, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.brandSteel),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(slot, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final photo1 = _photo1Controller.text.trim();
    final photo2 = _photo2Controller.text.trim();
    final notes = _notesController.text.trim();

    if (photo1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach at least 1 concept photo.')),
      );
      return;
    }

    final success = await ref.read(designerProvider.notifier).submitDesignPhotos(
      briefId: widget.brief.id,
      photoUrl1: photo1,
      photoUrl2: photo2.isNotEmpty ? photo2 : null,
      designerNotes: notes.isNotEmpty ? notes : null,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.brandSteel,
            content: Text('Photos submitted to Provisional Head!'),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit photos. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brief = widget.brief;
    final isPendingSubmission = brief.status == 'ALLOCATED' || brief.status == 'PH_REJECTED';
    final isSubmitting = ref.watch(designerProvider).isSubmitting;

    return Scaffold(
      backgroundColor: AppTheme.canvasCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.foregroundInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          brief.garmentType,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: AppTheme.foregroundInk,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Specs Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.standardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${brief.garmentType} (${brief.category})',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppTheme.foregroundInk,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.badgeNeutralBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.badgeNeutralBorder),
                        ),
                        child: Text(
                          brief.status.replaceAll('_', ' '),
                          style: GoogleFonts.publicSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.brandSteel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.canvasCream,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MAX COLORWAYS',
                                style: GoogleFonts.publicSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${brief.maxColors} Colors',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.foregroundInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.canvasCream,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STYLE CATEGORY',
                                style: GoogleFonts.publicSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                brief.category,
                                style: GoogleFonts.publicSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.foregroundInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (brief.instructions != null && brief.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'HEAD INSTRUCTIONS:',
                      style: GoogleFonts.publicSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.canvasCream,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        brief.instructions!,
                        style: GoogleFonts.publicSans(
                          fontSize: 13,
                          color: AppTheme.foregroundInk,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Revision Feedback if Rejected
            if (brief.status == 'PH_REJECTED' && brief.latestSubmission?.phFeedback != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.badgeRoseBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.badgeRoseBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.badgeRoseText, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Provisional Head Revision Feedback:',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.badgeRoseText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '“${brief.latestSubmission!.phFeedback!}”',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        color: AppTheme.badgeRoseText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submitted Photos View (if already submitted)
            if (brief.latestSubmission != null) ...[
              Text(
                'Current Submission (Max 2 Photos)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.foregroundInk,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.standardBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        brief.latestSubmission!.photoUrl1,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: brief.latestSubmission!.photoUrl2 != null
                        ? Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.standardBorder),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              brief.latestSubmission!.photoUrl2!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          )
                        : Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.standardBorder),
                            ),
                            child: const Center(
                              child: Text('No 2nd photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          ),
                  ),
                ],
              ),
              if (brief.latestSubmission!.designerNotes != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Notes: ${brief.latestSubmission!.designerNotes!}',
                  style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.mutedInk),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // Photo Upload Submission Form (if pending or rejected)
            if (isPendingSubmission) ...[
              Text(
                brief.status == 'PH_REJECTED' ? 'Resubmit Concept Photos' : 'Submit Concept Photos (Max 2)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.foregroundInk,
                ),
              ),
              const SizedBox(height: 10),

              // Two Photo Upload Slots
              Row(
                children: [
                  // Photo 1 Slot
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageSourceDialog(1),
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.standardBorder),
                        ),
                        child: _imageFile1 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.file(_imageFile1!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo_outlined, color: AppTheme.brandSteel, size: 28),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Photo 1 (Required)',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.mutedInk,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Photo 2 Slot
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageSourceDialog(2),
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.standardBorder),
                        ),
                        child: _imageFile2 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.file(_imageFile2!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.mutedInk, size: 28),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Photo 2 (Optional)',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.mutedInk,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Direct URL Inputs (fallback / direct entry)
              TextField(
                controller: _photo1Controller,
                decoration: const InputDecoration(
                  labelText: 'Photo 1 URL (or use camera upload above)',
                  prefixIcon: Icon(Icons.link, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _photo2Controller,
                decoration: const InputDecoration(
                  labelText: 'Photo 2 URL (Optional)',
                  prefixIcon: Icon(Icons.link, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Creative Notes
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Designer Creative Notes',
                  hintText: 'Inspiration, silhouette details, fabric texture...',
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandSteel,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSubmitting || _isUploading ? null : _handleSubmit,
                  child: isSubmitting || _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Submit Concept Photos to Head',
                          style: GoogleFonts.publicSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
