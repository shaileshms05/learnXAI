import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

class LearningPathService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Public getter for debugging
  FirebaseFirestore get firestore => _firestore;

  // ============================================================================
  // DAILY TASK MANAGEMENT
  // ============================================================================

  /// Generate daily tasks from a learning path
  Future<List<DailyTask>> generateDailyTasks({
    required String pathId,
    required String userId,
    required List<String> phases,
    required DateTime startDate,
    int tasksPerDay = 3,
  }) async {
    final List<DailyTask> tasks = [];
    DateTime currentDate = startDate;
    int taskId = 0;

    for (int phaseIndex = 0; phaseIndex < phases.length; phaseIndex++) {
      final phase = phases[phaseIndex];
      
      // Extract phase title and duration from format: "Phase Title (X months)"
      final match = RegExp(r'(.+?)\s*\((\d+)\s*months?\)').firstMatch(phase);
      final phaseTitle = match?.group(1) ?? phase;
      final durationMonths = int.tryParse(match?.group(2) ?? '1') ?? 1;
      
      // Calculate days for this phase (assuming 30 days per month, 5 working days per week)
      final workingDaysInPhase = (durationMonths * 30 * 5 / 7).round();
      
      // Generate daily tasks for this phase
      for (int day = 0; day < workingDaysInPhase; day++) {
        // Skip weekends
        if (currentDate.weekday == DateTime.saturday || currentDate.weekday == DateTime.sunday) {
          currentDate = currentDate.add(const Duration(days: 1));
          continue;
        }

        // Generate diverse tasks for each day
        final dayTasks = _generateTasksForDay(
          pathId: pathId,
          phaseTitle: phaseTitle,
          dayNumber: day + 1,
          date: currentDate,
          baseTaskId: taskId,
        );

        tasks.addAll(dayTasks.take(tasksPerDay));
        taskId += tasksPerDay;
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    return tasks;
  }

  List<DailyTask> _generateTasksForDay({
    required String pathId,
    required String phaseTitle,
    required int dayNumber,
    required DateTime date,
    required int baseTaskId,
  }) {
    final tasks = <DailyTask>[];
    
    // Coding challenge (always include)
    tasks.add(DailyTask(
      id: 'task_${baseTaskId}_0',
      pathId: pathId,
      phaseTitle: phaseTitle,
      title: 'Complete 2 LeetCode Problems',
      description: 'Solve 2 coding problems related to $phaseTitle concepts',
      type: TaskType.coding,
      scheduledDate: date,
      estimatedMinutes: 60,
      priority: 1,
    ));

    // Learning task (rotate between study types)
    final studyTasks = [
      DailyTask(
        id: 'task_${baseTaskId}_1',
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
        id: 'task_${baseTaskId}_1',
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
        id: 'task_${baseTaskId}_1',
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
    tasks.add(studyTasks[dayNumber % studyTasks.length]);

    // Project/Practice task (every few days)
    if (dayNumber % 3 == 0) {
      tasks.add(DailyTask(
        id: 'task_${baseTaskId}_2',
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
        id: 'task_${baseTaskId}_2',
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

  /// Save daily tasks to Firebase
  Future<void> saveDailyTasks(String userId, List<DailyTask> tasks) async {
    final batch = _firestore.batch();
    
    for (final task in tasks) {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_tasks')
          .doc(task.id);
      batch.set(docRef, task.toMap());
    }

    await batch.commit();
  }

  /// Get tasks for a specific date
  Future<List<DailyTask>> getTasksForDate(String userId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Simplified query to avoid composite index requirement
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_tasks')
        .where('scheduled_date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('scheduled_date', isLessThan: endOfDay.toIso8601String())
        .get();

    // Sort in memory instead of using orderBy in query
    final tasks = snapshot.docs
        .map((doc) => DailyTask.fromMap(doc.data()))
        .toList();
    
    // Sort by priority (1 = high first) then by scheduled date
    tasks.sort((a, b) {
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.scheduledDate.compareTo(b.scheduledDate);
    });
    
    return tasks;
  }

  /// Get today's tasks
  Future<List<DailyTask>> getTodaysTasks(String userId) async {
    return getTasksForDate(userId, DateTime.now());
  }

  /// Mark task as completed
  Future<void> completeTask(String userId, DailyTask task) async {
    final updatedTask = task.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    // Use set with merge to create document if it doesn't exist, or update if it does
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_tasks')
        .doc(task.id)
        .set(updatedTask.toMap(), SetOptions(merge: true));

    // Update progress
    await _updateProgress(userId, task.pathId);
  }

  /// Update learning path progress
  Future<void> _updateProgress(String userId, String pathId) async {
    // Get all tasks for this path
    final allTasksSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_tasks')
        .where('path_id', isEqualTo: pathId)
        .get();

    final allTasks = allTasksSnapshot.docs
        .map((doc) => DailyTask.fromMap(doc.data()))
        .toList();

    final completedTasks = allTasks.where((t) => t.isCompleted).length;
    final totalTasks = allTasks.length;
    final overallProgress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    // Calculate streak
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final tasksToday = allTasks.where((t) =>
        t.isCompleted &&
        t.completedAt != null &&
        t.completedAt!.year == today.year &&
        t.completedAt!.month == today.month &&
        t.completedAt!.day == today.day).isNotEmpty;
    
    final tasksYesterday = allTasks.where((t) =>
        t.isCompleted &&
        t.completedAt != null &&
        t.completedAt!.year == yesterday.year &&
        t.completedAt!.month == yesterday.month &&
        t.completedAt!.day == yesterday.day).isNotEmpty;

    // Get existing progress or create new
    final progressDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('learning_progress')
        .doc(pathId)
        .get();

    int currentStreak = 0;
    int longestStreak = 0;

    if (progressDoc.exists) {
      final existingProgress = LearningPathProgress.fromMap(progressDoc.data()!);
      currentStreak = tasksToday ? (tasksYesterday ? existingProgress.currentStreak + 1 : 1) : 0;
      longestStreak = currentStreak > existingProgress.longestStreak 
          ? currentStreak 
          : existingProgress.longestStreak;
    } else {
      currentStreak = tasksToday ? 1 : 0;
      longestStreak = currentStreak;
    }

    final progress = LearningPathProgress(
      pathId: pathId,
      userId: userId,
      overallProgress: overallProgress,
      totalTasksCompleted: completedTasks,
      totalTasks: totalTasks,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastActivityDate: DateTime.now(),
      startedAt: progressDoc.exists
          ? LearningPathProgress.fromMap(progressDoc.data()!).startedAt
          : DateTime.now(),
      completedAt: overallProgress >= 1.0 ? DateTime.now() : null,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('learning_progress')
        .doc(pathId)
        .set(progress.toMap());
  }

  /// Get learning path progress
  Future<LearningPathProgress?> getProgress(String userId, String pathId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('learning_progress')
        .doc(pathId)
        .get();

    if (doc.exists) {
      return LearningPathProgress.fromMap(doc.data()!);
    }
    return null;
  }

  // ============================================================================
  // ICS FILE GENERATION (BETTER THAN INDIVIDUAL CALENDAR LINKS)
  // ============================================================================

  /// Generate ICS file content for multiple tasks
  String generateIcsFile(List<DailyTask> tasks, String calendarName) {
    final buffer = StringBuffer();
    
    // ICS Header
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Student AI Platform//Learning Path//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-CALNAME:$calendarName');
    buffer.writeln('X-WR-TIMEZONE:UTC');
    
    // Add each task as an event
    for (final task in tasks) {
      final startTime = task.scheduledDate;
      final endTime = startTime.add(Duration(minutes: task.estimatedMinutes));
      
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${task.id}@studentai.com');
      buffer.writeln('DTSTAMP:${_formatDateTimeForIcs(DateTime.now())}');
      buffer.writeln('DTSTART:${_formatDateTimeForIcs(startTime)}');
      buffer.writeln('DTEND:${_formatDateTimeForIcs(endTime)}');
      buffer.writeln('SUMMARY:${_getTaskEmoji(task.type)} ${task.title}');
      buffer.writeln('DESCRIPTION:${task.description}\\n\\nPhase: ${task.phaseTitle}\\nPriority: ${_getPriorityText(task.priority)}');
      buffer.writeln('PRIORITY:${task.priority}');
      buffer.writeln('STATUS:CONFIRMED');
      buffer.writeln('TRANSP:OPAQUE');
      buffer.writeln('END:VEVENT');
    }
    
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  String _formatDateTimeForIcs(DateTime dt) {
    // Format: YYYYMMDDTHHmmssZ
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}Z';
  }

  // ============================================================================
  // GOOGLE CALENDAR INTEGRATION
  // ============================================================================

  /// Generate Google Calendar event URL for a task
  String generateGoogleCalendarUrl(DailyTask task) {
    final startTime = task.scheduledDate;
    final endTime = startTime.add(Duration(minutes: task.estimatedMinutes));

    // Format: YYYYMMDDTHHmmssZ
    final startStr = _formatDateTimeForGoogle(startTime);
    final endStr = _formatDateTimeForGoogle(endTime);

    final title = Uri.encodeComponent('${_getTaskEmoji(task.type)} ${task.title}');
    final description = Uri.encodeComponent(
      '${task.description}\n\n'
      'Phase: ${task.phaseTitle}\n'
      'Estimated Time: ${task.estimatedMinutes} minutes\n'
      'Priority: ${_getPriorityText(task.priority)}'
    );

    return 'https://www.google.com/calendar/render?action=TEMPLATE'
        '&text=$title'
        '&dates=$startStr/$endStr'
        '&details=$description'
        '&sf=true'
        '&output=xml';
  }

  /// Add single task to Google Calendar
  Future<void> addTaskToGoogleCalendar(DailyTask task) async {
    final url = generateGoogleCalendarUrl(task);
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch Google Calendar');
    }
  }

  /// Add all tasks for a date range to Google Calendar
  Future<void> addTasksToGoogleCalendar(List<DailyTask> tasks) async {
    for (final task in tasks) {
      await addTaskToGoogleCalendar(task);
      // Small delay to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  String _formatDateTimeForGoogle(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}00Z';
  }

  String _getTaskEmoji(TaskType type) {
    switch (type) {
      case TaskType.coding:
        return '💻';
      case TaskType.study:
        return '📚';
      case TaskType.project:
        return '🚀';
      case TaskType.practice:
        return '🔨';
      case TaskType.review:
        return '📝';
      case TaskType.quiz:
        return '❓';
      case TaskType.networking:
        return '🤝';
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 1:
        return '🔴 High';
      case 2:
        return '🟡 Medium';
      case 3:
        return '🟢 Low';
      default:
        return 'Medium';
    }
  }
}

