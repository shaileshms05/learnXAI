import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../models/models.dart';
import '../../services/resume_service.dart';
import '../../services/resume_storage_service.dart';
import '../../theme/app_theme.dart';
import 'resume_tailor_screen.dart';

class ResumeAnalyzerScreen extends StatefulWidget {
  const ResumeAnalyzerScreen({Key? key}) : super(key: key);

  @override
  State<ResumeAnalyzerScreen> createState() => _ResumeAnalyzerScreenState();
}

class _ResumeAnalyzerScreenState extends State<ResumeAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  final ResumeService _resumeService = ResumeService();
  final ResumeStorageService _resumeStorage = ResumeStorageService();
  
  bool _isLoading = false;
  bool _isAnalyzing = false;
  String? _errorMessage;
  String? _fileName;
  Uint8List? _resumeBytes;
  String? _resumeText;
  Map<String, dynamic>? _resumeSummary;
  ResumeAnalysis? _analysis;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyzeResume() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _analysis = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
        withData: true, // Important for web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _fileName = file.name;
        _resumeBytes = file.bytes;

        // Save resume to local storage for use in mock interview
        if (_resumeBytes != null) {
          await _resumeStorage.saveResume(
            resumeBytes: _resumeBytes!,
            resumeName: _fileName!,
            resumeType: file.extension ?? 'pdf',
          );
          print('✅ Resume saved for mock interview');
        }

        // For demo purposes, create sample resume data
        // In production, you'd parse the actual file
        _resumeText = '''John Doe
Software Engineer

Skills: Python, React, Flutter, FastAPI, Firebase
Experience: 
- Software Engineer at Tech Corp (2 years)
- Built web applications using React and Node.js
Education:
- BS in Computer Science from University

Contact: john.doe@email.com
''';

        _resumeSummary = {
          'name': 'John Doe',
          'email': 'john.doe@email.com',
          'skills': ['Python', 'React', 'Flutter', 'FastAPI', 'Firebase'],
          'experience': [
            'Software Engineer at Tech Corp - 2 years',
            'Built web applications using React and Node.js'
          ],
          'education': ['BS in Computer Science from University']
        };

        setState(() {
          _isAnalyzing = true;
        });

        // Call API
        final analysis = await _resumeService.analyzeResume(
          resumeText: _resumeText!,
          resumeSummary: _resumeSummary!,
        );

        if (analysis != null) {
          setState(() {
            _analysis = analysis;
            _isAnalyzing = false;
            _isLoading = false;
          });
          _animationController.forward();
        } else {
          setState(() {
            _errorMessage = 'Failed to analyze resume. Please try again.';
            _isAnalyzing = false;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isAnalyzing = false;
        _isLoading = false;
      });
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
                  child: _buildBody(),
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
                  '📄 Resume Analyzer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Get AI-powered feedback on your resume',
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

  Widget _buildBody() {
    if (_isAnalyzing) {
      return _buildAnalyzingState();
    }

    if (_analysis != null) {
      return _buildAnalysisResults();
    }

    return _buildUploadState();
  }

  Widget _buildUploadState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          
          // Upload illustration
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(
                Icons.upload_file_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Upload button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _pickAndAnalyzeResume,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(_isLoading ? 'Uploading...' : 'Upload Resume'),
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
          ),

          const SizedBox(height: 16),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.errorColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Supported formats
          _buildInfoCard(
            icon: Icons.info_outline,
            title: 'Supported Formats',
            content: 'PDF, DOCX, TXT',
            color: AppTheme.infoColor,
          ),

          const SizedBox(height: 16),

          // What we analyze
          _buildInfoCard(
            icon: Icons.analytics_outlined,
            title: 'What We Analyze',
            content: 'Format, Content, Skills, Experience, ATS Compatibility, Keywords',
            color: AppTheme.successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 6,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Analyzing Resume...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Our AI is reviewing your resume',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overall score card
            _buildScoreCard(),
            
            const SizedBox(height: 24),

            // Section scores
            _buildSectionScores(),

            const SizedBox(height: 24),

            // Strengths
            _buildListCard(
              title: '✅ Strengths',
              items: _analysis!.strengths,
              color: AppTheme.successColor,
            ),

            const SizedBox(height: 16),

            // Weaknesses
            _buildListCard(
              title: '⚠️ Areas to Improve',
              items: _analysis!.weaknesses,
              color: AppTheme.warningColor,
            ),

            const SizedBox(height: 16),

            // Suggestions
            _buildListCard(
              title: '💡 Suggestions',
              items: _analysis!.suggestions,
              color: AppTheme.infoColor,
            ),

            const SizedBox(height: 16),

            // ATS Issues
            if (_analysis!.atsIssues.isNotEmpty)
              _buildListCard(
                title: '🚨 ATS Issues',
                items: _analysis!.atsIssues,
                color: AppTheme.errorColor,
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickAndAnalyzeResume,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Analyze Another'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToTailor,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Tailor Resume'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final score = _analysis!.overallScore;
    final color = score >= 80
        ? AppTheme.successColor
        : score >= 60
            ? AppTheme.warningColor
            : AppTheme.errorColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Overall Score',
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${score.toInt()}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    'out of 100',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getScoreDescription(score),
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getScoreDescription(double score) {
    if (score >= 90) return 'Excellent! Your resume is outstanding.';
    if (score >= 80) return 'Great! Your resume is very strong.';
    if (score >= 70) return 'Good! Some improvements will make it great.';
    if (score >= 60) return 'Fair. Several areas need improvement.';
    return 'Needs work. Follow suggestions to improve.';
  }

  Widget _buildSectionScores() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Section Scores',
            style: AppTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          ..._analysis!.sectionScores.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildScoreBar(
                _formatSectionName(entry.key),
                entry.value,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatSectionName(String key) {
    return key.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Widget _buildScoreBar(String label, double score) {
    final color = score >= 80
        ? AppTheme.successColor
        : score >= 60
            ? AppTheme.warningColor
            : AppTheme.errorColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.bodyMedium),
            Text(
              '${score.toInt()}%',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildListCard({
    required String title,
    required List<String> items,
    required Color color,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.titleMedium.copyWith(color: color),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTheme.bodyMedium.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.labelLarge.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTailor() {
    if (_resumeSummary != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResumeTailorScreen(
            resumeSummary: _resumeSummary!,
            resumeText: _resumeText ?? '',
          ),
        ),
      );
    }
  }
}

