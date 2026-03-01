import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:audio_session/audio_session.dart';

class PodcastItem {
  final String title;
  final String date;
  final String audioUrl;
  final String? imageUrl;
  final String? summary;
  final List<dynamic> sources;
  final List<dynamic> questions;

  PodcastItem({
    required this.title,
    required this.date,
    required this.audioUrl,
    this.imageUrl,
    this.summary,
    this.sources = const [],
    this.questions = const [],
  });
}

class AudioManager extends ChangeNotifier {
  static final AudioManager instance = AudioManager._internal();
  AudioManager._internal();

  final AudioPlayer player = AudioPlayer();
  bool _isInitialized = false;

  PodcastItem? currentPodcast;
  bool isPlaying = false;

  AudioManager() {
    player.playerStateStream.listen((state) {
      debugPrint(
        "AudioPlayer state: playing=${state.playing}, processingState=${state.processingState}",
      );
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        isPlaying = false;
      }
      notifyListeners();
    });

    player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        debugPrint('A stream error occurred: $e');
      },
    );
  }

  Future<void> _initSession() async {
    if (_isInitialized) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _isInitialized = true;
      debugPrint("AudioSession initialized");
    } catch (e) {
      debugPrint("Error initializing AudioSession: $e");
    }
  }

  Future<void> playPodcast(PodcastItem podcast) async {
    debugPrint("Attempting to play: ${podcast.audioUrl}");
    await _initSession();
    if (currentPodcast?.audioUrl == podcast.audioUrl) {
      if (isPlaying) {
        debugPrint("Pausing current podcast");
        pause();
      } else {
        debugPrint("Resuming current podcast");
        resume();
      }
    } else {
      debugPrint("Setting new podcast URL");
      currentPodcast = podcast;
      isPlaying = true;
      notifyListeners();

      try {
        player.setUrl(podcast.audioUrl).catchError((e) {
          debugPrint("Error in setUrl: $e");
          return null;
        });
        player.play().catchError((e) {
          debugPrint("Error in play: $e");
          isPlaying = false;
          notifyListeners();
        });
      } catch (e) {
        isPlaying = false;
        notifyListeners();
        debugPrint("Catch block error playing audio: $e");
      }
    }
  }

  void pause() {
    isPlaying = false;
    notifyListeners();
    player.pause().catchError((e) => debugPrint("Error pausing: $e"));
  }

  void resume() {
    isPlaying = true;
    notifyListeners();
    player.play().catchError((e) {
      debugPrint("Error resuming: $e");
      isPlaying = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
