import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_service.dart';
import 'news_assistant_page.dart';
import 'news_detail_page.dart';
import 'user_preferences.dart';

class ShotsPage extends StatefulWidget {
  const ShotsPage({super.key});

  @override
  State<ShotsPage> createState() => _ShotsPageState();
}

class _ShotsPageState extends State<ShotsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allItems = [];
  // The queue of items yet to be shown (index into _allItems)
  int _nextIndex = 0;
  // Cards currently on screen (front = last in list)
  final List<Map<String, dynamic>> _stack = [];
  bool _isLoading = true;
  String? _error;
  Set<String> _favoritedIds = {};
  List<Map<String, dynamic>> _dismissedHistory = [];
  Set<String> _dismissedIds = {};

  // Drag state
  double _dragOffset = 0;
  bool _isDragging = false;

  // Interstitial ad
  InterstitialAd? _interstitialAd;
  int _swipeCount = 0;
  bool _adsEnabled = false;
  static const int _adEvery = 3;

  static const int _stackSize = 3;

  @override
  void initState() {
    super.initState();
    _fetchShots();
    _checkAndLoadAd();
    _fetchFavorites();
    UserPreferences.instance.languageNotifier.addListener(_onLanguageChange);
    UserPreferences.instance.categoryPreferencesNotifier.addListener(_onCategoryPreferencesChange);
  }

  void _onLanguageChange() => setState(() {});
  void _onCategoryPreferencesChange() => _fetchShots();

  @override
  void dispose() {
    UserPreferences.instance.languageNotifier.removeListener(_onLanguageChange);
    UserPreferences.instance.categoryPreferencesNotifier.removeListener(_onCategoryPreferencesChange);
    _interstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _checkAndLoadAd() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await Supabase.instance.client
            .from('users')
            .select('is_premium')
            .eq('id', userId)
            .maybeSingle();
        if (result?['is_premium'] == true) return; // premium: no ads
      }
    } catch (_) {
      // fall through and load ad if check fails
    }
    _adsEnabled = true;
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    final adUnitId =
        Platform.isAndroid
            ? (dotenv.env['ADMOB_ANDROID_SHOTS_INTERSTITIAL'] ?? '')
            : (dotenv.env['ADMOB_IOS_SHOTS_INTERSTITIAL'] ?? '');
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _maybeShowInterstitial() {
    if (!_adsEnabled) return;
    _swipeCount++;
    if (_swipeCount % _adEvery != 0) return;
    if (_interstitialAd == null) {
      _loadInterstitialAd();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  Future<void> _fetchShots() async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      List<dynamic> res;
      if (userId != null) {
        res = await _supabase.rpc(
          'get_personalized_feed_tier1',
          params: {'p_user_id': userId, 'p_limit': 100, 'p_offset': 0},
        );
      } else {
        res = await _supabase
            .from('newspresso_aggregated_news_in')
            .select(
              'id, content_title, url_to_image, content_description, content_summary, timestamp, articles, questions, translations',
            )
            .order('timestamp', ascending: false);
      }

      final items = res
          .map((e) => e as Map<String, dynamic>)
          .where((item) => !_dismissedIds.contains(item['id']?.toString() ?? ''))
          .toList();

      setState(() {
        _allItems = items;
        _isLoading = false;
        _nextIndex = 0;
        _stack.clear();
        _fillStack();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFavorites() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final result = await _supabase
          .from('users')
          .select('news_items_favorited, news_items_dismissed')
          .eq('id', userId)
          .maybeSingle();
      final raw = result?['news_items_favorited'];
      final rawDismissed = result?['news_items_dismissed'];
      setState(() {
        if (raw is List) {
          _favoritedIds = raw.map((e) => e.toString()).toSet();
        }
        if (rawDismissed is List) {
          _dismissedIds = rawDismissed.map((e) => e.toString()).toSet();
          // Re-filter _allItems if shots already loaded
          if (_allItems.isNotEmpty) {
            _allItems = _allItems
                .where((item) => !_dismissedIds.contains(item['id']?.toString() ?? ''))
                .toList();
            _stack.clear();
            _nextIndex = 0;
            _fillStack();
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String itemId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final newSet = Set<String>.from(_favoritedIds);
    final added = !newSet.contains(itemId);
    if (added) {
      newSet.add(itemId);
    } else {
      newSet.remove(itemId);
    }
    setState(() => _favoritedIds = newSet);
    AnalyticsService.instance.logArticleFavorite(articleId: itemId, added: added);
    try {
      await _supabase
          .from('users')
          .update({'news_items_favorited': newSet.toList()})
          .eq('id', userId);
    } catch (_) {}
  }

  void _fillStack() {
    while (_stack.length < _stackSize && _nextIndex < _allItems.length) {
      _stack.insert(
        0,
        _allItems[_nextIndex],
      ); // insert at front (bottom of visual stack)
      _nextIndex++;
    }
  }

  void _dismissTop() {
    setState(() {
      if (_stack.isNotEmpty) {
        final dismissed = _stack.last;
        _dismissedHistory.add(dismissed);
        final id = dismissed['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          _dismissedIds.add(id);
          _persistDismissed();
          AnalyticsService.instance.logShotDismissed(
            itemId: id,
            sessionSwipeCount: _swipeCount + 1,
          );
        }
        _stack.removeLast();
        _fillStack();
      }
      _dragOffset = 0;
      _isDragging = false;
    });
    _maybeShowInterstitial();
  }

  void _undoLastDismiss() {
    if (_dismissedHistory.isEmpty) return;
    setState(() {
      final item = _dismissedHistory.removeLast();
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        AnalyticsService.instance.logShotUndo(itemId: id);
        _dismissedIds.remove(id);
        _persistDismissed();
      }
      // If stack is full, push the deepest backing card back to the queue
      if (_stack.length >= _stackSize) {
        _stack.removeAt(0);
        _nextIndex--;
      }
      _stack.add(item); // restored card becomes the new front
      _dragOffset = 0;
      _isDragging = false;
    });
  }

  Future<void> _persistDismissed() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('users')
          .update({'news_items_dismissed': _dismissedIds.toList()})
          .eq('id', userId);
    } catch (_) {}
  }

  String _formatTimeAgo(dynamic ts) {
    if (ts == null) return 'Unknown';
    try {
      DateTime? date;
      if (ts is String) date = DateTime.tryParse(ts);
      if (date == null) return 'Unknown';
      final diff = DateTime.now().toUtc().difference(date.toUtc());
      if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC8936A)),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_stack.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No more shots!',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    // Bottom padding = tab bar height + its bottom safe area inset
    final bottomPad = MediaQuery.of(context).padding.bottom + 72.0;

    // The front card is the last element, backing cards are earlier
    return Scaffold(
      backgroundColor: Colors.transparent,
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
              // ── 'Newspresso' header ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.undo_rounded,
                        color: _dismissedHistory.isNotEmpty
                            ? Colors.white
                            : Colors.white24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _dismissedHistory.isNotEmpty
                          ? _undoLastDismiss
                          : null,
                    ),
                    const Text(
                      'Newspresso',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // ── Card stack ────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: Stack(
                    children: [
                      for (int i = 0; i < _stack.length; i++)
                        _buildCard(
                          context,
                          item: _stack[i],
                          stackPosition: _stack.length - 1 - i,
                          screenH: screenH,
                          screenW: screenW,
                        ),
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

  Widget _buildCard(
    BuildContext context, {
    required Map<String, dynamic> item,
    required int stackPosition, // 0 = front card
    required double screenH,
    required double screenW,
  }) {
    final isFront = stackPosition == 0;
    final scale = 1.0 - (stackPosition * 0.04);
    final topOffset = stackPosition * 18.0;

    // Extract data (resolve translated fields if language is not English)
    final resolved =
        UserPreferences.resolveContent(item, UserPreferences.instance.language);
    final itemId = item['id']?.toString() ?? '';
    final title = resolved['content_title']?.toString() ?? '';
    final imageUrl = item['url_to_image']?.toString();
    final description = resolved['content_description']?.toString() ?? '';
    final contentSummary =
        resolved['content_summary']?.toString() ?? description;
    final publishedText = 'Published ${_formatTimeAgo(item['timestamp'])}';

    List<dynamic> articlesList = [];
    final af = item['articles'];
    if (af is List) articlesList = af;

    List<String> questionsList = [];
    final qf = resolved['questions'];
    if (qf is List) questionsList = qf.map((e) => e.toString()).toList();

    // Front card drag offset (negative = swiped up)
    final dy = isFront ? _dragOffset : 0.0;
    // Opacity fades as dragged up
    final opacity = isFront ? (1.0 - (-dy / screenH).clamp(0.0, 1.0)) : 1.0;

    void navigateToDetail() {
      if (itemId.isNotEmpty) {
        AnalyticsService.instance.logShotTapped(itemId: itemId);
        AnalyticsService.instance.logArticleView(articleId: itemId, title: title, source: 'shots');
      }
      Navigator.push(
        context,
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
            newsItemId: itemId.isEmpty ? null : itemId,
          ),
        ),
      );
    }

    Widget card = Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: _ShotCard(
          itemId: itemId,
          title: title,
          imageUrl: imageUrl,
          description: description,
          publishedText: publishedText,
          articlesList: articlesList,
          questionsList: questionsList,
          newsTitle: title,
          screenH: screenH,
          screenW: screenW,
          onTap: navigateToDetail,
          isFavorited: _favoritedIds.contains(itemId),
          onFavorite: itemId.isEmpty ? null : () => _toggleFavorite(itemId),
        ),
      ),
    );

    // Only add drag gesture to front card
    if (isFront) {
      card = GestureDetector(
        onVerticalDragStart: (_) {
          setState(() => _isDragging = true);
        },
        onVerticalDragUpdate: (d) {
          setState(() {
            _dragOffset += d.delta.dy;
            // Clamp: allow upward only (negative), small positive for rubber-band
            if (_dragOffset > 20) _dragOffset = 20;
          });
        },
        onVerticalDragEnd: (d) {
          // Dismiss if swiped up past 30% screen height
          if (_dragOffset < -(screenH * 0.25) ||
              (d.primaryVelocity != null && d.primaryVelocity! < -600)) {
            _dismissTop();
          } else {
            setState(() {
              _dragOffset = 0;
              _isDragging = false;
            });
          }
        },
        child: card,
      );
    }

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      top: topOffset,
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        scale: scale,
        alignment: Alignment.topCenter,
        child: card,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Shot Card
// ─────────────────────────────────────────────────────────────────────────────

class _ShotCard extends StatelessWidget {
  final String itemId;
  final String title;
  final String? imageUrl;
  final String description;
  final String publishedText;
  final List<dynamic> articlesList;
  final List<String> questionsList;
  final String newsTitle;
  final double screenH;
  final double screenW;
  final VoidCallback? onTap;
  final bool isFavorited;
  final VoidCallback? onFavorite;

  const _ShotCard({
    required this.itemId,
    required this.title,
    this.imageUrl,
    required this.description,
    required this.publishedText,
    required this.articlesList,
    required this.questionsList,
    required this.newsTitle,
    required this.screenH,
    required this.screenW,
    this.onTap,
    this.isFavorited = false,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Outer container: border + rounded corners only (no clip)
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF6B4E38), width: 1.2),
        ),
        child: ClipRRect(
          // Inner clip to round image corners — separate from border
          borderRadius: BorderRadius.circular(23),
          child: Container(
            color: const Color(0xFF0F0F0F),
            child: Stack(
              children: [
                // ── Full image ──────────────────────────────────────────────────
                Positioned.fill(
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey[900]),
                        )
                      : Container(color: Colors.grey[900]),
                ),

                // ── Bottom gradient scrim ────────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: screenH * 0.65,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xD9000000),
                          Colors.black,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── Content overlay ──────────────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Sources + published row
                        Row(
                          children: [
                            ...articlesList
                                .take(3)
                                .toList()
                                .asMap()
                                .entries
                                .map((e) {
                                  final idx = e.key;
                                  final src =
                                      e.value as Map<String, dynamic>? ?? {};
                                  final fav = src['source_favicon_url']
                                      ?.toString();
                                  return Transform.translate(
                                    offset: Offset(idx * -6.0, 0),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 1.5,
                                        ),
                                        image: fav != null && fav.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(fav),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: fav == null || fav.isEmpty
                                          ? const Icon(
                                              Icons.public,
                                              size: 10,
                                              color: Colors.white54,
                                            )
                                          : null,
                                    ),
                                  );
                                }),
                            if (articlesList.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  left:
                                      (articlesList.length > 3
                                          ? 3
                                          : articlesList.length) *
                                      2.0,
                                ),
                                child: Text(
                                  '+${articlesList.length}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              publishedText,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Question capsules
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _QuestionCapsule(
                                label: 'Ask Assistant',
                                icon: Icons.chat_bubble_outline,
                                onTap: () {
                                  if (itemId.isNotEmpty) {
                                    AnalyticsService.instance.logShotAssistantOpened(
                                      itemId: itemId,
                                      hasPrefillQuestion: false,
                                    );
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewsAssistantPage(
                                        newsTitle: newsTitle,
                                        prefillQuestion: '',
                                        source: 'shots',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ...questionsList.map(
                                (q) => _QuestionCapsule(
                                  label: q,
                                  onTap: () {
                                    if (itemId.isNotEmpty) {
                                      AnalyticsService.instance.logShotAssistantOpened(
                                        itemId: itemId,
                                        hasPrefillQuestion: true,
                                      );
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NewsAssistantPage(
                                          newsTitle: newsTitle,
                                          prefillQuestion: q,
                                          source: 'shots',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // content_description
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionCapsule extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _QuestionCapsule({required this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white60),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
