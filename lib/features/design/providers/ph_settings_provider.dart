import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ph_settings_model.dart';

class PHSettingsState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final List<BodyPartCodeModel> bodyCodes;
  final List<BOMComponentCodeModel> bomCodes;
  final List<GarmentTemplateModel> templates;
  final int activeTab;

  const PHSettingsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.bodyCodes = const [],
    this.bomCodes = const [],
    this.templates = const [],
    this.activeTab = 0,
  });

  PHSettingsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    List<BodyPartCodeModel>? bodyCodes,
    List<BOMComponentCodeModel>? bomCodes,
    List<GarmentTemplateModel>? templates,
    int? activeTab,
  }) {
    return PHSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      bodyCodes: bodyCodes ?? this.bodyCodes,
      bomCodes: bomCodes ?? this.bomCodes,
      templates: templates ?? this.templates,
      activeTab: activeTab ?? this.activeTab,
    );
  }
}

class PHSettingsNotifier extends StateNotifier<PHSettingsState> {
  final Ref _ref;

  PHSettingsNotifier(this._ref) : super(const PHSettingsState()) {
    fetchSettings();
  }

  void setActiveTab(int tabIndex) {
    state = state.copyWith(activeTab: tabIndex);
  }

  Future<void> fetchSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authState = _ref.read(authProvider);
      final company = (authState.tenantProfile?.companyName ?? 'Nubira Creation').trim();
      final isLegacy = company.toLowerCase().contains('nubira') ||
          company.toLowerCase().contains('demo') ||
          (authState.tenantProfile?.isSuperAdmin ?? true) ||
          (authState.tenantProfile?.isPlatformAdmin ?? false);

      // 1. Body part codes
      List<BodyPartCodeModel> bodyList = [];
      try {
        dynamic bodyResp;
        if (!isLegacy && company.isNotEmpty) {
          bodyResp = await supabase
              .from('design_body_part_codes')
              .select('*')
              .eq('company_name', company)
              .order('sort_order', ascending: true);
        }
        if (bodyResp == null || (bodyResp is List && bodyResp.isEmpty)) {
          bodyResp = await supabase
              .from('design_body_part_codes')
              .select('*')
              .order('sort_order', ascending: true);
        }
        if (bodyResp is List) {
          bodyList = bodyResp
              .whereType<Map>()
              .map((m) => BodyPartCodeModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      } catch (_) {}

      // 2. BOM component codes
      List<BOMComponentCodeModel> bomList = [];
      try {
        dynamic bomResp;
        if (!isLegacy && company.isNotEmpty) {
          bomResp = await supabase
              .from('design_bom_component_codes')
              .select('*')
              .eq('company_name', company)
              .order('sort_order', ascending: true);
        }
        if (bomResp == null || (bomResp is List && bomResp.isEmpty)) {
          bomResp = await supabase
              .from('design_bom_component_codes')
              .select('*')
              .order('sort_order', ascending: true);
        }
        if (bomResp is List) {
          bomList = bomResp
              .whereType<Map>()
              .map((m) => BOMComponentCodeModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      } catch (_) {}

      // 3. Garment templates
      List<GarmentTemplateModel> templateList = [];
      try {
        final dynamic tmplResp = await supabase
            .from('design_garment_templates')
            .select('*')
            .order('garment_type', ascending: true);

        if (tmplResp is List) {
          templateList = tmplResp
              .whereType<Map>()
              .map((m) => GarmentTemplateModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        bodyCodes: bodyList,
        bomCodes: bomList,
        templates: templateList,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<({bool success, String? error, BodyPartCodeModel? data})> createBodyPartCode({
    required String code,
    required String bodyPartName,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final codeNorm = code.trim().toUpperCase();
      final nameClean = bodyPartName.trim();

      if (codeNorm.isEmpty || nameClean.isEmpty) {
        state = state.copyWith(isSubmitting: false);
        return (success: false, error: 'Code and body part name are required.', data: null);
      }

      // Check duplicate in current list
      final exists = state.bodyCodes.any((b) => b.code.toUpperCase() == codeNorm);
      if (exists) {
        state = state.copyWith(isSubmitting: false);
        return (success: false, error: 'Code "$codeNorm" is already defined.', data: null);
      }

      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName.trim() ?? 'Nubira Creation';
      final currentUserId = authState.tenantProfile?.userId ?? authState.cachedUsername ?? 'admin';

      final res = await supabase
          .from('design_body_part_codes')
          .insert({
            'ph_user_id': currentUserId,
            'company_name': company,
            'code': codeNorm,
            'body_part_name': nameClean,
            'sort_order': state.bodyCodes.length,
          })
          .select('*')
          .single();

      final created = BodyPartCodeModel.fromJson(Map<String, dynamic>.from(res));
      state = state.copyWith(
        isSubmitting: false,
        bodyCodes: [...state.bodyCodes, created],
      );
      return (success: true, error: null, data: created);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return (success: false, error: e.toString(), data: null);
    }
  }

  Future<bool> deleteBodyPartCode(String id) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await supabase.from('design_body_part_codes').delete().eq('id', id);
      state = state.copyWith(
        isSubmitting: false,
        bodyCodes: state.bodyCodes.where((b) => b.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<({bool success, String? error, BOMComponentCodeModel? data})> createBOMComponentCode({
    required String componentType,
    required String componentSpec,
    String? code,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final specClean = componentSpec.trim();
      if (specClean.isEmpty) {
        state = state.copyWith(isSubmitting: false);
        return (success: false, error: 'Component specification is required.', data: null);
      }

      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName.trim() ?? 'Nubira Creation';
      final currentUserId = authState.tenantProfile?.userId ?? authState.cachedUsername ?? 'admin';

      final res = await supabase
          .from('design_bom_component_codes')
          .insert({
            'ph_user_id': currentUserId,
            'company_name': company,
            'component_type': componentType.trim().toUpperCase(),
            'component_spec': specClean,
            'code': (code != null && code.trim().isNotEmpty) ? code.trim().toUpperCase() : null,
            'sort_order': state.bomCodes.length,
          })
          .select('*')
          .single();

      final created = BOMComponentCodeModel.fromJson(Map<String, dynamic>.from(res));
      state = state.copyWith(
        isSubmitting: false,
        bomCodes: [...state.bomCodes, created],
      );
      return (success: true, error: null, data: created);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return (success: false, error: e.toString(), data: null);
    }
  }

  Future<bool> deleteBOMComponentCode(String id) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await supabase.from('design_bom_component_codes').delete().eq('id', id);
      state = state.copyWith(
        isSubmitting: false,
        bomCodes: state.bomCodes.where((b) => b.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<({bool success, String? error, GarmentTemplateModel? data})> createGarmentTemplate({
    required String garmentType,
    required List<GarmentTemplateBodyPartModel> bodyParts,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final typeClean = garmentType.trim();
      if (typeClean.isEmpty) {
        state = state.copyWith(isSubmitting: false);
        return (success: false, error: 'Garment type is required.', data: null);
      }

      final authState = _ref.read(authProvider);
      final company = authState.tenantProfile?.companyName.trim() ?? 'Nubira Creation';
      final currentUserId = authState.tenantProfile?.userId ?? authState.cachedUsername ?? 'admin';

      final res = await supabase
          .from('design_garment_templates')
          .insert({
            'garment_type': typeClean,
            'body_parts': bodyParts.map((b) => b.toJson()).toList(),
            'bom_defaults': [],
            'is_system_template': false,
            'ph_user_id': currentUserId,
            'company_name': company,
          })
          .select('*')
          .single();

      final created = GarmentTemplateModel.fromJson(Map<String, dynamic>.from(res));
      state = state.copyWith(
        isSubmitting: false,
        templates: [...state.templates, created],
      );
      return (success: true, error: null, data: created);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return (success: false, error: e.toString(), data: null);
    }
  }

  Future<bool> deleteGarmentTemplate(String id) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await supabase.from('design_garment_templates').delete().eq('id', id);
      state = state.copyWith(
        isSubmitting: false,
        templates: state.templates.where((t) => t.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}

final phSettingsProvider = StateNotifierProvider<PHSettingsNotifier, PHSettingsState>((ref) {
  return PHSettingsNotifier(ref);
});
