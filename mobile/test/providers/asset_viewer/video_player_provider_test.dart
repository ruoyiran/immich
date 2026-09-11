import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_viewer.widget.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:native_video_player/native_video_player.dart';

class MockNativeVideoPlayerController extends Mock implements NativeVideoPlayerController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores position and playback when switching a playing video source', () {
    const state = VideoPlayerState(
      position: Duration(seconds: 12),
      duration: Duration(minutes: 1),
      status: VideoPlaybackStatus.playing,
    );

    expect(videoPlaybackRestorePlan(state), (position: const Duration(seconds: 12), shouldPlay: true));
  });

  test('restores position without starting a paused video', () {
    const state = VideoPlayerState(
      position: Duration(seconds: 7),
      duration: Duration(minutes: 1),
      status: VideoPlaybackStatus.paused,
    );

    expect(videoPlaybackRestorePlan(state), (position: const Duration(seconds: 7), shouldPlay: false));
  });

  test('reports a video source load failure to the viewer', () async {
    final controller = MockNativeVideoPlayerController();
    final source = await VideoSource.init(path: 'https://example.test/video', type: VideoSourceType.network);
    when(() => controller.loadVideoSource(source)).thenThrow(StateError('unsupported codec'));
    final notifier = VideoPlayerNotifier()..attachController(controller);
    addTearDown(notifier.dispose);

    expect(await notifier.load(source), isFalse);
  });

  test('applies a pending original source when an offscreen video becomes current', () {
    expect(shouldApplyPendingVideoSource(isCurrent: true, sourceChanged: false, hasPendingReplacement: true), isTrue);
  });
}
