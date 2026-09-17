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
  final List<DesignTeamMemberModel> teamMembers;
  final List<TechPackSummaryModel> techPacks;
  final bool isSubmitting;

  const DesignerState({
    this.isLoading = false,
    this.error,
    this.briefs = const [],
    this.teamMembers = const [],
    this.techPacks = const [],
    this.isSubmitting = false,
  });

  DesignerState copyWith({
    bool? isLoading,
    String? error,
    List<DesignBriefModel>? briefs,
    List<DesignTeamMemberModel>? teamMembers,
    List<TechPackSummaryModel>? techPacks,
    bool? isSubmitting,
  }) {
    return DesignerState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      briefs: briefs ?? this.briefs,
      teamMembers: teamMembers ?? this.teamMembers,
      techPacks: techPacks ?? this.techPacks,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class DesignerNotifier extends StateNotifier<DesignerState> {
  final Ref _ref;

  DesignerNotifier(this._ref) : super(const DesignerState()) {
    fetchStudioData();
  }

  Future<void> fetchStudioData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Nubira Creation';

      // 1. Fetch briefs with joined submissions and team member info
      var briefQuery = supabase
          .from('design_briefs')
          .select('*, design_team_members(*), design_submissions(*)')
          .eq('company_name', company)
          .order('created_at', ascending: false);

      final briefsResp = await briefQuery;
      final rawBriefs = briefsResp as List;

      List<DesignBriefModel> briefList = [];
      for (final item in rawBriefs) {
        final brief = DesignBriefModel.fromJson(item as Map<String, dynamic>);
        briefList.add(brief);
      }

      // 2. Fetch team members
      List<DesignTeamMemberModel> teamList = [];
      try {
        final teamResp = await supabase
            .from('design_team_members')
            .select('*')
            .eq('company_name', company)
            .order('designer_name', ascending: true);
        final rawTeam = teamResp as List;
        teamList = rawTeam.map((m) => DesignTeamMemberModel.fromJson(m as Map<String, dynamic>)).toList();
      } catch (_) {}

      // 3. Fetch tech packs
      List<TechPackSummaryModel> tpList = [];
      try {
        final tpResp = await supabase
            .from('design_tech_packs')
            .select('*')
            .eq('company_name', company)
            .order('created_at', ascending: false);
        final rawTp = tpResp as List;
        tpList = rawTp.map((t) => TechPackSummaryModel.fromJson(t as Map<String, dynamic>)).toList();
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        briefs: briefList,
        teamMembers: teamList,
        techPacks: tpList,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchAllocatedBriefs() => fetchStudioData();

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

  Future<bool> createDesignBrief({
    required String garmentType,
    required String category,
    required int targetDesigns,
    required int maxColors,
    required List<String> targetColors,
    String? designerMemberId,
    String? instructions,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final user = supabase.auth.currentUser;
      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Nubira Creation';

      String rawInstructions = instructions?.trim() ?? '';
      if (targetColors.isNotEmpty && !rawInstructions.contains('[COLORS:')) {
        rawInstructions = '[COLORS: ${targetColors.join(', ')}] $rawInstructions'.trim();
      }
      if (targetDesigns > 1 && !rawInstructions.contains('[TARGET:')) {
        rawInstructions = '[TARGET: $targetDesigns Designs] $rawInstructions'.trim();
      }

      await supabase.from('design_briefs').insert({
        'ph_user_id': user?.id ?? '',
        'designer_member_id': designerMemberId,
        'garment_type': garmentType.trim(),
        'category': category.trim(),
        'target_designs': targetDesigns,
        'max_colors': maxColors,
        'instructions': rawInstructions.isNotEmpty ? rawInstructions : null,
        'status': 'ALLOCATED',
        'company_name': company,
      });

      await fetchStudioData();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> reviewBriefVerdict({
    required String briefId,
    required String submissionId,
    required String verdict, // 'APPROVED' or 'REJECTED'
    String? feedback,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final isApprove = verdict == 'APPROVED';
      final newStatus = isApprove ? 'PH_APPROVED' : 'PH_REJECTED';

      // 1. Update submission verdict
      if (submissionId.isNotEmpty) {
        await supabase.from('design_submissions').update({
          'ph_verdict': isApprove ? 'APPROVED' : 'REJECTED',
          'ph_feedback': feedback,
          'reviewed_at': DateTime.now().toIso8601String(),
        }).eq('id', submissionId);
      }

      // 2. Update brief status
      await supabase.from('design_briefs').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', briefId);

      await fetchStudioData();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteBrief(String briefId) async {
    state = state.copyWith(isSubmitting: true);
    try {
      // 1. Delete associated submissions
      try {
        await supabase.from('design_submissions').delete().eq('brief_id', briefId);
      } catch (_) {}

      // 2. Delete the brief
      await supabase.from('design_briefs').delete().eq('id', briefId);

      await fetchStudioData();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> onboardDesigner({
    required String name,
    required String emailOrPhone,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Nubira Creation';

      final isEmail = emailOrPhone.contains('@');

      await supabase.from('design_team_members').insert({
        'designer_name': name.trim(),
        'designer_email': isEmail ? emailOrPhone.trim().toLowerCase() : null,
        'phone_number': !isEmail ? emailOrPhone.trim() : null,
        'designer_password': password.trim(),
        'status': 'ACTIVE',
        'company_name': company,
      });

      await fetchStudioData();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
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

      final conceptsJson = concepts.map((c) => c.toJson()).toList();
      final encodedConcepts = jsonEncode(conceptsJson);
      final combinedNotes = generalNotes != null && generalNotes.trim().isNotEmpty
          ? '${generalNotes.trim()}\n\n[CONCEPTS_JSON: $encodedConcepts]'
          : '[CONCEPTS_JSON: $encodedConcepts]';

      await supabase.from('design_submissions').insert({
        'brief_id': briefId,
        if (designerMemberId != null) 'designer_member_id': designerMemberId,
        'photo_url_1': firstPhotoFront,
        'photo_url_2': firstPhotoBack,
        'designer_notes': combinedNotes,
        'ph_verdict': 'PENDING',
        'company_name': company,
      });

      await supabase.from('design_briefs').update({
        'status': 'SUBMITTED',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', briefId);

      await fetchStudioData();
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
