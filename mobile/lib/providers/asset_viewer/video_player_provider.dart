import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:native_video_player/native_video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum VideoPlaybackStatus { paused, playing, buffering, completed }

class VideoPlayerState {
  final Duration position;
  final Duration duration;
  final VideoPlaybackStatus status;

  const VideoPlayerState({required this.position, required this.duration, required this.status});

  VideoPlayerState copyWith({Duration? position, Duration? duration, VideoPlaybackStatus? status}) {
    return VideoPlayerState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      status: status ?? this.status,
    );
  }
}

typedef VideoPlaybackRestorePlan = ({Duration position, bool shouldPlay});

VideoPlaybackRestorePlan videoPlaybackRestorePlan(VideoPlayerState state) => (
  position: state.position,
  shouldPlay: state.status == VideoPlaybackStatus.playing || state.status == VideoPlaybackStatus.buffering,
);

const _defaultState = VideoPlayerState(
  position: Duration.zero,
  duration: Duration.zero,
  status: VideoPlaybackStatus.paused,
);

final videoPlayerProvider = StateNotifierProvider.autoDispose.family<VideoPlayerNotifier, VideoPlayerState, String>((
  ref,
  name,
) {
  return VideoPlayerNotifier();
});

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  static final _log = Logger('VideoPlayerNotifier');

  VideoPlayerNotifier() : super(_defaultState);

  NativeVideoPlayerController? _controller;
  Timer? _bufferingTimer;
  Timer? _seekTimer;
  VideoPlaybackStatus? _holdStatus;
  VideoPlaybackStatus _requestedStatus = VideoPlaybackStatus.paused;
  int _playbackOperation = 0;

  @override
  void dispose() {
    _bufferingTimer?.cancel();
    _seekTimer?.cancel();
    unawaited(
      WakelockPlus.disable().catchError((error, stack) {
        _log.warning('Error disabling wakelock', error, stack);
      }),
    );
    _controller = null;

    super.dispose();
  }

  void attachController(NativeVideoPlayerController controller) {
    _controller = controller;
  }

  Future<bool> load(VideoSource source) async {
    final controller = _controller;
    if (controller == null) {
      return false;
    }
    _startBufferingTimer();
    try {
      await controller.loadVideoSource(source);
      return true;
    } catch (e) {
      _bufferingTimer?.cancel();
      _log.severe('Error loading video source: $e');
      return false;
    }
  }

  Future<void> pause() async {
    if (_controller == null) {
      return;
    }

    final operation = ++_playbackOperation;
    _requestedStatus = VideoPlaybackStatus.paused;
    _bufferingTimer?.cancel();
    if (mounted) {
      state = state.copyWith(status: VideoPlaybackStatus.paused);
    }

    try {
      await _controller!.pause();
      await _flushSeek();
      if (mounted && operation == _playbackOperation) {
        state = state.copyWith(status: VideoPlaybackStatus.paused);
      }
    } catch (e) {
      _log.severe('Error pausing video: $e');
    }
  }

  Future<void> play() async {
    if (_controller == null) {
      return;
    }

    final operation = ++_playbackOperation;
    _requestedStatus = VideoPlaybackStatus.playing;
    try {
      await _flushSeek();
      await _controller!.play();
      if (mounted && operation == _playbackOperation) {
        state = state.copyWith(status: VideoPlaybackStatus.playing);
        _startBufferingTimer();
      }
    } catch (e) {
      _log.severe('Error playing video: $e');
    }
  }

  Future<void> _flushSeek() async {
    final timer = _seekTimer;
    if (timer == null || !timer.isActive) {
      return;
    }

    timer.cancel();
    await _controller?.seekTo(state.position.inMilliseconds);
  }

  void seekTo(Duration position) {
    if (_controller == null || state.position == position) {
      return;
    }

    state = state.copyWith(position: position);

    if (_seekTimer?.isActive ?? false) {
      return;
    }

    _seekTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(_controller?.seekTo(state.position.inMilliseconds));
    });
  }

  void toggle() {
    _holdStatus = null;

    switch (state.status) {
      case VideoPlaybackStatus.paused:
        unawaited(play());
      case VideoPlaybackStatus.playing || VideoPlaybackStatus.buffering:
        unawaited(pause());
      case VideoPlaybackStatus.completed:
        unawaited(restart());
    }
  }

  /// Pauses playback and preserves the current status for later restoration.
  void hold() {
    if (_holdStatus != null) {
      return;
    }

    _holdStatus = state.status;
    unawaited(pause());
  }

  /// Restores playback to the status before [hold] was called.
  void release() {
    final status = _holdStatus;
    _holdStatus = null;

    switch (status) {
      case VideoPlaybackStatus.playing || VideoPlaybackStatus.buffering:
        unawaited(play());
      default:
    }
  }

  Future<void> restart() async {
    seekTo(Duration.zero);
    await play();
  }

  Future<void> setVolume(double volume) async {
    try {
      await _controller?.setVolume(volume);
    } catch (e) {
      _log.severe('Error setting volume: $e');
    }
  }

  Future<void> setLoop(bool loop) async {
    try {
      await _controller?.setLoop(loop);
    } catch (e) {
      _log.severe('Error setting loop: $e');
    }
  }

  void onNativePlaybackReady() {
    if (!mounted) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    final videoInfo = _controller?.videoInfo;

    if (playbackInfo == null || videoInfo == null) {
      return;
    }

    state = state.copyWith(
      position: Duration(milliseconds: playbackInfo.position),
      duration: Duration(milliseconds: videoInfo.duration),
      status: _mapStatus(playbackInfo.status),
    );
  }

  void onNativePositionChanged() {
    if (!mounted || (_seekTimer?.isActive ?? false)) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    if (playbackInfo == null) {
      return;
    }

    final position = Duration(milliseconds: playbackInfo.position);
    if (state.position == position) {
      return;
    }

    if (state.status == VideoPlaybackStatus.playing) {
      _startBufferingTimer();
    }

    state = state.copyWith(
      position: position,
      status: state.status == VideoPlaybackStatus.buffering ? VideoPlaybackStatus.playing : null,
    );
  }

  void onNativeStatusChanged() {
    if (!mounted) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    if (playbackInfo == null) {
      return;
    }

    final newStatus = _mapStatus(playbackInfo.status);
    if (_requestedStatus == VideoPlaybackStatus.paused && newStatus == VideoPlaybackStatus.playing) {
      return;
    }

    switch (newStatus) {
      case VideoPlaybackStatus.playing:
        unawaited(WakelockPlus.enable());
        _startBufferingTimer();
      default:
        onNativePlaybackEnded();
    }

    if (state.status != newStatus) {
      state = state.copyWith(status: newStatus);
    }
  }

  void onNativePlaybackEnded() {
    unawaited(WakelockPlus.disable());
    _bufferingTimer?.cancel();
  }

  void _startBufferingTimer() {
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && state.status != VideoPlaybackStatus.completed) {
        state = state.copyWith(status: VideoPlaybackStatus.buffering);
      }
    });
  }

  static VideoPlaybackStatus _mapStatus(PlaybackStatus status) => switch (status) {
    PlaybackStatus.playing => VideoPlaybackStatus.playing,
    PlaybackStatus.paused => VideoPlaybackStatus.paused,
    PlaybackStatus.stopped => VideoPlaybackStatus.completed,
  };
}
