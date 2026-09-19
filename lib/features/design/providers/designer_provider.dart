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
      final company = (authState.tenantProfile?.companyName ?? 'Nubira Creation').trim();
      final isLegacy = company.toLowerCase().contains('nubira') ||
          company.toLowerCase().contains('demo') ||
          (authState.tenantProfile?.isSuperAdmin ?? true) ||
          (authState.tenantProfile?.isPlatformAdmin ?? false);

      // 1. Fetch briefs with joined submissions and team member info
      List<DesignBriefModel> briefList = [];
      try {
        dynamic briefsResp;
        if (!isLegacy && company.isNotEmpty) {
          briefsResp = await supabase
              .from('design_briefs')
              .select('*, design_team_members(*), design_submissions(*)')
              .eq('company_name', company)
              .order('created_at', ascending: false);
        }
        if (briefsResp == null || (briefsResp is List && briefsResp.isEmpty)) {
          briefsResp = await supabase
              .from('design_briefs')
              .select('*, design_team_members(*), design_submissions(*)')
              .order('created_at', ascending: false);
        }

        if (briefsResp is List) {
          for (final item in briefsResp) {
            if (item is Map<String, dynamic>) {
              briefList.add(DesignBriefModel.fromJson(item));
            } else if (item is Map) {
              briefList.add(DesignBriefModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      } catch (e) {
        // Fallback simple query
        try {
          final simpleResp = await supabase
              .from('design_briefs')
              .select('*')
              .order('created_at', ascending: false);
          for (final item in (simpleResp as List)) {
            briefList.add(DesignBriefModel.fromJson(Map<String, dynamic>.from(item as Map)));
          }
        } catch (_) {}
      }

      // 2. Fetch team members
      List<DesignTeamMemberModel> teamList = [];
      try {
        dynamic teamResp;
        if (!isLegacy && company.isNotEmpty) {
          teamResp = await supabase
              .from('design_team_members')
              .select('*')
              .eq('company_name', company)
              .order('designer_name', ascending: true);
        }
        if (teamResp == null || (teamResp is List && teamResp.isEmpty)) {
          teamResp = await supabase
              .from('design_team_members')
              .select('*')
              .order('designer_name', ascending: true);
        }
        if (teamResp is List) {
          teamList = teamResp
              .whereType<Map>()
              .map((m) => DesignTeamMemberModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      } catch (_) {}

      // 3. Fetch tech packs
      List<TechPackSummaryModel> tpList = [];
      try {
        dynamic tpResp;
        if (!isLegacy && company.isNotEmpty) {
          try {
            tpResp = await supabase
                .from('design_tech_packs')
                .select('*, brands(*)')
                .eq('company_name', company)
                .order('created_at', ascending: false);
          } catch (_) {}
        }
        if (tpResp == null || (tpResp is List && tpResp.isEmpty)) {
          try {
            tpResp = await supabase
                .from('design_tech_packs')
                .select('*, brands(*)')
                .order('created_at', ascending: false);
          } catch (_) {
            // Fallback without join
            tpResp = await supabase
                .from('design_tech_packs')
                .select('*')
                .order('created_at', ascending: false);
          }
        }
        if (tpResp is List) {
          tpList = tpResp
              .whereType<Map>()
              .map((t) => TechPackSummaryModel.fromJson(Map<String, dynamic>.from(t)))
              .toList();
        }
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

  Future<bool> reviewSubmissionColorways({
    required String submissionId,
    required String briefId,
    int? conceptNumber,
    required String phVerdict, // 'APPROVED' or 'REJECTED'
    String? phFeedback,
    required Map<String, String> colorwayVerdicts, // color_name -> 'APPROVED' | 'REJECTED'
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      // 1. Fetch current submission
      final subData = await supabase
          .from('design_submissions')
          .select('id, brief_id, designer_notes, ph_verdict')
          .eq('id', submissionId)
          .single();

      final rawNotes = subData['designer_notes'] as String?;
      String cleanNotes = rawNotes ?? '';
      List<Map<String, dynamic>> updatedConcepts = [];

      if (rawNotes != null && rawNotes.contains('[CONCEPTS_JSON:')) {
        final match = RegExp(r'\[CONCEPTS_JSON:\s*(\[.*?\])\]', dotAll: true).firstMatch(rawNotes);
        if (match != null && match.group(1) != null) {
          final decoded = jsonDecode(match.group(1)!);
          if (decoded is List) {
            updatedConcepts = decoded.map((c) => Map<String, dynamic>.from(c as Map)).toList();
          }
          cleanNotes = rawNotes.replaceAll(RegExp(r'\[CONCEPTS_JSON:\s*(\[.*?\])\]', dotAll: true), '').trim();
        }
      }

      if (conceptNumber != null && updatedConcepts.isNotEmpty) {
        updatedConcepts = updatedConcepts.map((c) {
          if (c['concept_number'] == conceptNumber) {
            List<Map<String, dynamic>> cws = [];
            if (c['colorways'] is List) {
              cws = (c['colorways'] as List).map((cw) {
                final cwMap = Map<String, dynamic>.from(cw as Map);
                final colName = cwMap['color_name']?.toString() ?? '';
                final cwVerdict = colorwayVerdicts[colName] ?? phVerdict;
                cwMap['status'] = cwVerdict;
                return cwMap;
              }).toList();
            }
            final allCwRejected = cws.isNotEmpty && cws.every((cw) => cw['status'] == 'REJECTED');
            final anyCwApproved = cws.isNotEmpty && cws.any((cw) => cw['status'] == 'APPROVED');
            final conceptVerdict = allCwRejected ? 'REJECTED' : (anyCwApproved ? 'APPROVED' : phVerdict);
            c['ph_verdict'] = conceptVerdict;
            if (phFeedback != null && phFeedback.trim().isNotEmpty) {
              c['ph_feedback'] = phFeedback.trim();
            }
            c['status'] = conceptVerdict == 'APPROVED' ? 'PH_APPROVED' : 'PH_REJECTED';
            c['colorways'] = cws;
          }
          return c;
        }).toList();
      }

      String finalNotes = cleanNotes;
      if (updatedConcepts.isNotEmpty) {
        finalNotes = '[CONCEPTS_JSON: ${jsonEncode(updatedConcepts)}] $cleanNotes'.trim();
      }

      final hasAnyConceptApproved = updatedConcepts.isNotEmpty
          ? updatedConcepts.any((c) => c['ph_verdict'] == 'APPROVED' || c['status'] == 'PH_APPROVED')
          : (phVerdict == 'APPROVED' || colorwayVerdicts.values.any((v) => v == 'APPROVED'));

      final overallVerdict = (phVerdict == 'APPROVED' || hasAnyConceptApproved) ? 'APPROVED' : 'REJECTED';
      final briefStatus = overallVerdict == 'APPROVED' ? 'PH_APPROVED' : 'PH_REJECTED';

      // 2. Update submission
      await supabase.from('design_submissions').update({
        'designer_notes': finalNotes.isNotEmpty ? finalNotes : null,
        'ph_verdict': overallVerdict,
        'ph_feedback': (phFeedback != null && phFeedback.trim().isNotEmpty) ? phFeedback.trim() : null,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', submissionId);

      // 3. Update brief status
      await supabase.from('design_briefs').update({
        'status': briefStatus,
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

  Future<bool> deleteBrief(String briefId, {int? conceptNumber}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      if (conceptNumber != null) {
        // Fetch brief to check concepts
        final briefData = await supabase.from('design_briefs').select('*, design_submissions(*)').eq('id', briefId).single();
        final rawInstructions = briefData['instructions'] as String? ?? '';
        final subs = briefData['design_submissions'] as List? ?? [];
        final latestSub = subs.isNotEmpty ? subs.last as Map : null;

        // If instructions have CONCEPTS_JSON
        if (rawInstructions.contains('[CONCEPTS_JSON:')) {
          final match = RegExp(r'\[CONCEPTS_JSON:\s*(\[.*?\])\]', dotAll: true).firstMatch(rawInstructions);
          if (match != null && match.group(1) != null) {
            final decoded = jsonDecode(match.group(1)!);
            if (decoded is List) {
              final rem = decoded.where((c) => (c is Map && c['concept_number'] != conceptNumber)).toList();
              if (rem.isNotEmpty) {
                final renumbered = rem.asMap().entries.map((e) {
                  final m = Map<String, dynamic>.from(e.value as Map);
                  m['concept_number'] = e.key + 1;
                  return m;
                }).toList();
                final cleanInst = rawInstructions.replaceAll(RegExp(r'\[CONCEPTS_JSON:\s*(\[.*?\])\]', dotAll: true), '').trim();
                final newInst = '[CONCEPTS_JSON: ${jsonEncode(renumbered)}] $cleanInst'.trim();
                await supabase.from('design_briefs').update({
                  'instructions': newInst,
                  'target_designs': renumbered.length,
                }).eq('id', briefId);

                // Also update submission if present
                if (latestSub != null && latestSub['id'] != null) {
                  final subNotes = latestSub['designer_notes'] as String? ?? '';
                  if (subNotes.contains('[CONCEPTS_JSON:')) {
                    final subCleanNotes = subNotes.replaceAll(RegExp(r'\[CONCEPTS_JSON:\s*(\[.*?\])\]', dotAll: true), '').trim();
                    final newSubNotes = '[CONCEPTS_JSON: ${jsonEncode(renumbered)}] $subCleanNotes'.trim();
                    await supabase.from('design_submissions').update({
                      'designer_notes': newSubNotes,
                    }).eq('id', latestSub['id']);
                  }
                }

                await fetchStudioData();
                state = state.copyWith(isSubmitting: false);
                return true;
              }
            }
          }
        }
      }

      // Delete full brief
      try {
        await supabase.from('design_submissions').delete().eq('brief_id', briefId);
      } catch (_) {}

      await supabase.from('design_briefs').delete().eq('id', briefId);

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

  Future<bool> createTechPack({
    required String styleNumber,
    String? styleName,
    String? brandName,
    required String category,
    String sizeSystem = 'ALPHA_ADULT',
    required String baseSize,
    required String fabricComposition,
    required int targetGsm,
    String embellishmentSequence = 'NONE',
    int spi = 12,
    String seamClass = 'ISO 4915 Class 401 (Chainstitch)',
    String? cadFrontUrl,
    String? cadBackUrl,
    String? instructions,
    List<TechPackBomItemModel> bomItems = const [],
    String status = 'APPROVED_BULK',
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final user = supabase.auth.currentUser;
      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName ?? 'Nubira Creation';

      String fullFabric = fabricComposition.trim();
      if (bomItems.isNotEmpty) {
        final bomsJson = jsonEncode(bomItems.map((b) => b.toJson()).toList());
        fullFabric = '[BOM_JSON: $bomsJson] $fullFabric';
      }
      if (instructions != null && instructions.trim().isNotEmpty) {
        fullFabric = '$fullFabric [INSTRUCTIONS: ${instructions.trim()}]';
      }

      final categoryDB = category.toUpperCase().replaceAll(RegExp(r'\s+'), '_').replaceAll('-', '');

      // Resolve brand id if possible
      String? brandId;
      try {
        final brandFind = (brandName != null && brandName.trim().isNotEmpty) ? brandName.trim() : 'Inhouse';
        final brandResp = await supabase
            .from('brands')
            .select('id')
            .ilike('brand_name', brandFind)
            .maybeSingle();
        if (brandResp != null && brandResp['id'] != null) {
          brandId = brandResp['id'].toString();
        }
      } catch (_) {}

      await supabase.from('design_tech_packs').insert({
        'style_number': styleNumber.trim(),
        if (brandId != null) 'brand_id': brandId,
        'category': categoryDB,
        'size_system': sizeSystem,
        'base_size': baseSize.trim(),
        'fabric_composition': fullFabric,
        'target_gsm': targetGsm,
        'embellishment_sequence': embellishmentSequence,
        'spi': spi,
        'seam_class': seamClass,
        'cad_front_url': cadFrontUrl,
        'cad_back_url': cadBackUrl,
        'created_by_ph': user?.id,
        'approved_by_sa': true,
        'sa_verdict': 'APPROVED',
        'status': status,
        'version': 1,
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

  Future<bool> updateTechPack({
    required String id,
    required String styleNumber,
    required String category,
    required String baseSize,
    required String fabricComposition,
    required int targetGsm,
    String? sizeSystem,
    String? embellishmentSequence,
    int? spi,
    String? seamClass,
    String? cadFrontUrl,
    String? cadBackUrl,
    String? status,
    String? instructions,
    List<TechPackBomItemModel> bomItems = const [],
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      String fullFabric = fabricComposition.trim();
      if (bomItems.isNotEmpty) {
        final bomsJson = jsonEncode(bomItems.map((b) => b.toJson()).toList());
        fullFabric = '[BOM_JSON: $bomsJson] $fullFabric';
      }
      if (instructions != null && instructions.trim().isNotEmpty) {
        fullFabric = '$fullFabric [INSTRUCTIONS: ${instructions.trim()}]';
      }

      final categoryDB = category.toUpperCase().replaceAll(RegExp(r'\s+'), '_').replaceAll('-', '');

      final Map<String, dynamic> updateData = {
        'style_number': styleNumber.trim(),
        'category': categoryDB,
        'base_size': baseSize.trim(),
        'fabric_composition': fullFabric,
        'target_gsm': targetGsm,
        if (sizeSystem != null) 'size_system': sizeSystem,
        if (embellishmentSequence != null) 'embellishment_sequence': embellishmentSequence,
        if (spi != null) 'spi': spi,
        if (seamClass != null) 'seam_class': seamClass,
        if (cadFrontUrl != null) 'cad_front_url': cadFrontUrl,
        if (cadBackUrl != null) 'cad_back_url': cadBackUrl,
        if (status != null) 'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('design_tech_packs').update(updateData).eq('id', id);

      await fetchStudioData();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteTechPack(String techPackId) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await supabase.from('design_tech_packs').delete().eq('id', techPackId);
      await fetchStudioData();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  // ============================================================================
  // TEAM MANAGEMENT METHODS (PH adds/manages designers)
  // ============================================================================

  Future<({bool success, String? error, DesignTeamMemberModel? data})> onboardDesigner({
    required String designerName,
    required String phoneNumber,
    String? password,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final rawPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final phone10 = rawPhone.length >= 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;
      if (phone10.length != 10) {
        state = state.copyWith(isSubmitting: false);
        return (success: false, error: 'Please enter a valid 10-digit mobile number.', data: null);
      }

      final nameClean = designerName.trim();
      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName.trim() ?? 'Nubira Creation';
      final currentUserId = authState.tenantProfile?.userId ?? authState.cachedUsername ?? 'admin';
      final internalEmail = '$phone10@designer.nubira.local';

      final nameSlug = nameClean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').split('_').first;
      final companySlug = company.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').split('_').first;
      final baseUsername = '${nameSlug}_$companySlug';

      // Check existing usernames for counter
      final existingUsers = await supabase
          .from('design_team_members')
          .select('username')
          .ilike('username', '$baseUsername%');

      String finalUsername = baseUsername;
      if (existingUsers.isNotEmpty) {
        final existingSet = existingUsers
            .whereType<Map>()
            .map((m) => (m['username'] as String?)?.toLowerCase())
            .toSet();
        if (existingSet.contains(finalUsername.toLowerCase())) {
          int counter = 2;
          while (existingSet.contains('${baseUsername}_$counter'.toLowerCase())) {
            counter++;
          }
          finalUsername = '${baseUsername}_$counter';
        }
      }

      // Check if phone or email already exists in this company
      final existingPhone = await supabase
          .from('design_team_members')
          .select('*')
          .eq('company_name', company)
          .or('phone_number.eq.$phone10,designer_phone.eq.$phone10,designer_email.eq.$internalEmail')
          .maybeSingle();

      if (existingPhone != null) {
        final status = (existingPhone['status'] as String?)?.toUpperCase();
        if (status == 'REMOVED') {
          final revived = await supabase
              .from('design_team_members')
              .update({
                'status': 'ACTIVE',
                'designer_name': nameClean,
                'phone_number': phone10,
                'designer_phone': phone10,
                'username': finalUsername,
                'designer_email': internalEmail,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingPhone['id'])
              .select('*')
              .single();

          await fetchStudioData();
          state = state.copyWith(isSubmitting: false);
          return (
            success: true,
            error: null,
            data: DesignTeamMemberModel.fromJson(Map<String, dynamic>.from(revived))
          );
        }
        state = state.copyWith(isSubmitting: false);
        return (
          success: false,
          error: 'A team member with mobile number $phone10 is already registered in this company.',
          data: null
        );
      }

      // Insert new record
      final insertData = {
        'ph_user_id': currentUserId,
        'designer_name': nameClean,
        'phone_number': phone10,
        'designer_phone': phone10,
        'username': finalUsername,
        'designer_email': internalEmail,
        'company_name': company,
        'status': 'ACTIVE',
      };

      final inserted = await supabase
          .from('design_team_members')
          .insert(insertData)
          .select('*')
          .single();

      await fetchStudioData();
      state = state.copyWith(isSubmitting: false);
      return (
        success: true,
        error: null,
        data: DesignTeamMemberModel.fromJson(Map<String, dynamic>.from(inserted))
      );
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return (success: false, error: e.toString(), data: null);
    }
  }

  Future<bool> updateDesignerStatus(String memberId, String newStatus) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await supabase.from('design_team_members').update({
        'status': newStatus.toUpperCase(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', memberId);

      await fetchStudioData();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteDesigner(String memberId) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await supabase.from('design_team_members').delete().eq('id', memberId);
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
