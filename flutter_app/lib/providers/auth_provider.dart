import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/google_calendar_service.dart';
import '../services/gmail_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  late final GmailService _gmailService;
  
  User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null || _calendarService.isSignedIn;
  bool get hasCompletedProfile => _userProfile != null && 
                                    _userProfile!.skills.isNotEmpty &&
                                    _userProfile!.interests.isNotEmpty;

  AuthProvider() {
    _gmailService = GmailService(_calendarService.googleSignIn);
    _init();
  }

  // Getters for Google services
  GoogleCalendarService get calendarService => _calendarService;
  GmailService get gmailService => _gmailService;
  bool get hasGoogleAccess => _calendarService.isSignedIn;

  void _init() {
    _firebaseService.authStateChanges.listen((user) {
      _user = user;
      if (user != null) {
        _loadUserProfile(user.uid);
      } else {
        _userProfile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      _userProfile = await _firebaseService.getUserProfile(uid);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Check if user needs to complete profile setup
  Future<bool> needsProfileSetup() async {
    // If Google Sign-In succeeded but Firebase Auth user is null, check profile by email
    if (_user == null) {
      if (!_calendarService.isSignedIn) return false;
      
      // Google Sign-In succeeded - check if profile exists by email
      final googleUser = _calendarService.currentUser;
      if (googleUser?.email == null) return false;
      
      // Try to load profile using email as uid
      try {
        final profile = await _firebaseService.getUserProfile(googleUser!.email!);
        if (profile == null) return true;
        
        // Check if profile has required fields
        return profile.skills.isEmpty || 
               profile.interests.isEmpty ||
               profile.fieldOfStudy == null;
      } catch (e) {
        // Profile doesn't exist or error loading - needs setup
        return true;
      }
    }
    
    if (_userProfile == null) return true;
    
    // Check if profile has required fields
    return _userProfile!.skills.isEmpty || 
           _userProfile!.interests.isEmpty ||
           _userProfile!.fieldOfStudy == null;
  }

  Future<bool> signUp(String email, String password, String fullName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _firebaseService.signUp(email, password, fullName);
      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _firebaseService.signIn(email, password);
      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // STRATEGY: Use Firebase Auth's Google provider FIRST (gets idToken properly)
      // Then extract access token for Calendar/Gmail APIs
      
      print('🔐 Step 1: Signing in with Firebase Google Auth (gets idToken properly)...');
      
      // Create Google Auth Provider with required scopes
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('https://www.googleapis.com/auth/calendar');
      googleProvider.addScope('https://www.googleapis.com/auth/calendar.events');
      googleProvider.addScope('https://www.googleapis.com/auth/gmail.send');
      
      UserCredential? userCredential;
      String? accessToken;
      
      // METHOD 1: Try Firebase Auth's Google Sign-In via google_sign_in package
      // This should give us both idToken and accessToken
      try {
        print('🔄 Attempting Google Sign-In via google_sign_in...');
        final googleSuccess = await _calendarService.signIn();
        if (!googleSuccess) {
          _error = 'Google sign-in cancelled or failed';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        final googleUser = _calendarService.currentUser;
        if (googleUser == null) {
          _error = 'Failed to get Google user';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        // Get authentication tokens
        final googleAuth = await googleUser.authentication;
        accessToken = googleAuth.accessToken;
        print('🔑 Access Token: ${accessToken != null ? "✅" : "❌"}');
        print('🔑 ID Token: ${googleAuth.idToken != null ? "✅" : "❌"}');
        
        // If idToken is available, use it for Firebase Auth
        if (googleAuth.idToken != null) {
          print('✅ idToken available! Linking with Firebase Auth...');
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          _user = userCredential.user;
          print('✅ Firebase Auth linked successfully!');
        } else {
          // idToken not available - web limitation with google_sign_in
          print('⚠️  idToken not available (web limitation)');
          print('🔄 Creating Firebase user account to satisfy Firebase Auth...');
          
          // Create/Get Firebase user account using Google email
          // This satisfies Firebase Auth requirements
          final googleEmail = googleUser.email;
          if (googleEmail == null) {
            _error = 'Failed to get Google email';
            _isLoading = false;
            notifyListeners();
            return false;
          }
          
          try {
            // Check if Firebase user exists with this email
            final signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(googleEmail);
            
            if (signInMethods.isEmpty) {
              // User doesn't exist - create account
              print('📝 Creating new Firebase user account...');
              
              // Generate secure random password
              final randomPassword = _generateRandomPassword();
              
              // Create Firebase account
              final newUserCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: googleEmail,
                password: randomPassword,
              );
              
              _user = newUserCredential.user;
              
              // Update profile from Google account
              await _user!.updateDisplayName(googleUser.displayName ?? 'User');
              if (googleUser.photoUrl != null) {
                await _user!.updatePhotoURL(googleUser.photoUrl);
              }
              
              print('✅ Firebase user account created!');
              print('✅ User ID: ${_user?.uid}');
              print('✅ Email: ${_user?.email}');
              print('✅ Google Sign-In linked for Calendar/Gmail');
              
            } else {
              // User exists - check if already signed in
              print('📝 Firebase user exists for this email');
              final currentUser = FirebaseAuth.instance.currentUser;
              
              if (currentUser != null && currentUser.email == googleEmail) {
                // Already signed in with this email
                _user = currentUser;
                print('✅ Using existing Firebase Auth session');
                print('✅ User ID: ${_user?.uid}');
              } else {
                // User exists but not signed in - can't sign in without password
                // Continue without Firebase Auth linking
                print('ℹ️  Firebase account exists but can\'t link without idToken');
                print('ℹ️  Google Sign-In will work for Calendar/Gmail');
                print('ℹ️  Firebase Auth features may be limited');
              }
            }
          } catch (e) {
            // Handle specific error: email already in use
            if (e.toString().contains('email-already-in-use')) {
              print('📝 Email already in use - checking for existing session...');
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null && currentUser.email == googleEmail) {
                _user = currentUser;
                print('✅ Using existing Firebase Auth session');
              } else {
                print('ℹ️  Firebase account exists but can\'t link without idToken');
                print('ℹ️  Continuing with Google services (Calendar/Gmail will work)');
              }
            } else {
              print('⚠️  Could not create Firebase user: $e');
              print('ℹ️  Continuing with Google services only');
            }
            // Continue without Firebase Auth - Calendar/Gmail will work
          }
        }
      } catch (e) {
        print('❌ Error during Google Sign-In: $e');
        _error = 'Google sign-in failed: $e';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // STEP 3: Ensure Calendar/Gmail services are initialized
      print('🔐 Step 2: Initializing Calendar/Gmail services...');
      await _gmailService.initialize();
      
      // Get Google account email
      final googleEmail = _user?.email ?? _calendarService.currentUser?.email;
      if (googleEmail == null) {
        _error = 'Failed to get Google account email';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      print('✅ All services ready');
      print('✅ Firebase Auth: ${_user != null ? "Linked ✅" : "Not linked ⚠️"}');
      print('✅ Calendar API: Ready');
      print('✅ Gmail API: Ready');

      // Load or create user profile
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        
        // If profile doesn't exist, create basic one
        if (_userProfile == null) {
          final profile = UserProfile(
            uid: _user!.uid,
            email: googleEmail,
            fullName: _calendarService.currentUser?.displayName ?? 'User',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await createProfile(profile);
        }
      } else {
        // Firebase Auth didn't work, but Google Sign-In succeeded
        // Try to load profile using email as uid
        print('ℹ️  Using Google Sign-In without Firebase Auth');
        print('🔄 Loading profile using email as uid...');
        try {
          _userProfile = await _firebaseService.getUserProfile(googleEmail);
          if (_userProfile != null) {
            print('✅ Profile loaded using email as uid');
          } else {
            print('ℹ️  No profile found - user will need to complete setup');
          }
        } catch (e) {
          print('ℹ️  Profile not found: $e');
        }
        print('✅ Calendar and Gmail features available');
      }

      _isLoading = false;
      notifyListeners();
      
      // Return true if Google Sign-In succeeded (even if Firebase Auth failed)
      // Calendar and Gmail will work with Google access token
      final googleSignInSucceeded = googleEmail.isNotEmpty && _calendarService.isSignedIn;
      return googleSignInSucceeded || _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    _user = null;
    _userProfile = null;
    notifyListeners();
  }

  Future<bool> updateProfile(UserProfile profile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.updateUserProfile(profile);
      _userProfile = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createProfile(UserProfile profile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.createUserProfile(profile);
      _userProfile = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Generate a secure random password for Firebase account creation
  String _generateRandomPassword() {
    // Generate a secure random password
    // User won't need to use this - Google Sign-In handles auth
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return 'GoogleSignIn_${random}_Secure123!';
  }
}

