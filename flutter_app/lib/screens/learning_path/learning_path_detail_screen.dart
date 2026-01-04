import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/learning_path_service.dart';
import '../../theme/app_theme.dart';

class LearningPathDetailScreen extends StatefulWidget {
  final LearningPath learningPath;

  const LearningPathDetailScreen({
    super.key,
    required this.learningPath,
  });

  @override
  State<LearningPathDetailScreen> createState() => _LearningPathDetailScreenState();
}

class _LearningPathDetailScreenState extends State<LearningPathDetailScreen> with SingleTickerProviderStateMixin {
  final LearningPathService _pathService = LearningPathService();
  late TabController _tabController;
  
  List<DailyTask> _todaysTasks = [];
  List<DailyTask> _allTasks = [];
  bool _isLoading = true;
  bool _isGeneratingTasks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Calculate progress from in-memory tasks (like resume optimizer)
  LearningPathProgress? get _progress {
    if (_allTasks.isEmpty) return null;
    
    final totalTasks = _allTasks.length;
    final completedTasks = _allTasks.where((t) => t.isCompleted).length;
    final overallProgress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    
    // Calculate streak (simplified - just check if tasks completed today)
    final today = DateTime.now();
    final tasksToday = _allTasks.where((t) =>
        t.isCompleted &&
        t.completedAt != null &&
        t.completedAt!.year == today.year &&
        t.completedAt!.month == today.month &&
        t.completedAt!.day == today.day).isNotEmpty;
    
    return LearningPathProgress(
      pathId: widget.learningPath.id,
      userId: '', // Not needed for in-memory
      overallProgress: overallProgress,
      totalTasksCompleted: completedTasks,
      totalTasks: totalTasks,
      currentStreak: tasksToday ? 1 : 0,
      longestStreak: tasksToday ? 1 : 0,
      lastActivityDate: today,
      startedAt: _allTasks.isNotEmpty 
          ? _allTasks.map((t) => t.scheduledDate).reduce((a, b) => a.isBefore(b) ? a : b)
          : DateTime.now(),
      completedAt: overallProgress >= 1.0 ? DateTime.now() : null,
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Don't load from Firestore - keep in memory only (like resume optimizer)
    // Tasks and progress are stored in state after generation
    
    // Filter today's tasks from _allTasks
    final today = DateTime.now();
    final todayTasks = _allTasks.where((task) {
      return task.scheduledDate.year == today.year &&
             task.scheduledDate.month == today.month &&
             task.scheduledDate.day == today.day;
    }).toList();

      setState(() {
      _todaysTasks = todayTasks;
        _isLoading = false;
      });
  }

  // Download ICS file for web
  void _downloadIcsFile(String content, String filename) {
    final blob = html.Blob([content], 'text/calendar');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _generateAndSaveTasks() async {
    setState(() => _isGeneratingTasks = true);
    
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? 
                   authProvider.calendarService.currentUser?.email ?? 
                   '';

    if (userId.isEmpty) {
      print('❌ Error: No user ID available');
      setState(() => _isGeneratingTasks = false);
      return;
    }

    try {
      // Generate daily tasks for ONE WEEK ONLY (7 days)
      final today = DateTime.now();
      final weekTasks = <DailyTask>[];
      
      // Generate tasks for each day of the week (7 days)
      for (int day = 0; day < 7; day++) {
        final currentDate = today.add(Duration(days: day));
        
        // Get tasks for this day using the service's internal method
        // We'll generate 3 tasks per day
        final dayTasks = await _generateTasksForSingleDay(
        pathId: widget.learningPath.id,
        userId: userId,
          date: currentDate,
        phases: widget.learningPath.milestones,
        );
        
        weekTasks.addAll(dayTasks);
      }

      print('✅ Generated ${weekTasks.length} tasks for 1 week');
      
      final tasks = weekTasks;

      // Save to Firestore so tasks can be updated/completed
      await _pathService.saveDailyTasks(userId, tasks);

      // Also store in state for UI
      setState(() {
        _allTasks = tasks;
      });

      print('💾 Tasks saved to Firestore');

      // 🎯 AUTO-ADD TO GOOGLE CALENDAR (First week only - 7 days = 21 tasks)
      final firstWeekTasks = tasks.take(21).toList();
      
      if (mounted && firstWeekTasks.isNotEmpty) {
        // Check if Google Calendar is signed in
        final authProvider = context.read<AuthProvider>();
        if (!authProvider.calendarService.isSignedIn) {
          final signedIn = await authProvider.calendarService.signIn();
          if (!signedIn) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please sign in to Google Calendar to add tasks'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
            await _loadData();
            return;
          }
        }

        // Show progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Adding ${firstWeekTasks.length} tasks to Google Calendar...'),
                    ],
                  ),
                ),
        );

        try {
          // Add tasks to Google Calendar
          final successCount = await authProvider.calendarService.addTasksToCalendar(
                    firstWeekTasks,
            onProgress: (count) {
              // Progress callback if needed
            },
          );
                  
                  if (mounted) {
            Navigator.pop(context); // Close progress dialog
            
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                content: Text('✅ Added $successCount/${firstWeekTasks.length} tasks to Google Calendar!'),
                        backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 3),
                      ),
                    );
                  }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // Close progress dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error adding to calendar: $e'),
                backgroundColor: AppTheme.errorColor,
          ),
        );
          }
        }
      }

      // Reload data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Generated ${tasks.length} daily tasks!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      print('❌ Error generating tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating tasks: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingTasks = false);
    }
  }

  Future<void> _addTasksToGoogleCalendar() async {
    try {
      // Add tasks for the next 7 days
      final tasks = await _pathService.getTasksForDate(
        context.read<AuthProvider>().user!.uid,
        DateTime.now(),
      );

      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tasks to add. Generate tasks first!')),
        );
        return;
      }

      // Open first task in Google Calendar
      await _pathService.addTaskToGoogleCalendar(tasks.first);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗓️ Adding ${tasks.length} tasks to Google Calendar...'),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: 'Continue',
              onPressed: () async {
                for (int i = 1; i < tasks.length; i++) {
                  await Future.delayed(const Duration(seconds: 1));
                  await _pathService.addTaskToGoogleCalendar(tasks[i]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to calendar: $e')),
        );
      }
    }
  }

  Future<void> _toggleTaskCompletion(DailyTask task) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? 
                   authProvider.calendarService.currentUser?.email ?? 
                   '';

    if (userId.isEmpty) {
      print('❌ Error: No user ID available');
      return;
    }

    try {
      await _pathService.completeTask(userId, task);
      await _loadData(); // Reload to update progress
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundSecondary,
              AppTheme.backgroundPrimary,
              AppTheme.backgroundTertiary,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _buildProgressCard(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTodayTab(),
                      _buildPhasesTab(),
                      _buildStatsTab(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Learning Path', style: AppTheme.heading4),
                Text(
                  widget.learningPath.timeline,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          if (_progress == null)
            ElevatedButton.icon(
              onPressed: _isGeneratingTasks ? null : _generateAndSaveTasks,
              icon: _isGeneratingTasks
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.calendar_today_rounded),
              onPressed: _addTasksToGoogleCalendar,
              tooltip: 'Add to Google Calendar',
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    if (_progress == null) {
      return Container(
        margin: const EdgeInsets.all(AppTheme.spacingLg),
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.shadowMedium,
        ),
        child: Column(
          children: [
            const Icon(Icons.rocket_launch_rounded, size: 48, color: Colors.white),
            const SizedBox(height: AppTheme.spacingMd),
            const Text(
              'Ready to Start Your Journey?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Generate daily tasks and track your progress',
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLg),
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMedium,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.show_chart_rounded,
                label: 'Progress',
                value: '${(_progress!.overallProgress * 100).toStringAsFixed(0)}%',
                color: AppTheme.primaryColor,
              ),
              _buildStatItem(
                icon: Icons.local_fire_department_rounded,
                label: 'Streak',
                value: '${_progress!.currentStreak} days',
                color: AppTheme.warningColor,
              ),
              _buildStatItem(
                icon: Icons.task_alt_rounded,
                label: 'Completed',
                value: '${_progress!.totalTasksCompleted}/${_progress!.totalTasks}',
                color: AppTheme.successColor,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              value: _progress!.overallProgress,
              minHeight: 8,
              backgroundColor: AppTheme.backgroundSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Text(value, style: AppTheme.heading4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.shadowSm,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'Phases'),
          Tab(text: 'Stats'),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    final today = DateTime.now();
    final formattedDate = '${_getWeekday(today.weekday)}, ${_getMonth(today.month)} ${today.day}';
    
    return Column(
      children: [
        // Date Header
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          color: AppTheme.backgroundSecondary,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.today_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today\'s Tasks', style: AppTheme.heading4),
                    Text(
                      formattedDate,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ),
              if (_todaysTasks.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    '${_todaysTasks.where((t) => t.isCompleted).length}/${_todaysTasks.length}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Tasks List
        Expanded(
          child: _todaysTasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 64,
                        color: AppTheme.textTertiary.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      Text(
                        'No tasks for today',
                        style: AppTheme.heading4.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        _progress != null
                            ? 'You have ${_progress!.totalTasks} total tasks.\nThey might be scheduled for other days.'
                            : 'Generate tasks to get started',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  itemCount: _todaysTasks.length,
                  itemBuilder: (context, index) {
                    final task = _todaysTasks[index];
                    return _buildTaskCard(task);
                  },
                ),
        ),
      ],
    );
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildTaskCard(DailyTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowSm,
        border: Border.all(
          color: task.isCompleted ? AppTheme.successColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: () => _toggleTaskCompletion(task),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getTaskColor(task.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    task.isCompleted ? Icons.check_circle_rounded : _getTaskIcon(task.type),
                    color: task.isCompleted ? AppTheme.successColor : _getTaskColor(task.type),
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
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            '${task.estimatedMinutes} min',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(task.priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              _getPriorityText(task.priority),
                              style: AppTheme.bodySmall.copyWith(
                                color: _getPriorityColor(task.priority),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today_rounded),
                  onPressed: () => _pathService.addTaskToGoogleCalendar(task),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhasesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      itemCount: widget.learningPath.milestones.length,
      itemBuilder: (context, index) {
        final phase = widget.learningPath.milestones[index];
        final phaseProgress = _progress?.phaseProgress[index] ?? 0.0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Text(phase, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                child: LinearProgressIndicator(
                  value: phaseProgress,
                  minHeight: 6,
                  backgroundColor: AppTheme.backgroundSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                '${(phaseProgress * 100).toStringAsFixed(0)}% Complete',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Learning Statistics', style: AppTheme.heading3),
          const SizedBox(height: AppTheme.spacingLg),
          _buildStatCard(
            title: 'Longest Streak',
            value: '${_progress?.longestStreak ?? 0} days 🔥',
            subtitle: 'Keep it up!',
            color: AppTheme.warningColor,
          ),
          _buildStatCard(
            title: 'Total Tasks',
            value: '${_progress?.totalTasks ?? 0}',
            subtitle: 'Tasks generated',
            color: AppTheme.primaryColor,
          ),
          _buildStatCard(
            title: 'Completed Tasks',
            value: '${_progress?.totalTasksCompleted ?? 0}',
            subtitle: 'Tasks finished',
            color: AppTheme.successColor,
          ),
          _buildStatCard(
            title: 'Started On',
            value: _progress != null 
                ? DateFormat('MMM d, yyyy').format(_progress!.startedAt)
                : 'Not started',
            subtitle: 'Journey began',
            color: AppTheme.infoColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowSm,
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(Icons.insights_rounded, color: color, size: 28),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary)),
                Text(value, style: AppTheme.heading3),
                Text(subtitle, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
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

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return AppTheme.errorColor;
      case 2:
        return AppTheme.warningColor;
      case 3:
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 1:
        return 'High';
      case 2:
        return 'Medium';
      case 3:
        return 'Low';
      default:
        return 'Medium';
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
}

