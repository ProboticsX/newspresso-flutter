import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audio_manager.dart';

class PodcastsPage extends StatefulWidget {
  const PodcastsPage({super.key});

  @override
  State<PodcastsPage> createState() => _PodcastsPageState();
}

class _PodcastsPageState extends State<PodcastsPage> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _podcasts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPodcasts();
  }

  Future<void> _fetchPodcasts() async {
    try {
      final res = await _supabase
          .from('podcasts')
          .select(
            'id, podcast_title, podcast_summary, podcast_url_to_image, public_url, timestamp, category',
          )
          .order('timestamp', ascending: false);

      setState(() {
        _podcasts = res as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
          final item = _podcasts[index] as Map<String, dynamic>;
          final title = item['podcast_title']?.toString() ?? '';
          final summary = item['podcast_summary']?.toString() ?? '';
          final imageUrl = item['podcast_url_to_image']?.toString() ?? '';
          final audioUrl = item['public_url']?.toString() ?? '';
          final timestamp = item['timestamp']?.toString();

          // Using the podcast title as a unique identifier if ID is missing.
          final podcastItem = PodcastItem(
            title: title,
            date: _formatTimeAgo(timestamp),
            audioUrl: audioUrl,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
            summary: summary,
          );

          return Container(
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
                              errorBuilder: (_, __, ___) => Container(
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
                              Colors.black.withOpacity(0.0),
                              Colors.black.withOpacity(0.9),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.4, 1.0],
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left side: Add list and Play/Pause
                                Row(
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
                                          onTap: () => AudioManager.instance
                                              .playPodcast(podcastItem),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.15,
                                              ),
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
                                                if (isCurrent && isPlaying) ...[
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
                                  ],
                                ),
                                // Publish Date Text
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Newspresso',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
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
