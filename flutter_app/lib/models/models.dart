class UserProfile {
  final String uid;
  final String email;
  final String fullName;
  final String? fieldOfStudy;
  final int? currentSemester;
  final List<String> skills;
  final List<String> interests;
  final List<String> careerGoals;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    this.fieldOfStudy,
    this.currentSemester,
    this.skills = const [],
    this.interests = const [],
    this.careerGoals = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse dates from Firestore
    DateTime _parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      // Handle Firestore Timestamp
      try {
        final timestamp = value as dynamic;
        if (timestamp.seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp.seconds * 1000);
        }
      } catch (e) {
        // Fallback
      }
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return UserProfile(
      uid: _toString(map['uid']),
      email: _toString(map['email']),
      fullName: _toString(map['fullName']),
      fieldOfStudy: map['fieldOfStudy'] != null ? _toString(map['fieldOfStudy']) : null,
      currentSemester: map['currentSemester'] is int ? map['currentSemester'] : (int.tryParse(_toString(map['currentSemester']))),
      skills: (map['skills'] as List?)?.map((s) => _toString(s)).toList() ?? [],
      interests: (map['interests'] as List?)?.map((i) => _toString(i)).toList() ?? [],
      careerGoals: (map['careerGoals'] as List?)?.map((g) => _toString(g)).toList() ?? [],
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'fieldOfStudy': fieldOfStudy,
      'currentSemester': currentSemester,
      'skills': skills,
      'interests': interests,
      'careerGoals': careerGoals,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class LearningPath {
  final String id;
  final String userId;
  final List<Course> courses;
  final List<String> resources;
  final String timeline;
  final List<String> milestones;
  final DateTime createdAt;

  LearningPath({
    required this.id,
    required this.userId,
    required this.courses,
    required this.resources,
    required this.timeline,
    required this.milestones,
    required this.createdAt,
  });

  factory LearningPath.fromMap(Map<String, dynamic> map) {
    // Handle createdAt - can be String, Timestamp, or DateTime
    DateTime createdAt;
    final createdAtValue = map['createdAt'];
    if (createdAtValue is String) {
      createdAt = DateTime.parse(createdAtValue);
    } else if (createdAtValue is DateTime) {
      createdAt = createdAtValue;
    } else if (createdAtValue != null) {
      // Handle Firestore Timestamp
      try {
        createdAt = (createdAtValue as dynamic).toDate();
      } catch (e) {
        // Fallback to current time if parsing fails
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }
    
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return LearningPath(
      id: _toString(map['id']),
      userId: _toString(map['userId']),
      courses: (map['courses'] as List?)
              ?.map((c) {
                // Handle both Map and already-parsed Course objects
                if (c is Map<String, dynamic>) {
                  try {
                    return Course.fromMap(c);
                  } catch (e) {
                    // If Course.fromMap fails, return null and filter it out
                    return null;
                  }
                }
                // If it's already a Course, return as-is (shouldn't happen but safe)
                return c is Course ? c : null;
              })
              .whereType<Course>()
              .toList() ??
          [],
      resources: (map['resources'] as List?)
              ?.map((r) => _toString(r))
              .toList() ?? [],
      timeline: _toString(map['timeline']),
      milestones: (map['milestones'] as List?)
              ?.map((m) => _toString(m))
              .toList() ?? [],
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'courses': courses.map((c) => c.toMap()).toList(),
      'resources': resources,
      'timeline': timeline,
      'milestones': milestones,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// DAILY TASK TRACKING MODELS
// ============================================================================

class DailyTask {
  final String id;
  final String pathId;
  final String phaseTitle;
  final String title;
  final String description;
  final TaskType type;
  final DateTime scheduledDate;
  final int estimatedMinutes;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? notes;
  final int priority; // 1 = High, 2 = Medium, 3 = Low

  DailyTask({
    required this.id,
    required this.pathId,
    required this.phaseTitle,
    required this.title,
    required this.description,
    required this.type,
    required this.scheduledDate,
    required this.estimatedMinutes,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
    this.priority = 2,
  });

  factory DailyTask.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse dates from Firestore (String, Timestamp, or DateTime)
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      // Handle Firestore Timestamp
      if (value.toString().contains('Timestamp')) {
        try {
          // Try to extract timestamp from Firestore Timestamp object
          final timestamp = value as dynamic;
          if (timestamp.seconds != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp.seconds * 1000);
          }
        } catch (e) {
          // Fallback: try parsing as string
          try {
            return DateTime.parse(value.toString());
          } catch (e2) {
            return null;
          }
        }
      }
      return null;
    }

    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return DailyTask(
      id: _toString(map['id']),
      pathId: _toString(map['path_id']),
      phaseTitle: _toString(map['phase_title']),
      title: _toString(map['title']),
      description: _toString(map['description']),
      type: TaskType.values.firstWhere(
        (e) => e.toString().split('.').last == _toString(map['type']),
        orElse: () => TaskType.study,
      ),
      scheduledDate: _parseDate(map['scheduled_date']) ?? DateTime.now(),
      estimatedMinutes: map['estimated_minutes'] is int 
          ? map['estimated_minutes'] 
          : (int.tryParse(_toString(map['estimated_minutes'])) ?? 30),
      isCompleted: map['is_completed'] is bool 
          ? map['is_completed'] 
          : (_toString(map['is_completed']).toLowerCase() == 'true'),
      completedAt: _parseDate(map['completed_at']),
      notes: map['notes'] != null ? _toString(map['notes']) : null,
      priority: map['priority'] is int 
          ? map['priority'] 
          : (int.tryParse(_toString(map['priority'])) ?? 2),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path_id': pathId,
      'phase_title': phaseTitle,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'scheduled_date': scheduledDate.toIso8601String(),
      'estimated_minutes': estimatedMinutes,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
      'priority': priority,
    };
  }

  DailyTask copyWith({
    String? id,
    String? pathId,
    String? phaseTitle,
    String? title,
    String? description,
    TaskType? type,
    DateTime? scheduledDate,
    int? estimatedMinutes,
    bool? isCompleted,
    DateTime? completedAt,
    String? notes,
    int? priority,
  }) {
    return DailyTask(
      id: id ?? this.id,
      pathId: pathId ?? this.pathId,
      phaseTitle: phaseTitle ?? this.phaseTitle,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
    );
  }
}

enum TaskType {
  coding,      // LeetCode, coding challenges
  study,       // Reading, watching tutorials
  project,     // Building projects
  practice,    // Hands-on practice
  review,      // Review previous concepts
  quiz,        // Self-assessment
  networking,  // Community engagement
}

class LearningPathProgress {
  final String pathId;
  final String userId;
  final int currentPhaseIndex;
  final double overallProgress; // 0.0 to 1.0
  final Map<int, double> phaseProgress; // phase index -> progress
  final int totalTasksCompleted;
  final int totalTasks;
  final int currentStreak; // days
  final int longestStreak;
  final DateTime lastActivityDate;
  final DateTime startedAt;
  final DateTime? completedAt;

  LearningPathProgress({
    required this.pathId,
    required this.userId,
    this.currentPhaseIndex = 0,
    this.overallProgress = 0.0,
    this.phaseProgress = const {},
    this.totalTasksCompleted = 0,
    this.totalTasks = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.lastActivityDate,
    required this.startedAt,
    this.completedAt,
  });

  factory LearningPathProgress.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse dates from Firestore
    DateTime _parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      // Handle Firestore Timestamp
      try {
        final timestamp = value as dynamic;
        if (timestamp.seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp.seconds * 1000);
        }
      } catch (e) {
        // Fallback
      }
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return LearningPathProgress(
      pathId: _toString(map['path_id']),
      userId: _toString(map['user_id']),
      currentPhaseIndex: map['current_phase_index'] is int 
          ? map['current_phase_index'] 
          : (int.tryParse(_toString(map['current_phase_index'])) ?? 0),
      overallProgress: (map['overall_progress'] ?? 0.0).toDouble(),
      phaseProgress: (map['phase_progress'] as Map?)?.map(
            (key, value) => MapEntry(int.parse(_toString(key)), (value as num).toDouble()),
          ) ?? {},
      totalTasksCompleted: map['total_tasks_completed'] is int 
          ? map['total_tasks_completed'] 
          : (int.tryParse(_toString(map['total_tasks_completed'])) ?? 0),
      totalTasks: map['total_tasks'] is int 
          ? map['total_tasks'] 
          : (int.tryParse(_toString(map['total_tasks'])) ?? 0),
      currentStreak: map['current_streak'] is int 
          ? map['current_streak'] 
          : (int.tryParse(_toString(map['current_streak'])) ?? 0),
      longestStreak: map['longest_streak'] is int 
          ? map['longest_streak'] 
          : (int.tryParse(_toString(map['longest_streak'])) ?? 0),
      lastActivityDate: _parseDate(map['last_activity_date']),
      startedAt: _parseDate(map['started_at']),
      completedAt: map['completed_at'] != null ? _parseDate(map['completed_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path_id': pathId,
      'user_id': userId,
      'current_phase_index': currentPhaseIndex,
      'overall_progress': overallProgress,
      'phase_progress': phaseProgress.map((key, value) => MapEntry(key.toString(), value)),
      'total_tasks_completed': totalTasksCompleted,
      'total_tasks': totalTasks,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_activity_date': lastActivityDate.toIso8601String(),
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

// ENHANCED LEARNING PATH MODELS
// ============================================================================

class DetailedLearningPath {
  final String title;
  final String description;
  final String totalDuration;
  final String difficultyLevel;
  final List<LearningPhase> phases;
  final CareerOutcome careerOutcomes;
  final List<String> skillsAcquired;
  final List<String> prerequisites;
  final String dailyTimeCommitment;
  final List<SuccessStory> successStories;
  final List<CommunityResource> communityResources;
  final List<Certification> certifications;
  final List<String> nextSteps;
  int currentPhase;
  Map<int, double> phaseProgress; // phase index -> progress (0-1)

  DetailedLearningPath({
    required this.title,
    required this.description,
    required this.totalDuration,
    required this.difficultyLevel,
    required this.phases,
    required this.careerOutcomes,
    required this.skillsAcquired,
    required this.prerequisites,
    required this.dailyTimeCommitment,
    required this.successStories,
    required this.communityResources,
    required this.certifications,
    required this.nextSteps,
    this.currentPhase = 0,
    Map<int, double>? phaseProgress,
  }) : phaseProgress = phaseProgress ?? {};

  factory DetailedLearningPath.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return DetailedLearningPath(
      title: _toString(map['title']),
      description: _toString(map['description']),
      totalDuration: _toString(map['totalDuration']),
      difficultyLevel: _toString(map['difficultyLevel'] ?? 'intermediate'),
      phases: (map['phases'] as List?)
              ?.map((p) {
                if (p is Map<String, dynamic>) {
                  return LearningPhase.fromMap(p);
                }
                return null;
              })
              .whereType<LearningPhase>()
              .toList() ??
          [],
      careerOutcomes: CareerOutcome.fromMap(map['careerOutcomes'] ?? {}),
      skillsAcquired: _toStringList(map['skillsAcquired']),
      prerequisites: _toStringList(map['prerequisites']),
      dailyTimeCommitment: _toString(map['dailyTimeCommitment']),
      successStories: (map['successStories'] as List?)
              ?.map((s) {
                if (s is Map<String, dynamic>) {
                  return SuccessStory.fromMap(s);
                }
                return null;
              })
              .whereType<SuccessStory>()
              .toList() ??
          [],
      communityResources: (map['communityResources'] as List?)
              ?.map((r) {
                if (r is Map<String, dynamic>) {
                  return CommunityResource.fromMap(r);
                }
                return null;
              })
              .whereType<CommunityResource>()
              .toList() ??
          [],
      certifications: (map['certifications'] as List?)
              ?.map((c) {
                if (c is Map<String, dynamic>) {
                  return Certification.fromMap(c);
                }
                return null;
              })
              .whereType<Certification>()
              .toList() ??
          [],
      nextSteps: _toStringList(map['nextSteps']),
      currentPhase: map['currentPhase'] is int 
          ? map['currentPhase'] 
          : (int.tryParse(_toString(map['currentPhase'])) ?? 0),
      phaseProgress: (map['phaseProgress'] as Map?)?.map(
            (key, value) => MapEntry(
              int.tryParse(_toString(key)) ?? 0,
              (value as num?)?.toDouble() ?? 0.0,
            ),
          ) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'totalDuration': totalDuration,
      'difficultyLevel': difficultyLevel,
      'phases': phases.map((p) => p.toMap()).toList(),
      'careerOutcomes': careerOutcomes.toMap(),
      'skillsAcquired': skillsAcquired,
      'prerequisites': prerequisites,
      'dailyTimeCommitment': dailyTimeCommitment,
      'successStories': successStories.map((s) => s.toMap()).toList(),
      'communityResources': communityResources.map((r) => r.toMap()).toList(),
      'certifications': certifications.map((c) => c.toMap()).toList(),
      'nextSteps': nextSteps,
      'currentPhase': currentPhase,
      'phaseProgress': phaseProgress,
    };
  }

  double get overallProgress {
    if (phases.isEmpty) return 0;
    final total = phaseProgress.values.fold(0.0, (sum, val) => sum + val);
    return total / phases.length;
  }
}

class LearningPhase {
  final int phaseNumber;
  final String title;
  final String duration;
  final String description;
  final List<Topic> topics;
  final List<LearningResource> learningResources;
  final List<PracticeProject> practiceProjects;
  final List<WeekPlan> weekByWeekPlan;
  final List<String> assessmentCriteria;
  bool isCompleted;
  Map<int, bool> topicCompletion; // topic index -> completed

  LearningPhase({
    required this.phaseNumber,
    required this.title,
    required this.duration,
    required this.description,
    required this.topics,
    required this.learningResources,
    required this.practiceProjects,
    required this.weekByWeekPlan,
    required this.assessmentCriteria,
    this.isCompleted = false,
    Map<int, bool>? topicCompletion,
  }) : topicCompletion = topicCompletion ?? {};

  factory LearningPhase.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return LearningPhase(
      phaseNumber: map['phaseNumber'] is int 
          ? map['phaseNumber'] 
          : (int.tryParse(_toString(map['phaseNumber'])) ?? 0),
      title: _toString(map['title']),
      duration: _toString(map['duration']),
      description: _toString(map['description']),
      topics: (map['topics'] as List?)
              ?.map((t) {
                if (t is Map<String, dynamic>) {
                  return Topic.fromMap(t);
                }
                return null;
              })
              .whereType<Topic>()
              .toList() ??
          [],
      learningResources: (map['learningResources'] as List?)
              ?.map((r) {
                if (r is Map<String, dynamic>) {
                  return LearningResource.fromMap(r);
                }
                return null;
              })
              .whereType<LearningResource>()
              .toList() ??
          [],
      practiceProjects: (map['practiceProjects'] as List?)
              ?.map((p) {
                if (p is Map<String, dynamic>) {
                  return PracticeProject.fromMap(p);
                }
                return null;
              })
              .whereType<PracticeProject>()
              .toList() ??
          [],
      weekByWeekPlan: (map['weekByWeekPlan'] as List?)
              ?.map((w) {
                if (w is Map<String, dynamic>) {
                  return WeekPlan.fromMap(w);
                }
                return null;
              })
              .whereType<WeekPlan>()
              .toList() ??
          [],
      assessmentCriteria: _toStringList(map['assessmentCriteria']),
      isCompleted: map['isCompleted'] is bool 
          ? map['isCompleted'] 
          : (_toString(map['isCompleted']).toLowerCase() == 'true'),
      topicCompletion: (map['topicCompletion'] as Map?)?.map(
            (key, value) => MapEntry(
              int.tryParse(_toString(key)) ?? 0,
              value is bool ? value : (_toString(value).toLowerCase() == 'true'),
            ),
          ) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phaseNumber': phaseNumber,
      'title': title,
      'duration': duration,
      'description': description,
      'topics': topics.map((t) => t.toMap()).toList(),
      'learningResources': learningResources.map((r) => r.toMap()).toList(),
      'practiceProjects': practiceProjects.map((p) => p.toMap()).toList(),
      'weekByWeekPlan': weekByWeekPlan.map((w) => w.toMap()).toList(),
      'assessmentCriteria': assessmentCriteria,
      'isCompleted': isCompleted,
      'topicCompletion': topicCompletion,
    };
  }

  double get progress {
    if (topics.isEmpty) return 0;
    final completed = topicCompletion.values.where((v) => v).length;
    return completed / topics.length;
  }
}

class Topic {
  final String name;
  final List<String> subtopics;
  final int estimatedHours;
  final String difficulty;

  Topic({
    required this.name,
    required this.subtopics,
    required this.estimatedHours,
    required this.difficulty,
  });

  factory Topic.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return Topic(
      name: _toString(map['name']),
      subtopics: _toStringList(map['subtopics']),
      estimatedHours: map['estimatedHours'] is int 
          ? map['estimatedHours'] 
          : (int.tryParse(_toString(map['estimatedHours'])) ?? 0),
      difficulty: _toString(map['difficulty'] ?? 'intermediate'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subtopics': subtopics,
      'estimatedHours': estimatedHours,
      'difficulty': difficulty,
    };
  }
}

class LearningResource {
  final String title;
  final String type;
  final String provider;
  final String url;
  final String duration;
  final String cost;
  final String description;

  LearningResource({
    required this.title,
    required this.type,
    required this.provider,
    required this.url,
    required this.duration,
    required this.cost,
    required this.description,
  });

  factory LearningResource.fromMap(Map<String, dynamic> map) {
    return LearningResource(
      title: map['title'] ?? '',
      type: map['type'] ?? 'course',
      provider: map['provider'] ?? '',
      url: map['url'] ?? '',
      duration: map['duration'] ?? '',
      cost: map['cost'] ?? 'free',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'provider': provider,
      'url': url,
      'duration': duration,
      'cost': cost,
      'description': description,
    };
  }
}

class PracticeProject {
  final String title;
  final String description;
  final String difficulty;
  final int estimatedHours;
  final List<String> skills;
  final String? githubExample;
  bool isCompleted;

  PracticeProject({
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedHours,
    required this.skills,
    this.githubExample,
    this.isCompleted = false,
  });

  factory PracticeProject.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return PracticeProject(
      title: _toString(map['title']),
      description: _toString(map['description']),
      difficulty: _toString(map['difficulty'] ?? 'intermediate'),
      estimatedHours: map['estimatedHours'] is int 
          ? map['estimatedHours'] 
          : (int.tryParse(_toString(map['estimatedHours'])) ?? 0),
      skills: _toStringList(map['skills']),
      githubExample: map['githubExample'] != null ? _toString(map['githubExample']) : null,
      isCompleted: map['isCompleted'] is bool 
          ? map['isCompleted'] 
          : (_toString(map['isCompleted']).toLowerCase() == 'true'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'estimatedHours': estimatedHours,
      'skills': skills,
      'githubExample': githubExample,
      'isCompleted': isCompleted,
    };
  }
}

class WeekPlan {
  final int week;
  final String focus;
  final List<String> tasks;
  final String deliverable;
  bool isCompleted;

  WeekPlan({
    required this.week,
    required this.focus,
    required this.tasks,
    required this.deliverable,
    this.isCompleted = false,
  });

  factory WeekPlan.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return WeekPlan(
      week: map['week'] is int 
          ? map['week'] 
          : (int.tryParse(_toString(map['week'])) ?? 0),
      focus: _toString(map['focus']),
      tasks: _toStringList(map['tasks']),
      deliverable: _toString(map['deliverable']),
      isCompleted: map['isCompleted'] is bool 
          ? map['isCompleted'] 
          : (_toString(map['isCompleted']).toLowerCase() == 'true'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'week': week,
      'focus': focus,
      'tasks': tasks,
      'deliverable': deliverable,
      'isCompleted': isCompleted,
    };
  }
}

class CareerOutcome {
  final List<String> jobTitles;
  final String averageSalary;
  final String marketDemand;
  final String requiredYearsExperience;

  CareerOutcome({
    required this.jobTitles,
    required this.averageSalary,
    required this.marketDemand,
    required this.requiredYearsExperience,
  });

  factory CareerOutcome.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return CareerOutcome(
      jobTitles: _toStringList(map['jobTitles']),
      averageSalary: _toString(map['averageSalary']),
      marketDemand: _toString(map['marketDemand'] ?? 'medium'),
      requiredYearsExperience: _toString(map['requiredYearsExperience'] ?? '0-2 years'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobTitles': jobTitles,
      'averageSalary': averageSalary,
      'marketDemand': marketDemand,
      'requiredYearsExperience': requiredYearsExperience,
    };
  }
}

class SuccessStory {
  final String achievement;
  final String timeline;

  SuccessStory({
    required this.achievement,
    required this.timeline,
  });

  factory SuccessStory.fromMap(Map<String, dynamic> map) {
    return SuccessStory(
      achievement: map['achievement'] ?? '',
      timeline: map['timeline'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'achievement': achievement,
      'timeline': timeline,
    };
  }
}

class CommunityResource {
  final String name;
  final String url;
  final String description;

  CommunityResource({
    required this.name,
    required this.url,
    required this.description,
  });

  factory CommunityResource.fromMap(Map<String, dynamic> map) {
    return CommunityResource(
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'description': description,
    };
  }
}

class Certification {
  final String name;
  final String provider;
  final String cost;
  final String value;

  Certification({
    required this.name,
    required this.provider,
    required this.cost,
    required this.value,
  });

  factory Certification.fromMap(Map<String, dynamic> map) {
    return Certification(
      name: map['name'] ?? '',
      provider: map['provider'] ?? '',
      cost: map['cost'] ?? 'free',
      value: map['value'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'provider': provider,
      'cost': cost,
      'value': value,
    };
  }
}

class Course {
  final String name;
  final String description;
  final String duration;
  final String level;

  Course({
    required this.name,
    required this.description,
    required this.duration,
    required this.level,
  });

  factory Course.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return Course(
      name: _toString(map['name']),
      description: _toString(map['description']),
      duration: _toString(map['duration']),
      level: _toString(map['level']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'duration': duration,
      'level': level,
    };
  }
}

class Internship {
  final String company;
  final String role;
  final String description;
  final List<String> requirements;
  final String location;
  final String duration;
  final String? url; // URL to apply
  final String? source; // Source: "Indeed", "LinkedIn", "AI Generated", etc.
  final String? scrapedAt; // When it was scraped

  Internship({
    required this.company,
    required this.role,
    required this.description,
    required this.requirements,
    required this.location,
    required this.duration,
    this.url,
    this.source,
    this.scrapedAt,
  });

  factory Internship.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return Internship(
      company: _toString(map['company']),
      role: _toString(map['role'] ?? map['title']),
      description: _toString(map['description']),
      requirements: (map['requiredSkills'] as List? ?? map['requirements'] as List? ?? [])
          .map((r) => _toString(r))
          .toList(),
      location: _toString(map['location']),
      duration: _toString(map['duration'] ?? 'Not specified'),
      url: map['url'] != null ? _toString(map['url']) : null,
      source: map['source'] != null ? _toString(map['source']) : null,
      scrapedAt: map['scraped_at'] != null ? _toString(map['scraped_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company': company,
      'role': role,
      'title': role,
      'description': description,
      'requirements': requirements,
      'requiredSkills': requirements,
      'location': location,
      'duration': duration,
      if (url != null) 'url': url,
      if (source != null) 'source': source,
      if (scrapedAt != null) 'scraped_at': scrapedAt,
    };
  }
}

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse dates from Firestore
    DateTime _parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      // Handle Firestore Timestamp
      try {
        final timestamp = value as dynamic;
        if (timestamp.seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp.seconds * 1000);
        }
      } catch (e) {
        // Fallback
      }
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return ChatMessage(
      role: _toString(map['role']),
      content: _toString(map['content']),
      timestamp: _parseDate(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============================================================================
// BOOK LEARNING MODELS ("Upload → Learn → Master")
// ============================================================================

class BookMetadata {
  final String bookId;
  final String title;
  final String? author;
  final int? totalPages;
  final int totalChapters;
  final int totalConcepts;
  final DateTime uploadedAt;

  BookMetadata({
    required this.bookId,
    required this.title,
    this.author,
    this.totalPages,
    required this.totalChapters,
    required this.totalConcepts,
    required this.uploadedAt,
  });

  factory BookMetadata.fromMap(Map<String, dynamic> map) {
    return BookMetadata(
      bookId: map['book_id'] ?? '',
      title: map['metadata']['title'] ?? 'Unknown',
      author: map['metadata']['author'],
      totalPages: map['metadata']['total_pages'],
      totalChapters: map['metadata']['total_chapters'] ?? 0,
      totalConcepts: map['total_concepts'] ?? 0,
      uploadedAt: DateTime.now(),
    );
  }
}

class BookChapter {
  final int number;
  final String title;
  final double masteryPercentage;
  final String status; // 'mastered', 'in_progress', 'needs_work', 'not_started'

  BookChapter({
    required this.number,
    required this.title,
    this.masteryPercentage = 0.0,
    this.status = 'not_started',
  });

  factory BookChapter.fromMap(Map<String, dynamic> map) {
    return BookChapter(
      number: map['number'] ?? map['chapter'] ?? 0,
      title: map['title'] ?? 'Chapter ${map['number'] ?? 0}',
      masteryPercentage: (map['mastery'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'not_started',
    );
  }
}

class Concept {
  final String id;
  final String name;
  final String definition;
  final String difficulty; // 'beginner', 'intermediate', 'advanced'
  final List<String> prerequisites;
  final List<String> examples;

  Concept({
    required this.id,
    required this.name,
    required this.definition,
    required this.difficulty,
    this.prerequisites = const [],
    this.examples = const [],
  });

  factory Concept.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return Concept(
      id: _toString(map['id']),
      name: _toString(map['name']),
      definition: _toString(map['definition']),
      difficulty: _toString(map['difficulty'] ?? 'intermediate'),
      prerequisites: _toStringList(map['prerequisites']),
      examples: _toStringList(map['examples']),
    );
  }
}

class TeachingContent {
  final Concept concept;
  final String explanation;
  final String example;
  final String question;
  final int totalConcepts;
  final int currentIndex;

  TeachingContent({
    required this.concept,
    required this.explanation,
    required this.example,
    required this.question,
    required this.totalConcepts,
    required this.currentIndex,
  });

  factory TeachingContent.fromMap(Map<String, dynamic> map) {
    return TeachingContent(
      concept: Concept.fromMap(map['concept']),
      explanation: map['teaching']['explanation'] ?? '',
      example: map['teaching']['example'] ?? '',
      question: map['teaching']['question'] ?? '',
      totalConcepts: map['total_concepts'] ?? 1,
      currentIndex: map['current_concept_index'] ?? 0,
    );
  }
}

class UnderstandingEvaluation {
  final int score;
  final String feedback;
  final List<String> missingIdeas;
  final List<String> misconceptions;
  final String nextAction; // 'continue' or 'review'

  UnderstandingEvaluation({
    required this.score,
    required this.feedback,
    this.missingIdeas = const [],
    this.misconceptions = const [],
    required this.nextAction,
  });

  factory UnderstandingEvaluation.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    final eval = map['evaluation'] ?? map;
    return UnderstandingEvaluation(
      score: eval['score'] is int 
          ? eval['score'] 
          : (int.tryParse(_toString(eval['score'])) ?? 0),
      feedback: _toString(eval['feedback']),
      missingIdeas: _toStringList(eval['missing_ideas']),
      misconceptions: _toStringList(eval['misconceptions']),
      nextAction: _toString(map['next_action'] ?? 'continue'),
    );
  }
}

class QuizQuestion {
  final String type; // 'mcq', 'short_answer', 'explain'
  final String question;
  final List<String>? options; // For MCQ
  final String? correctAnswer; // For MCQ
  final String? explanation;
  final List<String>? keyPoints; // For short answer

  QuizQuestion({
    required this.type,
    required this.question,
    this.options,
    this.correctAnswer,
    this.explanation,
    this.keyPoints,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String>? _toStringList(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return null;
    }

    return QuizQuestion(
      type: _toString(map['type'] ?? 'short_answer'),
      question: _toString(map['question']),
      options: _toStringList(map['options']),
      correctAnswer: map['correct_answer'],
      explanation: map['explanation'] != null ? _toString(map['explanation']) : null,
      keyPoints: _toStringList(map['key_points']),
    );
  }
}

class MasteryDashboard {
  final double overallMastery;
  final List<BookChapter> chapters;
  final int totalConcepts;
  final int masteredConcepts;
  final DateTime lastUpdated;

  MasteryDashboard({
    required this.overallMastery,
    required this.chapters,
    required this.totalConcepts,
    required this.masteredConcepts,
    required this.lastUpdated,
  });

  factory MasteryDashboard.fromMap(Map<String, dynamic> map) {
    return MasteryDashboard(
      overallMastery: (map['overall_mastery'] ?? 0.0).toDouble(),
      chapters: (map['chapters'] as List)
          .map((ch) => BookChapter.fromMap(ch))
          .toList(),
      totalConcepts: map['total_concepts'] ?? 0,
      masteredConcepts: map['mastered_concepts'] ?? 0,
      lastUpdated: DateTime.parse(map['last_updated'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// ============================================================================
// MOCK INTERVIEW MODELS
// ============================================================================

class InterviewSession {
  final String sessionId;
  final String userId;
  final String interviewType; // technical, behavioral, hr
  final String difficulty; // easy, medium, hard
  final int totalQuestions;
  final int currentQuestionIndex;
  final String status; // in_progress, completed
  final DateTime startedAt;
  final DateTime? completedAt;

  InterviewSession({
    required this.sessionId,
    required this.userId,
    required this.interviewType,
    required this.difficulty,
    required this.totalQuestions,
    required this.currentQuestionIndex,
    required this.status,
    required this.startedAt,
    this.completedAt,
  });

  factory InterviewSession.fromMap(Map<String, dynamic> map) {
    return InterviewSession(
      sessionId: map['session_id'] ?? '',
      userId: map['user_id'] ?? '',
      interviewType: map['interview_type'] ?? 'technical',
      difficulty: map['difficulty'] ?? 'medium',
      totalQuestions: map['total_questions'] ?? 0,
      currentQuestionIndex: map['current_question_index'] ?? 0,
      status: map['status'] ?? 'in_progress',
      startedAt: DateTime.parse(map['started_at'] ?? DateTime.now().toIso8601String()),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
    );
  }
}

class InterviewQuestion {
  final int index;
  final String question;
  final String type; // technical, behavioral, situational, hr
  final String? audioUrl;

  InterviewQuestion({
    required this.index,
    required this.question,
    required this.type,
    this.audioUrl,
  });

  factory InterviewQuestion.fromMap(Map<String, dynamic> map) {
    return InterviewQuestion(
      index: map['index'] ?? 0,
      question: map['question'] ?? '',
      type: map['type'] ?? 'technical',
      audioUrl: map['audio_url'],
    );
  }
}

class InterviewFeedback {
  final double score; // 0-10
  final List<String> strengths;
  final List<String> areasForImprovement;
  final String feedback;
  final String? followUpSuggestion;
  final String questionType;

  InterviewFeedback({
    required this.score,
    required this.strengths,
    required this.areasForImprovement,
    required this.feedback,
    this.followUpSuggestion,
    required this.questionType,
  });

  factory InterviewFeedback.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return InterviewFeedback(
      score: (map['score'] ?? 0.0).toDouble(),
      strengths: _toStringList(map['strengths']),
      areasForImprovement: _toStringList(map['areas_for_improvement']),
      feedback: _toString(map['feedback']),
      followUpSuggestion: map['follow_up_suggestion'] != null ? _toString(map['follow_up_suggestion']) : null,
      questionType: _toString(map['question_type']),
    );
  }
}

class InterviewReport {
  final String sessionId;
  final String interviewType;
  final double overallScore;
  final String overallAssessment; // Excellent, Good, Average, Needs Improvement
  final Map<String, double?> scoresByCategory;
  final int totalQuestions;
  final List<String> strengths;
  final List<String> areasForImprovement;
  final int durationMinutes;
  final List<String> recommendations;

  InterviewReport({
    required this.sessionId,
    required this.interviewType,
    required this.overallScore,
    required this.overallAssessment,
    required this.scoresByCategory,
    required this.totalQuestions,
    required this.strengths,
    required this.areasForImprovement,
    required this.durationMinutes,
    required this.recommendations,
  });

  factory InterviewReport.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return InterviewReport(
      sessionId: _toString(map['session_id']),
      interviewType: _toString(map['interview_type']),
      overallScore: (map['overall_score'] ?? 0.0).toDouble(),
      overallAssessment: _toString(map['overall_assessment']),
      scoresByCategory: (map['scores_by_category'] as Map?)?.map(
            (key, value) => MapEntry(
              _toString(key),
              value != null ? (value as num).toDouble() : null,
        ),
          ) ?? {},
      totalQuestions: map['total_questions'] is int 
          ? map['total_questions'] 
          : (int.tryParse(_toString(map['total_questions'])) ?? 0),
      strengths: _toStringList(map['strengths']),
      areasForImprovement: _toStringList(map['areas_for_improvement']),
      durationMinutes: map['duration_minutes'] is int 
          ? map['duration_minutes'] 
          : (int.tryParse(_toString(map['duration_minutes'])) ?? 0),
      recommendations: _toStringList(map['recommendations']),
    );
  }
}

class ResumeSummary {
  final String? name;
  final List<String> skills;
  final List<String> experience;

  ResumeSummary({
    this.name,
    required this.skills,
    required this.experience,
  });

  factory ResumeSummary.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return ResumeSummary(
      name: map['name'] != null ? _toString(map['name']) : null,
      skills: _toStringList(map['skills']),
      experience: _toStringList(map['experience']),
    );
  }
}

// JOB APPLICATION AGENT MODELS
// ============================================================================

class JobApplication {
  final String id;
  final String userId;
  final String jobTitle;
  final String company;
  final String jobDescription;
  final String? jobUrl;
  final String status; // draft, sent, interview, rejected, accepted
  final String generatedEmail;
  final String? customizations;
  final DateTime createdAt;
  final DateTime? sentAt;

  JobApplication({
    required this.id,
    required this.userId,
    required this.jobTitle,
    required this.company,
    required this.jobDescription,
    this.jobUrl,
    this.status = 'draft',
    required this.generatedEmail,
    this.customizations,
    required this.createdAt,
    this.sentAt,
  });

  factory JobApplication.fromMap(Map<String, dynamic> map) {
    return JobApplication(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      jobTitle: map['job_title'] ?? '',
      company: map['company'] ?? '',
      jobDescription: map['job_description'] ?? '',
      jobUrl: map['job_url'],
      status: map['status'] ?? 'draft',
      generatedEmail: map['generated_email'] ?? '',
      customizations: map['customizations'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      sentAt: map['sent_at'] != null ? DateTime.parse(map['sent_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'job_title': jobTitle,
      'company': company,
      'job_description': jobDescription,
      'job_url': jobUrl,
      'status': status,
      'generated_email': generatedEmail,
      'customizations': customizations,
      'created_at': createdAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
    };
  }
}

class JobMatchScore {
  final double overallScore; // 0-100
  final Map<String, double> skillMatch; // skill -> match percentage
  final List<String> matchingSkills;
  final List<String> missingSkills;
  final List<String> recommendations;
  final String summary;

  JobMatchScore({
    required this.overallScore,
    required this.skillMatch,
    required this.matchingSkills,
    required this.missingSkills,
    required this.recommendations,
    required this.summary,
  });

  factory JobMatchScore.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return JobMatchScore(
      overallScore: (map['overall_score'] ?? 0.0).toDouble(),
      skillMatch: (map['skill_match'] as Map?)?.map(
            (key, value) => MapEntry(
              _toString(key),
              (value as num?)?.toDouble() ?? 0.0,
            ),
          ) ?? {},
      matchingSkills: _toStringList(map['matching_skills']),
      missingSkills: _toStringList(map['missing_skills']),
      recommendations: _toStringList(map['recommendations']),
      summary: _toString(map['summary']),
    );
  }
}

// RESUME OPTIMIZER MODELS
// ============================================================================

class ResumeAnalysis {
  final double overallScore;
  final Map<String, double> sectionScores;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> missingSections;
  final List<String> suggestions;
  final KeywordOptimization keywordOptimization;
  final List<String> atsIssues;
  final DateTime timestamp;

  ResumeAnalysis({
    required this.overallScore,
    required this.sectionScores,
    required this.strengths,
    required this.weaknesses,
    required this.missingSections,
    required this.suggestions,
    required this.keywordOptimization,
    required this.atsIssues,
    required this.timestamp,
  });

  factory ResumeAnalysis.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    final analysis = map['analysis'] ?? map;
    return ResumeAnalysis(
      overallScore: (analysis['overall_score'] ?? 0.0).toDouble(),
      sectionScores: (analysis['section_scores'] as Map?)?.map(
            (key, value) => MapEntry(
              _toString(key),
              (value as num?)?.toDouble() ?? 0.0,
        ),
          ) ?? {},
      strengths: _toStringList(analysis['strengths']),
      weaknesses: _toStringList(analysis['weaknesses']),
      missingSections: _toStringList(analysis['missing_sections']),
      suggestions: _toStringList(analysis['suggestions']),
      keywordOptimization: KeywordOptimization.fromMap(
        analysis['keyword_optimization'] ?? {},
      ),
      atsIssues: _toStringList(analysis['ats_issues']),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(_toString(map['timestamp']))
          : DateTime.now(),
    );
  }
}

class KeywordOptimization {
  final List<String> strongKeywords;
  final List<String> missingKeywords;
  final List<String> suggestions;

  KeywordOptimization({
    required this.strongKeywords,
    required this.missingKeywords,
    required this.suggestions,
  });

  factory KeywordOptimization.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    return KeywordOptimization(
      strongKeywords: _toStringList(map['strong_keywords']),
      missingKeywords: _toStringList(map['missing_keywords']),
      suggestions: _toStringList(map['suggestions']),
    );
  }
}

class ResumeTailoring {
  final String optimizedSummary;
  final List<String> skillsToEmphasize;
  final List<String> skillsToAdd;
  final List<ExperienceBullet> experienceBullets;
  final List<String> keywordsToInclude;
  final List<String> projectsToHighlight;
  final String overallStrategy;
  final DateTime timestamp;

  ResumeTailoring({
    required this.optimizedSummary,
    required this.skillsToEmphasize,
    required this.skillsToAdd,
    required this.experienceBullets,
    required this.keywordsToInclude,
    required this.projectsToHighlight,
    required this.overallStrategy,
    required this.timestamp,
  });

  factory ResumeTailoring.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    final optimization = map['optimization'] ?? map;
    return ResumeTailoring(
      optimizedSummary: _toString(optimization['optimized_summary']),
      skillsToEmphasize: _toStringList(optimization['skills_to_emphasize']),
      skillsToAdd: _toStringList(optimization['skills_to_add']),
      experienceBullets: (optimization['experience_bullets'] as List<dynamic>?)
              ?.map((e) {
                if (e is Map<String, dynamic>) {
                  return ExperienceBullet.fromMap(e);
                }
                return null;
              })
              .whereType<ExperienceBullet>()
              .toList() ??
          [],
      keywordsToInclude: _toStringList(optimization['keywords_to_include']),
      projectsToHighlight: _toStringList(optimization['projects_to_highlight']),
      overallStrategy: _toString(optimization['overall_strategy']),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(_toString(map['timestamp']))
          : DateTime.now(),
    );
  }
}

class ExperienceBullet {
  final String original;
  final String optimized;
  final String why;

  ExperienceBullet({
    required this.original,
    required this.optimized,
    required this.why,
  });

  factory ExperienceBullet.fromMap(Map<String, dynamic> map) {
    return ExperienceBullet(
      original: map['original'] ?? '',
      optimized: map['optimized'] ?? '',
      why: map['why'] ?? '',
    );
  }
}

class BulletPointsResult {
  final List<String> bulletPoints;
  final List<String> tips;
  final DateTime timestamp;

  BulletPointsResult({
    required this.bulletPoints,
    required this.tips,
    required this.timestamp,
  });

  factory BulletPointsResult.fromMap(Map<String, dynamic> map) {
    // Helper to safely convert to string
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely convert list to List<String>
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((v) => _toString(v)).toList();
      }
      return [];
    }

    final result = map['result'] ?? map;
    return BulletPointsResult(
      bulletPoints: _toStringList(result['bullet_points']),
      tips: _toStringList(result['tips']),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(_toString(map['timestamp']))
          : DateTime.now(),
    );
  }
}
