import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../models/models.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skillsController = TextEditingController();
  final _interestsController = TextEditingController();
  
  String? _fieldOfStudy;
  int? _currentSemester;
  final List<String> _selectedGoals = [];

  final List<String> _fields = [
    'Computer Science',
    'Engineering',
    'Business',
    'Medicine',
    'Arts',
    'Science',
    'Other',
  ];

  final List<String> _goals = [
    'Software Developer',
    'Data Scientist',
    'Product Manager',
    'Entrepreneur',
    'Researcher',
    'Consultant',
  ];

  @override
  void dispose() {
    _skillsController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<app_auth.AuthProvider>();
      final user = authProvider.user;
      
      // Handle case where Google Sign-In succeeded but Firebase Auth user is null
      String? uid;
      String? email;
      
      if (user != null) {
        uid = user.uid;
        email = user.email;
      } else {
        // Google Sign-In succeeded but Firebase Auth user is null
        // Get Google user email as fallback
        final googleUser = authProvider.calendarService.currentUser;
        if (googleUser == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No user account found. Please sign in again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        email = googleUser.email;
        // Try to create a Firebase user account
        // If email already exists, use email as uid for profile (Firestore allows any string as doc ID)
        try {
          // Generate a secure random password
          final randomPassword = 'GoogleSignIn_${DateTime.now().millisecondsSinceEpoch}_Secure123!';
          
          // Try to create Firebase account
          final newUserCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email!,
            password: randomPassword,
          );
          uid = newUserCredential.user?.uid;
          print('✅ Firebase user created: $uid');
        } catch (e) {
          // Email already exists - can't create account without password
          // Use email as uid for Firestore profile (Firestore allows any string as document ID)
          print('⚠️  Email already exists in Firebase: $e');
          print('ℹ️  Using email as profile uid');
          uid = email; // Use email directly as uid for Firestore document ID
        }
      }

      if (uid == null || email == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Could not identify user account.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final profile = UserProfile(
        uid: uid,
        email: email,
        fullName: authProvider.userProfile?.fullName ?? authProvider.calendarService.currentUser?.displayName ?? 'User',
        fieldOfStudy: _fieldOfStudy,
        currentSemester: _currentSemester,
        skills: _skillsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        interests: _interestsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        careerGoals: _selectedGoals,
        createdAt: authProvider.userProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await authProvider.createProfile(profile);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${authProvider.error ?? "Failed to save profile"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tell us about yourself',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us personalize your experience',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 32),
              DropdownButtonFormField<String>(
                value: _fieldOfStudy,
                decoration: const InputDecoration(
                  labelText: 'Field of Study',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
                ),
                items: _fields.map((field) {
                  return DropdownMenuItem(
                    value: field,
                    child: Text(field),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _fieldOfStudy = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your field of study';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _currentSemester,
                decoration: const InputDecoration(
                  labelText: 'Current Semester',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: List.generate(8, (index) => index + 1).map((sem) {
                  return DropdownMenuItem(
                    value: sem,
                    child: Text('Semester $sem'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _currentSemester = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select your current semester';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _skillsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Skills (comma-separated)',
                  hintText: 'e.g., Python, JavaScript, Data Analysis',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.code),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter at least one skill';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interestsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Interests (comma-separated)',
                  hintText: 'e.g., AI, Web Development, Mobile Apps',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.favorite),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter at least one interest';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Career Goals',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _goals.map((goal) {
                  final isSelected = _selectedGoals.contains(goal);
                  return FilterChip(
                    label: Text(goal),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedGoals.add(goal);
                        } else {
                          _selectedGoals.remove(goal);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Consumer<app_auth.AuthProvider>(
                builder: (context, authProvider, child) {
                  return ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save & Continue'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

