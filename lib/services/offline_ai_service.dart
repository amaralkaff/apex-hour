import 'dart:math';
import '../models/task.dart';
import '../models/user_settings.dart';

/// Offline AI service that provides intelligent health recommendations
/// without requiring internet connectivity or external API calls.
/// 
/// This service uses rule-based AI and contextual analysis to generate
/// personalized health recommendations based on work patterns.
class OfflineAIService {
  static final OfflineAIService _instance = OfflineAIService._internal();
  static OfflineAIService get instance => _instance;
  OfflineAIService._internal();

  final Random _random = Random();

  /// Generate context-aware health recommendation using offline AI
  String generateSmartRecommendation({
    required UserSettings settings,
    required List<Task> todaysTasks,
    required DateTime currentTime,
  }) {
    // Analyze work context
    final context = _analyzeWorkContext(settings, todaysTasks, currentTime);
    
    // Generate recommendation based on context
    return _generateContextualRecommendation(context);
  }

  /// Analyze current work context and patterns
  WorkContext _analyzeWorkContext(
    UserSettings settings, 
    List<Task> todaysTasks, 
    DateTime currentTime
  ) {
    final workStart = settings.getWorkdayStart(currentTime);
    final workEnd = settings.getWorkdayEnd(currentTime);
    final apexStart = settings.getApexHourStart(currentTime);
    
    final hoursWorked = currentTime.difference(workStart).inMinutes / 60.0;
    final hoursRemaining = workEnd.difference(currentTime).inMinutes / 60.0;
    
    final completedTasks = todaysTasks.where((t) => t.status == TaskStatus.completed).length;
    final totalTasks = todaysTasks.length;
    final deepWorkTasks = todaysTasks.where((t) => t.type == TaskType.deepWork).length;
    
    final isInApexHour = currentTime.isAfter(apexStart) && currentTime.isBefore(workEnd);
    final isLateInDay = hoursWorked > 6;
    final isOverworked = hoursWorked > 8;
    
    return WorkContext(
      hoursWorked: hoursWorked,
      hoursRemaining: hoursRemaining,
      completedTasks: completedTasks,
      totalTasks: totalTasks,
      deepWorkTasks: deepWorkTasks,
      isInApexHour: isInApexHour,
      isLateInDay: isLateInDay,
      isOverworked: isOverworked,
      timeOfDay: _getTimeOfDay(currentTime),
      workloadIntensity: _calculateWorkloadIntensity(todaysTasks),
    );
  }

  /// Generate contextual recommendation based on analyzed context
  String _generateContextualRecommendation(WorkContext context) {
    final recommendations = <String>[];

    // Time-based recommendations
    switch (context.timeOfDay) {
      case TimeOfDayPeriod.morning:
        recommendations.addAll(_getMorningRecommendations(context));
        break;
      case TimeOfDayPeriod.afternoon:
        recommendations.addAll(_getAfternoonRecommendations(context));
        break;
      case TimeOfDayPeriod.evening:
        recommendations.addAll(_getEveningRecommendations(context));
        break;
    }

    // Context-specific recommendations
    if (context.isOverworked) {
      recommendations.addAll(_getOverworkRecommendations());
    }
    
    if (context.isInApexHour) {
      recommendations.addAll(_getApexHourRecommendations());
    }
    
    if (context.workloadIntensity == WorkloadIntensity.high) {
      recommendations.addAll(_getHighIntensityRecommendations());
    }

    // Eye strain recommendations for long work sessions
    if (context.hoursWorked > 4) {
      recommendations.addAll(_getEyeStrainRecommendations());
    }

    // Productivity-based recommendations
    final completionRate = context.totalTasks > 0 ? context.completedTasks / context.totalTasks : 0;
    if (completionRate < 0.3 && context.hoursWorked > 3) {
      recommendations.addAll(_getProductivityBoostRecommendations());
    }

    // Select and return best recommendation
    return recommendations.isNotEmpty 
        ? recommendations[_random.nextInt(recommendations.length)]
        : 'Take a moment to breathe deeply and reset your focus.';
  }

  List<String> _getMorningRecommendations(WorkContext context) {
    return [
      'Start your day with 5 minutes of deep breathing to boost focus',
      'Hydrate well - aim for a full glass of water to kickstart your metabolism',
      'Do some gentle neck rolls to prepare for a day of focused work',
      'Set up your workspace ergonomically for optimal comfort',
    ];
  }

  List<String> _getAfternoonRecommendations(WorkContext context) {
    return [
      'Combat the afternoon slump with a 2-minute walk around your workspace',
      'Practice the 20-20-20 rule: look at something 20 feet away for 20 seconds',
      'Have a healthy snack and water to maintain energy levels',
      'Do some shoulder shrugs to release built-up tension',
    ];
  }

  List<String> _getEveningRecommendations(WorkContext context) {
    return [
      'Time to start winding down - avoid caffeine after 3 PM',
      'Reflect on today\'s accomplishments to end on a positive note',
      'Prepare for tomorrow by writing down 3 key priorities',
      'Dim your screen brightness to help your eyes adjust for evening',
    ];
  }

  List<String> _getOverworkRecommendations() {
    return [
      'You\'ve been working hard! Take a 10-minute break to recharge',
      'Consider ending work soon - rest is crucial for long-term productivity',
      'Step outside for fresh air and natural light exposure',
      'Do some gentle stretching to counteract prolonged sitting',
    ];
  }

  List<String> _getApexHourRecommendations() {
    return [
      'Perfect time for documentation and planning tasks',
      'Review today\'s work and prepare notes for tomorrow',
      'Organize your workspace for a fresh start tomorrow',
      'Reflect on lessons learned today while they\'re fresh',
    ];
  }

  List<String> _getHighIntensityRecommendations() {
    return [
      'High focus work detected - remember to blink frequently',
      'Take micro-breaks every 25 minutes to maintain peak performance',
      'Stay hydrated during intense concentration periods',
      'Practice progressive muscle relaxation for 2 minutes',
    ];
  }

  List<String> _getEyeStrainRecommendations() {
    return [
      'Give your eyes a rest - focus on distant objects for 30 seconds',
      'Blink deliberately 20 times to rewet your eyes',
      'Adjust your screen brightness to match your surroundings',
      'Consider blue light filtering if working late',
    ];
  }

  List<String> _getProductivityBoostRecommendations() {
    return [
      'Break large tasks into smaller, manageable chunks',
      'Try the Pomodoro Technique - 25 minutes focused work',
      'Clear mental fog with 10 deep breaths and a glass of water',
      'Eliminate distractions and focus on one task at a time',
    ];
  }

  TimeOfDayPeriod _getTimeOfDay(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return TimeOfDayPeriod.morning;
    if (hour < 17) return TimeOfDayPeriod.afternoon;
    return TimeOfDayPeriod.evening;
  }

  WorkloadIntensity _calculateWorkloadIntensity(List<Task> tasks) {
    final deepWorkCount = tasks.where((t) => t.type == TaskType.deepWork).length;
    final totalTasks = tasks.length;
    
    if (totalTasks == 0) return WorkloadIntensity.low;
    
    final deepWorkRatio = deepWorkCount / totalTasks;
    if (deepWorkRatio > 0.6) return WorkloadIntensity.high;
    if (deepWorkRatio > 0.3) return WorkloadIntensity.medium;
    return WorkloadIntensity.low;
  }
}

/// Work context analysis result
class WorkContext {
  final double hoursWorked;
  final double hoursRemaining;
  final int completedTasks;
  final int totalTasks;
  final int deepWorkTasks;
  final bool isInApexHour;
  final bool isLateInDay;
  final bool isOverworked;
  final TimeOfDayPeriod timeOfDay;
  final WorkloadIntensity workloadIntensity;

  WorkContext({
    required this.hoursWorked,
    required this.hoursRemaining,
    required this.completedTasks,
    required this.totalTasks,
    required this.deepWorkTasks,
    required this.isInApexHour,
    required this.isLateInDay,
    required this.isOverworked,
    required this.timeOfDay,
    required this.workloadIntensity,
  });
}

enum TimeOfDayPeriod { morning, afternoon, evening }
enum WorkloadIntensity { low, medium, high }