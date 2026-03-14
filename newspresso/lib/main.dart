import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';

import 'analytics_service.dart';
import 'interaction_service.dart';
import 'notification_service.dart';
import 'user_preferences.dart';

import 'shots_page.dart';
import 'news_assistant_page.dart';
import 'news_detail_page.dart';
import 'podcasts_page.dart';
import 'audio_manager.dart';
import 'podcast_detail_screen.dart';
import 'login_screen.dart';
import 'profile_page.dart';
import 'onboarding_flow.dart';
import 'splash_screen.dart';

String _formatTimeAgo(dynamic timestampField) {
  if (timestampField == null) return 'Unknown';
  try {
    DateTime? date;
    if (timestampField is String) {
      date = DateTime.tryParse(timestampField);
      if (date == null) {
        final doubleVal = double.tryParse(timestampField);
        if (doubleVal != null) {
          int epochValue = doubleVal.toInt();
          if (epochValue < 10000000000) epochValue *= 1000;
          date = DateTime.fromMillisecondsSinceEpoch(epochValue);
        }
      }
    } else if (timestampField is int || timestampField is double) {
      int epochValue = (timestampField as num).toInt();
      if (epochValue < 10000000000) epochValue *= 1000;
      date = DateTime.fromMillisecondsSinceEpoch(epochValue);
    }
    if (date == null) return 'Unknown';
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 7) return '${difference.inDays ~/ 7} weeks ago';
    if (difference.inDays > 1) return '${difference.inDays} days ago';
    if (difference.inDays == 1) return '1 day ago';
    if (difference.inHours > 0) return '${difference.inHours} hours ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes} minutes ago';
    return 'Just now';
  } catch (_) {
    return 'Unknown';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the environment variables from the .env file
  await dotenv.load(fileName: ".env");

  // Read Supabase credentials safely
  final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint("Error: Missing Supabase credentials in .env file");
  }

  try {
    await Firebase.initializeApp();
    AnalyticsService.instance.initialize();
    NotificationService.registerBackgroundHandler();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await MobileAds.instance.initialize();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['107d93066e57249258efb7fb01151b4d']),
  );
  await AudioManager.instance.init();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  // null = still resolving, true = authenticated, false = not authenticated
  bool? _isAuthenticated;
  // true = has profile in users table, false = needs onboarding
  bool _hasProfile = false;
  bool _checkingProfile = false;
  // Keeps splash visible for a minimum duration on first launch
  bool _showSplash = true;
  // Shows splash briefly after onboarding completes
  bool _showCompletionSplash = false;

  @override
  void initState() {
    super.initState();

    // Request notification permission + subscribe to FCM topics.
    // Must be called here (not in main) — the Activity must be attached first.
    NotificationService.instance.initialize();

    // Minimum splash display time
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showSplash = false);
    });

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _isAuthenticated = true;
      _checkUserProfile();
    } else {
      _isAuthenticated = false;
    }
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final isAuth = data.session != null;
      if (isAuth && _isAuthenticated != true) {
        setState(() => _isAuthenticated = true);
        _checkUserProfile();
      } else if (!isAuth) {
        setState(() {
          _isAuthenticated = false;
          _hasProfile = false;
          _checkingProfile = false;
        });
      }
    });
  }

  Future<void> _checkUserProfile() async {
    if (!mounted) return;
    setState(() => _checkingProfile = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _checkingProfile = false);
        return;
      }
      final result = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _hasProfile = result != null;
          _checkingProfile = false;
        });
      }
      // Load language preference once after confirming user exists
      if (result != null) {
        await UserPreferences.instance.load();
      }
    } catch (_) {
      if (mounted) setState(() => _checkingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Newspresso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC8936A),
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    if (_showSplash || _isAuthenticated == null || _checkingProfile) {
      return const SplashScreen(key: ValueKey('splash'));
    }
    if (!_isAuthenticated!) {
      return const LoginScreen(key: ValueKey('login'));
    }
    if (!_hasProfile) {
      return OnboardingFlow(
        key: const ValueKey('onboarding'),
        onComplete: () {
          setState(() {
            _hasProfile = true;
            _showCompletionSplash = true;
          });
          Future.delayed(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _showCompletionSplash = false);
          });
        },
      );
    }
    if (_showCompletionSplash) {
      return const SplashScreen(key: ValueKey('splash-complete'));
    }
    return const _MainShell(key: ValueKey('main'));
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({super.key});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  StreamSubscription<bool>? _notificationClickSub;
  StreamSubscription<Uri>? _deepLinkSub;
  bool _wentToBackground = false;

  final _podcastsRefresh = ValueNotifier<int>(0);
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const ShotsPage(),
      const NewsListPage(),
      PodcastsPage(refreshSignal: _podcastsRefresh),
      const ProfilePage(),
    ];
    WidgetsBinding.instance.addObserver(this);

    // Android: fires when the media notification is tapped
    _notificationClickSub = AudioService.notificationClicked.listen((clicked) {
      if (!clicked || !mounted) return;
      _navigateToPodcast();
    });

    // FCM: navigate to the article when a breaking news notification is tapped
    NotificationService.instance.onNotificationTap = (newsId) {
      if (mounted) _openNewsById(newsId);
    };
    // FCM: open Shots tab when a daily digest notification is tapped
    NotificationService.instance.onDigestNotificationTap = () {
      if (mounted) setState(() => _selectedIndex = 0);
    };
    NotificationService.instance.drainPending();

    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    // Handle link that cold-started the app
    final initialUri = await appLinks.getInitialLink();
    debugPrint('[DeepLink] initialUri: $initialUri');
    if (initialUri != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleDeepLink(initialUri),
      );
    }

    // Handle links while app is running
    _deepLinkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('[DeepLink] received: $uri');
    // Matches https://www.newspresso.org/news/<id>
    final segments = uri.pathSegments;
    debugPrint('[DeepLink] segments: $segments');
    if (segments.length >= 2 && segments[0] == 'news') {
      final newsId = segments[1];
      AnalyticsService.instance.logDeepLinkOpened(itemId: newsId);
      await _openNewsById(newsId);
    }
  }

  Future<void> _openNewsById(String newsId) async {
    debugPrint('[DeepLink] opening newsId: $newsId');
    if (!mounted) return;
    try {
      final raw = await Supabase.instance.client
          .from('newspresso_aggregated_news_in')
          .select(
            'id, content_title, url_to_image, content_description, content_summary, timestamp, articles, questions, translations',
          )
          .eq('id', newsId)
          .maybeSingle();
      debugPrint('[DeepLink] supabase result: $raw');
      if (raw == null || !mounted) return;

      final data = UserPreferences.resolveContent(
          raw, UserPreferences.instance.language);

      final title = data['content_title']?.toString() ?? '';
      final imageUrl = data['url_to_image']?.toString();
      final description = data['content_description']?.toString() ?? '';
      final contentSummary = data['content_summary']?.toString() ?? description;
      final ts = data['timestamp']?.toString() ?? '';
      final publishedText = ts.isNotEmpty ? 'Published ${_formatTimeAgo(ts)}' : 'Newspresso';

      List<dynamic> articlesList = [];
      final af = data['articles'];
      if (af is List) articlesList = af;

      List<String> questionsList = [];
      final qf = data['questions'];
      if (qf is List) questionsList = qf.map((e) => e.toString()).toList();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewsDetailPage(
            contentTitle: title,
            imageUrl: imageUrl,
            contentSummary: contentSummary,
            contentDescription: description,
            articlesList: articlesList,
            publishedText: publishedText,
            totalSources: articlesList.length,
            questionsList: questionsList,
            newsItemId: newsId,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[DeepLink] error: $e\n$st');
    }
  }

  // iOS: fires when the app is brought back to the foreground (e.g. tapping
  // the Now Playing widget on the lock screen or Control Center).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wentToBackground = true;
    } else if (state == AppLifecycleState.resumed && _wentToBackground) {
      _wentToBackground = false;
      if (Platform.isIOS) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToPodcast());
      }
    }
  }

  void _navigateToPodcast() {
    final podcast = AudioManager.instance.currentPodcast;
    if (podcast != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PodcastDetailScreen(podcast: podcast),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationClickSub?.cancel();
    _deepLinkSub?.cancel();
    _podcastsRefresh.dispose();
    NotificationService.instance.onNotificationTap = null;
    NotificationService.instance.onDigestNotificationTap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: _tabs),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini Player above tabs
            ListenableBuilder(
              listenable: AudioManager.instance,
              builder: (context, _) {
                final podcast = AudioManager.instance.currentPodcast;
                final isPlaying = AudioManager.instance.isPlaying;

                if (podcast == null || _selectedIndex == 0) return const SizedBox.shrink();

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PodcastDetailScreen(podcast: podcast),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.headphones,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        podcast.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Published ${podcast.date}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    if (isPlaying) {
                                      AudioManager.instance.pause();
                                    } else {
                                      AudioManager.instance.resume();
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Progress Bar at the bottom
                          StreamBuilder<Duration>(
                            stream: AudioManager.instance.player.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration =
                                  AudioManager.instance.player.duration ??
                                  Duration.zero;
                              final progress = duration.inMilliseconds > 0
                                  ? position.inMilliseconds /
                                        duration.inMilliseconds
                                  : 0.0;
                              return LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 2,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Nav Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.06)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        icon: Icons.local_cafe_outlined,
                        activeIcon: Icons.local_cafe,
                        label: 'Shots',
                        isSelected: _selectedIndex == 0,
                        onTap: () {
                          AnalyticsService.instance.logTabSwitch(tabName: 'shots');
                          setState(() => _selectedIndex = 0);
                        },
                      ),
                      _NavItem(
                        icon: Icons.language_outlined,
                        activeIcon: Icons.language,
                        label: 'Explore',
                        isSelected: _selectedIndex == 1,
                        onTap: () {
                          AnalyticsService.instance.logTabSwitch(tabName: 'explore');
                          setState(() => _selectedIndex = 1);
                        },
                      ),
                      _NavItem(
                        icon: Icons.play_circle_outline,
                        activeIcon: Icons.play_circle,
                        label: 'Podcasts',
                        isSelected: _selectedIndex == 2,
                        onTap: () {
                          AnalyticsService.instance.logTabSwitch(tabName: 'podcasts');
                          _podcastsRefresh.value++;
                          setState(() => _selectedIndex = 2);
                        },
                      ),
                      _NavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Profile',
                        isSelected: _selectedIndex == 3,
                        onTap: () {
                          AnalyticsService.instance.logTabSwitch(tabName: 'profile');
                          setState(() => _selectedIndex = 3);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFC8936A);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? amber : Colors.white38,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? amber : Colors.white38,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsListPage extends StatefulWidget {
  const NewsListPage({super.key});

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> _newsList = [];
  bool _isLoading = true;
  String? _error;

  // Pagination
  final ScrollController _scrollController = ScrollController();
  int _fetchOffset = 0;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _fetchNews();
    _scrollController.addListener(_onScroll);
    UserPreferences.instance.languageNotifier.addListener(_onLanguageChange);
    UserPreferences.instance.categoryPreferencesNotifier.addListener(_onCategoryPreferencesChange);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchMoreNews();
    }
  }

  void _onLanguageChange() => setState(() {});
  void _onCategoryPreferencesChange() => _fetchNews();

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    UserPreferences.instance.languageNotifier.removeListener(_onLanguageChange);
    UserPreferences.instance.categoryPreferencesNotifier.removeListener(_onCategoryPreferencesChange);
    super.dispose();
  }

  Future<void> _fetchNews() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      List<dynamic> response;
      if (userId != null) {
        response = await supabase.rpc(
          'get_personalized_feed',
          params: {'p_user_id': userId, 'p_limit': _pageSize, 'p_offset': 0},
        );
      } else {
        response = await supabase
            .from('newspresso_aggregated_news_in')
            .select(
              'id, content_title, url_to_image, content_summary, content_description, timestamp, articles, questions, translations',
            )
            .order('timestamp', ascending: false)
            .range(0, _pageSize - 1);
      }

      setState(() {
        _newsList = response;
        _fetchOffset = 0;
        _hasMore = response.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreNews() async {
    if (_isFetchingMore || !_hasMore) return;
    _isFetchingMore = true;
    final nextOffset = _fetchOffset + _pageSize;
    try {
      final userId = supabase.auth.currentUser?.id;
      List<dynamic> response;
      if (userId != null) {
        response = await supabase.rpc(
          'get_personalized_feed',
          params: {'p_user_id': userId, 'p_limit': _pageSize, 'p_offset': nextOffset},
        );
      } else {
        response = await supabase
            .from('newspresso_aggregated_news_in')
            .select(
              'id, content_title, url_to_image, content_summary, content_description, timestamp, articles, questions, translations',
            )
            .order('timestamp', ascending: false)
            .range(nextOffset, nextOffset + _pageSize - 1);
      }

      setState(() {
        _fetchOffset = nextOffset;
        _hasMore = response.length >= _pageSize;
        _newsList.addAll(response);
        _isFetchingMore = false;
      });
    } catch (_) {
      _isFetchingMore = false;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'Newspresso',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
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
            children: [
              const SizedBox(height: 16),
              // Main List Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFC8936A),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : _newsList.isEmpty
                    ? const Center(
                        child: Text(
                          'No news available.',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _newsList.length + (_isFetchingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _newsList.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFC8936A),
                                ),
                              ),
                            );
                          }
                          final raw = _newsList[index] as Map<String, dynamic>;
                          final item = UserPreferences.resolveContent(
                              raw, UserPreferences.instance.language);
                          final itemId = item['id']?.toString() ?? '';
                          final contentTitle =
                              item['content_title']?.toString() ?? 'No title';
                          final imageUrl = item['url_to_image']?.toString();
                          final contentSummary =
                              item['content_summary']?.toString() ?? '';
                          final contentDescription =
                              item['content_description']?.toString();
                          final timestampField = item['timestamp'];

                          // Safely parse articles from Supabase format
                          List<dynamic> articlesList = [];
                          final dynamic articlesField = item['articles'];
                          if (articlesField is List) {
                            articlesList = articlesField;
                          } else if (articlesField is Map &&
                              articlesField.containsKey('items')) {
                            // Some postgrest JSON array configs parse this way
                            articlesList =
                                articlesField['items'] as List<dynamic>? ?? [];
                            // Last resort, try to see if it's already an array representation
                            try {
                              articlesList = List.from(
                                articlesField as Iterable,
                              );
                            } catch (e) {
                              // Ignore formatting errors gracefully
                            }
                          }

                          // Safely parse podcast questions
                          List<String> questionsList = [];
                          final dynamic questionsField = item['questions'];
                          if (questionsField is List) {
                            questionsList = questionsField
                                .map((e) => e.toString())
                                .toList();
                          } else if (questionsField is Map &&
                              questionsField.containsKey('items')) {
                            // Some postgrest JSON array configs parse this way
                            questionsList =
                                (questionsField['items'] as List<dynamic>? ??
                                        [])
                                    .map((e) => e.toString())
                                    .toList();
                          } else if (questionsField != null) {
                            try {
                              questionsList = List.from(
                                questionsField as Iterable,
                              ).map((e) => e.toString()).toList();
                            } catch (e) {
                              // Ignore formatting
                            }
                          }

                          final int totalSources = articlesList.length;

                          final publishedText =
                              'Published ${_formatTimeAgo(timestampField)}';

                          return GestureDetector(
                            onTap: () {
                              AnalyticsService.instance.logArticleView(
                                articleId: itemId,
                                title: contentTitle,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NewsDetailPage(
                                    contentTitle: contentTitle,
                                    imageUrl: imageUrl,
                                    contentSummary: contentSummary,
                                    contentDescription: contentDescription,
                                    articlesList: articlesList,
                                    publishedText: publishedText,
                                    totalSources: totalSources,
                                    questionsList: questionsList,
                                    newsItemId: itemId.isEmpty ? null : itemId,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF0F0F0F,
                                ), // Absolute dark background for card
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Feed Image
                                        imageUrl != null && imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                height: 260,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      height: 260,
                                                      color: Colors.grey[800],
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        size: 50,
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                height: 260,
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                  Icons.article,
                                                  size: 50,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                        // Gradient to blend image with card bottom text
                                        Container(
                                          height: 260,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.black.withOpacity(0.0),
                                                Colors.black.withOpacity(0.8),
                                                const Color(0xFF0F0F0F),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              stops: const [0.5, 0.85, 1.0],
                                            ),
                                          ),
                                        ),
                                        // Title and Published Date Overlay Bottom
                                        Positioned(
                                          bottom: 0,
                                          left: 16,
                                          right: 16,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  contentTitle,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    // Sources avatars cluster
                                                    Row(
                                                      children: [
                                                        if (articlesList
                                                            .isEmpty)
                                                          const SizedBox() // No sources to show
                                                        else
                                                          // Map up to 3 article items to overlapping circular images
                                                          ...articlesList.take(3).toList().asMap().entries.map((
                                                            entry,
                                                          ) {
                                                            final index =
                                                                entry.key;
                                                            final sourceItem =
                                                                entry.value
                                                                    as Map<
                                                                      String,
                                                                      dynamic
                                                                    >? ??
                                                                {};
                                                            final faviconUrl =
                                                                sourceItem['source_favicon_url']
                                                                    ?.toString();

                                                            return Transform.translate(
                                                              // Shift each subsequent avatar slightly to the left to overlap
                                                              offset: Offset(
                                                                index * -8.0,
                                                                0,
                                                              ),
                                                              child: Container(
                                                                width: 22,
                                                                height: 22,
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .grey[800],
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  border: Border.all(
                                                                    color: Colors
                                                                        .black, // Dark border to define overlap
                                                                    width: 1.5,
                                                                  ),
                                                                  image:
                                                                      faviconUrl !=
                                                                              null &&
                                                                          faviconUrl
                                                                              .isNotEmpty
                                                                      ? DecorationImage(
                                                                          image: NetworkImage(
                                                                            faviconUrl,
                                                                          ),
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        )
                                                                      : null,
                                                                ),
                                                                child:
                                                                    faviconUrl ==
                                                                            null ||
                                                                        faviconUrl
                                                                            .isEmpty
                                                                    ? const Icon(
                                                                        Icons
                                                                            .public,
                                                                        size:
                                                                            12,
                                                                        color: Colors
                                                                            .white54,
                                                                      )
                                                                    : null,
                                                              ),
                                                            );
                                                          }),

                                                        // Render total additional sources text like "+24"
                                                        if (totalSources > 0)
                                                          Transform.translate(
                                                            // Adjust start layout since the overlapping avatars push bounding box slightly
                                                            offset: Offset(
                                                              (articlesList.length >
                                                                          3
                                                                      ? 3
                                                                      : articlesList
                                                                            .length) *
                                                                  -4.0,
                                                              0,
                                                            ),
                                                            child: Text(
                                                              '+$totalSources',
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),

                                                    // Publish Date Text
                                                    Text(
                                                      publishedText,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Questions / Podcasts Capsules
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      top: 16,
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          // Ask Assistant Capsule (empty text area)
                                          GestureDetector(
                                            onTap: () {
                                              if (itemId.isNotEmpty) {
                                                InteractionService.instance.logAskAssistant(itemId);
                                              }
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      NewsAssistantPage(
                                                        newsTitle: contentTitle,
                                                        prefillQuestion: '',
                                                        source: 'explore',
                                                        newsItemId: itemId.isEmpty ? null : itemId,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.05,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.chat_bubble_outline,
                                                    size: 15,
                                                    color: Colors.white54,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Ask Assistant',
                                                    style: TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Dynamic Questions
                                          ...questionsList.map((q) {
                                            return GestureDetector(
                                              onTap: () {
                                                if (itemId.isNotEmpty) {
                                                  InteractionService.instance.logAskAssistant(itemId);
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        NewsAssistantPage(
                                                          newsTitle:
                                                              contentTitle,
                                                          prefillQuestion: q,
                                                          source: 'explore',
                                                          newsItemId: itemId.isEmpty ? null : itemId,
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                margin: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  q,
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (contentSummary.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        contentSummary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
