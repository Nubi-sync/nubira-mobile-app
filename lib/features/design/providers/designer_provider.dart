import 'dart:io';
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
      final fileExt = file.path.split('.').last;
      final fileName = 'designer_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'submissions/$fileName';

      await supabase.storage.from('public-assets').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final publicUrl = supabase.storage.from('public-assets').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      // Fallback: If public-assets bucket isn't set up, we return a fallback demo image or error
      return null;
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
