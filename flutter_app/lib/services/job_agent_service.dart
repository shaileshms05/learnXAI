import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class JobAgentService {
  static const String _localhost = 'http://localhost:8000/api/jobs';
  static const String _phoneUrl = 'http://192.0.0.2:8000/api/jobs';
  
  static const bool _usePhoneUrl = false; // Set to true for phone testing

  final String baseUrl = _usePhoneUrl ? _phoneUrl : _localhost;

  Future<Map<String, dynamic>?> _makeRequest(String endpoint, Map<String, dynamic> body) async {
    try {
      print('📤 Making request to: $baseUrl$endpoint');
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ Request successful');
        return decoded;
      } else {
        print('❌ Job Agent API Error for $endpoint: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Job Agent Service Error for $endpoint: $e');
      if (e.toString().contains('Failed host lookup') || e.toString().contains('Connection refused')) {
        throw Exception('Cannot connect to backend server. Please ensure the backend is running on http://localhost:8000');
      }
      rethrow;
    }
  }

  Future<JobMatchScore?> analyzeJobMatch({
    required Map<String, dynamic> userProfile,
    required String jobTitle,
    required String company,
    required String jobDescription,
  }) async {
    try {
      final data = await _makeRequest('/analyze-match', {
        'user_profile': userProfile,
        'job_title': jobTitle,
        'company': company,
        'job_description': jobDescription,
      });

      if (data != null && data['success'] == true) {
        return JobMatchScore.fromMap(data['match_score']);
      }
      return null;
    } catch (e) {
      print('Error analyzing job match: $e');
      rethrow;
    }
  }

  Future<Map<String, String>?> generateApplicationEmail({
    required Map<String, dynamic> userProfile,
    required String jobTitle,
    required String company,
    required String jobDescription,
    String tone = 'professional',
    bool includeProject = true,
    String? customNotes,
  }) async {
    try {
      print('📧 Generating application email...');
      print('   Job Title: $jobTitle');
      print('   Company: $company');
      print('   Tone: $tone');
      
      final data = await _makeRequest('/generate-email', {
        'user_profile': userProfile,
        'job_title': jobTitle,
        'company': company,
        'job_description': jobDescription,
        'tone': tone,
        'include_project': includeProject,
        if (customNotes != null) 'custom_notes': customNotes,
      });

      if (data != null) {
        if (data['success'] == true && data['email'] != null) {
          final email = data['email'];
          final subject = email['subject'] ?? '';
          final body = email['body'] ?? '';
          
          if (subject.isNotEmpty && body.isNotEmpty) {
            print('✅ Email generated successfully');
            return {
              'subject': subject,
              'body': body,
            };
          } else {
            print('⚠️  Email generated but missing subject or body');
            print('   Subject: ${subject.isEmpty ? "MISSING" : "OK"}');
            print('   Body: ${body.isEmpty ? "MISSING" : "OK"}');
          }
        } else {
          print('⚠️  Response missing success flag or email data');
          print('   Data keys: ${data.keys.toList()}');
        }
      } else {
        print('❌ No data returned from API');
      }
      return null;
    } catch (e) {
      print('❌ Error generating email: $e');
      rethrow;
    }
  }

  Future<Map<String, String>?> improveEmail({
    required String originalEmail,
    required String feedback,
  }) async {
    try {
      final data = await _makeRequest('/improve-email', {
        'original_email': originalEmail,
        'feedback': feedback,
      });

      if (data != null && data['success'] == true) {
        final email = data['improved_email'];
        return {
          'subject': email['subject'] ?? '',
          'body': email['body'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error improving email: $e');
      rethrow;
    }
  }

  Future<Map<String, String>?> generateFollowUpEmail({
    required String company,
    required String jobTitle,
    required int daysSinceApplication,
    required String originalEmail,
  }) async {
    try {
      final data = await _makeRequest('/generate-follow-up', {
        'company': company,
        'job_title': jobTitle,
        'days_since_application': daysSinceApplication,
        'original_email': originalEmail,
      });

      if (data != null && data['success'] == true) {
        final email = data['follow_up_email'];
        return {
          'subject': email['subject'] ?? '',
          'body': email['body'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error generating follow-up: $e');
      rethrow;
    }
  }

  Future<bool> checkStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['enabled'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking job agent status: $e');
      return false;
    }
  }
}

