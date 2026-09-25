import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

/// All default 12 manufacturing divisions in Zigza MES
const List<String> allDefaultDivisions = [
  '/design',
  '/merchandising',
  '/cutting',
  '/printing',
  '/embroidery',
  '/stitching-sewing',
  '/washing',
  '/iron',
  '/ready-goods',
  '/alter',
  '/store',
  '/dispatch',
];

/// Resolved Tenant Profile structure matching web_admin/src/lib/tenant-context.ts
class ResolvedTenantProfile {
  final String userId;
  final String userEmail;
  final String role;
  final bool isSuperAdmin;
  final bool isPlatformAdmin;
  final String companyName;
  final String adminDisplayName;
  final String customUsername;
  final String phone;
  final String cityState;
  final String subscriptionTier;
  final List<String> allowedDivisions;
  final bool isProvisionedTenant;
  final String? tenantId;
  final String accessType;
  final String? expiresAt;
  final String provisionedAt;
  final bool isExpired;
  final String tenantStatus;
  final double monthlyBillingInr;

  ResolvedTenantProfile({
    required this.userId,
    required this.userEmail,
    required this.role,
    required this.isSuperAdmin,
    required this.isPlatformAdmin,
    required this.companyName,
    required this.adminDisplayName,
    required this.customUsername,
    required this.phone,
    required this.cityState,
    required this.subscriptionTier,
    required this.allowedDivisions,
    required this.isProvisionedTenant,
    this.tenantId,
    this.accessType = 'FULL_ACCESS',
    this.expiresAt,
    this.provisionedAt = '2026-09-15T00:00:00.000Z',
    this.isExpired = false,
    this.tenantStatus = 'ACTIVE',
    this.monthlyBillingInr = 4999,
  });

  bool get isLegacyNubira {
    final email = userEmail.toLowerCase().trim();
    final comp = companyName.toLowerCase().trim();
    return email == 'team.anga9@gmail.com' ||
        email == 'admin@nubira.local' ||
        email.endsWith('@nubira.local') ||
        comp == 'nubira creation';
  }

  int get operatingUnitsCount => allowedDivisions.length;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userEmail': userEmail,
    'role': role,
    'isSuperAdmin': isSuperAdmin,
    'isPlatformAdmin': isPlatformAdmin,
    'companyName': companyName,
    'adminDisplayName': adminDisplayName,
    'customUsername': customUsername,
    'phone': phone,
    'cityState': cityState,
    'subscriptionTier': subscriptionTier,
    'allowedDivisions': allowedDivisions,
    'isProvisionedTenant': isProvisionedTenant,
    'tenantId': tenantId,
    'accessType': accessType,
    'expiresAt': expiresAt,
    'provisionedAt': provisionedAt,
    'isExpired': isExpired,
    'tenantStatus': tenantStatus,
    'monthlyBillingInr': monthlyBillingInr,
  };

  factory ResolvedTenantProfile.fromJson(Map<String, dynamic> json) {
    return ResolvedTenantProfile(
      userId: json['userId'] ?? '',
      userEmail: json['userEmail'] ?? '',
      role: json['role'] ?? 'STAFF',
      isSuperAdmin: json['isSuperAdmin'] ?? false,
      isPlatformAdmin: json['isPlatformAdmin'] ?? false,
      companyName: json['companyName'] ?? 'Nubira Creation',
      adminDisplayName: json['adminDisplayName'] ?? 'Plant Admin',
      customUsername: json['customUsername'] ?? 'admin',
      phone: json['phone'] ?? '',
      cityState: json['cityState'] ?? 'India',
      subscriptionTier: json['subscriptionTier'] ?? 'FULL_PLANT_AI',
      allowedDivisions: List<String>.from(json['allowedDivisions'] ?? ['/stitching-sewing']),
      isProvisionedTenant: json['isProvisionedTenant'] ?? false,
      tenantId: json['tenantId'],
      accessType: json['accessType'] ?? 'FULL_ACCESS',
      expiresAt: json['expiresAt'],
      provisionedAt: json['provisionedAt'] ?? '2026-09-15T00:00:00.000Z',
      isExpired: json['isExpired'] ?? false,
      tenantStatus: json['tenantStatus'] ?? 'ACTIVE',
      monthlyBillingInr: (json['monthlyBillingInr'] as num?)?.toDouble() ?? 4999,
    );
  }
}

/// Central service that mirrors `web_admin/src/lib/tenant-context.ts`
class TenantResolverService {
  static Future<ResolvedTenantProfile> resolveUserTenant(User user, [Map<String, dynamic>? cachedProfile]) async {
    final userEmail = (user.email ?? '').trim().toLowerCase();
    final metadata = user.userMetadata ?? {};

    // 1. Platform Root SuperAdmin
    if (userEmail == 'admin@zigza.in' || metadata['role'] == 'PLATFORM_SUPERADMIN') {
      return ResolvedTenantProfile(
        userId: user.id,
        userEmail: userEmail,
        role: 'PLATFORM_SUPERADMIN',
        isSuperAdmin: true,
        isPlatformAdmin: true,
        companyName: 'Zigza MES Platform Operations',
        adminDisplayName: metadata['displayName'] ?? 'Platform SuperAdmin',
        customUsername: metadata['username'] ?? 'platform_admin',
        phone: '+91 98000 00000',
        cityState: 'India',
        subscriptionTier: 'ENTERPRISE_PLATFORM',
        allowedDivisions: ['/platform-admin', ...allDefaultDivisions],
        isProvisionedTenant: false,
        accessType: 'FULL_ACCESS',
      );
    }

    // 1.5. Check design_team_members for creative designers (matches web tenant-context.ts)
    try {
      final rawDigits = userEmail.split('@').first.replaceAll(RegExp(r'\D'), '');
      final phone10 = (rawDigits.length >= 10) ? rawDigits.substring(rawDigits.length - 10) : rawDigits;

      dynamic matchedMember;
      if (phone10.length == 10) {
        final res = await supabase
            .from('design_team_members')
            .select()
            .or('designer_user_id.eq.${user.id},designer_email.eq.$userEmail,phone_number.eq.$phone10,designer_phone.eq.$phone10')
            .limit(1);
        if ((res as List).isNotEmpty) matchedMember = res.first;
      } else {
        final res = await supabase
            .from('design_team_members')
            .select()
            .or('designer_user_id.eq.${user.id},designer_email.eq.$userEmail')
            .limit(1);
        if ((res as List).isNotEmpty) matchedMember = res.first;
      }

      if (matchedMember != null) {
        final comp = (matchedMember['company_name'] ?? 'Nubira Creation').toString();
        final dispName = (matchedMember['designer_name'] ?? 'Creative Designer').toString();
        final uname = (matchedMember['username'] ?? userEmail.split('@').first).toString();
        final phoneStr = (matchedMember['phone_number'] ?? matchedMember['designer_phone'] ?? '').toString();

        return ResolvedTenantProfile(
          userId: user.id,
          userEmail: userEmail,
          role: 'DESIGNER',
          isSuperAdmin: false,
          isPlatformAdmin: false,
          companyName: comp,
          adminDisplayName: dispName,
          customUsername: uname,
          phone: phoneStr,
          cityState: 'India',
          subscriptionTier: 'ENTERPRISE_PLAN',
          allowedDivisions: ['/design/designer'],
          isProvisionedTenant: true,
          accessType: 'FULL_ACCESS',
          isExpired: false,
          tenantStatus: (matchedMember['status'] ?? 'ACTIVE').toString(),
          provisionedAt: (matchedMember['created_at'] ?? '2026-09-15T00:00:00.000Z').toString(),
        );
      }
    } catch (_) {}

    // 2. Check platform_tenant_factories in Supabase
    try {
      dynamic tenantRow;

      // Exact email match
      try {
        tenantRow = await supabase
            .from('platform_tenant_factories')
            .select()
            .ilike('admin_email', userEmail)
            .maybeSingle();
      } catch (_) {}

      // Company metadata match fallback
      if (tenantRow == null && metadata['company'] != null) {
        try {
          tenantRow = await supabase
              .from('platform_tenant_factories')
              .select()
              .ilike('company_name', metadata['company'].toString().trim())
              .maybeSingle();
        } catch (_) {}
      }

      // Check profile company match
      if (tenantRow == null && cachedProfile != null && cachedProfile['company_name'] != null) {
        try {
          tenantRow = await supabase
              .from('platform_tenant_factories')
              .select()
              .ilike('company_name', cachedProfile['company_name'].toString().trim())
              .maybeSingle();
        } catch (_) {}
      }

      // Keyword match fallback
      if (tenantRow == null && userEmail.contains('shaw')) {
        try {
          final res = await supabase
              .from('platform_tenant_factories')
              .select()
              .or('plant_slug.ilike.%shaw%,company_name.ilike.%shaw%')
              .limit(1);
          if ((res as List).isNotEmpty) tenantRow = res.first;
        } catch (_) {}
      }

      if (tenantRow == null && (userEmail.contains('nubira') || userEmail == 'team.anga9@gmail.com' || userEmail == 'creationnubira@gmail.com' || userEmail.startsWith('admin'))) {
        try {
          final res = await supabase
              .from('platform_tenant_factories')
              .select()
              .or('plant_slug.ilike.%nubira%,company_name.ilike.%nubira%')
              .limit(1);
          if ((res as List).isNotEmpty) tenantRow = res.first;
        } catch (_) {}
      }

      if (tenantRow != null) {
        final isTenantAdmin = (tenantRow['admin_email'] != null &&
                tenantRow['admin_email'].toString().toLowerCase() == userEmail) ||
            userEmail == 'admin@zigza.in' ||
            userEmail == 'team.anga9@gmail.com' ||
            userEmail == 'admin@nubira.local' ||
            userEmail == 'creationnubira@gmail.com' ||
            userEmail.startsWith('admin@') ||
            metadata['role'] == 'ADMIN' ||
            metadata['role'] == 'SUPERADMIN';

        // Check user profile for department head or custom modules
        String profileRole = '';
        String profileUsername = '';
        List<String> profileAllowedModules = [];
        bool profileIsHead = false;
        String profileDesignation = '';
        String profileCompany = '';

        try {
          final prof = cachedProfile ??
              await supabase
                  .from('profiles')
                  .select('username, role, allowed_modules, is_head, designation, company_name')
                  .eq('id', user.id)
                  .maybeSingle();

          if (prof != null) {
            profileRole = (prof['role'] ?? '').toString();
            profileUsername = (prof['username'] ?? '').toString();
            if (prof['allowed_modules'] is List) {
              profileAllowedModules = List<String>.from(prof['allowed_modules']);
            }
            profileIsHead = prof['is_head'] == true;
            profileDesignation = (prof['designation'] ?? '').toString();
            profileCompany = (prof['company_name'] ?? '').toString();
          }
        } catch (_) {}

        final isDepartmentHead = profileIsHead ||
            metadata['is_head'] == true ||
            (!isTenantAdmin && profileAllowedModules.isNotEmpty);

        final isSuperAdmin = isTenantAdmin && !isDepartmentHead;

        final effectiveRole = isDepartmentHead
            ? (profileDesignation.isNotEmpty
                ? profileDesignation
                : (metadata['designation'] ?? (profileRole.isNotEmpty ? profileRole : 'DEPARTMENT_HEAD')))
            : (isTenantAdmin ? 'SUPERADMIN' : (profileRole.isNotEmpty ? profileRole : 'STAFF')).toUpperCase();

        List<String> divisions;
        final rawAllowed = tenantRow['allowed_divisions'];
        List<String> tenantDivisions = [];
        if (rawAllowed is List && rawAllowed.isNotEmpty) {
          tenantDivisions = List<String>.from(rawAllowed);
        } else {
          tenantDivisions = allDefaultDivisions;
        }

        if (isSuperAdmin) {
          divisions = tenantDivisions;
        } else {
          divisions = profileAllowedModules.isNotEmpty
              ? profileAllowedModules
              : tenantDivisions;
        }

        final displayName = isTenantAdmin
            ? (tenantRow['admin_name'] ?? metadata['displayName'] ?? 'Plant Head')
            : (metadata['display_name'] ?? metadata['displayName'] ?? (profileUsername.isNotEmpty ? profileUsername : 'Department Head'));

        final expiresAt = tenantRow['expires_at']?.toString();
        final tenantStatus = (tenantRow['status'] ?? 'ACTIVE').toString();
        final isPastExpiry = expiresAt != null ? DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) ?? false : false;
        final isExpired = tenantStatus == 'SUSPENDED' || tenantStatus == 'EXPIRED' || isPastExpiry;

        return ResolvedTenantProfile(
          userId: user.id,
          userEmail: userEmail,
          role: effectiveRole,
          isSuperAdmin: isSuperAdmin,
          isPlatformAdmin: false,
          companyName: tenantRow['company_name'] ?? (profileCompany.isNotEmpty ? profileCompany : 'Nubira Creation'),
          adminDisplayName: displayName,
          customUsername: metadata['username'] ?? (profileUsername.isNotEmpty ? profileUsername : userEmail.split('@').first),
          phone: isTenantAdmin ? (tenantRow['phone'] ?? '') : (metadata['phone'] ?? ''),
          cityState: tenantRow['city_state'] ?? 'India',
          subscriptionTier: tenantRow['subscription_tier'] ?? 'FULL_PLANT_AI',
          allowedDivisions: divisions,
          isProvisionedTenant: true,
          tenantId: tenantRow['id']?.toString(),
          accessType: tenantRow['access_type'] ?? 'FULL_ACCESS',
          expiresAt: expiresAt,
          provisionedAt: tenantRow['provisioned_at'] ?? '2026-09-15T00:00:00.000Z',
          isExpired: isExpired,
          tenantStatus: tenantStatus,
          monthlyBillingInr: (tenantRow['monthly_billing_inr'] as num?)?.toDouble() ?? 4999,
        );
      }
    } catch (_) {}

    // 3. Fallback: Profiles query
    String profileRole = '';
    String profileUsername = '';
    bool profileIsHead = false;
    List<String> profileAllowedModules = [];
    String profileDesignation = '';
    String profileCompany = '';

    try {
      final prof = cachedProfile ??
          await supabase
              .from('profiles')
              .select('username, role, is_head, allowed_modules, designation, company_name')
              .eq('id', user.id)
              .maybeSingle();

      if (prof != null) {
        profileRole = (prof['role'] ?? '').toString();
        profileUsername = (prof['username'] ?? '').toString();
        profileIsHead = prof['is_head'] == true;
        if (prof['allowed_modules'] is List) {
          profileAllowedModules = List<String>.from(prof['allowed_modules']);
        }
        profileDesignation = (prof['designation'] ?? '').toString();
        profileCompany = (prof['company_name'] ?? '').toString();
      }
    } catch (_) {}

    final isHead = profileIsHead || metadata['is_head'] == true || profileAllowedModules.isNotEmpty;
    final isSuperAdmin = !isHead && (profileRole.toUpperCase() == 'SUPERADMIN' || userEmail == 'team.anga9@gmail.com');
    final effectiveRole = isHead
        ? (profileDesignation.isNotEmpty ? profileDesignation : (profileRole.isNotEmpty ? profileRole : 'DEPARTMENT_HEAD'))
        : (profileRole.isNotEmpty ? profileRole : (isSuperAdmin ? 'SUPERADMIN' : 'STAFF')).toUpperCase();

    // 4. Legacy Nubira User Check (matches web logic)
    final isLegacyNubiraUser = !userEmail.contains('@designer.') && (
        userEmail == 'team.anga9@gmail.com' ||
        userEmail == 'admin@nubira.local' ||
        userEmail.endsWith('@nubira.local') ||
        userEmail == 'creationnubira@gmail.com' ||
        userEmail.startsWith('admin') ||
        metadata['company'] == 'Nubira Creation' ||
        profileCompany.toLowerCase() == 'nubira creation');

    if (isLegacyNubiraUser) {
      return ResolvedTenantProfile(
        userId: user.id,
        userEmail: userEmail,
        role: effectiveRole,
        isSuperAdmin: isSuperAdmin || userEmail == 'team.anga9@gmail.com' || userEmail == 'admin@nubira.local' || userEmail.startsWith('admin'),
        isPlatformAdmin: false,
        companyName: 'Nubira Creation',
        adminDisplayName: profileUsername.isNotEmpty ? profileUsername : 'Nubira Admin',
        customUsername: profileUsername.isNotEmpty ? profileUsername : 'admin',
        phone: '+91 98765 43210',
        cityState: 'Kolkata, West Bengal',
        subscriptionTier: 'FULL_PLANT_AI',
        allowedDivisions: profileAllowedModules.isNotEmpty ? profileAllowedModules : allDefaultDivisions,
        isProvisionedTenant: false,
        accessType: 'DEMO_TRIAL',
        expiresAt: '2026-09-22T23:59:59.000Z',
      );
    }

    // 5. Default Generic / Client Tenant Fallback
    final inferredCompanyName = userEmail.contains('shaw')
        ? 'Shaw Industries'
        : (profileCompany.isNotEmpty
            ? profileCompany
            : '${userEmail.split('@').first.replaceAll(RegExp(r'[._-]'), ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ')} Enterprise');

    return ResolvedTenantProfile(
      userId: user.id,
      userEmail: userEmail,
      role: effectiveRole,
      isSuperAdmin: isSuperAdmin,
      isPlatformAdmin: false,
      companyName: inferredCompanyName,
      adminDisplayName: profileUsername.isNotEmpty ? profileUsername : (metadata['displayName'] ?? 'Plant Head'),
      customUsername: profileUsername.isNotEmpty ? profileUsername : '${userEmail.split('@').first}_admin',
      phone: '',
      cityState: 'India',
      subscriptionTier: 'FULL_PLANT_AI',
      allowedDivisions: allDefaultDivisions,
      isProvisionedTenant: true,
      accessType: 'DEMO_TRIAL',
      expiresAt: '2026-09-22T23:59:59.000Z',
    );
  }
}
