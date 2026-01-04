import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class BookService {
  // Backend URL configuration
  static const String _localhost = 'http://localhost:8000/api/books';
  static const String _phoneUrl = 'http://192.0.0.2:8000/api/books';
  
  // Set to true when testing on phone, false for web
  static const bool _usePhoneUrl = false;

  final String baseUrl = _usePhoneUrl ? _phoneUrl : _localhost;

  /// Upload a book (PDF/EPUB/DOCX)
  Future<BookMetadata?> uploadBook({
    required String filePath,
    required String fileType,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_path': filePath,
          'file_type': fileType,
          'user_id': userId,
        }),
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return BookMetadata.fromMap(data);
        }
      }
      return null;
    } catch (e) {
      print('Error uploading book: $e');
      rethrow;
    }
  }

  /// Start teaching a chapter
  Future<TeachingContent?> startTeaching({
    required String bookId,
    required int chapterNum,
    String style = 'simple',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teach'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'book_id': bookId,
          'chapter_num': chapterNum,
          'style': style,
        }),
      ).timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return TeachingContent.fromMap(data);
        }
      }
      return null;
    } catch (e) {
      print('Error starting teaching: $e');
      rethrow;
    }
  }

  /// Check understanding of a concept
  Future<UnderstandingEvaluation?> checkUnderstanding({
    required String bookId,
    required String conceptId,
    required String question,
    required String studentAnswer,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check-understanding'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'book_id': bookId,
          'concept_id': conceptId,
          'question': question,
          'student_answer': studentAnswer,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return UnderstandingEvaluation.fromMap(data);
        }
      }
      return null;
    } catch (e) {
      print('Error checking understanding: $e');
      rethrow;
    }
  }

  /// Generate quiz for a chapter
  Future<List<QuizQuestion>> generateQuiz({
    required String bookId,
    required int chapterNum,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'book_id': bookId,
          'chapter_num': chapterNum,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['questions'] as List)
              .map((q) => QuizQuestion.fromMap(q))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error generating quiz: $e');
      return [];
    }
  }

  /// Get mastery dashboard
  Future<MasteryDashboard?> getMasteryDashboard({
    required String userId,
    required String bookId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mastery-dashboard'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'book_id': bookId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return MasteryDashboard.fromMap(data);
        }
      }
      return null;
    } catch (e) {
      print('Error getting mastery dashboard: $e');
      rethrow;
    }
  }

  /// Chat with the book
  Future<Map<String, dynamic>?> chatWithBook({
    required String bookId,
    required String question,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'book_id': bookId,
          'question': question,
        }),
      ).timeout(const Duration(minutes: 1));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'answer': data['answer'],
            'sources': data['sources'],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error chatting with book: $e');
      rethrow;
    }
  }

  /// Check if book learning system is available
  Future<bool> checkStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking status: $e');
      return false;
    }
  }
}

