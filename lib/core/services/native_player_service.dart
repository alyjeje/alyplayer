/// Platform channel bridge for the native iOS AVPlayerViewController.
///
/// On iOS, this presents Apple's native video player which handles PiP,
/// AirPlay, subtitles, and audio tracks natively — no hacks needed.
library;

import 'dart:io';

import 'package:flutter/services.dart';

class NativePlayerService {
  static const _channel = MethodChannel('com.alyplayer/native_player');

  /// Whether native player is available (iOS only).
  static bool get isAvailable => Platform.isIOS;

  // Callbacks from native side
  Function()? onPiPStarted;
  Function(double positionSeconds)? onPiPStopped;
  Function(String error)? onPiPError;
  Function(double positionSeconds)? onDismissed;

  NativePlayerService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPiPStarted':
        onPiPStarted?.call();
      case 'onPiPStopped':
        final args = call.arguments as Map?;
        final pos = (args?['positionSeconds'] as num?)?.toDouble() ?? 0;
        onPiPStopped?.call(pos);
      case 'onPiPError':
        final args = call.arguments as Map?;
        onPiPError?.call(args?['error'] as String? ?? 'Unknown error');
      case 'onDismissed':
        final args = call.arguments as Map?;
        final pos = (args?['positionSeconds'] as num?)?.toDouble() ?? 0;
        onDismissed?.call(pos);
    }
  }

  /// Present the native AVPlayerViewController full-screen.
  /// Returns true if successfully presented.
  Future<bool> presentPlayer({
    required String url,
    String? title,
    double positionSeconds = 0,
  }) async {
    try {
      final result = await _channel.invokeMethod('presentPlayer', {
        'url': url,
        'title': title,
        'positionSeconds': positionSeconds,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('[NativePlayerService] presentPlayer error: ${e.message}');
      return false;
    }
  }

  /// Dismiss the native player and get the current position.
  Future<double> dismissPlayer() async {
    try {
      final result = await _channel.invokeMethod('dismissPlayer');
      if (result is Map) {
        return (result['positionSeconds'] as num?)?.toDouble() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get the current playback position in seconds.
  Future<double> getPosition() async {
    try {
      final result = await _channel.invokeMethod('getPosition');
      return (result as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
