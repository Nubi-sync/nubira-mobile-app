import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import 'department_heads_screen.dart';

// ============================================================================
// APPOINT DEPARTMENT HEAD FULL-SCREEN FORM SHEET (Strictly matching Web Form)
// ============================================================================

class AppointDepartmentHeadScreen extends ConsumerStatefulWidget {
  final DepartmentHeadItem? existingHead;
  final String companyName;
  final List<String>? allowedDivisions;

  const AppointDepartmentHeadScreen({
    super.key,
    this.existingHead,
    required this.companyName,
    this.allowedDivisions,
  });

  /// Static helper to open the appoint head full-screen sheet
  static Future<bool?> show(
    BuildContext context, {
    DepartmentHeadItem? existingHead,
    required String companyName,
    List<String>? allowedDivisions,
  }) {
    final mediaQuery = MediaQuery.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      constraints: BoxConstraints(
        maxWidth: mediaQuery.size.width,
        maxHeight: mediaQuery.size.height * 0.92,
      ),
      builder: (ctx) => AppointDepartmentHeadScreen(
        existingHead: existingHead,
        companyName: companyName,
        allowedDivisions: allowedDivisions,
      ),
    );
  }

  @override
  ConsumerState<AppointDepartmentHeadScreen> createState() => _AppointDepartmentHeadScreenState();
}

class _AppointDepartmentHeadScreenState extends ConsumerState<AppointDepartmentHeadScreen> {
  // Theme Color Constants (Strictly matching specifications)
  static const Color kBrandIndigo = Color(0xFF332B6B);
  static const Color kSheetBg = Color(0xFFFFFFFF);
  static const Color kTextPrimary = Color(0xFF1C1C1A);
  static const Color kLabelText = Color(0xFF9B9A94);
  static const Color kPlaceholderText = Color(0xFFB6B4AC);
  static const Color kInputBorder = Color(0xFFDAD9D3);
  static const Color kBadgeAmberBg = Color(0xFFFDF0DC);
  static const Color kBadgeAmberText = Color(0xFF8A6D2F);

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  List<String> _selectedModules = [];
  bool _isSaving = false;
  bool _obscurePassword = false;
  String? _inlineUsernameError;
  String? _generalError;

  // Track initial values for unsaved changes confirmation
  late String _initialName;
  late String _initialUsername;
  late String _initialDesignation;
  late String _initialPhone;
  late List<String> _initialModules;

  List<DepartmentHeadCatalogDef> get _availableDivisions {
    final allowed = widget.allowedDivisions;
    if (allowed == null || allowed.isEmpty || allowed.contains('/modules')) {
      return kDepartmentHeadsCatalog;
    }
    return kDepartmentHeadsCatalog.where((div) => allowed.contains(div.route)).toList();
  }

  bool get _hasUnsavedChanges {
    return _nameCtrl.text != _initialName ||
        _usernameCtrl.text != _initialUsername ||
        _designationCtrl.text != _initialDesignation ||
        _phoneCtrl.text != _initialPhone ||
        _selectedModules.join(',') != _initialModules.join(',');
  }

  bool get _isFormValid {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final designation = _designationCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (name.isEmpty || username.isEmpty || designation.isEmpty) return false;
    if (widget.existingHead == null && password.length < 6) return false;
    if (_selectedModules.isEmpty) return false;
    if (_inlineUsernameError != null) return false;

    return true;
  }

  @override
  void initState() {
    super.initState();

    if (widget.existingHead != null) {
      final h = widget.existingHead!;
      _nameCtrl.text = h.displayName;
      _usernameCtrl.text = h.username;
      _designationCtrl.text = h.designation;
      _phoneCtrl.text = h.phone ?? '';
      _passwordCtrl.text = '';
      _selectedModules = List.from(h.allowedModules);
    } else {
      _nameCtrl.text = '';
      _usernameCtrl.text = '';
      _designationCtrl.text = '';
      _phoneCtrl.text = '';
      _selectedModules = [];
      final num = 1000 + Random().nextInt(9000);
      _passwordCtrl.text = '@Factory$num!';
    }

    _initialName = _nameCtrl.text;
    _initialUsername = _usernameCtrl.text;
    _initialDesignation = _designationCtrl.text;
    _initialPhone = _phoneCtrl.text;
    _initialModules = List.from(_selectedModules);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _designationCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _generateStrongPassword(String prefix) {
    final clean = prefix.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    final cap = clean.isNotEmpty ? clean[0].toUpperCase() + clean.substring(1).toLowerCase() : 'Factory';
    final num = 1000 + Random().nextInt(9000);
    _passwordCtrl.text = '@$cap$num!';
    if (mounted) {
      setState(() {});
    }
  }

  void _onNameChanged(String val) {
    setState(() {});
    if (widget.existingHead == null) {
      final clean = val.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
      if (clean.isNotEmpty) {
        final suffix = _selectedModules.isNotEmpty ? _selectedModules[0].replaceAll('/', '').replaceAll('-', '_') : 'head';
        _usernameCtrl.text = '${clean}_$suffix';
        _checkUsernameAvailability(_usernameCtrl.text);
      }
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() => _inlineUsernameError = null);
      return;
    }

    try {
      final res = await supabase
          .from('profiles')
          .select('id, username')
          .ilike('username', clean)
          .maybeSingle();

      if (res != null && (widget.existingHead == null || res['id'] != widget.existingHead!.id)) {
        if (mounted) {
          setState(() {
            _inlineUsernameError = 'Username "$clean" is already taken. Please choose another.';
          });
        }
      } else {
        if (mounted) {
          setState(() => _inlineUsernameError = null);
        }
      }
    } catch (_) {
      // Ignore network errors during debounce
    }
  }

  void _toggleModuleSelection(DepartmentHeadCatalogDef div) {
    setState(() {
      if (_selectedModules.contains(div.route)) {
        _selectedModules.remove(div.route);
        if (widget.existingHead == null && _selectedModules.isEmpty) {
          _designationCtrl.text = '';
        }
      } else {
        _selectedModules.add(div.route);
        if (widget.existingHead == null && _selectedModules.length == 1) {
          _designationCtrl.text = div.defaultDesignation;
          if (_nameCtrl.text.trim().isNotEmpty) {
            final clean = _nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
            _usernameCtrl.text = '${clean}_${div.code}';
            _checkUsernameAvailability(_usernameCtrl.text);
          }
        }
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || _isSaving) {
      return true;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Discard Unsaved Changes?',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
        ),
        content: Text(
          'You have filled form details that are not saved yet. Are you sure you want to discard them?',
          style: GoogleFonts.publicSans(fontSize: 13, color: AppTheme.mutedInk, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Editing', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: kBrandIndigo)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return discard ?? false;
  }

  Future<void> _handleConfirmSubmit() async {
    if (!_isFormValid) return;

    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.-]'), '');
    final designation = _designationCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    setState(() {
      _isSaving = true;
      _generalError = null;
    });

    try {
      final role = _deriveProfileRole(_selectedModules);

      if (widget.existingHead != null) {
        // Update existing head profile
        final updatePayload = {
          'username': name,
          'role': role,
          'designation': designation,
          'allowed_modules': _selectedModules,
          'company_name': widget.companyName,
          'is_head': true,
          'is_active': true,
          if (phone.isNotEmpty) 'phone': phone,
        };

        await supabase.from('profiles').update(updatePayload).eq('id', widget.existingHead!.id);
      } else {
        // Check duplicate username in profiles before insert
        final existing = await supabase
            .from('profiles')
            .select('id')
            .ilike('username', username)
            .maybeSingle();

        if (existing != null) {
          setState(() {
            _isSaving = false;
            _inlineUsernameError = 'Username "$username" already exists. Please choose a distinct username.';
          });
          return;
        }

        // Create new head in profiles
        final insertPayload = {
          'username': name,
          'role': role,
          'designation': designation,
          'allowed_modules': _selectedModules,
          'company_name': widget.companyName,
          'is_head': true,
          'is_active': true,
          if (phone.isNotEmpty) 'phone': phone,
        };

        await supabase.from('profiles').insert(insertPayload);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _generalError = 'Error saving Department Head: $e';
        });
      }
    }
  }

  String _deriveProfileRole(List<String> modules) {
    if (modules.contains('/stitching-sewing')) return 'PRODUCTION_MANAGER';
    if (modules.contains('/store')) return 'STORE';
    if (modules.contains('/ready-goods')) return 'QC';
    if (modules.contains('/alter')) return 'MENDING';
    if (modules.contains('/dispatch')) return 'DISPATCH';
    return 'ADMIN';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingHead != null;
    final available = _availableDivisions;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final bottomInset = mediaQuery.viewInsets.bottom;

    return PopScope(
      canPop: !_hasUnsavedChanges || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context, false);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          width: screenWidth,
          height: screenHeight * 0.90,
          child: Container(
            width: screenWidth,
            height: screenHeight * 0.90,
            decoration: const BoxDecoration(
              color: kSheetBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Material(
                color: kSheetBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag indicator bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 4),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDAD9D3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x14000000)),
                            ),
                            child: const Center(
                              child: Icon(Icons.person_add_outlined, color: kBrandIndigo, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: kBadgeAmberBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0x338A6D2F)),
                                      ),
                                      child: Text(
                                        isEditing ? 'EDIT HEAD' : 'Appoint head',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: kBadgeAmberText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '- ${widget.companyName}',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: kLabelText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEditing ? 'Edit department head' : 'Appoint department head',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: kTextPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                            onPressed: () async {
                              final shouldClose = await _onWillPop();
                              if (shouldClose && context.mounted) {
                                Navigator.pop(context, false);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0x14000000), height: 1),

                    // Form Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Field 1: Head Full Name
                              _buildFieldLabel('HEAD FULL NAME *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameCtrl,
                                onChanged: _onNameChanged,
                                style: GoogleFonts.publicSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: kTextPrimary,
                                ),
                                decoration: _buildInputDecoration(
                                  hintText: 'e.g. Mohd. Aslam',
                                  prefixIcon: Icons.person_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Field 2: Login Username / ID
                              _buildFieldLabel('LOGIN USERNAME / ID *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _usernameCtrl,
                                onChanged: (val) {
                                  setState(() {});
                                  _checkUsernameAvailability(val);
                                },
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: kTextPrimary,
                                ),
                                decoration: _buildInputDecoration(
                                  hintText: 'e.g. aslam_cutting',
                                  prefixIcon: Icons.alternate_email_rounded,
                                  errorText: _inlineUsernameError,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Field 3: Official Designation
                              _buildFieldLabel('OFFICIAL DESIGNATION *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _designationCtrl,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.publicSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: kTextPrimary,
                                ),
                                decoration: _buildInputDecoration(
                                  hintText: 'e.g. Cutting master / CAD head',
                                  prefixIcon: Icons.badge_outlined,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Field 4: Phone / WhatsApp
                              _buildFieldLabel('PHONE / WHATSAPP (OPTIONAL)'),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Dedicated Country Code Box
                                  Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFAF8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kInputBorder),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🇮🇳',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '+91',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: kTextPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Number Field
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: kTextPrimary,
                                      ),
                                      decoration: _buildInputDecoration(
                                        hintText: '98765 43210',
                                        prefixIcon: Icons.phone_outlined,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Field 5: Initial Password
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: _buildFieldLabel(isEditing ? 'UPDATE PASSWORD (OPTIONAL)' : 'INITIAL PASSWORD *'),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _generateStrongPassword(_nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Factory'),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, size: 13, color: kBrandIndigo),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Auto-generate strong',
                                            style: GoogleFonts.publicSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: kBrandIndigo,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscurePassword,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: kTextPrimary,
                                ),
                                decoration: _buildInputDecoration(
                                  hintText: isEditing ? 'Leave blank to keep unchanged' : 'Min 6 characters',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: kLabelText,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Field 6: Department / Unit Assignment
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: _buildFieldLabel('DEPARTMENT / UNIT ASSIGNMENT (${_selectedModules.length} SELECTED)'),
                                  ),
                                  if (_selectedModules.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedModules.clear();
                                          if (!isEditing) _designationCtrl.clear();
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Text(
                                          'Clear',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.mutedInk,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select the manufacturing unit this department head will lead:',
                                style: GoogleFonts.publicSans(fontSize: 12, color: AppTheme.mutedInk),
                              ),
                              const SizedBox(height: 8),

                              // Selectable Unit Rows
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAF8),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0x14000000)),
                                ),
                                child: available.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          'No authorized operating units found for this tenant.',
                                          style: GoogleFonts.publicSans(fontSize: 12.5, color: AppTheme.mutedInk),
                                        ),
                                      )
                                    : Column(
                                        children: available.map((div) {
                                          final isChecked = _selectedModules.contains(div.route);

                                          return InkWell(
                                            onTap: () => _toggleModuleSelection(div),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isChecked ? const Color(0xFFF9F9FB) : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isChecked ? kBrandIndigo : kInputBorder,
                                                  width: isChecked ? 1.5 : 1.0,
                                                ),
                                                boxShadow: isChecked
                                                    ? const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))]
                                                    : null,
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  // Checkbox
                                                  Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(5),
                                                      border: Border.all(
                                                        color: isChecked ? kBrandIndigo : const Color(0xFFCBD5E1),
                                                        width: 1.8,
                                                      ),
                                                      color: isChecked ? kBrandIndigo : Colors.white,
                                                    ),
                                                    child: isChecked
                                                        ? const Center(
                                                            child: Icon(Icons.check_rounded, color: Colors.white, size: 13),
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 12),

                                                  // Unit Icon
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFAF7F0),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0x14000000)),
                                                    ),
                                                    child: Icon(div.icon, size: 16, color: kBrandIndigo),
                                                  ),
                                                  const SizedBox(width: 10),

                                                  // Unit Name & Route
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '${div.code}. ${div.name}',
                                                          style: GoogleFonts.publicSans(
                                                            fontSize: 12.5,
                                                            fontWeight: isChecked ? FontWeight.bold : FontWeight.w600,
                                                            color: kTextPrimary,
                                                            height: 1.25,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          div.route,
                                                          style: GoogleFonts.jetBrainsMono(
                                                            fontSize: 10,
                                                            color: kPlaceholderText,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ),
                              const SizedBox(height: 14),

                              // General Error Notification
                              if (_generalError != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFECDD3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Color(0xFFBE123C), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _generalError!,
                                          style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF9F1239), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Sticky Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0x14000000))),
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () async {
                              final shouldClose = await _onWillPop();
                              if (shouldClose && context.mounted) {
                                Navigator.pop(context, false);
                              }
                            },
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mutedInk,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrandIndigo,
                              disabledBackgroundColor: kBrandIndigo.withValues(alpha: 0.35),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: (_isFormValid && !_isSaving) ? _handleConfirmSubmit : null,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    isEditing ? 'Save Head Changes' : 'Confirm & appoint head',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: kLabelText,
        letterSpacing: 0.8,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    IconData? prefixIcon,
    String? prefixText,
    TextStyle? prefixStyle,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.publicSans(fontSize: 13, color: kPlaceholderText),
      errorText: errorText,
      errorStyle: GoogleFonts.publicSans(fontSize: 11, color: const Color(0xFFBE123C)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF94A3B8)) : null,
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kInputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBrandIndigo, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBE123C), width: 1.5),
      ),
    );
  }
}
