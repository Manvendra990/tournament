import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';
import 'package:slotbooking/core/api/api_services.dart';
import 'package:slotbooking/core/api/session_manager.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final ProfileApi _profileApi = ProfileApi();
  late Future<Map<String, dynamic>> _profileFuture;
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileApi.get();
    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _avatarScale = CurvedAnimation(
      parent: _avatarController,
      curve: Curves.elasticOut,
    );
    _avatarController.forward();
  }

  @override
  void dispose() {
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await _profileApi.update(photo: File(picked.path));
      if (!mounted) return;
      setState(() {
        _profileFuture = _profileApi.get();
      });
      _avatarController
        ..reset()
        ..forward();
    } catch (e) {
      _showSnack('Failed to upload photo: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _editProfile(Map<String, dynamic> userData) async {
    final updatedUser = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _EditProfileDialog(profileApi: _profileApi, userData: userData),
    );

    if (updatedUser != null && mounted) {
      setState(() {
        _profileFuture = Future.value(updatedUser);
      });
      _showSnack('Profile updated');
    }
  }

  Future<void> _signOut() async {
    await SessionManager.clear();
    if (mounted) {
      context.go('/user/login');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<Map<String, int>> _fetchStats() async {
    if (!SessionManager.isLoggedIn) {
      return {'bookings': 0, 'spent': 0, 'grounds': 0};
    }
    final bookings = await BookingApi().mine();
    final total = bookings.fold<int>(0, (sum, b) {
      return sum + ((b['amount'] as num?)?.toInt() ?? 0);
    });
    final grounds = bookings
        .map((b) => b['groundId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    return {
      'bookings': bookings.length,
      'spent': total,
      'grounds': grounds.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final userData = snapshot.data ?? SessionManager.currentUser ?? {};
          final displayName = userData['name'] as String? ?? 'Player';
          final email = userData['email'] as String? ?? '';
          final phone = userData['phone']?.toString() ?? '';
          final photoUrl = userData['photoUrl'] as String?;

          return CustomScrollView(
            slivers: [
              // ── Header ─────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                // Back arrow
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                // Edit icon top-right (image jaise)
                actions: [
                  IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed: () => _editProfile(userData),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _ProfileHeader(
                    displayName: displayName,
                    email: email,
                    photoUrl: photoUrl,
                    avatarScale: _avatarScale,
                    isUploading: _isUploadingPhoto,
                    onTapPhoto: _pickAndUploadPhoto,
                  ),
                ),
              ),

              // ── Body ───────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats
                      FutureBuilder<Map<String, int>>(
                        future: _fetchStats(),
                        builder: (context, snap) {
                          final stats =
                              snap.data ??
                              {'bookings': 0, 'spent': 0, 'grounds': 0};
                          return _StatsRow(stats: stats);
                        },
                      ),

                      const SizedBox(height: 24),

                      // Account section — phone removed
                      _SectionLabel(label: 'Account'),
                      const SizedBox(height: 10),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.person_outline_rounded,
                            label: 'Full Name',
                            trailing: displayName,
                          ),
                          if (phone.isNotEmpty)
                            _MenuItem(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              trailing: phone,
                            ),
                          if (email.isNotEmpty)
                            _MenuItem(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              trailing: email,
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // More section
                      _SectionLabel(label: 'More'),
                      const SizedBox(height: 10),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.history_rounded,
                            label: 'Booking History',
                            showArrow: true,
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.receipt_long_rounded,
                            label: 'Transactions',
                            showArrow: true,
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.help_outline_rounded,
                            label: 'Help & Support',
                            showArrow: true,
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.info_outline_rounded,
                            label: 'About App',
                            showArrow: true,
                            onTap: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _LogoutButton(onTap: _signOut),

                      const SizedBox(height: 28),

                      Center(
                        child: AppText.bodyMedium('Ground Booking • v1.0.0'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const UserNavBar(currentIndex: 3),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final ProfileApi profileApi;
  final Map<String, dynamic> userData;

  const _EditProfileDialog({required this.profileApi, required this.userData});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.userData['name']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userData['phone']?.toString() ?? '',
    );
    _bioController = TextEditingController(
      text: widget.userData['bio']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final user = await widget.profileApi.update(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(user);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Failed to update profile: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your phone number'
                      : null,
                ),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final Animation<double> avatarScale;
  final bool isUploading;
  final VoidCallback onTapPhoto;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.avatarScale,
    required this.isUploading,
    required this.onTapPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkRed, AppTheme.primaryRed, Color(0xFFE8354A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar — floating above glass card
                  ScaleTransition(
                    scale: avatarScale,
                    child: GestureDetector(
                      onTap: onTapPhoto,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 102,
                            height: 102,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl!)
                                : null,
                            child: photoUrl == null
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          if (isUploading)
                            const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Glass card — name + badge + email
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Name
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Active Member badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D6A4F),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Active Member',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.2),
                          height: 1,
                        ),
                        const SizedBox(height: 12),

                        // Email row only (phone removed)
                        if (email.isNotEmpty)
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.mail_outline_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          icon: Icons.event_available_rounded,
          value: '${stats['bookings']}',
          label: 'Bookings',
          iconColor: AppTheme.primaryRed,
          iconBg: AppTheme.lightRed,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.currency_rupee_rounded,
          value: '₹${stats['spent']}',
          label: 'Total Spent',
          iconColor: AppTheme.success,
          iconBg: const Color(0xFFDCFCE7),
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.sports_soccer_rounded,
          value: '${stats['grounds']}',
          label: 'Grounds',
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color iconBg;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          AppText.label(label.toUpperCase(), color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

// ─── Menu Card ────────────────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              _MenuItemTile(item: item),
              if (i < items.length - 1)
                Divider(height: 1, indent: 54, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.showArrow = false,
    this.onTap,
  });
}

class _MenuItemTile extends StatelessWidget {
  final _MenuItem item;
  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: AppTheme.primaryRed),
            ),
            const SizedBox(width: 14),
            Expanded(child: AppText.bodyLarge(item.label)),
            if (item.trailing != null)
              Flexible(
                child: AppText.bodyMedium(
                  item.trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (item.showArrow)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.lightRed,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              color: AppTheme.primaryRed,
              size: 20,
            ),
            const SizedBox(width: 10),
            AppText.bodyLarge('Log Out', color: AppTheme.primaryRed),
          ],
        ),
      ),
    );
  }
}
