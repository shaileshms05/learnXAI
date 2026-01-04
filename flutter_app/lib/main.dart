import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'models/models.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/signin_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/profile/profile_edit_screen.dart';
import 'screens/dashboard/dashboard_screen_new.dart' as new_dash;
import 'screens/books/book_library_screen.dart';
import 'screens/interview/interview_setup_screen.dart';
import 'screens/jobs/job_application_screen.dart';
import 'screens/resume/resume_analyzer_screen.dart';
import 'screens/resume/bullet_generator_screen.dart';
import 'screens/learning_path/learning_path_detail_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Student AI Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/learning-path/detail') {
            final learningPath = settings.arguments as LearningPath;
            return MaterialPageRoute(
              builder: (context) => LearningPathDetailScreen(learningPath: learningPath),
            );
          }
          return null;
        },
        routes: {
          '/signin': (context) => const SignInScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/profile-setup': (context) => const ProfileSetupScreen(),
          '/profile/edit': (context) => const ProfileEditScreen(),
          '/dashboard': (context) => const new_dash.DashboardScreen(),
          '/books': (context) => const BookLibraryScreen(),
          '/interview': (context) => const InterviewSetupScreen(),
          '/jobs': (context) => const JobApplicationScreen(),
          '/resume/analyzer': (context) => const ResumeAnalyzerScreen(),
          '/resume/bullet-generator': (context) => const BulletGeneratorScreen(),
        },
      ),
    );
  }
}

