import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EmailLauncher {
  static const _channel = MethodChannel('com.quickmail.apply/email');

  static Future<void> openCompose({
    required String email,
    required String subject,
    required String body,
    String? attachmentPath,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Email compose is supported on Android and iOS only.');
    }

    await _channel.invokeMethod<void>('openMailCompose', {
      'email': email.trim(),
      'subject': subject,
      'body': body,
      'attachmentPath': attachmentPath,
    });
  }

  static String applyButtonLabel() {
    if (Platform.isIOS) return 'Open Mail';
    return 'Apply via Gmail';
  }

  static String applyingLabel() {
    if (Platform.isIOS) return 'Opening Mail…';
    return 'Opening Gmail…';
  }

  static String friendlyError(Object error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'NO_GMAIL':
          return 'Gmail is not installed. Install Gmail or use another email app.';
        case 'NO_MAIL':
          return 'No mail account configured. Set up Mail in Settings, then try again.';
        case 'NO_MAIL_APP':
          return 'Could not open a mail app on this device.';
        case 'INTENT_FAILED':
          if (error.message?.contains('configured root') == true) {
            return 'Could not attach resume. Re-select the resume in your profile and try again.';
          }
          return error.message ?? 'Could not open email.';
      }
      return error.message ?? 'Could not open email.';
    }
    if (error is UnsupportedError) {
      return error.message ?? 'This feature is not supported on this platform.';
    }
    debugPrint('EmailLauncher error: $error');
    return 'Something went wrong while opening email.';
  }
}
