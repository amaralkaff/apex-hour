import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

/// Tracks daily work patterns for AI health recommendations
class WorkPatternService {
  static final WorkPatternService _instance = WorkPatternService._internal();
  static WorkPatternService get instance => _instance;
  WorkPatternService._internal();

  static const String _workPatternsKey = 'work_patterns';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Records when a task is completed
  Future<void> recordTaskCompletion(Task task) async {
    await _ensureInitialized();
    
    final today = _getDateKey(DateTime.now());
    final patterns = await _getWorkPatterns();
    
    if (!patterns.containsKey(today)) {
      patterns[today] = WorkDayPattern();
    }
    
    patterns[today]!.addTaskCompletion(task);
    await _saveWorkPatterns(patterns);
  }

  /// Records when user starts/ends work
  Future<void> recordWorkSession({
    required DateTime startTime,
    DateTime? endTime,
  }) async {
    await _ensureInitialized();
    
    final today = _getDateKey(startTime);
    final patterns = await _getWorkPatterns();
    
    if (!patterns.containsKey(today)) {
      patterns[today] = WorkDayPattern();
    }
    
    patterns[today]!.recordWorkSession(startTime, endTime);
    await _saveWorkPatterns(patterns);
  }

  /// Records a health recommendation interaction
  Future<void> recordRecommendationInteraction({
    required String recommendation,
    required bool wasFollowed,
    DateTime? timestamp,
  }) async {
    await _ensureInitialized();
    
    final today = _getDateKey(timestamp ?? DateTime.now());
    final patterns = await _getWorkPatterns();
    
    if (!patterns.containsKey(today)) {
      patterns[today] = WorkDayPattern();
    }
    
    patterns[today]!.addRecommendationInteraction(
      recommendation,
      wasFollowed,
      timestamp ?? DateTime.now(),
    );
    await _saveWorkPatterns(patterns);
  }

  /// Gets work pattern for a specific date
  Future<WorkDayPattern?> getWorkPattern(DateTime date) async {
    await _ensureInitialized();
    final patterns = await _getWorkPatterns();
    return patterns[_getDateKey(date)];
  }

  /// Gets work patterns for the last N days
  Future<Map<String, WorkDayPattern>> getRecentWorkPatterns({int days = 7}) async {
    await _ensureInitialized();
    final patterns = await _getWorkPatterns();
    final recentPatterns = <String, WorkDayPattern>{};
    
    for (int i = 0; i < days; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = _getDateKey(date);
      if (patterns.containsKey(key)) {
        recentPatterns[key] = patterns[key]!;
      }
    }
    
    return recentPatterns;
  }

  /// Gets weekly work summary
  Future<WeeklyWorkSummary> getWeeklySummary() async {
    final patterns = await getRecentWorkPatterns(days: 7);
    return WeeklyWorkSummary.fromPatterns(patterns);
  }

  /// Clears old data (keep only last 30 days)
  Future<void> cleanupOldData() async {
    await _ensureInitialized();
    final patterns = await _getWorkPatterns();
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    
    final keysToRemove = patterns.keys
        .where((key) => _parseDateKey(key).isBefore(cutoffDate))
        .toList();
    
    for (final key in keysToRemove) {
      patterns.remove(key);
    }
    
    await _saveWorkPatterns(patterns);
  }

  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  Future<Map<String, WorkDayPattern>> _getWorkPatterns() async {
    final jsonString = _prefs!.getString(_workPatternsKey);
    if (jsonString == null) return {};
    
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    final patterns = <String, WorkDayPattern>{};
    
    for (final entry in jsonData.entries) {
      patterns[entry.key] = WorkDayPattern.fromJson(entry.value);
    }
    
    return patterns;
  }

  Future<void> _saveWorkPatterns(Map<String, WorkDayPattern> patterns) async {
    final jsonData = <String, dynamic>{};
    for (final entry in patterns.entries) {
      jsonData[entry.key] = entry.value.toJson();
    }
    
    await _prefs!.setString(_workPatternsKey, jsonEncode(jsonData));
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

/// Represents a single day's work pattern
class WorkDayPattern {
  DateTime? workStartTime;
  DateTime? workEndTime;
  int deepWorkTasksCompleted = 0;
  int shallowWorkTasksCompleted = 0;
  int windDownTasksCompleted = 0;
  List<TaskCompletionRecord> taskCompletions = [];
  List<RecommendationInteraction> recommendationInteractions = [];
  int totalWorkMinutes = 0;

  WorkDayPattern();

  void addTaskCompletion(Task task) {
    taskCompletions.add(TaskCompletionRecord(
      taskType: task.type,
      completedAt: task.completedAt ?? DateTime.now(),
      estimatedMinutes: task.estimatedMinutes,
    ));

    switch (task.type) {
      case TaskType.deepWork:
        deepWorkTasksCompleted++;
        break;
      case TaskType.shallowWork:
        shallowWorkTasksCompleted++;
        break;
      case TaskType.windDown:
        windDownTasksCompleted++;
        break;
    }
  }

  void recordWorkSession(DateTime start, DateTime? end) {
    workStartTime ??= start;
    if (end != null) {
      workEndTime = end;
      totalWorkMinutes = end.difference(workStartTime!).inMinutes;
    }
  }

  void addRecommendationInteraction(String recommendation, bool wasFollowed, DateTime timestamp) {
    recommendationInteractions.add(RecommendationInteraction(
      recommendation: recommendation,
      wasFollowed: wasFollowed,
      timestamp: timestamp,
    ));
  }

  Map<String, dynamic> toJson() {
    return {
      'workStartTime': workStartTime?.millisecondsSinceEpoch,
      'workEndTime': workEndTime?.millisecondsSinceEpoch,
      'deepWorkTasksCompleted': deepWorkTasksCompleted,
      'shallowWorkTasksCompleted': shallowWorkTasksCompleted,
      'windDownTasksCompleted': windDownTasksCompleted,
      'taskCompletions': taskCompletions.map((t) => t.toJson()).toList(),
      'recommendationInteractions': recommendationInteractions.map((r) => r.toJson()).toList(),
      'totalWorkMinutes': totalWorkMinutes,
    };
  }

  factory WorkDayPattern.fromJson(Map<String, dynamic> json) {
    final pattern = WorkDayPattern();
    pattern.workStartTime = json['workStartTime'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(json['workStartTime'])
        : null;
    pattern.workEndTime = json['workEndTime'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['workEndTime'])
        : null;
    pattern.deepWorkTasksCompleted = json['deepWorkTasksCompleted'] ?? 0;
    pattern.shallowWorkTasksCompleted = json['shallowWorkTasksCompleted'] ?? 0;
    pattern.windDownTasksCompleted = json['windDownTasksCompleted'] ?? 0;
    pattern.totalWorkMinutes = json['totalWorkMinutes'] ?? 0;
    
    if (json['taskCompletions'] != null) {
      pattern.taskCompletions = (json['taskCompletions'] as List)
          .map((t) => TaskCompletionRecord.fromJson(t))
          .toList();
    }
    
    if (json['recommendationInteractions'] != null) {
      pattern.recommendationInteractions = (json['recommendationInteractions'] as List)
          .map((r) => RecommendationInteraction.fromJson(r))
          .toList();
    }
    
    return pattern;
  }
}

class TaskCompletionRecord {
  final TaskType taskType;
  final DateTime completedAt;
  final int estimatedMinutes;

  TaskCompletionRecord({
    required this.taskType,
    required this.completedAt,
    required this.estimatedMinutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskType': taskType.name,
      'completedAt': completedAt.millisecondsSinceEpoch,
      'estimatedMinutes': estimatedMinutes,
    };
  }

  factory TaskCompletionRecord.fromJson(Map<String, dynamic> json) {
    return TaskCompletionRecord(
      taskType: TaskType.values.firstWhere((t) => t.name == json['taskType']),
      completedAt: DateTime.fromMillisecondsSinceEpoch(json['completedAt']),
      estimatedMinutes: json['estimatedMinutes'],
    );
  }
}

class RecommendationInteraction {
  final String recommendation;
  final bool wasFollowed;
  final DateTime timestamp;

  RecommendationInteraction({
    required this.recommendation,
    required this.wasFollowed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'recommendation': recommendation,
      'wasFollowed': wasFollowed,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory RecommendationInteraction.fromJson(Map<String, dynamic> json) {
    return RecommendationInteraction(
      recommendation: json['recommendation'],
      wasFollowed: json['wasFollowed'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}

class WeeklyWorkSummary {
  final int totalWorkDays;
  final double averageWorkHours;
  final int totalDeepWorkTasks;
  final int totalShallowWorkTasks;
  final int totalWindDownTasks;
  final double recommendationFollowRate;

  WeeklyWorkSummary({
    required this.totalWorkDays,
    required this.averageWorkHours,
    required this.totalDeepWorkTasks,
    required this.totalShallowWorkTasks,
    required this.totalWindDownTasks,
    required this.recommendationFollowRate,
  });

  factory WeeklyWorkSummary.fromPatterns(Map<String, WorkDayPattern> patterns) {
    if (patterns.isEmpty) {
      return WeeklyWorkSummary(
        totalWorkDays: 0,
        averageWorkHours: 0,
        totalDeepWorkTasks: 0,
        totalShallowWorkTasks: 0,
        totalWindDownTasks: 0,
        recommendationFollowRate: 0,
      );
    }

    final totalWorkMinutes = patterns.values
        .map((p) => p.totalWorkMinutes)
        .fold(0, (a, b) => a + b);
    
    final totalDeepWork = patterns.values
        .map((p) => p.deepWorkTasksCompleted)
        .fold(0, (a, b) => a + b);
    
    final totalShallowWork = patterns.values
        .map((p) => p.shallowWorkTasksCompleted)
        .fold(0, (a, b) => a + b);
    
    final totalWindDown = patterns.values
        .map((p) => p.windDownTasksCompleted)
        .fold(0, (a, b) => a + b);

    // Calculate recommendation follow rate
    final allInteractions = patterns.values
        .expand((p) => p.recommendationInteractions)
        .toList();
    
    final followRate = allInteractions.isEmpty ? 0.0 :
        allInteractions.where((i) => i.wasFollowed).length / allInteractions.length;

    return WeeklyWorkSummary(
      totalWorkDays: patterns.length,
      averageWorkHours: totalWorkMinutes / 60.0 / patterns.length,
      totalDeepWorkTasks: totalDeepWork,
      totalShallowWorkTasks: totalShallowWork,
      totalWindDownTasks: totalWindDown,
      recommendationFollowRate: followRate,
    );
  }
}