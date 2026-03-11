import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sources_modal.dart';
import 'audio_manager.dart';
import 'user_preferences.dart';

class PodcastsPage extends StatefulWidget {
  final ValueNotifier<int>? refreshSignal;

  const PodcastsPage({super.key, this.refreshSignal});

  @override
  State<PodcastsPage> createState() => _PodcastsPageState();
}

class _PodcastsPageState extends State<PodcastsPage> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _podcasts = [];
  Set<String> _unlockedIds = {};
  int? _podcastLimit; // null = premium (unlimited)
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.refreshSignal?.addListener(_onRefresh);
    UserPreferences.instance.languageNotifier.addListener(_onLanguageChange);
  }

  void _onLanguageChange() => setState(() {});

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onRefresh);
    UserPreferences.instance.languageNotifier.removeListener(_onLanguageChange);
    super.dispose();
  }

  void _onRefresh() => _loadData();

  Future<void> _loadData() async {
    try {
      // Fetch both in parallel, then apply a single setState
      final podcastsFuture = _supabase
          .from('podcasts')
          .select(
            'id, podcast_title, podcast_summary, podcast_url_to_image, public_url, timestamp, podcast_sources, podcast_questions, translations, podcast_duration',
          )
          .order('timestamp', ascending: false);
      final userFuture = _fetchUserData();

      final podcasts = await podcastsFuture;
      final userData = await userFuture;

      final raw = userData?['podcasts_unlocked'];
      final isPremium = userData?['is_premium'] == true;

      setState(() {
        _podcasts = podcasts as List<dynamic>;
        if (raw is List) {
          _unlockedIds = raw.map((e) => e.toString()).toSet();
        }
        _podcastLimit = isPremium ? null : (userData?['podcast_limit'] as int? ?? 3);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return await _supabase
        .from('users')
        .select('podcasts_unlocked, podcast_limit, is_premium')
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> _unlockPodcast(String podcastId, PodcastItem item) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final updated = [..._unlockedIds, podcastId];
      final newLimit = _podcastLimit != null ? _podcastLimit! - 1 : null;
      final updateData = <String, dynamic>{'podcasts_unlocked': updated};
      if (newLimit != null) updateData['podcast_limit'] = newLimit;
      await _supabase.from('users').update(updateData).eq('id', userId);
      setState(() {
        _unlockedIds = updated.toSet();
        if (newLimit != null) _podcastLimit = newLimit;
      });
      AudioManager.instance.playPodcast(item);
    } catch (_) {}
  }

  void _onPodcastTap(String podcastId, PodcastItem item) {
    // Premium: play directly, no unlock needed
    if (_podcastLimit == null) {
      AudioManager.instance.playPodcast(item);
      return;
    }
    if (_unlockedIds.contains(podcastId)) {
      AudioManager.instance.playPodcast(item);
      return;
    }
    // Block if limit reached (non-premium only)
    if (_podcastLimit! <= 0) {
      _showUpgradeDialog();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Unlock Podcast',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _podcastLimit != null
              ? 'Unlock "${item.title}" to start listening?\n\n$_podcastLimit unlock${_podcastLimit == 1 ? '' : 's'} remaining.'
              : 'Unlock "${item.title}" to start listening?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unlockPodcast(podcastId, item);
            },
            child: const Text(
              'Unlock',
              style: TextStyle(color: Color(0xFFC8936A), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Unlock Limit Reached',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "You've used all your free podcast unlocks.\n\nUpgrade to Premium to unlock unlimited podcasts.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _upgradeToPremium();
            },
            child: const Text(
              'Go Premium',
              style: TextStyle(
                color: Color(0xFFC8936A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upgradeToPremium() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase
          .from('users')
          .update({'is_premium': true})
          .eq('id', userId);
      await AudioManager.instance.stop();
      setState(() {
        _podcastLimit = null; // null = premium (unlimited)
      });
    } catch (_) {}
  }

  String _formatTimeAgo(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) {
        return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() > 1 ? 's' : ''} ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hr${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} min${diff.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_isLoading) {
      content = const Center(
        child: CircularProgressIndicator(color: Color(0xFFC8936A)),
      );
    } else if (_error != null) {
      content = Center(
        child: Text(
          'Error: $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 80),
        itemCount: _podcasts.length,
        itemBuilder: (context, index) {
          final raw = _podcasts[index] as Map<String, dynamic>;
          final item = UserPreferences.resolvePodcast(
              raw, UserPreferences.instance.language);
          final title = item['podcast_title']?.toString() ?? '';
          final summary = item['podcast_summary']?.toString() ?? '';
          final imageUrl = raw['podcast_url_to_image']?.toString() ?? '';
          final timestamp = raw['timestamp']?.toString();
          final audioUrl = item['public_url']?.toString() ?? '';

          List<dynamic> sourcesList = [];
          final dynamic sourcesField = raw['podcast_sources'];
          if (sourcesField is List) {
            sourcesList = sourcesField;
          } else if (sourcesField is Map && sourcesField.containsKey('items')) {
            sourcesList = sourcesField['items'] as List<dynamic>? ?? [];
            try {
              sourcesList = List.from(sourcesField as Iterable);
            } catch (_) {}
          }

          List<dynamic> questionsList = [];
          final dynamic qField = item['podcast_questions']; // from resolved item
          if (qField is List) {
            questionsList = qField;
          } else if (qField is Map && qField.containsKey('items')) {
            questionsList = qField['items'] as List<dynamic>? ?? [];
            try {
              questionsList = List.from(qField as Iterable);
            } catch (_) {}
          } else if (qField != null) {
            try {
              questionsList = List.from(qField as Iterable);
            } catch (_) {}
          }

          final podcastId = raw['id']?.toString() ?? '';
          // Premium users have all podcasts unlocked
          final isUnlocked = _podcastLimit == null || _unlockedIds.contains(podcastId);

          final durationRaw = raw['podcast_duration'];
          final duration = durationRaw != null ? (num.tryParse(durationRaw.toString())! / 60).round() : null;

          final podcastItem = PodcastItem(
            title: title,
            date: _formatTimeAgo(timestamp),
            audioUrl: audioUrl,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
            summary: summary,
            sources: sourcesList,
            questions: questionsList,
            duration: duration,
          );

          return GestureDetector(
            onTap: () => _onPodcastTap(podcastId, podcastItem),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(
                        16,
                      ), // Following screenshot styling for Podcasts where image wraps top but background continues
                      bottomRight: Radius.circular(
                        16,
                      ), // Wait, screenshot shows bottom padding has the text. We will just wrap top.
                    ),
                    child: Stack(
                      children: [
                        // Feed Image
                        imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  height: 220,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            : Container(height: 220, color: Colors.grey[800]),
                        // Gradient to blend image with card bottom text
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.9),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.4, 1.0],
                            ),
                          ),
                        ),
                        // Lock icon top-right
                        if (!isUnlocked)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        // Title and Actions Overlay Bottom
                        Positioned(
                          bottom: 12,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Left side: Play/Pause + duration
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListenableBuilder(
                                        listenable: AudioManager.instance,
                                        builder: (context, _) {
                                          final isCurrent =
                                              AudioManager
                                                  .instance
                                                  .currentPodcast
                                                  ?.audioUrl ==
                                              audioUrl;
                                          final isPlaying =
                                              isCurrent &&
                                              AudioManager.instance.isPlaying;

                                          return GestureDetector(
                                            onTap: () => _onPodcastTap(podcastId, podcastItem),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.white38,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isPlaying
                                                        ? Icons.pause
                                                        : Icons.play_arrow,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  if (isCurrent &&
                                                      isPlaying) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons.bar_chart,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (podcastItem.duration != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.headphones,
                                              color: Colors.white54,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${podcastItem.duration} mins',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  // Publish Date & Sources Text
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (podcastItem.sources.isNotEmpty)
                                        GestureDetector(
                                          onTap: () => showSourcesModal(
                                            context,
                                            podcastItem.sources,
                                          ),
                                          behavior: HitTestBehavior.opaque,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ...podcastItem.sources
                                                    .take(3)
                                                    .toList()
                                                    .asMap()
                                                    .entries
                                                    .map((entry) {
                                                      final index = entry.key;
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
                                                        offset: Offset(
                                                          index * -8.0,
                                                          0,
                                                        ),
                                                        child: Container(
                                                          width: 20,
                                                          height: 20,
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .grey[800],
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color:
                                                                  Colors.black,
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
                                                                  Icons.public,
                                                                  size: 10,
                                                                  color: Colors
                                                                      .white54,
                                                                )
                                                              : null,
                                                        ),
                                                      );
                                                    }),
                                                if (podcastItem.sources.length >
                                                    3)
                                                  Transform.translate(
                                                    offset: const Offset(
                                                      -12.0,
                                                      0,
                                                    ),
                                                    child: Text(
                                                      ' +${podcastItem.sources.length - 3}',
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                Transform.translate(
                                                  offset: Offset(
                                                    (podcastItem
                                                                    .sources
                                                                    .length >
                                                                3
                                                            ? 3
                                                            : podcastItem
                                                                  .sources
                                                                  .length) *
                                                        -4.0,
                                                    0,
                                                  ),
                                                  child: const Icon(
                                                    Icons.chevron_right,
                                                    color: Colors.white54,
                                                    size: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Text(
                                        'Published ${podcastItem.date}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (summary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Text(
                        summary,
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
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
            children: [
              // 'Newspresso' header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    // Spacer equal to badge width to keep title centered
                    SizedBox(width: _podcastLimit != null ? 48 : 0),
                    const Expanded(
                      child: Text(
                        'Newspresso',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (_podcastLimit != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.headphones,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_podcastLimit',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Main content
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}
