import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/resume_service.dart';
import '../../theme/app_theme.dart';

class BulletGeneratorScreen extends StatefulWidget {
  const BulletGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<BulletGeneratorScreen> createState() => _BulletGeneratorScreenState();
}

class _BulletGeneratorScreenState extends State<BulletGeneratorScreen> {
  final ResumeService _resumeService = ResumeService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _jobTitleController = TextEditingController();
  final List<TextEditingController> _responsibilityControllers = [
    TextEditingController()
  ];
  final List<TextEditingController> _achievementControllers = [
    TextEditingController()
  ];

  bool _isLoading = false;
  String? _errorMessage;
  BulletPointsResult? _result;

  @override
  void dispose() {
    _jobTitleController.dispose();
    for (var controller in _responsibilityControllers) {
      controller.dispose();
    }
    for (var controller in _achievementControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addResponsibilityField() {
    setState(() {
      _responsibilityControllers.add(TextEditingController());
    });
  }

  void _removeResponsibilityField(int index) {
    if (_responsibilityControllers.length > 1) {
      setState(() {
        _responsibilityControllers[index].dispose();
        _responsibilityControllers.removeAt(index);
      });
    }
  }

  void _addAchievementField() {
    setState(() {
      _achievementControllers.add(TextEditingController());
    });
  }

  void _removeAchievementField(int index) {
    setState(() {
      _achievementControllers[index].dispose();
      _achievementControllers.removeAt(index);
    });
  }

  Future<void> _generateBulletPoints() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responsibilities = _responsibilityControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final achievements = _achievementControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final result = await _resumeService.generateBulletPoints(
        jobTitle: _jobTitleController.text.trim(),
        responsibilities: responsibilities,
        achievements: achievements.isEmpty ? null : achievements,
      );

      if (result != null) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to generate bullet points. Please try again.';
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

  void _copyAllBullets() {
    if (_result != null) {
      final bullets = _result!.bulletPoints.join('\n\n');
      _copyToClipboard(bullets);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
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
                  child: _result != null ? _buildResults() : _buildInputForm(),
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
                  '✍️ Bullet Generator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create professional resume bullets',
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
                labelText: 'Job Title *',
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

            const SizedBox(height: 24),

            // Responsibilities Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Responsibilities *',
                  style: AppTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addResponsibilityField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add More'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._responsibilityControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'e.g., Developed web applications',
                          prefixIcon: const Icon(Icons.circle, size: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: index == 0
                            ? (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'At least one responsibility required';
                                }
                                return null;
                              }
                            : null,
                      ),
                    ),
                    if (_responsibilityControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppTheme.errorColor,
                        onPressed: () => _removeResponsibilityField(index),
                      ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            // Achievements Section (Optional)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Achievements (Optional)',
                  style: AppTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addAchievementField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add More'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._achievementControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'e.g., Improved performance by 50%',
                          prefixIcon: const Icon(Icons.emoji_events, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppTheme.errorColor,
                      onPressed: () => _removeAchievementField(index),
                    ),
                  ],
                ),
              );
            }).toList(),

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

            // Generate button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateBulletPoints,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isLoading ? 'Generating...' : 'Generate Bullets'),
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

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: AppTheme.infoColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pro Tips',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.infoColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Be specific about your responsibilities and quantify achievements with metrics (e.g., "50% faster", "10+ projects").',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Success message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Generated ${_result!.bulletPoints.length} professional bullet points',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bullet points
          ...(_result!.bulletPoints.asMap().entries.map((entry) {
            final index = entry.key;
            final bullet = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Bullet ${index + 1}',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () => _copyToClipboard(bullet),
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bullet,
                    style: AppTheme.bodyMedium.copyWith(
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList()),

          const SizedBox(height: 16),

          // Tips section
          if (_result!.tips.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: AppTheme.infoColor),
                      const SizedBox(width: 12),
                      Text(
                        'Tips for Improvement',
                        style: AppTheme.titleMedium.copyWith(
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._result!.tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.infoColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip,
                                style: AppTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _result = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Generate More'),
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
                  onPressed: _copyAllBullets,
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
}

