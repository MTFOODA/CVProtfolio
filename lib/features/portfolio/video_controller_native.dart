import 'dart:io';

import 'package:video_player/video_player.dart';

VideoPlayerController localVideoController(Uri uri) =>
    VideoPlayerController.file(File.fromUri(uri));
