# 🚀 Flutter Student AI Platform

A complete cross-platform mobile application built with Flutter and Dart, featuring AI-powered learning paths, internship recommendations, and career guidance.

## ✨ Features

- 🔐 **Firebase Authentication** - Secure email/password sign up and sign in
- 👤 **Profile Management** - Complete profile with skills, interests, and goals
- 🎯 **AI Learning Path Generator** - Personalized learning roadmaps
- 💼 **AI Internship Recommendations** - Matching opportunities based on your profile
- 💬 **Career Guidance Chatbot** - AI-powered career advice
- 📱 **Cross-Platform** - Works on both iOS and Android

## 🛠️ Tech Stack

- **Framework**: Flutter 3.x
- **Language**: Dart 3.x
- **Backend**: Firebase (Auth, Firestore, Functions)
- **AI**: Vertex AI (Gemini Pro)
- **State Management**: Provider
- **Architecture**: MVVM Pattern

## 📁 Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── firebase_options.dart     # Firebase configuration
│   ├── models/
│   │   └── models.dart          # Data models
│   ├── services/
│   │   ├── firebase_service.dart # Firebase operations
│   │   └── ai_service.dart       # AI API calls
│   ├── providers/
│   │   └── auth_provider.dart    # Auth state management
│   └── screens/
│       ├── splash_screen.dart
│       ├── auth/
│       │   ├── signin_screen.dart
│       │   └── signup_screen.dart
│       ├── profile/
│       │   └── profile_setup_screen.dart
│       └── dashboard/
│           └── dashboard_screen.dart
└── pubspec.yaml                  # Dependencies
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- Firebase account
- Android Studio / VS Code
- Xcode (for iOS development on macOS)

### Installation

1. **Clone the repository**
   ```bash
   cd /Users/shailesh/gdg-hackathon/flutter_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   
   Run the FlutterFire CLI:
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your project
   flutterfire configure
   ```
   
   This will:
   - Create/update `lib/firebase_options.dart`
   - Configure iOS, Android, and Web platforms
   - Set up your Firebase project

4. **Update API endpoint**
   
   Edit `lib/services/ai_service.dart` and replace:
   ```dart
   final String baseUrl = 'https://your-app.com/api/ai';
   ```
   With your actual backend URL.

### Running the App

#### iOS (macOS only)
```bash
flutter run -d ios
```

#### Android
```bash
flutter run -d android
```

#### Web
```bash
flutter run -d chrome
```

### Build for Production

#### Android APK
```bash
flutter build apk --release
```
APK location: `build/app/outputs/flutter-apk/app-release.apk`

#### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```
Then open Xcode to archive and upload to App Store.

## 🔥 Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project or use existing: `student-ai-platform-2882c`
3. Add iOS and Android apps

### 2. Enable Services

In Firebase Console:

- **Authentication** → Sign-in method → Enable Email/Password
- **Firestore Database** → Create database (Start in production mode)
- **Cloud Functions** → Enable (for AI backend)

### 3. Firestore Collections

The app automatically creates these collections:

- `users/` - User profiles
- `learningPaths/` - Generated learning paths
- `chatHistory/` - Career chat messages

### 4. Security Rules

Apply these Firestore rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /learningPaths/{pathId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    match /chatHistory/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 💡 Usage

### 1. Sign Up
- Open app
- Click "Sign Up"
- Enter email, password, and full name
- Create account

### 2. Complete Profile
- Select field of study
- Choose current semester
- Add skills (comma-separated)
- Add interests
- Select career goals
- Save profile

### 3. Dashboard Features

#### AI Learning Path
- Click "Generate" to create personalized learning path
- View recommended courses, timeline, and milestones
- Based on your profile and goals

#### Internship Recommendations
- Click "Get Recommendations"
- View AI-matched internship opportunities
- See requirements, location, and duration

#### Career Guidance Chat
- Click "Start Chat"
- Ask career-related questions
- Get personalized AI advice
- Chat history is saved

## 📱 Screenshots

### Authentication Flow
- Splash Screen → Sign In → Sign Up → Profile Setup

### Main Features
- Dashboard with 3 AI cards
- Learning Path modal with courses
- Internships list with details
- Career chat interface

## 🎨 UI/UX Features

- **Material 3 Design** - Modern, beautiful UI
- **Dark Mode** - Automatic system theme detection
- **Responsive** - Works on all screen sizes
- **Smooth Animations** - Native feel
- **Loading States** - Clear feedback for user actions
- **Error Handling** - Proper error messages

## 🔧 Customization

### Change Colors

Edit `lib/main.dart`:

```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: const Color(0xFF6366F1), // Change this
  brightness: Brightness.light,
),
```

### Add More Fields

1. Update models in `lib/models/models.dart`
2. Add fields to Firestore
3. Update UI in respective screens

## 🐛 Troubleshooting

### Firebase Not Initialized
```bash
# Run FlutterFire configuration
flutterfire configure
```

### Dependencies Issues
```bash
flutter clean
flutter pub get
```

### iOS Build Fails
```bash
cd ios
pod install
cd ..
flutter run
```

### Android Gradle Issues
```bash
cd android
./gradlew clean
cd ..
flutter run
```

## 📦 Dependencies

### Main Dependencies:
- `firebase_core` - Firebase initialization
- `firebase_auth` - Authentication
- `cloud_firestore` - Database
- `provider` - State management
- `http` / `dio` - API calls
- `google_fonts` - Typography

### Dev Dependencies:
- `flutter_test` - Testing
- `flutter_lints` - Code analysis

## 🚢 Deployment

### Android (Google Play)

1. Update `android/app/build.gradle`:
   - Increase `versionCode` and `versionName`
   - Add signing config

2. Create keystore:
   ```bash
   keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
   ```

3. Build:
   ```bash
   flutter build appbundle --release
   ```

4. Upload to Play Console

### iOS (App Store)

1. Open Xcode
2. Update version and build number
3. Archive → Distribute App
4. Upload to App Store Connect

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repo
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## 📄 License

MIT License - feel free to use for your projects!

## 👥 Support

For issues or questions:
- Check documentation
- Review error logs
- Verify Firebase configuration
- Ensure dependencies are up to date

## 🎉 What's Next?

Potential enhancements:
- Push notifications
- Offline mode
- Social features
- Resume builder
- Interview prep
- Progress tracking

---

**Built with ❤️ using Flutter and Firebase**

*Cross-platform • AI-Powered • Production-Ready*

