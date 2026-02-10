/// Widget that embeds the native iOS AVPlayerViewController inline via UiKitView.
///
/// On non-iOS platforms this renders an empty black box (should never happen
/// since [PlayerScreen] only uses this widget on iOS).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_player_controller.dart';

class NativePlayerView extends StatelessWidget {
  final NativePlayerController controller;

  const NativePlayerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return const ColoredBox(color: Colors.black);
    }
    return UiKitView(
      viewType: 'native_player_view',
      onPlatformViewCreated: controller.onPlatformViewCreated,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
