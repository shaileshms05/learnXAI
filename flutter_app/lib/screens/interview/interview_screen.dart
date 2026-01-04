import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/interview_service.dart';
import '../../models/models.dart';
import 'interview_report_screen.dart';

class InterviewScreen extends StatefulWidget {
  final String sessionId;
  final InterviewQuestion firstQuestion;
  final int totalQuestions;
  final ResumeSummary resumeSummary;

  const InterviewScreen({
    super.key,
    required this.sessionId,
    required this.firstQuestion,
    required this.totalQuestions,
    required this.resumeSummary,
  });

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final _interviewService = InterviewService();
  final _audioPlayer = AudioPlayer();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  late InterviewQuestion _currentQuestion;
  int _currentIndex = 0;
  InterviewFeedback? _lastFeedback;
  bool _isSubmitting = false;
  bool _isPlayingAudio = false;
  bool _showFeedback = false;
  
  // Voice input state (ALWAYS ON - voice-only mode)
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  double _confidence = 0.0;
  bool _isSpeaking = false;
  bool _questionRead = false;

  @override
  void initState() {
    super.initState();
    _currentQuestion = widget.firstQuestion;
    _currentIndex = widget.firstQuestion.index;
    _initializeSpeech();
    _initializeTts();
    // Auto-read first question after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readQuestionAndStartListening();
    });
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onError: (error) {
        print('Speech recognition error: $error');
        setState(() {
          _speechAvailable = false;
          _isListening = false;
        });
      },
      onStatus: (status) {
        print('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
    
    setState(() {
      _speechAvailable = available;
    });
    
    if (!available) {
      print('Speech recognition not available');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Slightly slower for clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
      // Auto-start listening after question is read
      if (!_isListening && !_isSubmitting) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _startListening();
        });
      }
    });
    
    _flutterTts.setErrorHandler((msg) {
      print('TTS Error: $msg');
      setState(() {
        _isSpeaking = false;
      });
      // Still start listening even if TTS fails
      if (!_isListening && !_isSubmitting) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _startListening();
        });
      }
    });
  }

  Future<void> _readQuestionAndStartListening() async {
    if (_isSubmitting || _showFeedback) return;
    
    setState(() {
      _questionRead = false;
      _isSpeaking = true;
      _recognizedText = '';
    });

    try {
      // Read the question using TTS
      await _flutterTts.speak(_currentQuestion.question);
      setState(() {
        _questionRead = true;
      });
    } catch (e) {
      print('Error reading question: $e');
      setState(() {
        _isSpeaking = false;
        _questionRead = true;
      });
      // Start listening even if TTS fails
      Future.delayed(const Duration(milliseconds: 500), () {
        _startListening();
      });
    }
  }

  Future<void> _readFeedback(InterviewFeedback feedback) async {
    if (!mounted) return;
    
    setState(() {
      _isSpeaking = true;
    });

    try {
      // Read feedback summary
      final feedbackText = 'Your score is ${feedback.score.toStringAsFixed(1)} out of 10. ${feedback.feedback}';
      await _flutterTts.speak(feedbackText);
    } catch (e) {
      print('Error reading feedback: $e');
    } finally {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _playAudio() async {
    if (_currentQuestion.audioUrl == null) return;

    try {
      setState(() => _isPlayingAudio = true);
      
      await _audioPlayer.play(UrlSource(_currentQuestion.audioUrl!));
      
      // Wait for audio to finish
      await _audioPlayer.onPlayerComplete.first;
      
      setState(() => _isPlayingAudio = false);
    } catch (e) {
      print('Error playing audio: $e');
      setState(() => _isPlayingAudio = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play audio')),
        );
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available. Please enable microphone permissions.')),
      );
      }
      return;
    }

    if (_isListening) return; // Already listening

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _confidence = 0.0;
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
          _confidence = result.confidence;
        });
      },
      listenFor: const Duration(seconds: 120), // Longer duration for voice-only
      pauseFor: const Duration(seconds: 5), // Longer pause before stopping
      localeId: 'en_US',
      listenMode: stt.ListenMode.confirmation, // Better for longer answers
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _submitAnswer() async {
    // Stop listening if active
    if (_isListening) {
      await _stopListening();
    }
    
    // Stop TTS if speaking
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    
    if (_recognizedText.trim().isEmpty) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please speak your answer. Tap the microphone to start recording.')),
      );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _showFeedback = false;
    });

    try {
      final result = await _interviewService.submitAnswer(
        sessionId: widget.sessionId,
        answer: _recognizedText, // Use voice-recognized text
      );

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final feedback = InterviewFeedback.fromMap(result['current_feedback']);
        
        setState(() {
          _lastFeedback = feedback;
          _showFeedback = true;
        });

        // Read feedback aloud using TTS
        await _readFeedback(feedback);

        // Check if interview is complete
        if (result['interview_complete'] == true) {
          // Show final report
          final report = InterviewReport.fromMap(result['final_report']);
          
          // Wait a moment to show feedback, then navigate
          await Future.delayed(const Duration(seconds: 2));
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => InterviewReportScreen(report: report),
              ),
            );
          }
        } else {
          // Move to next question
          final nextQuestion = InterviewQuestion.fromMap(result['next_question']);
          
          // Wait for user to read feedback
          await Future.delayed(const Duration(seconds: 3));
          
          setState(() {
            _currentQuestion = nextQuestion;
            _currentIndex = nextQuestion.index;
            _showFeedback = false;
            _lastFeedback = null;
            _recognizedText = '';
            _confidence = 0.0;
            _questionRead = false;
            if (_isListening) {
              _stopListening();
            }
          });
          
          // Auto-read next question and start listening
          Future.delayed(const Duration(seconds: 1), () {
            _readQuestionAndStartListening();
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit answer')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mock Interview - Question ${_currentIndex + 1}/${widget.totalQuestions}'),
        actions: [
          // Progress indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${(((_currentIndex + 1) / widget.totalQuestions) * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.totalQuestions,
            backgroundColor: Colors.grey[200],
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question type badge
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getTypeColor(_currentQuestion.type).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getTypeColor(_currentQuestion.type)),
                      ),
                      child: Text(
                        _currentQuestion.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getTypeColor(_currentQuestion.type),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Question text (Voice-only mode)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isSpeaking ? Icons.volume_up : Icons.help_outline,
                                size: 24,
                                color: _isSpeaking ? Colors.blue : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isSpeaking ? 'Reading Question...' : 'Question',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isSpeaking ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              if (_isSpeaking)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentQuestion.question,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.5,
                            ),
                          ),
                          if (!_questionRead && !_isSpeaking) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _readQuestionAndStartListening,
                              icon: const Icon(Icons.volume_up),
                              label: const Text('Read Question Aloud'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Feedback section (if available) - Voice-only mode
                  if (_showFeedback && _lastFeedback != null) ...[
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isSpeaking ? Icons.volume_up : Icons.feedback,
                                  color: _isSpeaking ? Colors.blue : Colors.green,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isSpeaking ? 'Reading Feedback...' : 'Feedback',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isSpeaking ? Colors.blue : Colors.green,
                                  ),
                                ),
                                const Spacer(),
                                if (_isSpeaking)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getScoreColor(_lastFeedback!.score),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_lastFeedback!.score.toStringAsFixed(1)}/10',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_lastFeedback!.feedback),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Voice Answer Section (Voice-Only Mode)
                      const Text(
                    'Your Voice Answer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Voice recording indicator (always visible when listening)
                  if (_isListening) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade300, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Animated microphone icon
                          Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  color: Colors.white,
                                  size: 28,
                            ),
                          ),
                              const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                      '🎤 Listening...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                    color: Colors.red,
                                  ),
                                ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Speak your answer clearly',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.stop_circle, color: Colors.red, size: 32),
                                onPressed: _stopListening,
                                tooltip: 'Stop recording',
                              ),
                            ],
                          ),
                          if (_recognizedText.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recognized:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _recognizedText,
                                    style: const TextStyle(fontSize: 16),
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_confidence > 0) ...[
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: _confidence,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _confidence > 0.7 ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                    Text(
                                      'Confidence: ${(_confidence * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                              ],
                            ),
                          ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    // Not listening - show prompt to start
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.mic_none,
                            size: 64,
                            color: Colors.grey.shade400,
                              ),
                          const SizedBox(height: 16),
                          Text(
                            _recognizedText.isEmpty
                                ? 'Tap the microphone to start speaking your answer'
                                : 'Tap microphone to continue or submit your answer',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_recognizedText.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _recognizedText,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),

                  // Action buttons row
                  Row(
                    children: [
                      // Start/Stop microphone button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_isSubmitting || _showFeedback || _isSpeaking) 
                              ? null 
                              : (_isListening ? _stopListening : _startListening),
                          icon: Icon(_isListening ? Icons.stop : Icons.mic),
                          label: Text(_isListening ? 'Stop Recording' : 'Start Recording'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(20),
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 2),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                  // Submit button
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: (_isSubmitting || _showFeedback || _isListening || _recognizedText.isEmpty) 
                              ? null 
                              : _submitAnswer,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.send_and_archive),
                    label: Text(
                      _isSubmitting 
                          ? 'Evaluating...' 
                              : 'Submit Answer'
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'technical':
        return Colors.blue;
      case 'behavioral':
        return Colors.purple;
      case 'hr':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.blue;
    if (score >= 4) return Colors.orange;
    return Colors.red;
  }
}



