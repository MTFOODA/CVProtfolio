import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_project_media.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  final calls = <String>[];
  final sources = <String?>[];
  bool fail = false;
  bool failBeforeCreation = false;
  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    if (failBeforeCreation) {
      throw UnimplementedError('No video plugin on this platform');
    }
    final id = streams.length;
    final events = StreamController<VideoEvent>();
    streams[id] = events;
    sources.add(options.dataSource.uri);
    if (fail) {
      events.addError(
        PlatformException(
          code: 'unsupported',
          message: 'Unsupported video codec',
        ),
      );
    } else {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(1280, 720),
          duration: const Duration(seconds: 30),
        ),
      );
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    unawaited(streams[playerId]?.close());
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    calls.add('seek');
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  late _VideoPlatform platform;
  setUp(() {
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  Future<void> mount(WidgetTester tester, {bool active = true}) =>
      tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PortfolioProjectMedia(
                source: 'https://media.test/demo.mp4',
                ownerId: 'owner',
                active: active,
              ),
            ),
          ),
        ),
      );

  testWidgets('demo playback loads on tap, pauses on tab change and disposes', (
    tester,
  ) async {
    await mount(tester);
    expect(platform.sources, isEmpty);
    await tester.tap(find.byTooltip('Play demo video'));
    await tester.pumpAndSettle();
    expect(platform.sources, ['https://media.test/demo.mp4']);
    expect(platform.calls, contains('play'));
    expect(find.byTooltip('Pause video'), findsOneWidget);
    await mount(tester, active: false);
    await tester.pumpAndSettle();
    expect(platform.calls.last, 'pause');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(platform.calls, contains('dispose'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unsupported video shows retry and recovers without leaking controller',
    (tester) async {
      platform.fail = true;
      await mount(tester);
      await tester.tap(find.byTooltip('Play demo video'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
      expect(
        find.textContaining('Video unavailable'),
        findsOneWidget,
        reason: platform.calls.toString(),
      );
      expect(platform.calls, contains('dispose'));
      platform.fail = false;
      await tester.tap(find.byTooltip('Retry demo video'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pause video'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing platform plugin shows retry instead of an endless spinner',
    (tester) async {
      platform.failBeforeCreation = true;
      await mount(tester);
      await tester.tap(find.byTooltip('Play demo video'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry demo video'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
