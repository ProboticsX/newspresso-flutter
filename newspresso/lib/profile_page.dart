import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'audio_manager.dart';

// ─── Profile Page ─────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSigningOut = false;
  Map<String, dynamic>? _userProfile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final result = await Supabase.instance.client
          .from('users')
          .select('first_name, last_name, date_of_birth, gender, username, email')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _userProfile = result;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    setState(() => _isSigningOut = true);
    try {
      await AudioManager.instance.stop();
      await Future.delayed(const Duration(milliseconds: 600));
      await GoogleSignIn().signOut();
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (context.mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = Supabase.instance.client.auth.currentUser;
    final avatarUrl =
        authUser?.userMetadata?['avatar_url']?.toString() ??
        authUser?.userMetadata?['picture']?.toString();
    final email = authUser?.email ?? '';

    final firstName = _userProfile?['first_name']?.toString() ?? '';
    final lastName = _userProfile?['last_name']?.toString() ?? '';
    final fullName = [firstName, lastName]
        .where((s) => s.isNotEmpty)
        .join(' ')
        .trim();
    final username = _userProfile?['username']?.toString() ?? '';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B4E38), Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.35],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // ── Progress bar while signing out ────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSigningOut
                    ? LinearProgressIndicator(
                        key: const ValueKey('progress'),
                        backgroundColor: Colors.white12,
                        color: const Color(0xFFC8936A),
                        minHeight: 2,
                      )
                    : const SizedBox(key: ValueKey('empty'), height: 2),
              ),
            ),

            Expanded(
              child: _loadingProfile
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFC8936A)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Avatar ──────────────────────────────────────
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[800],
                              border: Border.all(
                                color: const Color(0xFFC8936A)
                                    .withValues(alpha: 0.5),
                                width: 2,
                              ),
                              image: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? const Icon(Icons.person,
                                    color: Colors.white54, size: 44)
                                : null,
                          ),

                          const SizedBox(height: 12),

                          Text(
                            fullName.isNotEmpty ? fullName : 'Newspresso User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            username.isNotEmpty ? '@$username' : '',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Account Settings (navigates to detail page) ──
                          _InfoCard(
                            children: [
                              _ActionTile(
                                iconBg: const Color(0xFF1A1A2E),
                                icon: Icons.settings_outlined,
                                iconColor: const Color(0xFFC8936A),
                                label: 'Account Settings',
                                subtitle: 'Manage your information & account',
                                labelColor: Colors.white,
                                showChevron: true,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AccountSettingsPage(
                                        userProfile: _userProfile,
                                        email: email,
                                      ),
                                    ),
                                  );
                                  // Refresh in case profile was edited
                                  _fetchUserProfile();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // ── Log Out ──────────────────────────────────────
                          _InfoCard(
                            children: [
                              _ActionTile(
                                iconBg: const Color(0xFF1A2A1A),
                                icon: Icons.logout,
                                iconColor: Colors.white70,
                                label: 'Log Out',
                                labelColor: Colors.white,
                                showChevron: false,
                                onTap: _isSigningOut
                                    ? null
                                    : () => _signOut(context),
                              ),
                            ],
                          ),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Account Settings Page ────────────────────────────────────────────────────

class AccountSettingsPage extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final String email;

  const AccountSettingsPage({
    super.key,
    required this.userProfile,
    required this.email,
  });

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool _isDeleting = false;
  bool _showDeleteSuccess = false;
  late Map<String, dynamic>? _profile;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.userProfile != null
        ? Map<String, dynamic>.from(widget.userProfile!)
        : null;
  }

  String _formatDob(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Capture navigator before any awaits
    final navigator = Navigator.of(context);

    setState(() => _isDeleting = true);
    try {
      await AudioManager.instance.stop();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('users')
            .delete()
            .eq('id', userId);
      }
      await GoogleSignIn().signOut();
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _showDeleteSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted) navigator.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete account. Please try again: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  Widget _buildStatusOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B4E38), Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.35],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showDeleteSuccess) ...[
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Account Deleted',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your account has been successfully deleted!',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      color: Colors.redAccent,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Deleting Account...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Please wait while we remove your data',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.white12,
                      color: Colors.redAccent,
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleting || _showDeleteSuccess) {
      return Scaffold(body: _buildStatusOverlay());
    }

    final firstName = _profile?['first_name']?.toString() ?? '';
    final lastName = _profile?['last_name']?.toString() ?? '';
    final fullName = [firstName, lastName]
        .where((s) => s.isNotEmpty)
        .join(' ')
        .trim();
    final dob = _formatDob(_profile?['date_of_birth']?.toString());
    final gender = _profile?['gender']?.toString() ?? '—';
    final username = _profile?['username']?.toString() ?? '';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B4E38), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 28),
                    ),
                    const Text(
                      'Account Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Edit button
                    IconButton(
                      onPressed: () async {
                        final updated =
                            await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditProfilePage(userProfile: _profile),
                          ),
                        );
                        if (updated != null && mounted) {
                          setState(() => _profile = updated);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white70, size: 22),
                      tooltip: 'Edit profile',
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── User Information ─────────────────────────────────
                      _SectionHeader(
                        icon: Icons.person_outline,
                        label: 'User Information',
                      ),
                      const SizedBox(height: 8),
                      _InfoCard(
                        children: [
                          _InfoTile(
                            iconBg: const Color(0xFF1A2A5E),
                            icon: Icons.person,
                            label: 'Name',
                            value: fullName.isNotEmpty ? fullName : '—',
                          ),
                          _Divider(),
                          _InfoTile(
                            iconBg: const Color(0xFF1A3A1A),
                            icon: Icons.calendar_month,
                            label: 'Date of Birth',
                            value: dob,
                          ),
                          _Divider(),
                          _InfoTile(
                            iconBg: const Color(0xFF3A1A5E),
                            icon: Icons.people,
                            label: 'Gender',
                            value: gender,
                          ),
                          _Divider(),
                          _InfoTile(
                            iconBg: const Color(0xFF1E1410),
                            icon: Icons.alternate_email,
                            label: 'Username',
                            value: username.isNotEmpty ? username : '—',
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Account Details ───────────────────────────────────
                      _SectionHeader(
                        icon: Icons.manage_accounts_outlined,
                        label: 'Account Details',
                      ),
                      const SizedBox(height: 8),
                      _InfoCard(
                        children: [
                          // Connected Account
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A2E),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CustomPaint(
                                          painter: _GoogleGPainter()),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Connected Account',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.email,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 14),
                                ),
                              ],
                            ),
                          ),
                          _Divider(),
                          // Delete Account
                          _ActionTile(
                            iconBg: const Color(0xFF3A1010),
                            icon: Icons.delete_outline,
                            iconColor: Colors.redAccent,
                            label: 'Delete Account',
                            subtitle:
                                'Permanently delete your account and all data',
                            labelColor: Colors.redAccent,
                            showChevron: true,
                            onTap: _isDeleting
                                ? null
                                : () => _deleteAccount(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Edit Profile Page ────────────────────────────────────────────────────────

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const EditProfilePage({super.key, required this.userProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Name
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  // Username
  late final TextEditingController _usernameController;
  String _originalUsername = '';
  String? _usernameError;
  String? _usernameSuccess;
  bool _isCheckingUsername = false;
  Timer? _usernameDebounce;

  // Gender
  String? _selectedGender;

  // DOB
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  late final List<int> _years;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _yearController;
  int _selectedMonthIdx = 0;
  int _selectedDay = 1;
  int _selectedYear = 2000;

  // Save state
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final p = widget.userProfile;

    _firstNameController =
        TextEditingController(text: p?['first_name']?.toString() ?? '');
    _lastNameController =
        TextEditingController(text: p?['last_name']?.toString() ?? '');

    _originalUsername = p?['username']?.toString() ?? '';
    _usernameController = TextEditingController(text: _originalUsername);
    // Pre-validate unchanged username
    if (_originalUsername.isNotEmpty &&
        _originalUsername.length >= 6 &&
        RegExp(r'^[a-zA-Z0-9]+$').hasMatch(_originalUsername)) {
      _usernameSuccess = 'Current username';
    }

    _selectedGender = p?['gender']?.toString();

    // Parse DOB
    DateTime dob = DateTime(2000, 1, 1);
    final dobStr = p?['date_of_birth']?.toString();
    if (dobStr != null && dobStr.isNotEmpty) {
      try {
        dob = DateTime.parse(dobStr);
      } catch (_) {}
    }
    _selectedMonthIdx = dob.month - 1;
    _selectedDay = dob.day;
    _selectedYear = dob.year;

    final now = DateTime.now();
    _years =
        List.generate(now.year - 1900 + 1, (i) => 1900 + i).reversed.toList();
    final yearInitIdx =
        _years.indexOf(_selectedYear).clamp(0, _years.length - 1);

    _monthController =
        FixedExtentScrollController(initialItem: _selectedMonthIdx);
    _dayController =
        FixedExtentScrollController(initialItem: _selectedDay - 1);
    _yearController = FixedExtentScrollController(initialItem: yearInitIdx);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  // ── DOB helpers ──────────────────────────────────────────────────────────

  int _daysInSelectedMonth() =>
      DateTime(_selectedYear, _selectedMonthIdx + 2, 0).day;

  DateTime get _selectedDate =>
      DateTime(_selectedYear, _selectedMonthIdx + 1, _selectedDay);

  int get _calculatedAge {
    final now = DateTime.now();
    final dob = _selectedDate;
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  bool get _isAgeValid => _calculatedAge >= 13;

  // ── Username validation ───────────────────────────────────────────────────

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    setState(() {
      _usernameError = null;
      _usernameSuccess = null;
      _isCheckingUsername = false;
    });

    if (value.isEmpty) return;

    // Restore success immediately if reverted to original
    if (value == _originalUsername) {
      setState(() => _usernameSuccess = 'Current username');
      return;
    }

    if (value.length < 6) {
      setState(
          () => _usernameError = 'Username must be at least 6 characters.');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
      setState(() => _usernameError =
          'Only letters and numbers are allowed (no spaces or symbols).');
      return;
    }

    setState(() => _isCheckingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        final result = await Supabase.instance.client
            .from('users')
            .select('username')
            .eq('username', value)
            .maybeSingle();
        if (!mounted) return;
        setState(() {
          _isCheckingUsername = false;
          if (result != null) {
            _usernameError = 'This username is already taken.';
            _usernameSuccess = null;
          } else {
            _usernameError = null;
            _usernameSuccess = 'Username is available!';
          }
        });
      } catch (_) {
        if (mounted) setState(() => _isCheckingUsername = false);
      }
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  bool get _canSave {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) { return false; }
    if (_usernameController.text.trim().isEmpty) { return false; }
    if (_usernameError != null || _isCheckingUsername) { return false; }
    if (_usernameSuccess == null) { return false; }
    if (_selectedGender == null) { return false; }
    if (!_isAgeValid) { return false; }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final newDob = _selectedDate;
      final updates = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'gender': _selectedGender,
        'date_of_birth': newDob.toIso8601String(),
        'age': _calculatedAge,
      };

      await Supabase.instance.client
          .from('users')
          .update(updates)
          .eq('id', userId);

      if (mounted) {
        Navigator.pop(context, {
          ...updates,
          'email': widget.userProfile?['email'],
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'Failed to save changes. Please try again.';
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final daysCount = _daysInSelectedMonth();
    final age = _calculatedAge;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B4E38), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 28),
                    ),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Save button
                    _isSaving
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFFC8936A),
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: _canSave ? _save : null,
                            child: Text(
                              'Save',
                              style: TextStyle(
                                color: _canSave
                                    ? const Color(0xFFC8936A)
                                    : Colors.white24,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              // ── Error banner ─────────────────────────────────────────────
              if (_saveError != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _saveError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Personal Info ────────────────────────────────────
                      _SectionHeader(
                          icon: Icons.person_outline, label: 'Personal Info'),
                      const SizedBox(height: 10),
                      _buildLabel('First Name'),
                      const SizedBox(height: 8),
                      _buildTextField(_firstNameController, 'Enter first name'),
                      const SizedBox(height: 16),
                      _buildLabel('Last Name'),
                      const SizedBox(height: 8),
                      _buildTextField(_lastNameController, 'Enter last name'),

                      const SizedBox(height: 28),

                      // ── Username ─────────────────────────────────────────
                      _SectionHeader(
                          icon: Icons.alternate_email, label: 'Username'),
                      const SizedBox(height: 10),
                      _buildLabel('Username'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        onChanged: _onUsernameChanged,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          hintText: 'e.g. newsreader42',
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF111111),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _isCheckingUsername
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Color(0xFFC8936A),
                                        strokeWidth: 2),
                                  ),
                                )
                              : _usernameSuccess != null
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : _usernameError != null
                                      ? const Icon(Icons.cancel,
                                          color: Colors.redAccent)
                                      : null,
                        ),
                      ),
                      if (_usernameError != null) ...[
                        const SizedBox(height: 6),
                        Text(_usernameError!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ],
                      if (_usernameSuccess != null) ...[
                        const SizedBox(height: 6),
                        Text(_usernameSuccess!,
                            style: const TextStyle(
                                color: Colors.green, fontSize: 13)),
                      ],

                      const SizedBox(height: 28),

                      // ── Gender ───────────────────────────────────────────
                      _SectionHeader(
                          icon: Icons.people_outline, label: 'Gender'),
                      const SizedBox(height: 10),
                      _InfoCard(
                        children: [
                          for (final g in ['Male', 'Female', 'Others']) ...[
                            if (g != 'Male') _Divider(),
                            InkWell(
                              onTap: () =>
                                  setState(() => _selectedGender = g),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _selectedGender == g
                                              ? const Color(0xFFC8936A)
                                              : Colors.white38,
                                          width: 2,
                                        ),
                                      ),
                                      child: _selectedGender == g
                                          ? const Center(
                                              child: CircleAvatar(
                                                radius: 5,
                                                backgroundColor:
                                                    Color(0xFFC8936A),
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      g,
                                      style: TextStyle(
                                        color: _selectedGender == g
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 15,
                                        fontWeight: _selectedGender == g
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Date of Birth ────────────────────────────────────
                      _SectionHeader(
                          icon: Icons.calendar_month_outlined,
                          label: 'Date of Birth'),
                      const SizedBox(height: 10),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Container(
                                height: 44,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                // Month
                                Expanded(
                                  flex: 3,
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _monthController,
                                    itemExtent: 44,
                                    perspective: 0.004,
                                    diameterRatio: 1.8,
                                    physics:
                                        const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (i) {
                                      final maxDays = DateTime(
                                              _selectedYear, i + 2, 0)
                                          .day;
                                      setState(
                                          () => _selectedMonthIdx = i);
                                      if (_selectedDay > maxDays) {
                                        setState(
                                            () => _selectedDay = maxDays);
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (mounted) {
                                            _dayController.animateToItem(
                                              maxDays - 1,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                        });
                                      }
                                    },
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                      childCount: 12,
                                      builder: (ctx, i) => _ScrollItem(
                                        label: _months[i],
                                        isSelected: i == _selectedMonthIdx,
                                      ),
                                    ),
                                  ),
                                ),
                                // Day
                                Expanded(
                                  flex: 2,
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _dayController,
                                    itemExtent: 44,
                                    perspective: 0.004,
                                    diameterRatio: 1.8,
                                    physics:
                                        const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (i) =>
                                        setState(() => _selectedDay = i + 1),
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                      childCount: daysCount,
                                      builder: (ctx, i) => _ScrollItem(
                                        label: '${i + 1}',
                                        isSelected:
                                            (i + 1) == _selectedDay,
                                      ),
                                    ),
                                  ),
                                ),
                                // Year
                                Expanded(
                                  flex: 2,
                                  child: ListWheelScrollView.useDelegate(
                                    controller: _yearController,
                                    itemExtent: 44,
                                    perspective: 0.004,
                                    diameterRatio: 1.8,
                                    physics:
                                        const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (i) {
                                      final newYear = _years[i];
                                      final maxDays = DateTime(newYear,
                                              _selectedMonthIdx + 2, 0)
                                          .day;
                                      setState(
                                          () => _selectedYear = newYear);
                                      if (_selectedDay > maxDays) {
                                        setState(
                                            () => _selectedDay = maxDays);
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (mounted) {
                                            _dayController.animateToItem(
                                              maxDays - 1,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                        });
                                      }
                                    },
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                      childCount: _years.length,
                                      builder: (ctx, i) => _ScrollItem(
                                        label: '${_years[i]}',
                                        isSelected:
                                            _years[i] == _selectedYear,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Age status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isAgeValid
                              ? Colors.green.withValues(alpha: 0.08)
                              : Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isAgeValid
                                ? Colors.green.withValues(alpha: 0.25)
                                : Colors.red.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isAgeValid
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: _isAgeValid
                                  ? Colors.green
                                  : Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              age >= 0
                                  ? 'Age: $age years old'
                                  : 'Please select a valid date',
                              style: TextStyle(
                                color: _isAgeValid
                                    ? Colors.green
                                    : Colors.redAccent,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      );

  Widget _buildTextField(TextEditingController ctrl, String hint) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF111111),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC8936A), size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.05),
      indent: 70,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.iconBg,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Color labelColor;
  final VoidCallback? onTap;
  final bool showChevron;

  const _ActionTile({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right,
                color: labelColor.withValues(alpha: 0.4),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

// Reusable scroll item for the DOB picker
class _ScrollItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  const _ScrollItem({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white38,
          fontSize: isSelected ? 17 : 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// Google "G" logo painter
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final ar = r * 0.64;
    final sw = r * 0.27;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: ar);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, 0.45, 0.85, false,
        paint..color = const Color(0xFFEA4335));
    canvas.drawArc(rect, 1.30, 1.55, false,
        paint..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, 2.85, 1.60, false,
        paint..color = const Color(0xFF34A853));
    canvas.drawArc(rect, 4.45, 1.38, false,
        paint..color = const Color(0xFF4285F4));

    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + ar, cy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
