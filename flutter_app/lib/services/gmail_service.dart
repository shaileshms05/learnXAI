import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GmailService {
  final GoogleSignIn _googleSignIn;
  gmail.GmailApi? _gmailApi;

  GmailService(this._googleSignIn);

  /// Initialize Gmail API
  Future<bool> initialize() async {
    try {
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) return false;

      _gmailApi = gmail.GmailApi(authClient);
      return true;
    } catch (e) {
      print('❌ Error initializing Gmail API: $e');
      return false;
    }
  }

  /// Send an email
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
  }) async {
    if (_gmailApi == null) {
      print('❌ Gmail API not initialized');
      return false;
    }

    try {
      // Create email message
      final email = _createEmailMessage(
        to: to,
        subject: subject,
        body: body,
        cc: cc,
        bcc: bcc,
      );

      // Send email
      await _gmailApi!.users.messages.send(
        gmail.Message()..raw = email,
        'me',
      );

      print('✅ Email sent successfully to: $to');
      return true;
    } catch (e) {
      print('❌ Error sending email: $e');
      return false;
    }
  }

  /// Create RFC 2822 formatted email
  String _createEmailMessage({
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
  }) {
    final lines = <String>[
      'To: $to',
      if (cc != null) 'Cc: $cc',
      if (bcc != null) 'Bcc: $bcc',
      'Subject: $subject',
      'Content-Type: text/html; charset=utf-8',
      '',
      body,
    ];

    final email = lines.join('\r\n');
    
    // Base64 encode (URL-safe)
    final bytes = utf8.encode(email);
    final base64Email = base64Url.encode(bytes).replaceAll('=', '');
    
    return base64Email;
  }

  /// Send job application email
  Future<bool> sendJobApplicationEmail({
    required String to,
    required String jobTitle,
    required String company,
    required String emailBody,
    required String userName,
  }) async {
    final subject = 'Application for $jobTitle position at $company';
    
    final htmlBody = '''
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
        .signature { margin-top: 30px; padding-top: 20px; border-top: 2px solid #ddd; }
        .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #999; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2 style="margin: 0;">Application for $jobTitle</h2>
            <p style="margin: 5px 0 0 0; opacity: 0.9;">$company</p>
        </div>
        <div class="content">
            $emailBody
            
            <div class="signature">
                <p style="margin: 0;"><strong>Best regards,</strong></p>
                <p style="margin: 5px 0;">$userName</p>
            </div>
        </div>
        <div class="footer">
            <p>Sent via Student AI Platform</p>
        </div>
    </div>
</body>
</html>
''';

    return await sendEmail(
      to: to,
      subject: subject,
      body: htmlBody,
    );
  }

  /// Get user's email address
  Future<String?> getUserEmail() async {
    try {
      final profile = await _gmailApi?.users.getProfile('me');
      return profile?.emailAddress;
    } catch (e) {
      print('❌ Error getting user email: $e');
      return null;
    }
  }
}

