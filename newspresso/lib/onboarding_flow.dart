import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingFlow({super.key, required this.onComplete});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _showCreateSuccess = false;

  // ── Page 1: Name ──────────────────────────────────────────────────────────
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _nameError;

  // ── Page 2: DOB ───────────────────────────────────────────────────────────
  static const _months = [
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  late final List<int> _years;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _yearController;

  int _selectedMonthIdx = 0;
  int _selectedDay = 1;
  int _selectedYear = 2000;

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

  // ── Page 3: Gender ────────────────────────────────────────────────────────
  String? _selectedGender;

  // ── Page 4: Username ──────────────────────────────────────────────────────
  final _usernameController = TextEditingController();
  String? _usernameError;
  String? _usernameSuccess;
  bool _isCheckingUsername = false;
  Timer? _usernameDebounce;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _years = List.generate(now.year - 1900 + 1, (i) => 1900 + i)
        .reversed
        .toList();
    final yearInitIdx = _years.indexOf(2000).clamp(0, _years.length - 1);
    _monthController = FixedExtentScrollController(initialItem: 0);
    _dayController = FixedExtentScrollController(initialItem: 0);
    _yearController = FixedExtentScrollController(initialItem: yearInitIdx);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  Future<void> _animateToPage(int page) async {
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    if (mounted) setState(() => _currentPage = page);
  }

  void _goBack() {
    if (_currentPage == 0) {
      _showAbandonDialog();
    } else {
      _animateToPage(_currentPage - 1);
    }
  }

  void _showAbandonDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Exit setup?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your account setup is incomplete. Exiting will delete your account and you\'ll need to sign in again.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Stay',
              style: TextStyle(
                  color: Color(0xFFC8936A), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _abandonOnboarding(
                'Account setup was not completed. Please sign in and try again.',
              );
            },
            child: const Text(
              'Exit',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abandonOnboarding(String reason) async {
    setState(() => _isLoading = true);
    LoginErrorState.message = reason;
    try {
      await Supabase.instance.client.rpc('delete_user');
    } catch (_) {}
    await Supabase.instance.client.auth.signOut();
    // Auth listener in main.dart routes back to LoginScreen automatically
  }

  // ── Page 1 actions ───────────────────────────────────────────────────────

  void _continuePage1() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(
          () => _nameError = 'Please enter both first and last name.');
      return;
    }
    setState(() => _nameError = null);
    _animateToPage(1);
  }

  // ── Page 2 actions ───────────────────────────────────────────────────────

  void _continuePage2() {
    if (_isAgeValid) _animateToPage(2);
  }

  // ── Page 3 actions ───────────────────────────────────────────────────────

  void _continuePage3() {
    if (_selectedGender != null) _animateToPage(3);
  }

  // ── Page 4 actions ───────────────────────────────────────────────────────

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    setState(() {
      _usernameError = null;
      _usernameSuccess = null;
      _isCheckingUsername = false;
    });

    if (value.isEmpty) return;

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

  Future<void> _submitOnboarding() async {
    if (_usernameSuccess == null || _isCheckingUsername) return;
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      await Supabase.instance.client.from('users').insert({
        'id': user.id,
        'username': _usernameController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': user.email,
        'date_of_birth': _selectedDate.toIso8601String(),
        'date_created': DateTime.now().toUtc().toIso8601String(),
        'age': _calculatedAge,
        'gender': _selectedGender,
      });
      if (mounted) {
        setState(() => _showCreateSuccess = true);
        await Future.delayed(const Duration(milliseconds: 2500));
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showCreateSuccess = false;
          _usernameError = 'Failed to create profile. Please try again.';
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
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
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_showCreateSuccess) ...[
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
                                    'Account Created!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Your account has been successfully created!',
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
                                      color: Color(0xFFC8936A),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Creating Account...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Setting up your Newspresso profile',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 28),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: const LinearProgressIndicator(
                                      backgroundColor: Colors.white12,
                                      color: Color(0xFFC8936A),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildNamePage(),
                            _buildDobPage(),
                            _buildGenderPage(),
                            _buildUsernamePage(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isLoading ? null : _goBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.chevron_left,
                  color: Colors.white, size: 22),
            ),
          ),
          const Spacer(),
          Row(
            children: List.generate(4, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isActive ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFC8936A)
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Page 1: Name ──────────────────────────────────────────────────────────

  Widget _buildNamePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(child: _IconCircle(icon: Icons.person_outline)),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              "What's your name?",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'This helps us personalize your experience',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          _buildLabel('First Name'),
          const SizedBox(height: 8),
          _buildTextField(_firstNameController, 'Enter your first name'),
          const SizedBox(height: 20),
          _buildLabel('Last Name'),
          const SizedBox(height: 8),
          _buildTextField(_lastNameController, 'Enter your last name'),
          if (_nameError != null) ...[
            const SizedBox(height: 10),
            _buildErrorText(_nameError!),
          ],
          const SizedBox(height: 40),
          _buildContinueButton(_continuePage1),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Page 2: DOB ───────────────────────────────────────────────────────────

  Widget _buildDobPage() {
    final daysCount = _daysInSelectedMonth();
    final age = _calculatedAge;
    final isValid = age >= 13;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Center(child: _IconCircle(icon: Icons.calendar_month_outlined)),
          const SizedBox(height: 24),
          const Text(
            'When were you born?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'You must be at least 13 years old',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          // Scroll picker
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Stack(
              children: [
                // Selection highlight bar
                Center(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
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
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) {
                          final maxDays =
                              DateTime(_selectedYear, i + 2, 0).day;
                          setState(() => _selectedMonthIdx = i);
                          if (_selectedDay > maxDays) {
                            setState(() => _selectedDay = maxDays);
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (mounted) {
                                _dayController.animateToItem(
                                  maxDays - 1,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          }
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
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
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _selectedDay = i + 1),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: daysCount,
                          builder: (ctx, i) => _ScrollItem(
                            label: '${i + 1}',
                            isSelected: (i + 1) == _selectedDay,
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
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) {
                          final newYear = _years[i];
                          final maxDays = DateTime(
                                  newYear, _selectedMonthIdx + 2, 0)
                              .day;
                          setState(() => _selectedYear = newYear);
                          if (_selectedDay > maxDays) {
                            setState(() => _selectedDay = maxDays);
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (mounted) {
                                _dayController.animateToItem(
                                  maxDays - 1,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          }
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _years.length,
                          builder: (ctx, i) => _ScrollItem(
                            label: '${_years[i]}',
                            isSelected: _years[i] == _selectedYear,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Selected date chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today,
                    color: Color(0xFFC8936A), size: 16),
                const SizedBox(width: 8),
                const Text('Selected Date:',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 8),
                Text(
                  '${_months[_selectedMonthIdx]} $_selectedDay, $_selectedYear',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Age status
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isValid
                  ? Colors.green.withValues(alpha: 0.08)
                  : Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isValid
                    ? Colors.green.withValues(alpha: 0.25)
                    : Colors.red.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.error_outline,
                  color: isValid ? Colors.green : Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  age >= 0
                      ? 'Age: $age years old'
                      : 'Please select a valid date',
                  style: TextStyle(
                    color: isValid ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildContinueButton(isValid ? _continuePage2 : null),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Page 3: Gender ────────────────────────────────────────────────────────

  Widget _buildGenderPage() {
    const genders = ['Male', 'Female', 'Others'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Center(child: _IconCircle(icon: Icons.people_outline)),
          const SizedBox(height: 24),
          const Text(
            "What's your gender?",
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'This helps us provide better content\nrecommendations',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ...genders.map(
            (g) => _GenderOption(
              label: g,
              isSelected: _selectedGender == g,
              onTap: () => setState(() => _selectedGender = g),
            ),
          ),
          const SizedBox(height: 32),
          _buildContinueButton(
              _selectedGender != null ? _continuePage3 : null),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Page 4: Username ──────────────────────────────────────────────────────

  Widget _buildUsernamePage() {
    final canSubmit = _usernameSuccess != null && !_isCheckingUsername;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(child: _IconCircle(icon: Icons.alternate_email)),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Pick a username',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Min. 6 characters — letters and numbers only',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          _buildLabel('Username'),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            onChanged: _onUsernameChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'e.g. newsreader42',
              hintStyle: const TextStyle(color: Colors.white38),
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
                            color: Color(0xFFC8936A), strokeWidth: 2),
                      ),
                    )
                  : _usernameSuccess != null
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : _usernameError != null
                          ? const Icon(Icons.cancel,
                              color: Colors.redAccent)
                          : null,
            ),
          ),
          if (_usernameError != null) ...[
            const SizedBox(height: 8),
            _buildErrorText(_usernameError!),
          ],
          if (_usernameSuccess != null) ...[
            const SizedBox(height: 8),
            Text(_usernameSuccess!,
                style: const TextStyle(color: Colors.green, fontSize: 13)),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canSubmit ? _submitOnboarding : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8936A),
                disabledBackgroundColor: const Color(0xFF3A2A1A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Create Account',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.check, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15),
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

  Widget _buildErrorText(String text) =>
      Text(text, style: const TextStyle(color: Colors.redAccent, fontSize: 13));

  Widget _buildContinueButton(VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC8936A),
            disabledBackgroundColor: const Color(0xFF3A2A1A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Continue',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            ],
          ),
        ),
      );
}

// ─── Reusable sub-widgets ────────────────────────────────────────────────────

class _IconCircle extends StatelessWidget {
  final IconData icon;
  const _IconCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1410),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Icon(icon, color: const Color(0xFFC8936A), size: 38),
    );
  }
}

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

class _GenderOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _GenderOption(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2A1E14)
                : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFC8936A)
                  : Colors.white.withValues(alpha: 0.06),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFC8936A)
                        : Colors.white38,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: CircleAvatar(
                          radius: 5,
                          backgroundColor: Color(0xFFC8936A),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 16,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
