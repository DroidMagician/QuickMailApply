import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles mailto: links when user taps an email in LinkedIn or other apps.
class IncomingLinkService {
  static const _methodChannel = MethodChannel('com.quickmail.apply/incoming');
  static const _mailtoEvents = EventChannel('com.quickmail.apply/incoming_mailto');

  static StreamSubscription<dynamic>? _mailtoSubscription;

  static Future<String?> getInitialMailto() async {
    if (!Platform.isAndroid) return null;
    try {
      final email = await _methodChannel.invokeMethod<String>('getInitialMailto');
      return email?.trim().isEmpty == true ? null : email?.trim();
    } catch (error, stackTrace) {
      debugPrint('IncomingLinkService.getInitialMailto: $error\n$stackTrace');
      return null;
    }
  }

  static void listenMailto(void Function(String email) onEmail) {
    if (!Platform.isAndroid) return;

    _mailtoSubscription?.cancel();
    _mailtoSubscription = _mailtoEvents.receiveBroadcastStream().listen(
      (event) {
        if (event is String && event.trim().isNotEmpty) {
          onEmail(event.trim());
        }
      },
      onError: (Object error) => debugPrint('IncomingLinkService mailto stream: $error'),
    );
  }

  static void dispose() {
    _mailtoSubscription?.cancel();
    _mailtoSubscription = null;
  }
}
