import '../../core/design/app_icons.dart';

import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../core/utils/project_media.dart';
import 'portfolio_controller.dart';
import 'portfolio_widgets.dart';
import 'video_controller_web.dart'
    if (dart.library.io) 'video_controller_native.dart';

/// Videos initialise on demand and stop when their tab/app is no longer active.
class PortfolioProjectMedia extends ConsumerStatefulWidget {
  const PortfolioProjectMedia({
    super.key,
    required this.source,
    required this.ownerId,
    this.active = true,
  });
  final String? source;
  final String ownerId;
  final bool active;
  @override
  ConsumerState<PortfolioProjectMedia> createState() =>
      _PortfolioProjectMediaState();
}

class _PortfolioProjectMediaState extends ConsumerState<PortfolioProjectMedia>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _loading = false;
  String? _error;
  int _generation = 0;
  late bool _imageRequested = widget.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(PortfolioProjectMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) _imageRequested = true;
    if (oldWidget.source != widget.source ||
        oldWidget.ownerId != widget.ownerId) {
      _generation++;
      _controller?.dispose();
      _controller = null;
      _loading = false;
      _error = null;
    } else if (!widget.active) {
      _controller?.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_loading || !widget.active) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    VideoPlayerController? player;
    try {
      var source = widget.source!;
      if (Uri.tryParse(source)?.hasScheme != true) {
        source =
            await ref.read(backendProvider).signedUrl(widget.ownerId, source) ??
            '';
      }
      if (RegExp(r'^file://[A-Za-z]:').hasMatch(source)) {
        source = Uri.file(source.substring(7), windows: true).toString();
      }
      final uri = Uri.parse(source);
      if (uri.scheme == 'file') {
        player = localVideoController(uri);
      } else if (portfolioWebUri(source) != null) {
        player = VideoPlayerController.networkUrl(uri);
      } else {
        throw const FormatException('Unavailable video');
      }
      await player.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || generation != _generation) {
        await player.dispose();
        return;
      }
      await _controller?.dispose();
      _controller = player;
      if (widget.active &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        await player.play();
      }
    } catch (_) {
      // Some platforms fail before the plugin creates a player ID. Their
      // disposal Future may stay pending; it must not block the retry UI.
      if (player != null) {
        unawaited(player.dispose().catchError((Object _) {}));
        if (identical(player, _controller)) _controller = null;
      }
      if (mounted && generation == _generation) _error = 'Video unavailable. Check your connection or try a supported MP4 video.';
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _placeholder(BuildContext context, {bool video = false}) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: .15),
            accent.withValues(alpha: .04),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: video
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading)
                  const CircularProgressIndicator()
                else
                  IconButton.filled(
                    tooltip: _error == null
                        ? 'Play demo video'
                        : 'Retry demo video',
                    onPressed: widget.active ? _start : null,
                    icon: Icon(
                      _error == null ? AppIcons.playArrow : AppIcons.refresh,
                    ),
                    iconSize: 36,
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: UiText(
                    _error ?? 'Demo video',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: accent, fontSize: 12),
                  ),
                ),
              ],
            )
          : Icon(
              AppIcons.webAsset,
              size: 52,
              color: accent.withValues(alpha: .6),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    if (source == null || !isProjectVideo(source)) {
      return AspectRatio(
        aspectRatio: 1.8,
        child: !_imageRequested
            ? _placeholder(context)
            : PortfolioImage(
                source: source,
                ownerId: widget.ownerId,
                fallback: _placeholder(context),
              ),
      );
    }
    final controller = _controller;
    if (controller == null || _loading || _error != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _placeholder(context, video: true),
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.hasError) {
          return AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(
              child: TextButton.icon(
                onPressed: _start,
                icon: const Icon(AppIcons.refresh),
                label: const UiText('Video failed. Retry'),
              ),
            ),
          );
        }
        return Column(
          children: [
            ColoredBox(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
            VideoProgressIndicator(
              controller,
              allowScrubbing: widget.active,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: context.ui(
                    value.isPlaying ? 'Pause video' : 'Play video',
                  ),
                  onPressed: !widget.active
                      ? null
                      : () async {
                          if (value.isPlaying) {
                            await controller.pause();
                          } else {
                            if (value.position >= value.duration) {
                              await controller.seekTo(Duration.zero);
                            }
                            await controller.play();
                          }
                        },
                  icon: Icon(
                    value.isPlaying ? AppIcons.pause : AppIcons.playArrow,
                  ),
                ),
                Expanded(
                  child: UiText(
                    '${_time(value.position)} / ${_time(value.duration)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: context.ui(
                    value.volume == 0 ? 'Unmute video' : 'Mute video',
                  ),
                  onPressed: () =>
                      controller.setVolume(value.volume == 0 ? 1 : 0),
                  icon: Icon(
                    value.volume == 0 ? AppIcons.volumeOff : AppIcons.volumeUp,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _time(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
