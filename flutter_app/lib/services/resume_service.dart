import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ResumeService {
  static const String _localhost = 'http://localhost:8000/api/resume';
  static const String _phoneUrl = 'http://192.0.0.2:8000/api/resume';
  
  static const bool _usePhoneUrl = false; // Set to true for phone testing

  final String baseUrl = _usePhoneUrl ? _phoneUrl : _localhost;

  Future<Map<String, dynamic>?> _makeRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 2)); // Longer timeout for AI processing

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Resume Service API Error for $endpoint: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Resume Service Network Error for $endpoint: $e');
      rethrow;
    }
  }

  /// Analyze a resume and get comprehensive feedback
  Future<ResumeAnalysis?> analyzeResume({
    required String resumeText,
    required Map<String, dynamic> resumeSummary,
  }) async {
    try {
      final data = await _makeRequest('/analyze', {
        'resume_text': resumeText,
        'resume_summary': resumeSummary,
      });

      if (data != null && data['success'] == true) {
        return ResumeAnalysis.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error analyzing resume: $e');
      rethrow;
    }
  }

  /// Tailor resume for a specific job
  Future<ResumeTailoring?> tailorResume({
    required Map<String, dynamic> resumeSummary,
    required String jobTitle,
    required String jobDescription,
    required String company,
  }) async {
    try {
      final data = await _makeRequest('/tailor', {
        'resume_summary': resumeSummary,
        'job_title': jobTitle,
        'job_description': jobDescription,
        'company': company,
      });

      if (data != null && data['success'] == true) {
        return ResumeTailoring.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error tailoring resume: $e');
      rethrow;
    }
  }

  /// Generate professional bullet points
  Future<BulletPointsResult?> generateBulletPoints({
    required String jobTitle,
    required List<String> responsibilities,
    List<String>? achievements,
  }) async {
    try {
      final data = await _makeRequest('/generate-bullets', {
        'job_title': jobTitle,
        'responsibilities': responsibilities,
        'achievements': achievements,
      });

      if (data != null && data['success'] == true) {
        return BulletPointsResult.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error generating bullet points: $e');
      rethrow;
    }
  }

  /// Check if Resume Optimizer is available
  Future<bool> checkStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['enabled'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking resume optimizer status: $e');
      return false;
    }
  }
}

