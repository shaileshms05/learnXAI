import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({Key? key}) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _fullNameController;
  late TextEditingController _skillsController;
  late TextEditingController _interestsController;
  String? _fieldOfStudy;
  int? _currentSemester;
  List<String> _selectedGoals = [];

  final List<String> _goals = [
    'Software Developer',
    'Data Scientist',
    'Machine Learning Engineer',
    'Product Manager',
    'UX/UI Designer',
    'DevOps Engineer',
    'Mobile Developer',
    'Full Stack Developer',
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final profile = authProvider.userProfile;

    _fullNameController = TextEditingController(text: profile?.fullName ?? '');
    _skillsController = TextEditingController(
      text: profile?.skills.join(', ') ?? '',
    );
    _interestsController = TextEditingController(
      text: profile?.interests.join(', ') ?? '',
    );
    _fieldOfStudy = profile?.fieldOfStudy;
    _currentSemester = profile?.currentSemester;
    _selectedGoals = List.from(profile?.careerGoals ?? []);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _skillsController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      
      if (user == null) return;

      final profile = UserProfile(
        uid: user.uid,
        email: user.email!,
        fullName: _fullNameController.text.trim(),
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

      final success = await authProvider.updateProfile(profile);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile updated successfully!'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(authProvider.error ?? 'Failed to update profile'),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _buildForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚙️ Edit Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Update your information',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            
            // Full Name
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Field of Study
            DropdownButtonFormField<String>(
              value: _fieldOfStudy,
              decoration: InputDecoration(
                labelText: 'Field of Study',
                prefixIcon: const Icon(Icons.school),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Computer Science',
                  child: Text('Computer Science'),
                ),
                DropdownMenuItem(
                  value: 'Information Technology',
                  child: Text('Information Technology'),
                ),
                DropdownMenuItem(
                  value: 'Engineering',
                  child: Text('Engineering'),
                ),
                DropdownMenuItem(
                  value: 'Business',
                  child: Text('Business'),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text('Other'),
                ),
              ],
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

            // Current Semester
            DropdownButtonFormField<int>(
              value: _currentSemester,
              decoration: InputDecoration(
                labelText: 'Current Semester',
                prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
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

            // Skills
            TextFormField(
              controller: _skillsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Skills (comma-separated)',
                hintText: 'e.g., Python, JavaScript, Data Analysis',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.code),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter at least one skill';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Interests
            TextFormField(
              controller: _interestsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Interests (comma-separated)',
                hintText: 'e.g., AI, Web Development, Mobile Apps',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.favorite),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter at least one interest';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Career Goals
            Text(
              'Career Goals',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: 12),
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
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryColor,
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Update Button
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return ElevatedButton.icon(
                  onPressed: authProvider.isLoading ? null : _updateProfile,
                  icon: authProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(authProvider.isLoading ? 'Updating...' : 'Update Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

