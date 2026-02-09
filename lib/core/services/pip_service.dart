import 'dart:io';
import 'package:flutter/services.dart';

/// Service that bridges to native iOS Picture-in-Picture via platform channels.
///
/// On iOS, this hands the stream URL to a native AVPlayer which provides
/// PiP through AVPlayerViewController. When PiP ends, it reports back the
/// playback position so media_kit can resume from the same point.
class PiPService {
  PiPService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channel = MethodChannel('com.alyplayer/pip');

  void Function()? onPiPStarted;
  void Function(double positionSeconds)? onPiPStopped;
  void Function(double positionSeconds)? onPiPRestoreUI;
  void Function(String error)? onPiPError;

  Future<bool> get isSupported async {
    if (!Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> get isActive async {
    if (!Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isPiPActive');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> startPiP({
    required String url,
    double positionSeconds = 0.0,
    Map<String, String>? headers,
  }) async {
    if (!Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod<bool>('startPiP', {
        'url': url,
        'positionSeconds': positionSeconds,
        'headers': headers,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      onPiPError?.call(e.message ?? 'Unknown PiP error');
      return false;
    }
  }

  Future<void> stopPiP() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('stopPiP');
    } on PlatformException {
      // Ignore -- PiP may already be stopped
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPiPStarted':
        onPiPStarted?.call();
      case 'onPiPStopped':
        final args = call.arguments as Map?;
        final position = (args?['position'] as num?)?.toDouble() ?? 0.0;
        onPiPStopped?.call(position);
      case 'onPiPRestoreUI':
        final args = call.arguments as Map?;
        final position = (args?['position'] as num?)?.toDouble() ?? 0.0;
        onPiPRestoreUI?.call(position);
      case 'onPiPError':
        final args = call.arguments as Map?;
        final error = args?['error'] as String? ?? 'Unknown error';
        onPiPError?.call(error);
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    onPiPStarted = null;
    onPiPStopped = null;
    onPiPRestoreUI = null;
    onPiPError = null;
  }
}
