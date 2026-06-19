import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../utils/email_validator.dart';

class ShareIntentService {
  static StreamSubscription<List<SharedMediaFile>>? _subscription;

  static Future<String?> getInitialSharedText() async {
    try {
      final media = await ReceiveSharingIntent.instance.getInitialMedia();
      if (media.isEmpty) return null;

      final text = _extractText(media);
      if (text != null) {
        await ReceiveSharingIntent.instance.reset();
      }
      return text;
    } catch (error, stackTrace) {
      debugPrint('ShareIntentService.getInitialSharedText: $error\n$stackTrace');
      return null;
    }
  }

  static void listen(void Function(String text) onText) {
    _subscription?.cancel();
    try {
      _subscription = ReceiveSharingIntent.instance.getMediaStream().listen((media) {
        final text = _extractText(media);
        if (text != null) onText(text);
      });
    } catch (error, stackTrace) {
      debugPrint('ShareIntentService.listen: $error\n$stackTrace');
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  static String? _extractText(List<SharedMediaFile> media) {
    for (final item in media) {
      if (item.type == SharedMediaType.text) {
        return extractEmailFromText(item.path) ?? item.path.trim();
      }
    }

    for (final item in media) {
      final message = item.message?.trim();
      if (message != null && message.isNotEmpty) {
        return extractEmailFromText(message) ?? message;
      }
    }

    for (final item in media) {
      if (item.type == SharedMediaType.url) {
        final email = extractEmailFromText(item.path);
        if (email != null) return email;
      }
    }

    for (final item in media) {
      final email = extractEmailFromText(item.path);
      if (email != null) return email;
    }

    return null;
  }
}
