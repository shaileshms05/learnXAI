import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth Methods
  Future<User?> signUp(String email, String password, String fullName) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create user profile
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'fullName': fullName,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Firestore Methods
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(profile.uid).set(
            profile.toMap(),
            SetOptions(merge: true), // Use set with merge to create if not exists
          );
    } catch (e) {
      rethrow;
    }
  }

  // Create or update user profile (for profile setup screen)
  Future<void> createUserProfile(UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(profile.uid).set(
            profile.toMap(),
            SetOptions(merge: false), // Overwrite completely
          );
    } catch (e) {
      rethrow;
    }
  }

  // Check if user has completed profile setup
  Future<bool> hasCompletedProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      // Check if required fields are present
      return data.containsKey('fieldOfStudy') && 
             data.containsKey('skills') &&
             data.containsKey('interests') &&
             data['skills'] != null &&
             data['interests'] != null &&
             (data['skills'] as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> saveLearningPath(LearningPath learningPath) async {
    try {
      await _firestore
          .collection('learningPaths')
          .doc(learningPath.id)
          .set(learningPath.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<LearningPath?> getLearningPath(String userId) async {
    try {
      // Try with orderBy first (requires index)
      try {
      final querySnapshot = await _firestore
          .collection('learningPaths')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return LearningPath.fromMap(querySnapshot.docs.first.data());
        }
      } catch (e) {
        // If index error, fallback to query without orderBy
        if (e.toString().contains('index')) {
          print('⚠️  Firestore index not found. Using fallback query. Create index at: ${e.toString()}');
          final querySnapshot = await _firestore
              .collection('learningPaths')
              .where('userId', isEqualTo: userId)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            // Sort manually by createdAt
            final docs = querySnapshot.docs.toList();
            docs.sort((a, b) {
              final aDate = _parseDate(a.data()['createdAt']);
              final bDate = _parseDate(b.data()['createdAt']);
              return bDate.compareTo(aDate); // descending
            });
            return LearningPath.fromMap(docs.first.data());
          }
        } else {
          rethrow;
        }
      }
      return null;
    } catch (e) {
      print('Error loading learning path: $e');
      rethrow;
    }
  }
  
  // Helper to parse date from various formats
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    } else if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue != null) {
      try {
        return (dateValue as dynamic).toDate();
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Future<void> saveChatHistory(
      String userId, List<ChatMessage> messages) async {
    try {
      await _firestore.collection('chatHistory').doc(userId).set({
        'userId': userId,
        'messages': messages.map((m) => m.toMap()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ChatMessage>> getChatHistory(String userId) async {
    try {
      final doc = await _firestore.collection('chatHistory').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final messagesList = data['messages'] as List;
        return messagesList
            .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}

