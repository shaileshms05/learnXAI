import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/job_agent_service.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class JobApplicationScreen extends StatefulWidget {
  const JobApplicationScreen({super.key});

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> with SingleTickerProviderStateMixin {
  final _jobAgentService = JobAgentService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Form controllers
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();
  final _jobDescriptionController = TextEditingController();
  final _customNotesController = TextEditingController();
  final _recipientEmailController = TextEditingController(); // NEW: For recipient email
  
  // State
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Results
  JobMatchScore? _matchScore;
  String? _generatedSubject;
  String? _generatedBody;
  
  // Options
  String _selectedTone = 'professional';
  bool _includeProject = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _jobTitleController.dispose();
    _companyController.dispose();
    _jobDescriptionController.dispose();
    _customNotesController.dispose();
    _recipientEmailController.dispose(); // Dispose new controller
    super.dispose();
  }

  Map<String, dynamic> _getUserProfile() {
    // In production, get from auth provider
    return {
      'name': 'Student',
      'skills': ['Python', 'Flutter', 'FastAPI', 'AI/ML', 'Firebase'],
      'interests': ['AI', 'Mobile Development', 'Backend Development'],
      'experience': ['Built Student AI Platform with Flutter and Python', 'Integrated Cerebras AI for intelligent features'],
      'education': 'Computer Science Student',
    };
  }

  Future<void> _analyzeMatch() async {
    if (_jobTitleController.text.isEmpty || _companyController.text.isEmpty || _jobDescriptionController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all job details';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final matchScore = await _jobAgentService.analyzeJobMatch(
        userProfile: _getUserProfile(),
        jobTitle: _jobTitleController.text,
        company: _companyController.text,
        jobDescription: _jobDescriptionController.text,
      );

      if (matchScore != null) {
        setState(() {
          _matchScore = matchScore;
          _currentStep = 1;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to analyze job match';
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

  Future<void> _generateEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate inputs
      if (_jobTitleController.text.isEmpty || 
          _companyController.text.isEmpty || 
          _jobDescriptionController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please fill in all job details';
          _isLoading = false;
        });
        return;
      }

      final email = await _jobAgentService.generateApplicationEmail(
        userProfile: _getUserProfile(),
        jobTitle: _jobTitleController.text,
        company: _companyController.text,
        jobDescription: _jobDescriptionController.text,
        tone: _selectedTone,
        includeProject: _includeProject,
        customNotes: _customNotesController.text.isNotEmpty ? _customNotesController.text : null,
      );

      if (email != null && email['subject'] != null && email['body'] != null) {
        setState(() {
          _generatedSubject = email['subject'];
          _generatedBody = email['body'];
          _currentStep = 2;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to generate email. Please check:\n• Backend server is running (http://localhost:8000)\n• Internet connection\n• Try again in a moment';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error generating email: $e');
      setState(() {
        _errorMessage = 'Error generating email: ${e.toString()}\n\nPlease ensure:\n• Backend server is running\n• Check browser console for details';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _sendViaGmail() async {
    if (_generatedSubject == null || _generatedBody == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final subject = Uri.encodeComponent(_generatedSubject!);
      final body = Uri.encodeComponent(_generatedBody!);
      final to = _recipientEmailController.text.trim().isNotEmpty
          ? Uri.encodeComponent(_recipientEmailController.text.trim())
          : '';
      
      // Build Gmail web URL with all parameters
      final gmailUrl = to.isNotEmpty
          ? 'https://mail.google.com/mail/?view=cm&fs=1&to=$to&su=$subject&body=$body'
          : 'https://mail.google.com/mail/?view=cm&fs=1&su=$subject&body=$body';
      
      final uri = Uri.parse(gmailUrl);
      
      // Try to launch Gmail
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      to.isNotEmpty
                          ? 'Opening Gmail with recipient filled!'
                          : 'Opening Gmail - add recipient email',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        // Fallback: Try mailto scheme
        final mailtoUri = Uri(
          scheme: 'mailto',
          path: to,
          query: 'subject=$subject&body=$body',
        );
        
        if (await canLaunchUrl(mailtoUri)) {
          await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
        } else {
          // Last resort: Copy and show instructions
          await Clipboard.setData(ClipboardData(
            text: to.isNotEmpty
                ? 'To: $to\nSubject: $_generatedSubject\n\n$_generatedBody'
                : 'Subject: $_generatedSubject\n\n$_generatedBody',
          ));
          
          if (mounted) {
            _showFallbackDialog();
          }
        }
      }
    } catch (e) {
      print('Error opening Gmail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Gmail: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFallbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('Email Copied!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your email has been copied to clipboard.'),
            SizedBox(height: 16),
            Text(
              'To send:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('1. Open Gmail in your browser'),
            Text('2. Click "Compose"'),
            Text('3. Paste the email (Cmd+V / Ctrl+V)'),
            Text('4. Review and Send!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse('https://mail.google.com'));
            },
            child: const Text('Open Gmail'),
          ),
        ],
      ),
    );
  }

  void _openGmail() async {
    if (_generatedSubject == null || _generatedBody == null) return;
    
    // Show loading
    setState(() => _isLoading = true);
    
    try {
      // Method 1: Try Gmail web app (works best on web)
      final gmailWebUrl = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1'
        '&su=${Uri.encodeComponent(_generatedSubject!)}'
        '&body=${Uri.encodeComponent(_generatedBody!)}',
      );
      
      // Method 2: Try mailto (works on mobile)
      final mailtoUri = Uri(
        scheme: 'mailto',
        path: '',
        query: 'subject=${Uri.encodeComponent(_generatedSubject!)}&body=${Uri.encodeComponent(_generatedBody!)}',
      );
      
      bool launched = false;
      
      // Try Gmail web first (better for web platform)
      if (await canLaunchUrl(gmailWebUrl)) {
        launched = await launchUrl(
          gmailWebUrl,
          mode: LaunchMode.externalApplication,
        );
      }
      
      // Fallback to mailto
      if (!launched && await canLaunchUrl(mailtoUri)) {
        launched = await launchUrl(
          mailtoUri,
          mode: LaunchMode.externalApplication,
        );
      }
      
      if (launched) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Opening email app...')),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        if (!mounted) return;
        // Show dialog with manual copy option
        _showEmailOptionsDialog();
      }
    } catch (e) {
      if (!mounted) return;
      _showEmailOptionsDialog();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showEmailOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.email_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('Send Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose how to send your email:',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            
            // Option 1: Copy and open Gmail manually
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mail, color: Colors.red),
              ),
              title: const Text('Open Gmail Web'),
              subtitle: const Text('Copy email and open Gmail'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard('$_generatedSubject\n\n$_generatedBody');
                _launchGmailWeb();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Option 2: Copy to clipboard
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.copy_all, color: AppTheme.primaryColor),
              ),
              title: const Text('Copy Email'),
              subtitle: const Text('Copy and paste manually'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard('Subject: $_generatedSubject\n\n$_generatedBody');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _launchGmailWeb() async {
    final url = Uri.parse('https://mail.google.com/mail/u/0/#inbox?compose=new');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email copied to clipboard!', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Paste it in Gmail compose window', style: TextStyle(fontSize: 12)),
            ],
          ),
          backgroundColor: AppTheme.infoColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.secondaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildProgressIndicator(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStepContent(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 24),
                          _buildErrorCard(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.work_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Job Application Agent', style: AppTheme.heading4),
                Text('AI-powered email generator', style: AppTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        children: [
          _buildProgressStep(0, 'Job Details', Icons.description_rounded),
          _buildProgressLine(0),
          _buildProgressStep(1, 'Match Analysis', Icons.analytics_rounded),
          _buildProgressLine(1),
          _buildProgressStep(2, 'Generate Email', Icons.email_rounded),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, IconData icon) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isActive ? AppTheme.primaryGradient : null,
              color: isActive ? null : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: isCurrent ? Border.all(color: AppTheme.primaryColor, width: 3) : null,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? AppTheme.primaryColor : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    final isActive = _currentStep > step;
    
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 40),
        decoration: BoxDecoration(
          gradient: isActive ? AppTheme.primaryGradient : null,
          color: isActive ? null : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildJobDetailsStep();
      case 1:
        return _buildMatchAnalysisStep();
      case 2:
        return _buildEmailGeneratedStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildJobDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Enter Job Details', style: AppTheme.heading3),
        const SizedBox(height: 8),
        const Text(
          'Provide information about the job you\'re applying for',
          style: AppTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _jobTitleController,
          decoration: const InputDecoration(
            labelText: 'Job Title',
            hintText: 'e.g., Software Engineer',
            prefixIcon: Icon(Icons.work_outline),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _companyController,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            hintText: 'e.g., Google',
            prefixIcon: Icon(Icons.business_rounded),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _jobDescriptionController,
          decoration: const InputDecoration(
            labelText: 'Job Description',
            hintText: 'Paste the job description here...',
            prefixIcon: Icon(Icons.description_outlined),
            alignLabelWithHint: true,
          ),
          maxLines: 8,
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _analyzeMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Analyze Match', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchAnalysisStep() {
    if (_matchScore == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Job Match Analysis', style: AppTheme.heading3),
        const SizedBox(height: 24),
        
        // Match Score Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getScoreColor(_matchScore!.overallScore),
                _getScoreColor(_matchScore!.overallScore).withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text(
                'Overall Match',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '${_matchScore!.overallScore.toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _matchScore!.summary,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Matching Skills
        if (_matchScore!.matchingSkills.isNotEmpty) ...[
          const Text('✅ Matching Skills', style: AppTheme.heading4),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _matchScore!.matchingSkills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successColor),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        
        // Missing Skills
        if (_matchScore!.missingSkills.isNotEmpty) ...[
          const Text('📚 Skills to Develop', style: AppTheme.heading4),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _matchScore!.missingSkills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warningColor),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        
        // Recommendations
        if (_matchScore!.recommendations.isNotEmpty) ...[
          const Text('💡 Recommendations', style: AppTheme.heading4),
          const SizedBox(height: 12),
          ...(_matchScore!.recommendations.map((rec) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppTheme.infoColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rec,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            );
          })),
          const SizedBox(height: 24),
        ],
        
        // Email Options
        const Text('Email Options', style: AppTheme.heading4),
        const SizedBox(height: 16),
        
        // Tone Selection
        const Text('Tone:', style: AppTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: ['professional', 'enthusiastic', 'casual'].map((tone) {
            final isSelected = _selectedTone == tone;
            return ChoiceChip(
              label: Text(tone[0].toUpperCase() + tone.substring(1)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedTone = tone;
                });
              },
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 20),
        
        // Include Project
        CheckboxListTile(
          title: const Text('Include Student AI Platform project'),
          subtitle: const Text('Showcase your technical skills'),
          value: _includeProject,
          onChanged: (value) {
            setState(() {
              _includeProject = value ?? true;
            });
          },
          activeColor: AppTheme.primaryColor,
        ),
        
        const SizedBox(height: 20),
        
        // Custom Notes
        TextField(
          controller: _customNotesController,
          decoration: const InputDecoration(
            labelText: 'Additional Notes (Optional)',
            hintText: 'Any specific points you want to mention...',
            prefixIcon: Icon(Icons.note_add_outlined),
          ),
          maxLines: 3,
        ),
        
        const SizedBox(height: 32),
        
        // Generate Email Button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _generateEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_rounded),
                      SizedBox(width: 8),
                      Text('Generate Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailGeneratedStep() {
    if (_generatedSubject == null || _generatedBody == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 32),
            SizedBox(width: 12),
            Text('Email Generated!', style: AppTheme.heading3),
          ],
        ),
        const SizedBox(height: 24),
        
        // Subject
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subject:', style: AppTheme.bodySmall),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyToClipboard(_generatedSubject!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _generatedSubject!,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Body
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Email Body:', style: AppTheme.bodySmall),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyToClipboard(_generatedBody!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _generatedBody!,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.infoColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Clicking "Send via Gmail" will copy your email and open Gmail in a new tab. Just paste and send!',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.infoColor.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Primary Action: Quick Send
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _openGmail,
            icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 24),
            label: Text(
              _isLoading ? 'Opening...' : 'Send via Gmail',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Secondary Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copyToClipboard('Subject: $_generatedSubject\n\n$_generatedBody'),
                icon: const Icon(Icons.copy_all_rounded, size: 20),
                label: const Text('Copy All'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _copyToClipboard(_generatedSubject!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Subject copied!'),
                      backgroundColor: AppTheme.successColor,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                icon: const Icon(Icons.title_rounded, size: 20),
                label: const Text('Copy Subject'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Start New Application
        TextButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = 0;
              _matchScore = null;
              _generatedSubject = null;
              _generatedBody = null;
              _jobTitleController.clear();
              _companyController.clear();
              _jobDescriptionController.clear();
              _customNotesController.clear();
            });
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Start New Application'),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 75) return AppTheme.successColor;
    if (score >= 50) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}

