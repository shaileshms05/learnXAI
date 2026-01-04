import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AIService _aiService = AIService();
  final FirebaseService _firebaseService = FirebaseService();
  
  LearningPath? _learningPath;
  List<Internship> _internships = [];
  bool _isLoadingPath = false;
  bool _isLoadingInternships = false;

  @override
  void initState() {
    super.initState();
    _loadLearningPath();
  }

  Future<void> _loadLearningPath() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      final path = await _firebaseService.getLearningPath(authProvider.user!.uid);
      setState(() {
        _learningPath = path;
      });
    }
  }

  Future<void> _generateLearningPath() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userProfile == null) return;

    setState(() {
      _isLoadingPath = true;
    });

    try {
      final path = await _aiService.generateLearningPath(authProvider.userProfile!);
      if (path != null) {
        await _firebaseService.saveLearningPath(path);
        setState(() {
          _learningPath = path;
          _isLoadingPath = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Learning path generated!')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingPath = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _getInternships() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userProfile == null) return;

    setState(() {
      _isLoadingInternships = true;
    });

    try {
      final internships = await _aiService.getInternshipRecommendations(
        authProvider.userProfile!,
      );
      setState(() {
        _internships = internships;
        _isLoadingInternships = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingInternships = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showLearningPath() {
    if (_learningPath == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Learning Path',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Timeline: ${_learningPath!.timeline}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'Recommended Courses',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ..._learningPath!.courses.map((course) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(course.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.description),
                          const SizedBox(height: 4),
                          Text(
                            'Duration: ${course.duration} | Level: ${course.level}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              Text(
                'Milestones',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ..._learningPath!.milestones.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          child: Text('${entry.key + 1}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.value)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showInternships() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Internship Opportunities',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _internships.length,
                  itemBuilder: (context, index) {
                    final internship = _internships[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              internship.role,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              internship.company,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(internship.description),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(internship.location),
                                  avatar: const Icon(Icons.location_on, size: 16),
                                ),
                                Chip(
                                  label: Text(internship.duration),
                                  avatar: const Icon(Icons.access_time, size: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Requirements:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...internship.requirements.map(
                              (req) => Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• '),
                                    Expanded(child: Text(req)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CareerChatScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/signin');
              }
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final profile = authProvider.userProfile;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${profile.fullName}!',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${profile.fieldOfStudy} • Semester ${profile.currentSemester}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Learning Path Card
                _buildFeatureCard(
                  context,
                  icon: Icons.school,
                  title: 'AI Learning Path',
                  description: _learningPath != null
                      ? 'View your personalized learning path'
                      : 'Generate a personalized learning path',
                  buttonText: _learningPath != null ? 'View Path' : 'Generate',
                  isLoading: _isLoadingPath,
                  onPressed: _learningPath != null
                      ? _showLearningPath
                      : _generateLearningPath,
                ),
                const SizedBox(height: 16),
                // Internships Card
                _buildFeatureCard(
                  context,
                  icon: Icons.work,
                  title: 'Internship Opportunities',
                  description: _internships.isNotEmpty
                      ? 'View ${_internships.length} recommended internships'
                      : 'Get AI-powered internship recommendations',
                  buttonText:
                      _internships.isNotEmpty ? 'View' : 'Get Recommendations',
                  isLoading: _isLoadingInternships,
                  onPressed:
                      _internships.isNotEmpty ? _showInternships : _getInternships,
                ),
                const SizedBox(height: 16),
                // Career Chat Card
                _buildFeatureCard(
                  context,
                  icon: Icons.chat,
                  title: 'Career Guidance Chat',
                  description: 'Chat with AI for career advice and guidance',
                  buttonText: 'Start Chat',
                  isLoading: false,
                  onPressed: _showChatbot,
                ),
                const SizedBox(height: 16),
                // Book Learning Card (NEW!)
                _buildFeatureCard(
                  context,
                  icon: Icons.menu_book,
                  title: '📚 Learn from Books',
                  description: 'Upload & learn from any book with AI teaching',
                  buttonText: 'My Books',
                  isLoading: false,
                  onPressed: () {
                    Navigator.pushNamed(context, '/books');
                  },
                ),
                const SizedBox(height: 16),
                // Mock Interview Card (NEW!)
                _buildFeatureCard(
                  context,
                  icon: Icons.mic,
                  title: '🎤 Mock Interview',
                  description: 'Practice interviews with AI based on your resume',
                  buttonText: 'Start Interview',
                  isLoading: false,
                  onPressed: () {
                    Navigator.pushNamed(context, '/interview');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Career Chat Screen
class CareerChatScreen extends StatefulWidget {
  const CareerChatScreen({super.key});

  @override
  State<CareerChatScreen> createState() => _CareerChatScreenState();
}

class _CareerChatScreenState extends State<CareerChatScreen> {
  final AIService _aiService = AIService();
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      final history =
          await _firebaseService.getChatHistory(authProvider.user!.uid);
      setState(() {
        _messages.addAll(history);
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      role: 'user',
      content: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();

    final authProvider = context.read<AuthProvider>();
    if (authProvider.userProfile != null) {
      try {
        final response = await _aiService.chatWithAI(
          userMessage.content,
          authProvider.userProfile!,
          _messages,
        );

        final assistantMessage = ChatMessage(
          role: 'assistant',
          content: response,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(assistantMessage);
          _isLoading = false;
        });

        // Save chat history
        await _firebaseService.saveChatHistory(
          authProvider.user!.uid,
          _messages,
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Career Guidance Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == 'user';

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your career...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

