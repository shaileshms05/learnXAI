import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class ResumeStorageService {
  static const String _resumeBytesKey = 'latest_resume_bytes';
  static const String _resumeNameKey = 'latest_resume_name';
  static const String _resumeTypeKey = 'latest_resume_type';
  static const String _resumeSavedAtKey = 'latest_resume_saved_at';

  /// Save resume data to local storage
  Future<bool> saveResume({
    required Uint8List resumeBytes,
    required String resumeName,
    required String resumeType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert bytes to base64 string for storage
      final base64String = base64Encode(resumeBytes);
      
      await prefs.setString(_resumeBytesKey, base64String);
      await prefs.setString(_resumeNameKey, resumeName);
      await prefs.setString(_resumeTypeKey, resumeType);
      await prefs.setString(_resumeSavedAtKey, DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      print('Error saving resume: $e');
      return false;
    }
  }

  /// Get the latest saved resume
  Future<Map<String, dynamic>?> getLatestResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final base64String = prefs.getString(_resumeBytesKey);
      final resumeName = prefs.getString(_resumeNameKey);
      final resumeType = prefs.getString(_resumeTypeKey);
      final savedAt = prefs.getString(_resumeSavedAtKey);
      
      if (base64String == null || resumeName == null || resumeType == null) {
        return null;
      }
      
      // Convert base64 string back to bytes
      final resumeBytes = base64Decode(base64String);
      
      return {
        'bytes': resumeBytes,
        'name': resumeName,
        'type': resumeType,
        'savedAt': savedAt,
      };
    } catch (e) {
      print('Error loading resume: $e');
      return null;
    }
  }

  /// Check if a resume is saved
  Future<bool> hasSavedResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_resumeBytesKey);
    } catch (e) {
      return false;
    }
  }

  /// Clear saved resume
  Future<bool> clearSavedResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_resumeBytesKey);
      await prefs.remove(_resumeNameKey);
      await prefs.remove(_resumeTypeKey);
      await prefs.remove(_resumeSavedAtKey);
      return true;
    } catch (e) {
      print('Error clearing resume: $e');
      return false;
    }
  }
}

