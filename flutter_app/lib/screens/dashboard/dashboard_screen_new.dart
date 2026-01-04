import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/ai_service.dart';
import '../../services/learning_path_service.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final _aiService = AIService();
  final _pathService = LearningPathService();
  final _firebaseService = FirebaseService();
  bool _isGeneratingPath = false;
  bool _isGeneratingInternships = false;
  LearningPath? _learningPath;
  List<Internship> _internships = [];
  List<DailyTask> _todaysTasks = [];
  List<DailyTask> _weekTasks = [];
  bool _isLoadingTasks = false;
  bool _isLoadingWeekTasks = false;
  bool _isAddingToCalendar = false;
  bool _weekHasEnded = false;
  DateTime? _weekStartDate;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _loadLearningPath();
    _loadWeekTasks(); // Load week tasks first
    _loadTodaysTasks();
  }

  Future<void> _loadLearningPath() async {
    // Don't load from Firestore - keep in memory only (like resume optimizer)
    // Learning path is generated and stored in state, not persisted
  }
  
  Future<void> _loadTodaysTasks() async {
    setState(() => _isLoadingTasks = true);
    
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? 
                   authProvider.calendarService.currentUser?.email ?? 
                   '';
    
    if (userId.isNotEmpty) {
      try {
        // Load from Firestore
        final tasks = await _pathService.getTodaysTasks(userId);
        setState(() {
          _todaysTasks = tasks;
          _isLoadingTasks = false;
        });
      } catch (e) {
        setState(() => _isLoadingTasks = false);
      }
    } else {
      setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _loadWeekTasks() async {
    setState(() => _isLoadingWeekTasks = true);
    
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? 
                   authProvider.calendarService.currentUser?.email ?? 
                   '';
    
    if (userId.isEmpty) {
      setState(() => _isLoadingWeekTasks = false);
      return;
    }

    try {
      // Load tasks for the next 7 days from Firestore
      final List<DailyTask> allWeekTasks = [];
      final today = DateTime.now();
      
      for (int i = 0; i < 7; i++) {
        final date = today.add(Duration(days: i));
        final tasks = await _pathService.getTasksForDate(userId, date);
        allWeekTasks.addAll(tasks);
      }
      
      // Check if week has ended (all tasks are in the past, beyond today)
      bool weekHasEnded = false;
      DateTime? weekStartDate;
      
      if (allWeekTasks.isNotEmpty) {
        // Find the earliest and latest task dates
        final earliestDate = allWeekTasks.map((t) => t.scheduledDate).reduce((a, b) => a.isBefore(b) ? a : b);
        final latestDate = allWeekTasks.map((t) => t.scheduledDate).reduce((a, b) => a.isAfter(b) ? a : b);
        weekStartDate = earliestDate;
        
        // Check if the week has ended (latest task is in the past)
        // Week ends when the latest task date is before today
        final todayStart = DateTime(today.year, today.month, today.day);
        final latestDateStart = DateTime(latestDate.year, latestDate.month, latestDate.day);
        weekHasEnded = latestDateStart.isBefore(todayStart);
      } else {
        // No tasks exist - week hasn't started
        weekHasEnded = false;
      }
      
      setState(() {
        _weekTasks = allWeekTasks;
        _weekHasEnded = weekHasEnded;
        _weekStartDate = weekStartDate;
        _isLoadingWeekTasks = false;
      });
    } catch (e) {
      print('Error loading week tasks: $e');
      setState(() => _isLoadingWeekTasks = false);
    }
  }

  Future<void> _startTasks() async {
    if (_learningPath == null) {
      _showErrorSnackBar('Please generate a learning path first');
      return;
    }

    setState(() => _isLoadingTasks = true);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? 
                   authProvider.calendarService.currentUser?.email ?? 
                   '';

    if (userId.isEmpty) {
      _showErrorSnackBar('Please sign in to start tasks');
      setState(() => _isLoadingTasks = false);
      return;
    }

    try {
      // Check if Google Calendar is signed in
      if (!authProvider.calendarService.isSignedIn) {
        final signedIn = await authProvider.calendarService.signIn();
        if (!signedIn) {
          _showErrorSnackBar('Please sign in to Google Calendar to add tasks');
          setState(() => _isLoadingTasks = false);
          return;
        }
      }

      // Generate tasks for ONE WEEK ONLY (7 days)
      final today = DateTime.now();
      final weekTasks = <DailyTask>[];
      
      // Generate tasks for each day of the week (7 days)
      for (int day = 0; day < 7; day++) {
        final currentDate = today.add(Duration(days: day));
        
        // Skip weekends if desired (optional - you can remove this if you want weekends)
        // if (currentDate.weekday == DateTime.saturday || currentDate.weekday == DateTime.sunday) {
        //   continue;
        // }
        
        // Generate 3 tasks per day
        final dayTasks = await _generateTasksForSingleDay(
          pathId: _learningPath!.id,
          userId: userId,
          date: currentDate,
          phases: _learningPath!.milestones,
        );
        
        weekTasks.addAll(dayTasks);
      }

      // Save to Firestore so tasks can be updated/completed
      await _pathService.saveDailyTasks(userId, weekTasks);

      // Automatically add to Google Calendar
      setState(() => _isAddingToCalendar = true);
      
      int successCount = 0;
      final totalTasks = weekTasks.length;
      
      // Show progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Adding $totalTasks tasks to Google Calendar...'),
                const SizedBox(height: 8),
                Text('$successCount / $totalTasks', style: AppTheme.bodySmall),
              ],
            ),
          ),
        );
      }

      // Add tasks to Google Calendar with progress callback
      successCount = await authProvider.calendarService.addTasksToCalendar(
        weekTasks,
        onProgress: (count) {
          if (mounted) {
            setState(() {});
          }
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        
        // Reload week tasks first to get the latest
        await _loadWeekTasks();
        
        // Load today's tasks
        await _loadTodaysTasks();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Generated and added $successCount/$totalTasks tasks to Google Calendar!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog if still open
        _showErrorSnackBar('Error starting tasks: $e');
      }
        setState(() => _isLoadingTasks = false);
      setState(() => _isAddingToCalendar = false);
    } finally {
      setState(() => _isLoadingTasks = false);
      setState(() => _isAddingToCalendar = false);
    }
  }

  Future<List<DailyTask>> _generateTasksForSingleDay({
    required String pathId,
    required String userId,
    required DateTime date,
    required List<String> phases,
  }) async {
    final tasks = <DailyTask>[];
    
    // Determine which phase this day belongs to (simplified - just use first phase)
    final phaseTitle = phases.isNotEmpty ? phases[0] : 'Learning Phase';
    
    // Generate 3 tasks for this day
    final dayOfWeek = date.day % 7;
    final baseTaskId = '${pathId}_${date.millisecondsSinceEpoch}';
    
    // Task 1: Coding challenge
    tasks.add(DailyTask(
      id: '${baseTaskId}_0',
      pathId: pathId,
      phaseTitle: phaseTitle,
      title: 'Complete 2 LeetCode Problems',
      description: 'Solve 2 coding problems related to $phaseTitle concepts',
      type: TaskType.coding,
      scheduledDate: date,
      estimatedMinutes: 60,
      priority: 1,
    ));

    // Task 2: Learning task (rotate based on day)
    final studyTasks = [
      DailyTask(
        id: '${baseTaskId}_1',
        pathId: pathId,
        phaseTitle: phaseTitle,
        title: 'Study New Concept',
        description: 'Learn a new concept in $phaseTitle (video/article)',
        type: TaskType.study,
        scheduledDate: date,
        estimatedMinutes: 45,
        priority: 1,
      ),
      DailyTask(
        id: '${baseTaskId}_1',
        pathId: pathId,
        phaseTitle: phaseTitle,
        title: 'Hands-on Practice',
        description: 'Apply what you learned with practical exercises',
        type: TaskType.practice,
        scheduledDate: date,
        estimatedMinutes: 45,
        priority: 1,
      ),
      DailyTask(
        id: '${baseTaskId}_1',
        pathId: pathId,
        phaseTitle: phaseTitle,
        title: 'Review Previous Topics',
        description: 'Revisit and strengthen concepts from earlier days',
        type: TaskType.review,
        scheduledDate: date,
        estimatedMinutes: 30,
        priority: 2,
      ),
    ];
    tasks.add(studyTasks[dayOfWeek % studyTasks.length]);

    // Task 3: Project/Practice task
    if (dayOfWeek % 3 == 0) {
      tasks.add(DailyTask(
        id: '${baseTaskId}_2',
        pathId: pathId,
        phaseTitle: phaseTitle,
        title: 'Work on Portfolio Project',
        description: 'Build a project component related to $phaseTitle',
        type: TaskType.project,
        scheduledDate: date,
        estimatedMinutes: 90,
        priority: 1,
      ));
    } else {
      tasks.add(DailyTask(
        id: '${baseTaskId}_2',
        pathId: pathId,
        phaseTitle: phaseTitle,
        title: 'Read Documentation',
        description: 'Study official docs and best practices',
        type: TaskType.study,
        scheduledDate: date,
        estimatedMinutes: 30,
        priority: 2,
      ));
    }

    return tasks;
  }

  Future<void> _addWeekTasksToGoogleCalendar() async {
    if (_weekTasks.isEmpty) {
      _showErrorSnackBar('No tasks to add. Please start tasks first.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    
    // Check if Google Calendar is signed in
    if (!authProvider.calendarService.isSignedIn) {
      final signedIn = await authProvider.calendarService.signIn();
      if (!signedIn) {
        _showErrorSnackBar('Please sign in to Google Calendar');
        return;
      }
    }

    setState(() => _isAddingToCalendar = true);

    try {
      int successCount = 0;
      int totalTasks = _weekTasks.length;

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Adding $totalTasks tasks to Google Calendar...'),
                const SizedBox(height: 8),
                Text('$successCount / $totalTasks', style: AppTheme.bodySmall),
              ],
            ),
          ),
        );
      }

      // Add tasks with progress callback
      successCount = await authProvider.calendarService.addTasksToCalendar(
        _weekTasks,
        onProgress: (count) {
          if (mounted) {
            setState(() {});
          }
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added $successCount/$totalTasks tasks to Google Calendar!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog if still open
        _showErrorSnackBar('Error adding to calendar: $e');
      }
    } finally {
      setState(() => _isAddingToCalendar = false);
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.displayName ?? 'Student';
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFAFBFC),
              const Color(0xFFF5F7FA),
              const Color(0xFFEFF1F5),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildModernAppBar(context, userName),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLg,
                      vertical: AppTheme.spacingMd,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildPremiumWelcomeCard(userName),
                        const SizedBox(height: AppTheme.spacingXl),
                        _buildModernTasksSection(),
                        const SizedBox(height: AppTheme.spacingXl),
                        _buildModernStatsSection(),
                        const SizedBox(height: AppTheme.spacingXl),
                        _buildModernQuickActions(context),
                        const SizedBox(height: AppTheme.spacingXl),
                        _buildModernFeaturesGrid(context),
                        const SizedBox(height: AppTheme.spacing2xl),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context, String userName) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          boxShadow: AppTheme.glassShadow,
          border: Border(
            bottom: BorderSide(
              color: Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLg,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.premiumShadow,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                    child: Text(
                      'Student AI',
                      style: AppTheme.heading4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowSm,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.person_outline_rounded, size: 22),
                    onPressed: () {
                      Navigator.pushNamed(context, '/profile/edit');
                    },
                    tooltip: 'Profile',
                    color: AppTheme.primaryColor,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowSm,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 22),
                    onPressed: () async {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      await authProvider.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacementNamed('/signin');
                    },
                    tooltip: 'Logout',
                    color: AppTheme.errorColor,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumWelcomeCard(String userName) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
          ),
            ),
      ),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                      ),
                    ),
                        const SizedBox(height: 6),
                    Text(
                      userName,
                      style: AppTheme.heading2.copyWith(
                        color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                    padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                      size: 36,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '✨ Ready to level up your skills today?',
            style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
            ),
          ),
              ),
              const SizedBox(height: AppTheme.spacingXl),
          Row(
            children: [
              Expanded(
                    child: _buildPremiumStatItem(
                      icon: Icons.local_fire_department_rounded,
                  value: '12',
                      label: 'Day Streak',
                      gradient: AppTheme.accentGradient,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                    child: _buildPremiumStatItem(
                      icon: Icons.stars_rounded,
                  value: '850',
                  label: 'XP Points',
                      gradient: AppTheme.secondaryGradient,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                    child: _buildPremiumStatItem(
                  icon: Icons.trending_up_rounded,
                  value: '85%',
                  label: 'Progress',
                      gradient: AppTheme.successGradient,
                ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPremiumStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text(
                  'Today\'s Tasks',
                  style: AppTheme.heading3,
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                if (_learningPath != null) {
                  Navigator.pushNamed(
                    context,
                    '/learning-path/detail',
                    arguments: _learningPath,
                  ).then((_) => _loadTodaysTasks());
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View All'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        if (_isLoadingTasks)
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.glassShadow,
              ),
              child: const CircularProgressIndicator(),
            ),
          )
        else if (_todaysTasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              gradient: AppTheme.glassGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              boxShadow: AppTheme.glassShadow,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _weekHasEnded ? Icons.refresh_rounded : Icons.task_alt_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Text(
                  _learningPath != null 
                      ? (_weekHasEnded ? 'Your week has ended!' : 'No tasks for today')
                      : 'No learning path yet',
                  style: AppTheme.heading4.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  _learningPath != null
                      ? (_weekHasEnded 
                          ? 'Start a new week to continue your learning journey'
                          : 'Click Start to generate and load today\'s tasks')
                      : 'Generate a learning path to get started',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (_learningPath != null) ...[
                  const SizedBox(height: AppTheme.spacingXl),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.premiumShadow,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingTasks ? null : _startTasks,
                      icon: _isLoadingTasks
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_weekHasEnded ? Icons.refresh_rounded : Icons.play_arrow_rounded),
                      label: Text(_weekHasEnded ? 'Start New Week' : 'Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingXl,
                          vertical: AppTheme.spacingMd,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Column(
            children: _todaysTasks.take(3).map((task) {
              return Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                decoration: BoxDecoration(
                  gradient: AppTheme.glassGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: AppTheme.glassShadow,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    onTap: () async {
                      final authProvider = context.read<AuthProvider>();
                      final userId = authProvider.user?.uid ?? 
                                   authProvider.calendarService.currentUser?.email ?? 
                                   '';
                      if (userId.isNotEmpty) {
                        await _pathService.completeTask(userId, task);
                        _loadTodaysTasks();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getTaskColor(task.type),
                                  _getTaskColor(task.type).withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                              boxShadow: [
                                BoxShadow(
                                  color: _getTaskColor(task.type).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              task.isCompleted
                                  ? Icons.check_circle_rounded
                                  : _getTaskIcon(task.type),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: AppTheme.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.isCompleted
                                        ? AppTheme.textTertiary
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 14,
                                      color: AppTheme.textTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${task.estimatedMinutes} min',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!task.isCompleted)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTodaysTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Today\'s Tasks', style: AppTheme.heading3),
            TextButton.icon(
              onPressed: () {
                // Navigate to full learning path if exists
                if (_learningPath != null) {
                  Navigator.pushNamed(
                    context,
                    '/learning-path/detail',
                    arguments: _learningPath,
                  ).then((_) => _loadTodaysTasks());
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        if (_isLoadingTasks)
          const Center(child: CircularProgressIndicator())
        else if (_todaysTasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: AppTheme.shadowSm,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 48,
                  color: AppTheme.textTertiary.withOpacity(0.5),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  _learningPath != null 
                      ? (_weekHasEnded ? 'Your week has ended!' : 'No tasks for today')
                      : 'No learning path yet',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  _learningPath != null
                      ? (_weekHasEnded 
                          ? 'Start a new week to continue your learning journey'
                          : 'Click Start to generate and load today\'s tasks')
                      : 'Generate a learning path to get started',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                  textAlign: TextAlign.center,
                ),
                if (_learningPath != null) ...[
                  const SizedBox(height: AppTheme.spacingLg),
                  ElevatedButton.icon(
                    onPressed: _isLoadingTasks ? null : _startTasks,
                    icon: _isLoadingTasks
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_weekHasEnded ? Icons.refresh_rounded : Icons.play_arrow_rounded),
                    label: Text(_weekHasEnded ? 'Start New Week' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXl,
                        vertical: AppTheme.spacingMd,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Column(
            children: _todaysTasks.take(3).map((task) {
              return Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    onTap: () async {
                      final authProvider = context.read<AuthProvider>();
                      final userId = authProvider.user?.uid ?? 
                                   authProvider.calendarService.currentUser?.email ?? 
                                   '';
                      if (userId.isNotEmpty) {
                        await _pathService.completeTask(userId, task);
                        _loadTodaysTasks();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getTaskColor(task.type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Icon(
                              task.isCompleted
                                  ? Icons.check_circle_rounded
                                  : _getTaskIcon(task.type),
                              color: task.isCompleted
                                  ? AppTheme.successColor
                                  : _getTaskColor(task.type),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: AppTheme.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 14,
                                      color: AppTheme.textTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${task.estimatedMinutes} min',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!task.isCompleted)
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textTertiary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  IconData _getTaskIcon(TaskType type) {
    switch (type) {
      case TaskType.coding:
        return Icons.code_rounded;
      case TaskType.study:
        return Icons.menu_book_rounded;
      case TaskType.project:
        return Icons.rocket_launch_rounded;
      case TaskType.practice:
        return Icons.fitness_center_rounded;
      case TaskType.review:
        return Icons.replay_rounded;
      case TaskType.quiz:
        return Icons.quiz_rounded;
      case TaskType.networking:
        return Icons.people_rounded;
    }
  }

  Color _getTaskColor(TaskType type) {
    switch (type) {
      case TaskType.coding:
        return AppTheme.primaryColor;
      case TaskType.study:
        return AppTheme.infoColor;
      case TaskType.project:
        return AppTheme.warningColor;
      case TaskType.practice:
        return AppTheme.successColor;
      case TaskType.review:
        return AppTheme.secondaryColor;
      case TaskType.quiz:
        return const Color(0xFFEC4899);
      case TaskType.networking:
        return const Color(0xFF8B5CF6);
    }
  }

  Widget _buildSourceChip(
    String label,
    String value,
    List<String> selectedSources,
    BuildContext context,
    StateSetter setDialogState,
  ) {
    final isSelected = selectedSources.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setDialogState(() {
          if (selected) {
            selectedSources.add(value);
          } else {
            selectedSources.remove(value);
          }
        });
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildModernStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text('Your Progress', style: AppTheme.heading3),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                icon: Icons.school_rounded,
                value: '8',
                label: 'Courses',
                gradient: AppTheme.primaryGradient,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _buildModernStatCard(
                icon: Icons.check_circle_rounded,
                value: '24',
                label: 'Completed',
                gradient: AppTheme.successGradient,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                icon: Icons.timer_rounded,
                value: '42h',
                label: 'Study Time',
                gradient: AppTheme.accentGradient,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _buildModernStatCard(
                icon: Icons.workspace_premium_rounded,
                value: '5',
                label: 'Certificates',
                gradient: AppTheme.secondaryGradient,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.glassShadow,
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          ShaderMask(
            shaderCallback: (bounds) => gradient.createShader(bounds),
            child: Text(
              value,
              style: AppTheme.heading2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Your Progress', style: AppTheme.heading3),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.insights, size: 18),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.school_rounded,
                value: '8',
                label: 'Courses',
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_rounded,
                value: '24',
                label: 'Completed',
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.timer_rounded,
                value: '42h',
                label: 'Study Time',
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _buildStatCard(
                icon: Icons.workspace_premium_rounded,
                value: '5',
                label: 'Certificates',
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            value,
            style: AppTheme.heading2.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildModernQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                Icons.flash_on_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            const Text('Quick Actions', style: AppTheme.heading3),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.psychology_rounded,
                title: 'AI Chat',
                gradient: AppTheme.primaryGradient,
                onTap: () => _showChatbot(context),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.menu_book_rounded,
                title: 'My Books',
                gradient: AppTheme.successGradient,
                onTap: () => Navigator.pushNamed(context, '/books'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _buildModernQuickActionCard(
                icon: Icons.mic_rounded,
                title: 'Interview',
                gradient: AppTheme.accentGradient,
                onTap: () => Navigator.pushNamed(context, '/interview'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernQuickActionCard({
    required IconData icon,
    required String title,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingLg,
        ),
        decoration: BoxDecoration(
          gradient: AppTheme.glassGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.glassShadow,
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              title,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: AppTheme.heading3),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.psychology_rounded,
                title: 'AI Chat',
                color: AppTheme.primaryColor,
                onTap: () => _showChatbot(context),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.menu_book_rounded,
                title: 'My Books',
                color: AppTheme.successColor,
                onTap: () => Navigator.pushNamed(context, '/books'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.mic_rounded,
                title: 'Interview',
                color: AppTheme.accentColor,
                onTap: () => Navigator.pushNamed(context, '/interview'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingLg,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              title,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFeaturesGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            const Text('AI-Powered Features', style: AppTheme.heading3),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildModernFeatureCard(
          context,
          icon: Icons.route_rounded,
          title: 'Learning Path Generator',
          description: 'Get a personalized roadmap based on your goals',
          gradient: AppTheme.primaryGradient,
          onTap: () => _generateLearningPath(context),
          isLoading: _isGeneratingPath,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildModernFeatureCard(
          context,
          icon: Icons.work_rounded,
          title: 'Internship Finder',
          description: 'Discover relevant internships tailored to your profile',
          gradient: AppTheme.secondaryGradient,
          onTap: () => _generateInternships(context),
          isLoading: _isGeneratingInternships,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildModernFeatureCard(
          context,
          icon: Icons.description_rounded,
          title: 'Resume Optimizer',
          description: 'AI-powered resume analysis and optimization',
          gradient: AppTheme.accentGradient,
          onTap: () => Navigator.pushNamed(context, '/resume/analyzer'),
          isLoading: false,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildModernFeatureCard(
          context,
          icon: Icons.work_rounded,
          title: 'Job Application',
          description: 'AI-powered email generator for job applications',
          gradient: AppTheme.successGradient,
          onTap: () => Navigator.pushNamed(context, '/jobs'),
          isLoading: false,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildModernFeatureCard(
          context,
          icon: Icons.mic_rounded,
          title: 'Mock Interview',
          description: 'Practice with AI voice-powered interviews',
          gradient: AppTheme.warningGradient,
          onTap: () => Navigator.pushNamed(context, '/interview'),
          isLoading: false,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildModernFeatureCard(
          context,
          icon: Icons.auto_stories_rounded,
          title: 'Learn from Books',
          description: 'Upload books and learn with AI teaching',
          gradient: AppTheme.infoGradient,
          onTap: () => Navigator.pushNamed(context, '/books'),
          isLoading: false,
        ),
      ],
    );
  }

  Widget _buildModernFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          gradient: AppTheme.glassGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.glassShadow,
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: AppTheme.spacingLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.heading4.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI-Powered Features', style: AppTheme.heading3),
        const SizedBox(height: AppTheme.spacingMd),
        _buildFeatureCard(
          context,
          icon: Icons.route_rounded,
          title: 'Learning Path Generator',
          description: 'Get a personalized roadmap based on your goals',
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          onTap: () => _generateLearningPath(context),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildFeatureCard(
          context,
          icon: Icons.work_outline_rounded,
          title: 'Internship Finder',
          description: 'Discover opportunities that match your skills',
          gradient: const LinearGradient(
            colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
          ),
          onTap: () => _generateInternships(context),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildFeatureCard(
          context,
          icon: Icons.auto_stories_rounded,
          title: 'Learn from Books',
          description: 'Upload books and learn with AI teaching',
          gradient: const LinearGradient(
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          ),
          onTap: () => Navigator.pushNamed(context, '/books'),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildFeatureCard(
          context,
          icon: Icons.mic_rounded,
          title: 'Mock Interview',
          description: 'Practice with AI voice-powered interviews',
          gradient: const LinearGradient(
            colors: [Color(0xFFfa709a), Color(0xFFfee140)],
          ),
          onTap: () => Navigator.pushNamed(context, '/interview'),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildFeatureCard(
          context,
          icon: Icons.work_rounded,
          title: 'Job Application',
          description: 'AI-powered email generator for job applications',
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          onTap: () => Navigator.pushNamed(context, '/jobs'),
        ),
        
        // Resume Optimizer
        _buildFeatureCard(
          context,
          icon: Icons.description_rounded,
          title: 'Resume Optimizer',
          description: 'Analyze, tailor & improve your resume with AI',
          gradient: const LinearGradient(
            colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
          ),
          onTap: () => Navigator.pushNamed(context, '/resume/analyzer'),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.shadowMd,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppTheme.spacingLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.heading4),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        boxShadow: AppTheme.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              const Expanded(
                child: Text(
                  'Pro Tip',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Practice mock interviews regularly to build confidence. AI feedback helps you improve faster!',
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.95),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showChatbot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildChatBottomSheet(context),
    );
  }

  Widget _buildChatBottomSheet(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    final List<ChatMessage> messages = [];
    bool isLoading = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radius2xl),
                  topRight: Radius.circular(AppTheme.radius2xl),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Career Advisor', style: AppTheme.heading4),
                              Text('Ask me anything about your career', style: AppTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Messages
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 48,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingLg),
                                const Text('Start a conversation', style: AppTheme.heading4),
                                const SizedBox(height: AppTheme.spacingSm),
                                Text(
                                  'Ask about career paths, skills, or interview tips',
                                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(AppTheme.spacingLg),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isUser = message.role == 'user';
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? AppTheme.primaryColor
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  ),
                                  child: Text(
                                    message.content,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: isUser ? Colors.white : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppTheme.spacingMd),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: AppTheme.spacingMd),
                          Text('AI is thinking...', style: AppTheme.bodySmall),
                        ],
                      ),
                    ),
                  // Input
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            decoration: InputDecoration(
                              hintText: 'Ask about your career...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingLg,
                                vertical: AppTheme.spacingMd,
                              ),
                            ),
                            onSubmitted: (value) async {
                              if (value.trim().isEmpty || isLoading) return;
                              
                              final userMessage = ChatMessage(
                                role: 'user',
                                content: value,
                                timestamp: DateTime.now(),
                              );
                              
                              setState(() {
                                messages.add(userMessage);
                                isLoading = true;
                              });
                              
                              messageController.clear();
                              
                              try {
                                // Create sample profile for chat
                                final sampleProfile = UserProfile(
                                  uid: 'sample_user',
                                  email: 'user@example.com',
                                  fullName: 'Student',
                                  fieldOfStudy: 'Computer Science',
                                  skills: ['Python', 'JavaScript'],
                                  interests: ['AI', 'Web Development'],
                                  careerGoals: ['Software Engineer'],
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );
                                
                                final responseText = await _aiService.chatWithAI(value, sampleProfile, messages);
                                setState(() {
                                  messages.add(ChatMessage(
                                    role: 'ai',
                                    content: responseText,
                                    timestamp: DateTime.now(),
                                  ));
                                  isLoading = false;
                                });
                              } catch (e) {
                                setState(() {
                                  messages.add(ChatMessage(
                                    role: 'ai',
                                    content: 'Sorry, I encountered an error. Please try again.',
                                    timestamp: DateTime.now(),
                                  ));
                                  isLoading = false;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white),
                            onPressed: () async {
                              if (messageController.text.trim().isEmpty || isLoading) return;
                              
                              final userMessage = ChatMessage(
                                role: 'user',
                                content: messageController.text,
                                timestamp: DateTime.now(),
                              );
                              
                              setState(() {
                                messages.add(userMessage);
                                isLoading = true;
                              });
                              
                              final text = messageController.text;
                              messageController.clear();
                              
                              try {
                                // Create sample profile for chat
                                final sampleProfile = UserProfile(
                                  uid: 'sample_user',
                                  email: 'user@example.com',
                                  fullName: 'Student',
                                  fieldOfStudy: 'Computer Science',
                                  skills: ['Python', 'JavaScript'],
                                  interests: ['AI', 'Web Development'],
                                  careerGoals: ['Software Engineer'],
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );
                                
                                final responseText = await _aiService.chatWithAI(text, sampleProfile, messages);
                                setState(() {
                                  messages.add(ChatMessage(
                                    role: 'ai',
                                    content: responseText,
                                    timestamp: DateTime.now(),
                                  ));
                                  isLoading = false;
                                });
                              } catch (e) {
                                setState(() {
                                  messages.add(ChatMessage(
                                    role: 'ai',
                                    content: 'Sorry, I encountered an error. Please try again.',
                                    timestamp: DateTime.now(),
                                  ));
                                  isLoading = false;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateLearningPath(BuildContext context) async {
    setState(() => _isGeneratingPath = true);
    
    try {
      // Create sample profile - in production, get from auth provider
      final sampleProfile = UserProfile(
        uid: 'sample_user',
        email: 'user@example.com',
        fullName: 'Student',
        fieldOfStudy: 'Computer Science',
        skills: ['Python', 'JavaScript', 'React'],
        interests: ['AI', 'Machine Learning', 'Web Development'],
        careerGoals: ['Full Stack AI Engineer'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final path = await _aiService.generateLearningPath(sampleProfile);
      
      if (!mounted) return;
      
      if (path != null) {
        // Don't save to Firestore - keep in memory only (like resume optimizer)
        setState(() {
          _learningPath = path;
          _isGeneratingPath = false;
        });
        // Navigate to detailed screen instead of showing dialog
        Navigator.pushNamed(
          context,
          '/learning-path/detail',
          arguments: path,
        );
      } else {
        setState(() => _isGeneratingPath = false);
        _showErrorSnackBar('Failed to generate learning path');
      }
    } catch (e) {
      setState(() => _isGeneratingPath = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _generateInternships(BuildContext context) async {
    // Go directly to web scraping
    setState(() => _isGeneratingInternships = true);
    
    try {
        await _scrapeInternships(context);
    } catch (e) {
      setState(() => _isGeneratingInternships = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _getAIRecommendations(BuildContext context) async {
    try {
      // Create sample profile
      final sampleProfile = UserProfile(
        uid: 'sample_user',
        email: 'user@example.com',
        fullName: 'Student',
        fieldOfStudy: 'Computer Science',
        skills: ['Python', 'JavaScript', 'React'],
        interests: ['AI', 'Web Development'],
        careerGoals: ['Software Engineer'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final internships = await _aiService.getInternshipRecommendations(sampleProfile);
      
      if (!mounted) return;
      
      if (internships != null && internships.isNotEmpty) {
        setState(() {
          _internships = internships;
          _isGeneratingInternships = false;
        });
        _showInternshipsDialog(context, internships, isScraped: false);
      } else {
        setState(() => _isGeneratingInternships = false);
        _showErrorSnackBar('No internships found');
      }
    } catch (e) {
      setState(() => _isGeneratingInternships = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _scrapeInternships(BuildContext context) async {
    try {
      // Get search query, location, and sources from user
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          final queryController = TextEditingController();
          final locationController = TextEditingController(text: 'Remote');
          final selectedSources = <String>['indeed', 'linkedin', 'glassdoor', 'internships.com'];
          
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Search Real-Time Internships'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: queryController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Search query',
                          hintText: 'e.g., software engineering, data science',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location (optional)',
                          hintText: 'e.g., Remote, San Francisco, New York',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Job Boards to Search:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSourceChip('Indeed', 'indeed', selectedSources, dialogContext, setDialogState),
                          _buildSourceChip('LinkedIn', 'linkedin', selectedSources, dialogContext, setDialogState),
                          _buildSourceChip('Glassdoor', 'glassdoor', selectedSources, dialogContext, setDialogState),
                          _buildSourceChip('Internships.com', 'internships.com', selectedSources, dialogContext, setDialogState),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${selectedSources.length} source(s) selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (queryController.text.isNotEmpty && selectedSources.isNotEmpty) {
                        Navigator.pop(context, {
                          'query': queryController.text,
                          'location': locationController.text.trim(),
                          'sources': selectedSources,
                        });
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ],
              );
            },
          );
        },
      );
      
      if (result == null || result['query'] == null || result['query']!.isEmpty) {
        setState(() => _isGeneratingInternships = false);
        return;
      }
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Scraping internships from ${(result['sources'] as List?)?.length ?? 4} source(s)...',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // Scrape internships
      final internships = await _aiService.scrapeInternships(
        query: result['query']!,
        location: result['location']?.isEmpty == true ? '' : result['location']!,
        maxResults: 20,
        sources: (result['sources'] as List?)?.cast<String>() ?? [],
      );
      
      if (!mounted) return;
      
      if (internships.isNotEmpty) {
        setState(() {
          _internships = internships;
          _isGeneratingInternships = false;
        });
        _showInternshipsDialog(context, internships, isScraped: true);
      } else {
        setState(() => _isGeneratingInternships = false);
        _showErrorSnackBar('No internships found. Try a different search query.');
      }
    } catch (e) {
      setState(() => _isGeneratingInternships = false);
      _showErrorSnackBar('Error scraping internships: $e');
    }
  }

  void _showLearningPathDialog(BuildContext context, LearningPath path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.route_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  const Expanded(
                    child: Text('Your Learning Path', style: AppTheme.heading3),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),
              const Text('Your Personalized Learning Journey', style: AppTheme.heading4),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Based on your skills and career goals',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              AppComponents.badge(
                text: '⏱ ${path.timeline}',
                icon: Icons.timer_outlined,
              ),
              const SizedBox(height: AppTheme.spacingXl),
              const Text('Learning Phases', style: AppTheme.heading4),
              const SizedBox(height: AppTheme.spacingMd),
              Expanded(
                child: path.milestones.isEmpty 
                  ? Center(
                      child: Text(
                        'No phases available',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: path.milestones.length,
                      itemBuilder: (context, index) {
                        final milestone = path.milestones[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                          padding: const EdgeInsets.all(AppTheme.spacingLg),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.05),
                                AppTheme.secondaryColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      milestone,
                                      style: AppTheme.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle_outline,
                                color: AppTheme.successColor.withOpacity(0.5),
                                size: 20,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              if (path.resources.isNotEmpty) ...[
                const Text('Next Steps', style: AppTheme.heading4),
                const SizedBox(height: AppTheme.spacingSm),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: path.resources.take(3).map((resource) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_right_rounded, size: 20, color: AppTheme.successColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              resource,
                              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showInternshipsDialog(BuildContext context, List<Internship> internships, {bool isScraped = false}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isScraped 
                            ? [Colors.blue.shade400, Colors.blue.shade600]
                            : [Color(0xFFf093fb), Color(0xFFf5576c)],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      isScraped ? Icons.search : Icons.auto_awesome,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Internship Opportunities (${internships.length})',
                          style: AppTheme.heading3,
                        ),
                        if (isScraped)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Real-time from job boards',
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (internships.any((i) => i.source == 'Sample'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Sample results (scraping unavailable)',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: Colors.orange.shade700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        else
                          Text(
                            'AI-powered recommendations',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.purple.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXl),
              Expanded(
                child: ListView.builder(
                  itemCount: internships.length,
                  itemBuilder: (context, index) {
                    final internship = internships[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(internship.role, style: AppTheme.heading4),
                                    const SizedBox(height: 4),
                                    Text(
                                      internship.company,
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (internship.source != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    internship.source!,
                                    style: AppTheme.bodySmall.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            internship.description,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AppComponents.badge(
                                text: internship.location,
                                icon: Icons.location_on,
                                backgroundColor: Colors.blue.withOpacity(0.1),
                                textColor: Colors.blue,
                              ),
                              AppComponents.badge(
                                text: internship.duration,
                                icon: Icons.schedule,
                                backgroundColor: Colors.green.withOpacity(0.1),
                                textColor: Colors.green,
                              ),
                            ],
                          ),
                          if (internship.url != null && internship.url!.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacingMd),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(internship.url!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Apply Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }
}


