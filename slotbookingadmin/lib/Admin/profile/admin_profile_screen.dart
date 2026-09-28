import 'dart:io';

import 'package:slotbookingadmin/core/api/api_services.dart';
import 'package:slotbookingadmin/core/api/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:slotbookingadmin/theme/app_colors.dart'; // adjust import path as needed

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  Map<String,dynamic>? _user = SessionManager.currentUser;
  final _profileApi = ProfileApi();
  final _formKey = GlobalKey<FormState>();

  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;

  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: (_user?['name'] ?? 'Admin').toString(),
    );
    _phoneController = TextEditingController(text: (_user?['phone'] ?? '').toString());
    _bioController = TextEditingController(
      text: 'Managing sports grounds & bookings.',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = await _profileApi.update(name: _nameController.text.trim(), phone: _phoneController.text.trim(), bio: _bioController.text.trim(), photo: _pickedImage);
      _user = updated;
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        _snack('Profile updated successfully', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _snack('Update failed: $e', isError: true);
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Sign out?',
          style: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Youll be redirected to the login screen.',
          style: TextStyle(fontFamily: 'Lexend'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Sign out',
              style: TextStyle(fontFamily: 'Lexend'),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await SessionManager.clear();
      if (mounted) context.go('/admin/login');
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Lexend')),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HeroBanner(
              user: _user,
              pickedImage: _pickedImage,
              isEditing: _isEditing,
              onPickImage: _pickImage,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatsRow(),
                  const SizedBox(height: 28),
                  _buildAccountSection(),
                  const SizedBox(height: 22),
                  _buildBioSection(),
                  const SizedBox(height: 22),
                  _buildSecuritySection(),
                  const SizedBox(height: 32),
                  _buildSignOutButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Profile',
        style: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      actions: [
        if (!_isEditing)
          TextButton(
            onPressed: () => setState(() => _isEditing = true),
            child: const Text(
              'Edit',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          )
        else ...[
          TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: AppColors.divider),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Account info'),
        const SizedBox(height: 10),
        _FlatCard(
          children: [
            _ProfileField(
              icon: Icons.person_outline_rounded,
              label: 'Display name',
              controller: _nameController,
              isEditing: _isEditing,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const _CardDivider(),
            _ProfileField(
              icon: Icons.email_outlined,
              label: 'Email',
              staticValue: (_user?['email'] ?? '—').toString(),
              isEditing: false,
            ),
            const _CardDivider(),
            _ProfileField(
              icon: Icons.phone_outlined,
              label: 'Phone',
              controller: _phoneController,
              isEditing: _isEditing,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Bio'),
        const SizedBox(height: 10),
        _FlatCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _isEditing
                  ? TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write something about yourself…',
                        hintStyle: TextStyle(
                          fontFamily: 'Lexend',
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      _bioController.text.isNotEmpty
                          ? _bioController.text
                          : 'No bio added.',
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Security'),
        const SizedBox(height: 10),
        _FlatCard(
          children: [
            _ActionTile(
              icon: Icons.lock_reset_outlined,
              label: 'Change password',
              iconColor: AppColors.primary,
              onTap: () async {
                _snack('Password changes are handled securely through the API.', isError: false);
              },
            ),
            const _CardDivider(),
            _ActionTile(
              icon: Icons.verified_user_outlined,
              label: 'Email verified',
              iconColor: (_user?['emailVerified'] ?? _user?['isEmailVerified'] ?? true) == true
                  ? AppColors.success
                  : AppColors.warning,
              showChevron: false,
              trailing: _StatusChip(
                label: (_user?['emailVerified'] ?? _user?['isEmailVerified'] ?? true) == true ? 'Verified' : 'Unverified',
                isPositive: (_user?['emailVerified'] ?? _user?['isEmailVerified'] ?? true) == true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade300, width: 1),
          backgroundColor: Colors.red.shade50,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        icon: Icon(Icons.logout_rounded, size: 18, color: Colors.red.shade600),
        label: Text(
          'Sign out',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade600,
          ),
        ),
        onPressed: _confirmSignOut,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero banner — pink gradient, avatar, name, email
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final Map<String,dynamic>? user;
  final File? pickedImage;
  final bool isEditing;
  final VoidCallback onPickImage;

  const _HeroBanner({
    required this.user,
    required this.pickedImage,
    required this.isEditing,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final initials = ((user?['name'] ?? 'A').toString())[0].toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        // Subtle pink tint — not saturated, clean like the rest of the app
        color: Color(0xFFFFF0F6),
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  color: const Color(0xFFFFD6E9),
                ),
                child: ClipOval(
                  child: pickedImage != null
                      ? Image.file(pickedImage!, fit: BoxFit.cover)
                      : (user?['photoUrl'] != null
                            ? Image.network(user!['photoUrl'].toString(), fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )),
                ),
              ),
              if (isEditing)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: onPickImage,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            (user?['name'] ?? 'Admin').toString(),
            style: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (user?['email'] ?? '').toString(),
            style: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          // Role chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Text(
              'Ground Admin',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _StatCard(value: '4', label: 'Grounds'),
        SizedBox(width: 10),
        _StatCard(value: '128', label: 'Bookings'),
        SizedBox(width: 10),
        _StatCard(value: '₹48K', label: 'Revenue'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card shell — matches cardTheme (elevation 0, border, radius 8)
// ─────────────────────────────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  final List<Widget> children;
  const _FlatCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.divider);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile field — view / edit mode
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? staticValue;
  final TextEditingController? controller;
  final bool isEditing;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _ProfileField({
    required this.icon,
    required this.label,
    this.staticValue,
    this.controller,
    required this.isEditing,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: isEditing && controller != null
                ? TextFormField(
                    controller: controller,
                    validator: validator,
                    keyboardType: keyboardType,
                    style: const TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        controller?.text.isNotEmpty == true
                            ? controller!.text
                            : (staticValue ?? '—'),
                        style: const TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Lexend',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.onTap,
    this.trailing,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ?trailing,
            if (showChevron && trailing == null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isPositive;

  const _StatusChip({required this.label, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
