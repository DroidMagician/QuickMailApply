import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart';
import 'package:http/http.dart' as http;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GmailService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      GmailApi.gmailSendScope,
      GmailApi.gmailReadonlyScope,
    ],
  );

  GoogleSignInAccount? _currentUser;

  GmailService() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
      notifyListeners();
    });
  }

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> init() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('GmailService signin silently failed: $e');
    }
  }

  Future<bool> get isSignedIn async {
    if (_currentUser != null) return true;
    final signedIn = await _googleSignIn.isSignedIn();
    if (signedIn) {
      _currentUser = _googleSignIn.currentUser;
    }
    return signedIn;
  }

  Future<String?> get currentUserEmail async {
    if (await isSignedIn) {
      return _currentUser?.email;
    }
    return null;
  }

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      return account != null;
    } catch (e) {
      debugPrint('GmailService signin failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    _currentUser = null;
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    if (await isSignedIn && _currentUser != null) {
      return await _currentUser!.authHeaders;
    }
    return null;
  }

  /// Sends a direct email using Gmail API and returns Map with 'id' and 'threadId'
  Future<Map<String, String>> sendDirectEmail({
    required String to,
    required String subject,
    required String body,
    String? attachmentPath,
    String? attachmentFileName,
  }) async {
    final headers = await getAuthHeaders();
    if (headers == null) {
      throw Exception('Gmail user is not signed in.');
    }

    final client = GoogleAuthClient(headers);
    final gmailApi = GmailApi(client);

    final rawMimeBase64url = _buildMimeMessage(
      to: to,
      subject: subject,
      body: body,
      attachmentPath: attachmentPath,
      attachmentFileName: attachmentFileName,
    );

    final message = Message()..raw = rawMimeBase64url;
    final sentMessage = await gmailApi.users.messages.send(message, 'me');

    return {
      'id': sentMessage.id ?? '',
      'threadId': sentMessage.threadId ?? '',
    };
  }

  /// Checks if a thread has received a reply (more than 1 message, last message not from user)
  Future<Map<String, dynamic>?> checkReplyStatus(String threadId, String userEmail) async {
    final headers = await getAuthHeaders();
    if (headers == null) return null;

    final client = GoogleAuthClient(headers);
    final gmailApi = GmailApi(client);

    try {
      final thread = await gmailApi.users.threads.get('me', threadId);
      final messages = thread.messages;

      if (messages == null || messages.isEmpty) {
        return null;
      }

      // If there is only one message, it's our sent email
      if (messages.length <= 1) {
        return {
          'status': 'sent',
          'snippet': null,
        };
      }

      final lastMessage = messages.last;
      
      final fromHeader = lastMessage.payload?.headers
          ?.firstWhere(
            (h) => h.name?.toLowerCase() == 'from',
            orElse: () => MessagePartHeader(),
          )
          .value;

      final isFromUser = fromHeader != null && fromHeader.toLowerCase().contains(userEmail.toLowerCase());

      if (!isFromUser) {
        return {
          'status': 'replied',
          'snippet': lastMessage.snippet,
        };
      } else {
        return {
          'status': 'sent',
          'snippet': null,
        };
      }
    } catch (e) {
      debugPrint('Error checking reply status for thread $threadId: $e');
      return null;
    }
  }

  String _buildMimeMessage({
    required String to,
    required String subject,
    required String body,
    String? attachmentPath,
    String? attachmentFileName,
  }) {
    final boundary = 'quickmail_apply_boundary_${DateTime.now().millisecondsSinceEpoch}';
    final buffer = StringBuffer();

    buffer.writeln('MIME-Version: 1.0');
    buffer.writeln('To: $to');
    final encodedSubject = base64.encode(utf8.encode(subject));
    buffer.writeln('Subject: =?utf-8?B?$encodedSubject?=');
    buffer.writeln('Content-Type: multipart/mixed; boundary="$boundary"');
    buffer.writeln();

    buffer.writeln('--$boundary');
    buffer.writeln('Content-Type: text/plain; charset="utf-8"');
    buffer.writeln('Content-Transfer-Encoding: base64');
    buffer.writeln();
    buffer.writeln(base64.encode(utf8.encode(body)));
    buffer.writeln();

    if (attachmentPath != null) {
      final file = File(attachmentPath);
      if (file.existsSync()) {
        final fileBytes = file.readAsBytesSync();
        final base64File = base64Encode(fileBytes);
        final fileName = attachmentFileName ?? file.uri.pathSegments.last;

        buffer.writeln('--$boundary');
        buffer.writeln('Content-Type: application/octet-stream; name="$fileName"');
        buffer.writeln('Content-Disposition: attachment; filename="$fileName"');
        buffer.writeln('Content-Transfer-Encoding: base64');
        buffer.writeln();
        buffer.writeln(base64File);
        buffer.writeln();
      }
    }

    buffer.writeln('--$boundary--');

    final rawMime = buffer.toString();
    return base64Url.encode(utf8.encode(rawMime));
  }
}
