import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/book_service.dart';
import '../../models/models.dart';

class TeachingScreen extends StatefulWidget {
  final String bookId;

  const TeachingScreen({
    super.key,
    required this.bookId,
  });

  @override
  State<TeachingScreen> createState() => _TeachingScreenState();
}

class _TeachingScreenState extends State<TeachingScreen> {
  final BookService _bookService = BookService();
  final TextEditingController _answerController = TextEditingController();
  
  TeachingContent? _currentTeaching;
  UnderstandingEvaluation? _evaluation;
  bool _isLoading = false;
  bool _isEvaluating = false;
  String _teachingStyle = 'simple';
  int _currentChapter = 1;

  @override
  void initState() {
    super.initState();
    _loadTeaching();
  }

  Future<void> _loadTeaching() async {
    setState(() {
      _isLoading = true;
      _evaluation = null;
    });

    try {
      final teaching = await _bookService.startTeaching(
        bookId: widget.bookId,
        chapterNum: _currentChapter,
        style: _teachingStyle,
      );

      setState(() {
        _currentTeaching = teaching;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading teaching: $e')),
        );
      }
    }
  }

  Future<void> _checkUnderstanding() async {
    if (_answerController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your answer'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_currentTeaching == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No teaching content available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isEvaluating = true;
    });

    try {
      // Use a default user ID if not authenticated, or get from auth provider if available
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid ?? 'anonymous_user';

      print('🔍 Checking understanding for concept: ${_currentTeaching!.concept.id}');

      final evaluation = await _bookService.checkUnderstanding(
        bookId: widget.bookId,
        conceptId: _currentTeaching!.concept.id,
        question: _currentTeaching!.question,
        studentAnswer: _answerController.text,
        userId: userId,
      );

      setState(() {
        _evaluation = evaluation;
        _isEvaluating = false;
      });
    } catch (e) {
      setState(() {
        _isEvaluating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error evaluating: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn from Book'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _teachingStyle,
            onSelected: (value) {
              setState(() {
                _teachingStyle = value;
              });
              _loadTeaching();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'simple', child: Text('👶 Simple (ELI12)')),
              const PopupMenuItem(value: 'code-first', child: Text('👩‍💻 Code-First')),
              const PopupMenuItem(value: 'math-heavy', child: Text('🧮 Math-Heavy')),
              const PopupMenuItem(value: 'interview', child: Text('🎯 Interview Prep')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentTeaching == null
              ? const Center(child: Text('No teaching content available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress Indicator
                      LinearProgressIndicator(
                        value: (_currentTeaching!.currentIndex + 1) / _currentTeaching!.totalConcepts,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Concept ${_currentTeaching!.currentIndex + 1} of ${_currentTeaching!.totalConcepts}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 24),

                      // Concept Card
                      Card(
                        color: Colors.purple.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb, color: Colors.purple.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _currentTeaching!.concept.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(_currentTeaching!.concept.difficulty),
                                    backgroundColor: _getDifficultyColor(_currentTeaching!.concept.difficulty),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentTeaching!.concept.definition,
                                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Explanation
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.school, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Explanation',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _currentTeaching!.explanation,
                                style: const TextStyle(height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Example
                      if (_currentTeaching!.example.isNotEmpty)
                        Card(
                          color: Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.emoji_objects, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Example',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _currentTeaching!.example,
                                  style: const TextStyle(height: 1.6),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Understanding Check
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.quiz, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Understanding Check',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _currentTeaching!.question,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _answerController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Type your answer here...',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isEvaluating 
                                      ? null 
                                      : () {
                                          print('🔘 Check Answer button clicked');
                                          _checkUnderstanding();
                                        },
                                  icon: _isEvaluating
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.check_circle),
                                  label: Text(_isEvaluating ? 'Evaluating...' : 'Check My Answer'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Evaluation Result
                      if (_evaluation != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: _evaluation!.score >= 70 ? Colors.green.shade50 : Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _evaluation!.score >= 70 ? Icons.check_circle : Icons.error,
                                      color: _evaluation!.score >= 70 ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Score: ${_evaluation!.score}%',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: _evaluation!.score >= 70 ? Colors.green.shade700 : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _evaluation!.feedback,
                                  style: const TextStyle(height: 1.5),
                                ),
                                if (_evaluation!.missingIdeas.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Missing Ideas:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  ...(_evaluation!.missingIdeas.map((idea) => Text('• $idea'))),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green.shade100;
      case 'intermediate':
        return Colors.orange.shade100;
      case 'advanced':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }
}

