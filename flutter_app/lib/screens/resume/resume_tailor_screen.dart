import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/resume_service.dart';
import '../../theme/app_theme.dart';

class ResumeTailorScreen extends StatefulWidget {
  final Map<String, dynamic> resumeSummary;
  final String resumeText;

  const ResumeTailorScreen({
    Key? key,
    required this.resumeSummary,
    required this.resumeText,
  }) : super(key: key);

  @override
  State<ResumeTailorScreen> createState() => _ResumeTailorScreenState();
}

class _ResumeTailorScreenState extends State<ResumeTailorScreen> {
  final ResumeService _resumeService = ResumeService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobDescriptionController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  ResumeTailoring? _tailoring;

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _jobDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _tailorResume() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tailoring = await _resumeService.tailorResume(
        resumeSummary: widget.resumeSummary,
        jobTitle: _jobTitleController.text.trim(),
        jobDescription: _jobDescriptionController.text.trim(),
        company: _companyController.text.trim(),
      );

      if (tailoring != null) {
        setState(() {
          _tailoring = tailoring;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to tailor resume. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.secondaryGradient,
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
                  '🎯 Resume Tailor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Optimize your resume for specific jobs',
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
    if (_tailoring != null) {
      return _buildTailoringResults();
    }

    return _buildInputForm();
  }

  Widget _buildInputForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Job Title
            TextFormField(
              controller: _jobTitleController,
              decoration: InputDecoration(
                labelText: 'Job Title',
                hintText: 'e.g., Software Engineer',
                prefixIcon: const Icon(Icons.work_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter job title';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Company
            TextFormField(
              controller: _companyController,
              decoration: InputDecoration(
                labelText: 'Company Name',
                hintText: 'e.g., Google',
                prefixIcon: const Icon(Icons.business_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter company name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Job Description
            TextFormField(
              controller: _jobDescriptionController,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'Job Description',
                hintText: 'Paste the full job description here...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 140),
                  child: Icon(Icons.description_outlined),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter job description';
                }
                if (value.trim().length < 50) {
                  return 'Please enter a more detailed job description';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
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
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),

            // Tailor button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _tailorResume,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(_isLoading ? 'Tailoring Resume...' : 'Tailor Resume'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTailoringResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Strategy card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Strategy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _tailoring!.overallStrategy,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Optimized Summary
          _buildCopyableSection(
            title: '📝 Optimized Professional Summary',
            content: _tailoring!.optimizedSummary,
            icon: Icons.copy,
          ),

          const SizedBox(height: 16),

          // Skills to Emphasize
          if (_tailoring!.skillsToEmphasize.isNotEmpty)
            _buildListSection(
              title: '⭐ Skills to Emphasize',
              items: _tailoring!.skillsToEmphasize,
              color: AppTheme.successColor,
            ),

          const SizedBox(height: 16),

          // Skills to Add
          if (_tailoring!.skillsToAdd.isNotEmpty)
            _buildListSection(
              title: '➕ Skills to Add',
              items: _tailoring!.skillsToAdd,
              color: AppTheme.infoColor,
            ),

          const SizedBox(height: 16),

          // Keywords
          if (_tailoring!.keywordsToInclude.isNotEmpty)
            _buildKeywordsSection(),

          const SizedBox(height: 16),

          // Experience Bullets
          if (_tailoring!.experienceBullets.isNotEmpty)
            _buildExperienceBullets(),

          const SizedBox(height: 16),

          // Projects to Highlight
          if (_tailoring!.projectsToHighlight.isNotEmpty)
            _buildListSection(
              title: '🚀 Projects to Highlight',
              items: _tailoring!.projectsToHighlight,
              color: AppTheme.primaryColor,
            ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _tailoring = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tailor Another'),
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
                  onPressed: _copyAllContent,
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy All'),
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
        ],
      ),
    );
  }

  Widget _buildCopyableSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: Icon(icon, color: AppTheme.primaryColor),
                onPressed: () => _copyToClipboard(content),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTheme.bodyMedium.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection({
    required String title,
    required List<String> items,
    required Color color,
  }) {
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
                        style: AppTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildKeywordsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔑 Keywords to Include',
            style: AppTheme.titleMedium.copyWith(color: AppTheme.warningColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tailoring!.keywordsToInclude.map((keyword) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  keyword,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceBullets() {
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
            '✍️ Optimized Experience Bullets',
            style: AppTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ..._tailoring!.experienceBullets.map((bullet) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Original',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bullet.original,
                    style: AppTheme.bodySmall.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Optimized',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.successColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () => _copyToClipboard(bullet.optimized),
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bullet.optimized,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.infoColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bullet.why,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.infoColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _copyAllContent() {
    final buffer = StringBuffer();
    buffer.writeln('=== TAILORED RESUME CONTENT ===\n');
    buffer.writeln('Professional Summary:');
    buffer.writeln(_tailoring!.optimizedSummary);
    buffer.writeln('\n---\n');
    
    if (_tailoring!.skillsToEmphasize.isNotEmpty) {
      buffer.writeln('Skills to Emphasize:');
      for (var skill in _tailoring!.skillsToEmphasize) {
        buffer.writeln('• $skill');
      }
      buffer.writeln('\n---\n');
    }
    
    if (_tailoring!.experienceBullets.isNotEmpty) {
      buffer.writeln('Optimized Experience Bullets:');
      for (var bullet in _tailoring!.experienceBullets) {
        buffer.writeln('• ${bullet.optimized}');
      }
    }
    
    _copyToClipboard(buffer.toString());
  }
}

