import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_service.dart';
import 'login_screen.dart';

// ── Indian cities (city + state) for manual location search ──────────────────

const List<Map<String, String>> kIndianCities = [
  {'city': 'Mumbai', 'state': 'Maharashtra'},
  {'city': 'Pune', 'state': 'Maharashtra'},
  {'city': 'Nagpur', 'state': 'Maharashtra'},
  {'city': 'Thane', 'state': 'Maharashtra'},
  {'city': 'Nashik', 'state': 'Maharashtra'},
  {'city': 'Aurangabad', 'state': 'Maharashtra'},
  {'city': 'Solapur', 'state': 'Maharashtra'},
  {'city': 'New Delhi', 'state': 'Delhi'},
  {'city': 'Bengaluru', 'state': 'Karnataka'},
  {'city': 'Mysuru', 'state': 'Karnataka'},
  {'city': 'Hubli', 'state': 'Karnataka'},
  {'city': 'Mangaluru', 'state': 'Karnataka'},
  {'city': 'Belagavi', 'state': 'Karnataka'},
  {'city': 'Chennai', 'state': 'Tamil Nadu'},
  {'city': 'Coimbatore', 'state': 'Tamil Nadu'},
  {'city': 'Madurai', 'state': 'Tamil Nadu'},
  {'city': 'Salem', 'state': 'Tamil Nadu'},
  {'city': 'Tiruchirappalli', 'state': 'Tamil Nadu'},
  {'city': 'Tirunelveli', 'state': 'Tamil Nadu'},
  {'city': 'Hyderabad', 'state': 'Telangana'},
  {'city': 'Warangal', 'state': 'Telangana'},
  {'city': 'Karimnagar', 'state': 'Telangana'},
  {'city': 'Visakhapatnam', 'state': 'Andhra Pradesh'},
  {'city': 'Vijayawada', 'state': 'Andhra Pradesh'},
  {'city': 'Guntur', 'state': 'Andhra Pradesh'},
  {'city': 'Nellore', 'state': 'Andhra Pradesh'},
  {'city': 'Ahmedabad', 'state': 'Gujarat'},
  {'city': 'Surat', 'state': 'Gujarat'},
  {'city': 'Vadodara', 'state': 'Gujarat'},
  {'city': 'Rajkot', 'state': 'Gujarat'},
  {'city': 'Bhavnagar', 'state': 'Gujarat'},
  {'city': 'Jaipur', 'state': 'Rajasthan'},
  {'city': 'Jodhpur', 'state': 'Rajasthan'},
  {'city': 'Udaipur', 'state': 'Rajasthan'},
  {'city': 'Kota', 'state': 'Rajasthan'},
  {'city': 'Bikaner', 'state': 'Rajasthan'},
  {'city': 'Ajmer', 'state': 'Rajasthan'},
  {'city': 'Lucknow', 'state': 'Uttar Pradesh'},
  {'city': 'Kanpur', 'state': 'Uttar Pradesh'},
  {'city': 'Agra', 'state': 'Uttar Pradesh'},
  {'city': 'Varanasi', 'state': 'Uttar Pradesh'},
  {'city': 'Ghaziabad', 'state': 'Uttar Pradesh'},
  {'city': 'Meerut', 'state': 'Uttar Pradesh'},
  {'city': 'Prayagraj', 'state': 'Uttar Pradesh'},
  {'city': 'Noida', 'state': 'Uttar Pradesh'},
  {'city': 'Kolkata', 'state': 'West Bengal'},
  {'city': 'Howrah', 'state': 'West Bengal'},
  {'city': 'Durgapur', 'state': 'West Bengal'},
  {'city': 'Asansol', 'state': 'West Bengal'},
  {'city': 'Patna', 'state': 'Bihar'},
  {'city': 'Gaya', 'state': 'Bihar'},
  {'city': 'Muzaffarpur', 'state': 'Bihar'},
  {'city': 'Bhopal', 'state': 'Madhya Pradesh'},
  {'city': 'Indore', 'state': 'Madhya Pradesh'},
  {'city': 'Jabalpur', 'state': 'Madhya Pradesh'},
  {'city': 'Gwalior', 'state': 'Madhya Pradesh'},
  {'city': 'Ujjain', 'state': 'Madhya Pradesh'},
  {'city': 'Ludhiana', 'state': 'Punjab'},
  {'city': 'Amritsar', 'state': 'Punjab'},
  {'city': 'Jalandhar', 'state': 'Punjab'},
  {'city': 'Chandigarh', 'state': 'Chandigarh'},
  {'city': 'Gurgaon', 'state': 'Haryana'},
  {'city': 'Faridabad', 'state': 'Haryana'},
  {'city': 'Ambala', 'state': 'Haryana'},
  {'city': 'Bhubaneswar', 'state': 'Odisha'},
  {'city': 'Cuttack', 'state': 'Odisha'},
  {'city': 'Guwahati', 'state': 'Assam'},
  {'city': 'Dibrugarh', 'state': 'Assam'},
  {'city': 'Ranchi', 'state': 'Jharkhand'},
  {'city': 'Jamshedpur', 'state': 'Jharkhand'},
  {'city': 'Raipur', 'state': 'Chhattisgarh'},
  {'city': 'Bilaspur', 'state': 'Chhattisgarh'},
  {'city': 'Dehradun', 'state': 'Uttarakhand'},
  {'city': 'Haridwar', 'state': 'Uttarakhand'},
  {'city': 'Shimla', 'state': 'Himachal Pradesh'},
  {'city': 'Dharamshala', 'state': 'Himachal Pradesh'},
  {'city': 'Srinagar', 'state': 'Jammu & Kashmir'},
  {'city': 'Jammu', 'state': 'Jammu & Kashmir'},
  {'city': 'Thiruvananthapuram', 'state': 'Kerala'},
  {'city': 'Kochi', 'state': 'Kerala'},
  {'city': 'Kozhikode', 'state': 'Kerala'},
  {'city': 'Thrissur', 'state': 'Kerala'},
  {'city': 'Panaji', 'state': 'Goa'},
  {'city': 'Margao', 'state': 'Goa'},
  {'city': 'Imphal', 'state': 'Manipur'},
  {'city': 'Shillong', 'state': 'Meghalaya'},
  {'city': 'Agartala', 'state': 'Tripura'},
  {'city': 'Gangtok', 'state': 'Sikkim'},
  {'city': 'Itanagar', 'state': 'Arunachal Pradesh'},
  {'city': 'Kohima', 'state': 'Nagaland'},
  {'city': 'Aizawl', 'state': 'Mizoram'},
  {'city': 'Leh', 'state': 'Ladakh'},
  {'city': 'Puducherry', 'state': 'Puducherry'},
];

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

  // ── Page 0: Phone OTP ─────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  final _otpController   = TextEditingController();
  String? _phoneError;
  String? _otpError;
  bool    _otpSent              = false;
  bool    _isSendingOtp         = false;
  bool    _isVerifyingOtp       = false;
  String? _verifiedPhone;
  String? _firebaseVerificationId;
  int?    _forceResendToken;
  Timer?  _resendTimer;
  int     _resendCountdown      = 30;
  bool    _canResend            = false;

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

  // ── Page 5: Location ──────────────────────────────────────────────────────
  LocationPermission _locationPermission = LocationPermission.denied;
  bool _isCheckingLocation = false;
  bool _isFetchingGpsCity = false;
  String? _gpsCity;
  String? _gpsState;
  String? _manualCity;
  String? _manualState;
  final _citySearchController = TextEditingController();
  List<Map<String, String>> _filteredCities = [];
  bool _showManualSearch = false;

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
    _checkInitialLocationPermission();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    _citySearchController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialLocationPermission() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (mounted) setState(() => _locationPermission = perm);
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        _fetchGpsCity();
      }
    } catch (_) {}
  }

  Future<void> _fetchGpsCity() async {
    if (mounted) setState(() => _isFetchingGpsCity = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (mounted && placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _gpsCity = p.locality?.isNotEmpty == true
              ? p.locality
              : p.subAdministrativeArea;
          _gpsState = p.administrativeArea;
          _isFetchingGpsCity = false;
        });
      } else if (mounted) {
        setState(() => _isFetchingGpsCity = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingGpsCity = false);
    }
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
  }

  // ── Page 0 actions ───────────────────────────────────────────────────────

  void _continuePage0() {
    AnalyticsService.instance.logOnboardingStepCompleted(stepName: 'phone_otp', stepNumber: 0);
    _animateToPage(1);
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
    AnalyticsService.instance.logOnboardingStepCompleted(stepName: 'name', stepNumber: 1);
    _animateToPage(2);
  }

  // ── Page 2 actions ───────────────────────────────────────────────────────

  void _continuePage2() {
    if (_isAgeValid) {
      AnalyticsService.instance.logOnboardingStepCompleted(stepName: 'date_of_birth', stepNumber: 2);
      _animateToPage(3);
    }
  }

  // ── Page 3 actions ───────────────────────────────────────────────────────

  void _continuePage3() {
    if (_selectedGender != null) {
      AnalyticsService.instance.logOnboardingStepCompleted(stepName: 'gender', stepNumber: 3);
      _animateToPage(4);
    }
  }

  // ── Page 4 actions (username) ─────────────────────────────────────────────

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

  void _continuePage4() {
    if (_usernameSuccess == null || _isCheckingUsername) return;
    AnalyticsService.instance.logOnboardingStepCompleted(stepName: 'username', stepNumber: 4);
    _animateToPage(5);
  }

  // ── Page 5 actions (location) ─────────────────────────────────────────────

  bool get _locationPermissionGranted =>
      _locationPermission == LocationPermission.always ||
      _locationPermission == LocationPermission.whileInUse;

  bool get _locationPermanentlyDenied =>
      _locationPermission == LocationPermission.deniedForever;

  Future<void> _requestLocationPermission() async {
    setState(() => _isCheckingLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (mounted) {
        setState(() {
          _locationPermission = perm;
          _isCheckingLocation = false;
          if (perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse) {
            _showManualSearch = false;
          } else {
            _showManualSearch = true;
          }
        });
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          _fetchGpsCity();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  void _onCitySearchChanged(String value) {
    final query = value.toLowerCase().trim();
    setState(() {
      _filteredCities = query.isEmpty
          ? []
          : kIndianCities
              .where((c) =>
                  c['city']!.toLowerCase().contains(query) ||
                  c['state']!.toLowerCase().contains(query))
              .take(10)
              .toList();
    });
  }

  bool get _canCreateAccount =>
      _locationPermissionGranted || _manualCity != null;

  Future<void> _submitOnboarding() async {
    if (!_canCreateAccount) return;
    AnalyticsService.instance.logOnboardingStepCompleted(stepName: 'location', stepNumber: 5);
    AnalyticsService.instance.logOnboardingLocationMethod(
      method: _locationPermissionGranted ? 'auto' : 'manual',
    );
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
        'location_city': _locationPermissionGranted
            ? (_gpsCity ?? '')
            : (_manualCity ?? ''),
        'location_state': _locationPermissionGranted
            ? (_gpsState ?? '')
            : (_manualState ?? ''),
        'location_permission': _locationPermissionGranted,
        'is_premium': false,
        'newspresso_assistant_limit': 3,
        'podcast_limit': 3,
        'phone': _verifiedPhone,
        'phone_verified': true,
      });
      if (mounted) {
        setState(() => _showCreateSuccess = true);
        AnalyticsService.instance.logOnboardingComplete();
        await Future.delayed(const Duration(milliseconds: 2500));
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showCreateSuccess = false;
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
                            _buildPhonePage(),
                            _buildNamePage(),
                            _buildDobPage(),
                            _buildGenderPage(),
                            _buildUsernamePage(),
                            _buildLocationPage(),
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
            children: List.generate(6, (i) {
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

  // ── Page 0: Phone OTP ─────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final digits = _phoneController.text.trim();
    if (digits.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      setState(() => _phoneError = 'Enter a valid 10-digit Indian mobile number');
      return;
    }
    setState(() { _phoneError = null; _isSendingOtp = true; });

    // Check if phone is already linked to another account before burning an SMS
    try {
      final existing = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('phone', '+91$digits')
          .maybeSingle();
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _isSendingOtp = false;
          _phoneError = 'This number is already linked to another account. Please use a different number.';
        });
        return;
      }
    } catch (_) {
      // Network error — let Firebase call proceed; the post-verify check will catch it
    }

    await fb.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91$digits',
      forceResendingToken: _forceResendToken,
      timeout: const Duration(seconds: 60),
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _firebaseVerificationId = verificationId;
          _forceResendToken = resendToken;
          _verifiedPhone = '+91$digits';
          _otpSent = true;
          _isSendingOtp = false;
          _otpController.clear();
          _otpError = null;
        });
        _startResendCountdown();
        AnalyticsService.instance.logPhoneOtpSent();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (mounted) setState(() => _firebaseVerificationId = verificationId);
      },
      verificationCompleted: (credential) async {
        if (!mounted) return;
        setState(() { _verifiedPhone = '+91$digits'; _isSendingOtp = false; });
        AnalyticsService.instance.logPhoneOtpVerified(method: 'auto');
        _continuePage0();
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() { _isSendingOtp = false; _phoneError = _mapFirebaseError(e.code); });
        AnalyticsService.instance.logPhoneOtpError(code: e.code);
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _otpError = 'Enter the 6-digit code sent to your phone');
      return;
    }
    setState(() { _otpError = null; _isVerifyingOtp = true; });

    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: _firebaseVerificationId!,
        smsCode: code,
      );
      final userCred = await fb.FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      if (userCred.user?.phoneNumber != _verifiedPhone) {
        throw Exception('mismatch');
      }
      await fb.FirebaseAuth.instance.signOut();

      final existing = await Supabase.instance.client
          .from('users').select('id').eq('phone', _verifiedPhone!).maybeSingle();
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _isVerifyingOtp = false;
          _otpError = 'This number is already linked to another account.';
        });
        AnalyticsService.instance.logPhoneOtpError(code: 'duplicate_phone');
        return;
      }

      setState(() => _isVerifyingOtp = false);
      AnalyticsService.instance.logPhoneOtpVerified();
      _continuePage0();
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() { _isVerifyingOtp = false; _otpError = _mapFirebaseOtpError(e.code); });
        AnalyticsService.instance.logPhoneOtpError(code: e.code);
      }
    } catch (_) {
      if (mounted) setState(() { _isVerifyingOtp = false; _otpError = 'Verification failed. Please try again.'; });
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() { _resendCountdown = 30; _canResend = false; });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) { _canResend = true; t.cancel(); }
      });
    });
  }

  String _mapFirebaseError(String? code) => switch (code) {
    'invalid-phone-number'    => 'Invalid phone number format.',
    'too-many-requests'       => 'Too many attempts. Please wait a few minutes.',
    'network-request-failed'  => 'No internet connection. Try again.',
    _                         => 'Unable to send OTP. Please try again.',
  };

  String _mapFirebaseOtpError(String? code) => switch (code) {
    'invalid-verification-code' => 'Incorrect OTP. Please check and try again.',
    'session-expired'           => 'OTP expired. Please request a new one.',
    'invalid-verification-id'   => 'Session expired. Please request a new OTP.',
    _                           => 'Verification failed. Please try again.',
  };

  Widget _buildPhonePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(
            child: _IconCircle(
              icon: _otpSent ? Icons.lock_outline : Icons.phone_android,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _otpSent ? 'Enter verification code' : 'Verify your phone number',
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _otpSent
                  ? 'Sent to ${_verifiedPhone != null ? _verifiedPhone!.replaceRange(3, 8, 'XXXXX') : ''}'
                  : "We'll send a 6-digit OTP to confirm your identity",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          if (!_otpSent) ...[
            _buildLabel('Mobile Number'),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '🇮🇳  +91',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '10-digit mobile number',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF111111),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_phoneError != null) ...[
              const SizedBox(height: 10),
              _buildErrorText(_phoneError!),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSendingOtp ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8936A),
                  disabledBackgroundColor: const Color(0xFF3A2A1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSendingOtp
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Send OTP',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(width: 8),
                          Icon(Icons.send, color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ] else ...[
            _buildLabel('Verification Code'),
            const SizedBox(height: 8),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.bold, letterSpacing: 12),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 28, letterSpacing: 12),
                filled: true,
                fillColor: const Color(0xFF111111),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_otpError != null) ...[
              const SizedBox(height: 10),
              _buildErrorText(_otpError!),
            ],
            const SizedBox(height: 16),
            Center(
              child: _canResend
                  ? GestureDetector(
                      onTap: () {
                        setState(() => _otpSent = false);
                        AnalyticsService.instance.logPhoneOtpResent();
                        _sendOtp();
                      },
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: Color(0xFFC8936A), fontSize: 14,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFFC8936A),
                        ),
                      ),
                    )
                  : Text(
                      'Resend OTP in ${_resendCountdown}s',
                      style: const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
            ),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: () => setState(() { _otpSent = false; _otpError = null; }),
                child: const Text(
                  '← Change number',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isVerifyingOtp ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8936A),
                  disabledBackgroundColor: const Color(0xFF3A2A1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isVerifyingOtp
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Verify OTP',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(width: 8),
                          Icon(Icons.verified_outlined, color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ],
          const SizedBox(height: 32),
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
    final canContinue = _usernameSuccess != null && !_isCheckingUsername;
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
          _buildContinueButton(canContinue ? _continuePage4 : null),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Page 5: Location ──────────────────────────────────────────────────────

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // Icon — changes based on permission status
          Center(
            child: _locationPermissionGranted
                ? Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on,
                        color: Colors.green, size: 40),
                  )
                : _IconCircle(icon: Icons.location_on_outlined),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            _locationPermissionGranted
                ? 'Location Access Granted'
                : 'Enable Your Location',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            _locationPermissionGranted
                ? 'Your news will be tailored to your region.'
                : 'Enabling location will help us deliver\nbetter news to you.',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          // ── GRANTED state ────────────────────────────────────────────────
          if (_locationPermissionGranted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isFetchingGpsCity
                        ? const Text(
                            'Detecting your city...',
                            style: TextStyle(
                                color: Colors.green, fontSize: 13, height: 1.4),
                          )
                        : Text(
                            _gpsCity != null
                                ? 'Location: $_gpsCity${_gpsState != null ? ', $_gpsState' : ''}'
                                : 'Location access granted — we\'ll use your GPS to personalise your feed.',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 13, height: 1.4),
                          ),
                  ),
                ],
              ),
            ),
          ],

          // ── NOT GRANTED state ────────────────────────────────────────────
          if (!_locationPermissionGranted) ...[
            // Enable Location button
            if (!_showManualSearch) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isCheckingLocation ? null : _requestLocationPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC8936A),
                    disabledBackgroundColor: const Color(0xFF3A2A1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isCheckingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, color: Colors.white, size: 20),
                  label: Text(
                    _isCheckingLocation ? 'Requesting...' : 'Enable Location',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Permanently denied — open settings hint
              if (_locationPermanentlyDenied)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Location access was denied. Enable it in device Settings.',
                            style: TextStyle(
                                color: Colors.orange, fontSize: 12, height: 1.4),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Geolocator.openAppSettings(),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(60, 28)),
                          child: const Text('Settings',
                              style: TextStyle(
                                  color: Color(0xFFC8936A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Set manually link
              GestureDetector(
                onTap: () => setState(() => _showManualSearch = true),
                child: const Text(
                  'Set location manually instead',
                  style: TextStyle(
                    color: Color(0xFFC8936A),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFC8936A),
                  ),
                ),
              ),
            ],

            // ── Manual search ──────────────────────────────────────────────
            if (_showManualSearch) ...[
              // If a city was already picked, show it
              if (_manualCity != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8936A).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFFC8936A), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _manualCity!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _manualState ?? '',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _manualCity = null;
                          _manualState = null;
                          _citySearchController.clear();
                          _filteredCities = [];
                        }),
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Search bar
              TextField(
                controller: _citySearchController,
                onChanged: _onCitySearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search city in India...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF111111),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // Results
              if (_filteredCities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: _filteredCities.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final c = entry.value;
                      return Column(
                        children: [
                          if (idx > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.white.withValues(alpha: 0.05),
                              indent: 50,
                            ),
                          InkWell(
                            borderRadius: idx == 0
                                ? const BorderRadius.vertical(
                                    top: Radius.circular(14))
                                : idx == _filteredCities.length - 1
                                    ? const BorderRadius.vertical(
                                        bottom: Radius.circular(14))
                                    : BorderRadius.zero,
                            onTap: () {
                              setState(() {
                                _manualCity = c['city'];
                                _manualState = c['state'];
                                _citySearchController.text =
                                    '${c['city']}, ${c['state']}';
                                _filteredCities = [];
                              });
                              FocusScope.of(context).unfocus();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_city,
                                      color: Color(0xFFC8936A), size: 18),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['city']!,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        c['state']!,
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Option to go back to GPS request
              if (!_locationPermanentlyDenied)
                GestureDetector(
                  onTap: () => setState(() {
                    _showManualSearch = false;
                    _citySearchController.clear();
                    _filteredCities = [];
                  }),
                  child: const Text(
                    'Use GPS location instead',
                    style: TextStyle(
                      color: Color(0xFFC8936A),
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFFC8936A),
                    ),
                  ),
                ),
            ],
          ],

          const SizedBox(height: 32),

          // ── Create Account button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canCreateAccount ? _submitOnboarding : null,
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
