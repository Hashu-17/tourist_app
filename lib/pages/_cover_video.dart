import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class _CoverVideo extends StatelessWidget {
  final VideoPlayerController controller;
  const _CoverVideo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: controller.value.isInitialized
          ? controller.value.aspectRatio
          : 16 / 9,
      child: VideoPlayer(controller),
    );
  }
}