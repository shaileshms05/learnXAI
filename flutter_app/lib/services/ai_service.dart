import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AIService {
  // Backend URL configuration
  // For web (Chrome): use localhost
  // For phone: use your computer's local IP (find with: ifconfig | grep "inet ")
  
  // CHANGE THIS based on how you're running:
  static const String _localhost = 'http://localhost:8000/api/ai';
  static const String _phoneUrl = 'http://192.0.0.2:8000/api/ai'; // Your Mac's IP
  
  // Set to true when testing on phone, false for web
  static const bool _usePhoneUrl = false;  // Set to false for web/Chrome testing
  
  final String baseUrl = _usePhoneUrl ? _phoneUrl : _localhost;

  // Helper to add http package if needed
  Future<Map<String, dynamic>?> _makeRequest(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('AI Service Error: $e');
      rethrow;
    }
  }

  Future<LearningPath?> generateLearningPath(UserProfile profile) async {
    try {
      final data = await _makeRequest('/learning-path', {
        'interests': profile.interests,
        'skills': profile.skills,
        'careerGoal': profile.careerGoals.isNotEmpty ? profile.careerGoals.first : 'General Career',
        'educationLevel': profile.fieldOfStudy,
        'timeCommitment': '10 hours/week',
      });

      if (data != null) {
        // Parse backend response (totalDuration, phases, etc.)
        final List<String> milestonesList = [];
        
        // Extract milestones from phases
        if (data['phases'] != null && data['phases'] is List) {
          for (var phase in data['phases']) {
            final phaseTitle = phase['title'] ?? 'Phase';
            final phaseDuration = phase['duration'] ?? '';
            milestonesList.add('$phaseTitle ($phaseDuration)');
          }
        }
        
        // Parse Cerebras AI response
        return LearningPath(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: profile.uid,
          courses: [], // Will be populated from milestones
          resources: List<String>.from(data['nextSteps'] ?? data['recommendations'] ?? []),
          timeline: data['totalDuration'] ?? data['estimatedDuration'] ?? '6-8 months',
          milestones: milestonesList,
          createdAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('Error generating learning path: $e');
      rethrow;
    }
  }

  Future<List<Internship>> getInternshipRecommendations(
      UserProfile profile) async {
    try {
      final data = await _makeRequest('/internships', {
        'skills': profile.skills,
        'interests': profile.interests,
        'location': 'Remote',
        'experienceLevel': 'Beginner',
      });

      if (data != null && data['opportunities'] != null) {
        return (data['opportunities'] as List)
            .map((opportunity) => Internship.fromMap(opportunity))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting internship recommendations: $e');
      return [];
    }
  }

  /// Scrape real-time internship opportunities from job boards using MCP scraper
  Future<List<Internship>> scrapeInternships({
    required String query,
    String location = '',
    int maxResults = 20,
    List<String> sources = const [],
  }) async {
    try {
      // Use the scraping endpoint (different from AI recommendations)
      // Build URL directly from base URL
      final baseUrlStr = _usePhoneUrl ? _phoneUrl : _localhost;
      final scrapeUrl = baseUrlStr.replaceAll('/api/ai', '/api/internships/scrape');
      
      print('🔍 Scraping internships: $query');
      print('📍 Location: ${location.isEmpty ? "Any" : location}');
      print('📊 Max results: $maxResults');
      
      final response = await http.post(
        Uri.parse(scrapeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'location': location,
          'max_results': maxResults,
          if (sources.isNotEmpty) 'sources': sources,
        }),
      ).timeout(const Duration(minutes: 5)); // Increased timeout for scraping multiple sources

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data['opportunities'] != null) {
          final internships = (data['opportunities'] as List)
              .map((opportunity) => Internship.fromMap(opportunity))
              .toList();
          
          final hasFallback = data['has_fallback'] == true;
          if (hasFallback) {
            print('⚠️  Using fallback sample internships (scraping returned no results)');
          } else {
            print('✅ Scraped ${internships.length} internships from job boards');
          }
          return internships;
        }
      } else {
        print('❌ Scraping failed: ${response.statusCode} - ${response.body}');
      }
      
      return [];
    } catch (e) {
      print('❌ Error scraping internships: $e');
      return [];
    }
  }

  Future<String> chatWithAI(
      String message, UserProfile profile, List<ChatMessage> history) async {
    try {
      final data = await _makeRequest('/chat', {
        'message': message,
        'context': {
          'educationLevel': profile.fieldOfStudy,
          'careerGoal': profile.careerGoals.isNotEmpty ? profile.careerGoals.first : 'General Career',
          'skills': profile.skills,
          'interests': profile.interests,
        },
      });

      if (data != null && data['message'] != null) {
        return data['message'] as String;
      }
      return 'Sorry, I encountered an error. Please try again.';
    } catch (e) {
      print('Error in chat: $e');
      return 'Sorry, I encountered an error connecting to the AI service.';
    }
  }
}

