import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/design_brief_model.dart';

class DesignerState {
  final bool isLoading;
  final String? error;
  final List<DesignBriefModel> briefs;
  final bool isSubmitting;

  const DesignerState({
    this.isLoading = false,
    this.error,
    this.briefs = const [],
    this.isSubmitting = false,
  });

  DesignerState copyWith({
    bool? isLoading,
    String? error,
    List<DesignBriefModel>? briefs,
    bool? isSubmitting,
  }) {
    return DesignerState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      briefs: briefs ?? this.briefs,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class DesignerNotifier extends StateNotifier<DesignerState> {
  final Ref _ref;

  DesignerNotifier(this._ref) : super(const DesignerState()) {
    fetchAllocatedBriefs();
  }

  Future<void> fetchAllocatedBriefs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = supabase.auth.currentUser;
      final userEmail = user?.email;
      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Nubira Creation';

      var query = supabase
          .from('design_briefs')
          .select('*, design_team_members(*), design_submissions(*)')
          .eq('company_name', company)
          .order('created_at', ascending: false);

      final response = await query;
      final rawList = response as List;

      // Filter to this designer's email if designer role
      List<DesignBriefModel> list = [];
      for (final item in rawList) {
        final brief = DesignBriefModel.fromJson(item as Map<String, dynamic>);
        if (userEmail == null ||
            brief.designerEmail == null ||
            brief.designerEmail!.toLowerCase() == userEmail.toLowerCase() ||
            authState.userRole?.toUpperCase() == 'ADMIN' ||
            authState.userRole?.toUpperCase() == 'SUPERADMIN') {
          list.add(brief);
        }
      }

      state = state.copyWith(isLoading: false, briefs: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> uploadPhotoFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last.toLowerCase();
      final fileName = 'designer_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'submissions/$fileName';

      try {
        await supabase.storage.from('public-assets').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
        final publicUrl = supabase.storage.from('public-assets').getPublicUrl(path);
        if (publicUrl.isNotEmpty && !publicUrl.contains('null')) {
          return publicUrl;
        }
      } catch (_) {}

      // Resilient fallback: Base64 data URI format (works offline & regardless of bucket RLS)
      final b64 = base64Encode(bytes);
      final mime = (fileExt == 'png') ? 'image/png' : (fileExt == 'webp' ? 'image/webp' : 'image/jpeg');
      return 'data:$mime;base64,$b64';
    } catch (e) {
      return null;
    }
  }

  Future<bool> submitDesignConcepts({
    required String briefId,
    String? designerMemberId,
    required List<DesignConceptItemModel> concepts,
    String? generalNotes,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Nubira Creation';

      String firstPhotoFront = '';
      String? firstPhotoBack;

      // Extract first front and back photos for legacy/summary columns
      for (final c in concepts) {
        for (final cw in c.safeColorways) {
          if (firstPhotoFront.isEmpty && cw.photoFront != null && cw.photoFront!.trim().isNotEmpty) {
            firstPhotoFront = cw.photoFront!.trim();
          }
          if (firstPhotoBack == null && cw.photoBack != null && cw.photoBack!.trim().isNotEmpty) {
            firstPhotoBack = cw.photoBack!.trim();
          }
          if (firstPhotoFront.isNotEmpty && firstPhotoBack != null) break;
        }
        if (firstPhotoFront.isNotEmpty && firstPhotoBack != null) break;
      }

      // Serialize concepts to JSON
      final conceptsJson = concepts.map((c) => c.toJson()).toList();
      final encodedConcepts = jsonEncode(conceptsJson);
      final combinedNotes = generalNotes != null && generalNotes.trim().isNotEmpty
          ? '${generalNotes.trim()}\n\n[CONCEPTS_JSON: $encodedConcepts]'
          : '[CONCEPTS_JSON: $encodedConcepts]';

      // 1. Insert into design_submissions
      await supabase.from('design_submissions').insert({
        'brief_id': briefId,
        if (designerMemberId != null) 'designer_member_id': designerMemberId,
        'photo_url_1': firstPhotoFront,
        'photo_url_2': firstPhotoBack,
        'designer_notes': combinedNotes,
        'ph_verdict': 'PENDING',
        'company_name': company,
      });

      // 2. Update brief status to SUBMITTED
      await supabase.from('design_briefs').update({
        'status': 'SUBMITTED',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', briefId);

      await fetchAllocatedBriefs();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> submitDesignPhotos({
    required String briefId,
    required String photoUrl1,
    String? photoUrl2,
    String? designerNotes,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Nubira Creation';

      // 1. Insert into design_submissions
      await supabase.from('design_submissions').insert({
        'brief_id': briefId,
        'photo_url_1': photoUrl1,
        'photo_url_2': photoUrl2,
        'designer_notes': designerNotes,
        'ph_verdict': 'PENDING',
        'company_name': company,
      });

      // 2. Update brief status to SUBMITTED
      await supabase.from('design_briefs').update({
        'status': 'SUBMITTED',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', briefId);

      await fetchAllocatedBriefs();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}

final designerProvider = StateNotifierProvider<DesignerNotifier, DesignerState>((ref) {
  return DesignerNotifier(ref);
});
