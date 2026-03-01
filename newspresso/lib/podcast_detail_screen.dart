import 'package:flutter/material.dart';
import 'audio_manager.dart';
import 'sources_modal.dart';
import 'news_assistant_page.dart';

class PodcastDetailScreen extends StatefulWidget {
  final PodcastItem podcast;

  const PodcastDetailScreen({super.key, required this.podcast});

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen> {
  // Format seconds to mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Only fetch exactly what the podcast has currently buffered
    final player = AudioManager.instance.player;

    return Scaffold(
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
              // Header & Back Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_ios,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Newspresso',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Podcast Image Header
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFF0F0F0F),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              widget.podcast.imageUrl != null
                                  ? Image.network(
                                      widget.podcast.imageUrl!,
                                      height: 250,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                height: 250,
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                  Icons.mic,
                                                  size: 50,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                    )
                                  : Container(
                                      height: 250,
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.mic,
                                        size: 50,
                                        color: Colors.white54,
                                      ),
                                    ),
                              Container(
                                height: 250,
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
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: Text(
                                  widget.podcast.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Published Data & Sources row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Published ${widget.podcast.date}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          if (widget.podcast.sources.isNotEmpty)
                            GestureDetector(
                              onTap: () => showSourcesModal(
                                context,
                                widget.podcast.sources,
                              ),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                children: [
                                  // Overlapping icons
                                  Row(
                                    children: widget.podcast.sources
                                        .take(3)
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                          final index = entry.key;
                                          final sourceItem =
                                              entry.value
                                                  as Map<String, dynamic>? ??
                                              {};
                                          final faviconUrl =
                                              sourceItem['source_favicon_url']
                                                  ?.toString();
                                          return Transform.translate(
                                            offset: Offset(index * -8.0, 0),
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
                                                image:
                                                    faviconUrl != null &&
                                                        faviconUrl.isNotEmpty
                                                    ? DecorationImage(
                                                        image: NetworkImage(
                                                          faviconUrl,
                                                        ),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                              ),
                                              child:
                                                  faviconUrl == null ||
                                                      faviconUrl.isEmpty
                                                  ? const Icon(
                                                      Icons.public,
                                                      size: 10,
                                                      color: Colors.white54,
                                                    )
                                                  : null,
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                  if (widget.podcast.sources.length > 3)
                                    Transform.translate(
                                      offset: const Offset(-8.0, 0),
                                      child: Text(
                                        '+${widget.podcast.sources.length - 3} Sources',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    Transform.translate(
                                      offset: Offset(
                                        (widget.podcast.sources.length * -4.0),
                                        0,
                                      ),
                                      child: const Text(
                                        ' Sources',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  Transform.translate(
                                    offset: Offset(
                                      (widget.podcast.sources.length > 3
                                              ? 3
                                              : widget.podcast.sources.length) *
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
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Audio Player Control section
                      // Check if we are currently listening to this actual podcast
                      ListenableBuilder(
                        listenable: AudioManager.instance,
                        builder: (context, _) {
                          final isCurrent =
                              AudioManager.instance.currentPodcast?.audioUrl ==
                              widget.podcast.audioUrl;
                          final isPlaying =
                              isCurrent && AudioManager.instance.isPlaying;

                          return StreamBuilder<Duration>(
                            stream: player.positionStream,
                            builder: (context, posSnap) {
                              return StreamBuilder<Duration?>(
                                stream: player.durationStream,
                                builder: (context, durSnap) {
                                  final position = isCurrent
                                      ? (posSnap.data ?? Duration.zero)
                                      : Duration.zero;
                                  final duration = isCurrent
                                      ? (durSnap.data ?? Duration.zero)
                                      : Duration.zero;

                                  return Column(
                                    children: [
                                      // Progress Slider
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 4.0,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 8.0,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 16.0,
                                              ),
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white
                                              .withValues(alpha: 0.2),
                                          thumbColor: Colors.white,
                                          overlayColor: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                        child: Slider(
                                          min: 0.0,
                                          max: duration.inMilliseconds > 0
                                              ? duration.inMilliseconds
                                                    .toDouble()
                                              : 1.0,
                                          value: position.inMilliseconds
                                              .toDouble()
                                              .clamp(
                                                0.0,
                                                duration.inMilliseconds > 0
                                                    ? duration.inMilliseconds
                                                          .toDouble()
                                                    : 1.0,
                                              ),
                                          onChanged: (value) {
                                            if (isCurrent) {
                                              player.seek(
                                                Duration(
                                                  milliseconds: value.toInt(),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      // Time markers
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(duration),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Control Buttons (Back 10s, Play/Pause, Forward 10s)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // -10 button
                                          IconButton(
                                            icon: const Icon(
                                              Icons.replay_10,
                                              color: Colors.white,
                                              size: 36,
                                            ),
                                            onPressed: () {
                                              if (isCurrent) {
                                                final newPos =
                                                    position -
                                                    const Duration(seconds: 10);
                                                player.seek(
                                                  newPos < Duration.zero
                                                      ? Duration.zero
                                                      : newPos,
                                                );
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 24),
                                          // Big Play/Pause
                                          GestureDetector(
                                            onTap: () {
                                              if (isCurrent) {
                                                if (isPlaying) {
                                                  AudioManager.instance.pause();
                                                } else {
                                                  AudioManager.instance
                                                      .resume();
                                                }
                                              } else {
                                                AudioManager.instance
                                                    .playPodcast(
                                                      widget.podcast,
                                                    );
                                              }
                                            },
                                            child: Container(
                                              width: 64,
                                              height: 64,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isPlaying
                                                    ? Icons.pause
                                                    : Icons.play_arrow,
                                                color: Colors.black,
                                                size: 36,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          // +10 button
                                          IconButton(
                                            icon: const Icon(
                                              Icons.forward_10,
                                              color: Colors.white,
                                              size: 36,
                                            ),
                                            onPressed: () {
                                              if (isCurrent &&
                                                  duration.inMilliseconds > 0) {
                                                final newPos =
                                                    position +
                                                    const Duration(seconds: 10);
                                                player.seek(
                                                  newPos > duration
                                                      ? duration
                                                      : newPos,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Podcast Summary Text
                      if (widget.podcast.summary != null &&
                          widget.podcast.summary!.isNotEmpty)
                        Text(
                          widget.podcast.summary!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.5,
                            letterSpacing: 0.2,
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Follow Up Section
                      if (widget.podcast.questions.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Follow up',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NewsAssistantPage(
                                      newsTitle: widget.podcast.title,
                                      prefillQuestion: '',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 15,
                                      color: Colors.white60,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Ask Assistant',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        ...widget.podcast.questions.map((q) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NewsAssistantPage(
                                    newsTitle: widget.podcast.title,
                                    prefillQuestion: q.toString(),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      q.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white38,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
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
