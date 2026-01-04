import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/models.dart';

class GoogleCalendarService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'openid', // Explicitly request OpenID for idToken
      'email',
      'profile',
      calendar.CalendarApi.calendarScope,
      calendar.CalendarApi.calendarEventsScope,
      'https://www.googleapis.com/auth/gmail.send',
    ],
    // Request idToken explicitly
    hostedDomain: null, // Allow any Google account
  );

  GoogleSignInAccount? _currentUser;
  calendar.CalendarApi? _calendarApi;

  /// Get GoogleSignIn instance (for GmailService)
  GoogleSignIn get googleSignIn => _googleSignIn;

  /// Initialize and sign in
  Future<bool> signIn() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user == null) return false;

      _currentUser = user;
      
      // Get authenticated HTTP client
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) return false;

      // Initialize Calendar API
      _calendarApi = calendar.CalendarApi(authClient);
      
      return true;
    } catch (e) {
      print('❌ Error signing in with Google: $e');
      return false;
    }
  }

  /// Check if user is signed in
  bool get isSignedIn => _currentUser != null;

  /// Get current user
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _calendarApi = null;
  }

  /// Add a single task to Google Calendar
  Future<bool> addTaskToCalendar(DailyTask task) async {
    if (_calendarApi == null) {
      print('❌ Calendar API not initialized. Please sign in first.');
      return false;
    }

    try {
      final startTime = task.scheduledDate;
      final endTime = startTime.add(Duration(minutes: task.estimatedMinutes));

      final startDateTime = calendar.EventDateTime()
        ..dateTime = startTime
        ..timeZone = 'UTC';

      final endDateTime = calendar.EventDateTime()
        ..dateTime = endTime
        ..timeZone = 'UTC';

      final reminders = calendar.EventReminders()
        ..useDefault = false
        ..overrides = [
          calendar.EventReminder()
            ..method = 'popup'
            ..minutes = 30,
        ];

      final event = calendar.Event()
        ..summary = '${_getTaskEmoji(task.type)} ${task.title}'
        ..description = '${task.description}\n\n'
            'Phase: ${task.phaseTitle}\n'
            'Estimated Time: ${task.estimatedMinutes} minutes\n'
            'Priority: ${_getPriorityText(task.priority)}'
        ..start = startDateTime
        ..end = endDateTime
        ..reminders = reminders;

      // Add color based on priority
      if (task.priority == 1) {
        event.colorId = '11'; // Red for high priority
      } else if (task.priority == 2) {
        event.colorId = '5'; // Yellow for medium
      } else {
        event.colorId = '2'; // Green for low
      }

      await _calendarApi!.events.insert(event, 'primary');
      print('✅ Added task to Google Calendar: ${task.title}');
      return true;
    } catch (e) {
      print('❌ Error adding task to calendar: $e');
      return false;
    }
  }

  /// Add multiple tasks to Google Calendar
  Future<int> addTasksToCalendar(List<DailyTask> tasks, {Function(int)? onProgress}) async {
    int successCount = 0;
    
    for (int i = 0; i < tasks.length; i++) {
      final success = await addTaskToCalendar(tasks[i]);
      if (success) successCount++;
      
      onProgress?.call(i + 1);
      
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    return successCount;
  }

  /// Get upcoming events from Google Calendar
  Future<List<calendar.Event>> getUpcomingEvents({int days = 7}) async {
    if (_calendarApi == null) {
      print('❌ Calendar API not initialized. Please sign in first.');
      return [];
    }

    try {
      final now = DateTime.now();
      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: now,
        timeMax: now.add(Duration(days: days)),
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items ?? [];
    } catch (e) {
      print('❌ Error fetching calendar events: $e');
      return [];
    }
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

