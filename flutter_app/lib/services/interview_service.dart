import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class InterviewService {
  // Backend URL configuration
  static const String _localhost = 'http://localhost:8000/api/interview';
  static const String _phoneUrl = 'http://192.0.0.2:8000/api/interview';
  
  // Set to true when testing on phone, false for web
  static const bool _usePhoneUrl = false;

  final String baseUrl = _usePhoneUrl ? _phoneUrl : _localhost;

  /// Start a new mock interview session
  Future<Map<String, dynamic>?> startInterview({
    String? resumePath,  // For mobile/file paths
    Uint8List? resumeBytes,  // For web uploads
    required String resumeType,
    required String userId,
    String interviewType = 'technical',
    String difficulty = 'medium',
  }) async {
    try {
      // Prepare request body
      final Map<String, dynamic> body = {
        'resume_type': resumeType,
        'user_id': userId,
        'interview_type': interviewType,
        'difficulty': difficulty,
      };
      
      // Handle web uploads (base64) vs mobile (file path)
      if (resumeBytes != null) {
        // Web: send base64 encoded file data
        body['resume_data'] = base64Encode(resumeBytes);
      } else if (resumePath != null) {
        // Mobile: send file path
        body['resume_path'] = resumePath;
      } else {
        throw Exception('Either resumePath or resumeBytes must be provided');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90)); // Long timeout for resume processing

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Interview Service API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Interview Service Network Error: $e');
      rethrow;
    }
  }

  /// Submit answer to current interview question
  Future<Map<String, dynamic>?> submitAnswer({
    required String sessionId,
    required String answer,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'answer': answer,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Submit Answer API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Submit Answer Network Error: $e');
      rethrow;
    }
  }

  /// Get interview session details
  Future<InterviewSession?> getSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/session/$sessionId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return InterviewSession.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Get Session Error: $e');
      rethrow;
    }
  }

  /// Get audio URL for a question
  String getAudioUrl(String sessionId, int questionIndex) {
    final baseAudioUrl = _usePhoneUrl 
        ? 'http://192.0.0.2:8000/api/interview'
        : 'http://localhost:8000/api/interview';
    return '$baseAudioUrl/audio/$sessionId/$questionIndex';
  }

  /// Check if interview system is available
  Future<bool> checkStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['available'] == true;
      }
      return false;
    } catch (e) {
      print('Status Check Error: $e');
      return false;
    }
  }
}

