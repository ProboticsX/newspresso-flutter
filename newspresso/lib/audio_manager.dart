import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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

/// Handles audio playback and broadcasts state to the OS media session
/// (lock screen, notification, Control Center).
class PodcastAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  PodcastAudioHandler() {
    _configureAudioSession();
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  }

  AudioPlayer get player => _player;

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        const MediaControl(
          androidIcon: 'drawable/audio_service_fast_rewind',
          label: 'Rewind 10s',
          action: MediaAction.rewind,
        ),
        if (_player.playing) MediaControl.pause else MediaControl.play,
        const MediaControl(
          androidIcon: 'drawable/audio_service_fast_forward',
          label: 'Forward 10s',
          action: MediaAction.fastForward,
        ),
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.rewind,
        MediaAction.fastForward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> playFromUrl(String url, MediaItem item) async {
    mediaItem.add(item);
    await _player.setUrl(url);
    await _player.play();
  }
}

class AudioManager extends ChangeNotifier {
  static final AudioManager instance = AudioManager._internal();
  AudioManager._internal();

  PodcastAudioHandler? _handler;

  PodcastItem? currentPodcast;
  bool isPlaying = false;

  AudioPlayer get player => _handler!.player;

  /// Must be called once in [main] before [runApp].
  Future<void> init() async {
    _handler = await AudioService.init(
      builder: () => PodcastAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.newspresso.audio',
        androidNotificationChannelName: 'Newspresso Podcasts',
        androidNotificationIcon: 'drawable/ic_notification',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        fastForwardInterval: Duration(seconds: 10),
        rewindInterval: Duration(seconds: 10),
      ),
    );

    _handler!.player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        isPlaying = false;
      }
      notifyListeners();
    });
  }

  Future<void> playPodcast(PodcastItem podcast) async {
    if (currentPodcast?.audioUrl == podcast.audioUrl) {
      if (isPlaying) {
        pause();
      } else {
        resume();
      }
      return;
    }

    currentPodcast = podcast;
    isPlaying = true;
    notifyListeners();

    try {
      final item = MediaItem(
        id: podcast.audioUrl,
        title: podcast.title,
        artUri: podcast.imageUrl != null
            ? Uri.tryParse(podcast.imageUrl!)
            : null,
      );
      await _handler!.playFromUrl(podcast.audioUrl, item);
    } catch (e) {
      debugPrint('Error playing podcast: $e');
      isPlaying = false;
      notifyListeners();
    }
  }

  void pause() {
    isPlaying = false;
    notifyListeners();
    _handler?.pause();
  }

  void resume() {
    isPlaying = true;
    notifyListeners();
    _handler?.play();
  }

  Future<void> stop() async {
    await _handler?.stop();
    currentPodcast = null;
    isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _handler?.player.dispose();
    super.dispose();
  }
}
