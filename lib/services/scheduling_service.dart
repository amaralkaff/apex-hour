import '../models/task.dart';
import '../models/user_settings.dart';
import 'settings_service.dart';
import 'task_service.dart';

class SchedulingService {
  static SchedulingService? _instance;
  static SchedulingService get instance => _instance ??= SchedulingService._();
  SchedulingService._();

  /// Validates if a task can be scheduled at the given time
  Future<SchedulingValidationResult> validateTaskScheduling({
    required Task task,
    required DateTime proposedStart,
    required DateTime proposedEnd,
  }) async {
    final settings = await SettingsService.instance.getSettings();
    final existingTasks = await TaskService.instance.getTasksForDate(proposedStart);
    
    final warnings = <SchedulingWarning>[];
    final conflicts = <SchedulingConflict>[];
    bool isValid = true;

    // Check if task conflicts with Apex Hour (Story 1.3)
    if (!task.canScheduleDuringApexHour) {
      final apexStart = settings.getApexHourStart(proposedStart);
      final apexEnd = settings.getWorkdayEnd(proposedStart);
      
      // Check if task overlaps with Apex Hour
      if (_timesOverlap(proposedStart, proposedEnd, apexStart, apexEnd)) {
        conflicts.add(SchedulingConflict(
          type: ConflictType.apexHourViolation,
          message: 'This ${task.type.displayName} task conflicts with your Apex Hour (${_formatTime(apexStart)} - ${_formatTime(apexEnd)})',
          severity: ConflictSeverity.high,
          suggestedAction: 'Move to earlier in the day or change to Wind-Down task',
        ));
        isValid = false;
      }
      
      // Warn if task is too close to Apex Hour (within 1 hour)
      else if (proposedEnd.isAfter(apexStart.subtract(const Duration(hours: 1)))) {
        warnings.add(SchedulingWarning(
          type: WarningType.closeToApexHour,
          message: 'This task ends close to your Apex Hour. Consider allowing more buffer time.',
          suggestion: 'Schedule earlier or reduce task duration',
        ));
      }
    }

    // Check for task overlaps
    for (final existingTask in existingTasks) {
      if (existingTask.id == task.id) continue; // Skip self when editing
      if (existingTask.scheduledStart == null || existingTask.scheduledEnd == null) continue;
      
      if (_timesOverlap(
        proposedStart, 
        proposedEnd, 
        existingTask.scheduledStart!, 
        existingTask.scheduledEnd!
      )) {
        conflicts.add(SchedulingConflict(
          type: ConflictType.taskOverlap,
          message: 'Overlaps with "${existingTask.title}" (${_formatTime(existingTask.scheduledStart!)} - ${_formatTime(existingTask.scheduledEnd!)})',
          severity: ConflictSeverity.high,
          suggestedAction: 'Choose a different time slot',
        ));
        isValid = false;
      }
    }

    // Check if task is outside work hours
    final workStart = settings.getWorkdayStart(proposedStart);
    final workEnd = settings.getWorkdayEnd(proposedStart);
    
    if (proposedStart.isBefore(workStart) || proposedEnd.isAfter(workEnd)) {
      warnings.add(SchedulingWarning(
        type: WarningType.outsideWorkHours,
        message: 'Task is scheduled outside your normal work hours (${_formatTime(workStart)} - ${_formatTime(workEnd)})',
        suggestion: 'Consider rescheduling within work hours',
      ));
    }

    // Check for optimal scheduling based on task type
    if (task.type == TaskType.deepWork) {
      final morningEnd = workStart.add(const Duration(hours: 4)); // First 4 hours of work
      
      if (proposedStart.isAfter(morningEnd)) {
        warnings.add(SchedulingWarning(
          type: WarningType.suboptimalTiming,
          message: 'Deep Work tasks are most effective in the morning when energy is highest',
          suggestion: 'Consider scheduling this task earlier in the day',
        ));
      }
    }

    // Generate suggestions for better scheduling
    final suggestions = (!isValid || warnings.isNotEmpty) 
        ? await _generateSchedulingSuggestions(
            task: task,
            proposedStart: proposedStart,
            proposedEnd: proposedEnd,
            settings: settings,
            existingTasks: existingTasks,
          )
        : <SchedulingSuggestion>[];

    return SchedulingValidationResult(
      isValid: isValid,
      warnings: warnings,
      conflicts: conflicts,
      suggestions: suggestions,
    );
  }

  /// Finds the next available time slot for a task
  Future<List<TimeSlot>> findAvailableTimeSlots({
    required TaskType taskType,
    required Duration taskDuration,
    required DateTime date,
    int maxSuggestions = 3,
  }) async {
    final settings = await SettingsService.instance.getSettings();
    final existingTasks = await TaskService.instance.getTasksForDate(date);
    
    final workStart = settings.getWorkdayStart(date);
    final workEnd = settings.getWorkdayEnd(date);
    final apexStart = settings.getApexHourStart(date);
    
    final List<TimeSlot> availableSlots = [];
    final slotDuration = taskDuration;
    const slotIncrement = Duration(minutes: 30); // Check every 30 minutes
    
    DateTime currentTime = workStart;
    
    while (currentTime.add(slotDuration).isBefore(workEnd) && availableSlots.length < maxSuggestions) {
      final slotEnd = currentTime.add(slotDuration);
      
      // Skip if this would conflict with Apex Hour for non-wind-down tasks
      if (taskType != TaskType.windDown && 
          _timesOverlap(currentTime, slotEnd, apexStart, workEnd)) {
        currentTime = currentTime.add(slotIncrement);
        continue;
      }
      
      // Check if this slot conflicts with existing tasks
      bool hasConflict = false;
      for (final task in existingTasks) {
        if (task.scheduledStart == null || task.scheduledEnd == null) continue;
        
        if (_timesOverlap(currentTime, slotEnd, task.scheduledStart!, task.scheduledEnd!)) {
          hasConflict = true;
          break;
        }
      }
      
      if (!hasConflict) {
        availableSlots.add(TimeSlot(
          start: currentTime,
          end: slotEnd,
          isOptimal: _isOptimalTimeForTaskType(taskType, currentTime, settings),
        ));
      }
      
      currentTime = currentTime.add(slotIncrement);
    }
    
    // Sort by optimality and time
    availableSlots.sort((a, b) {
      if (a.isOptimal && !b.isOptimal) return -1;
      if (!a.isOptimal && b.isOptimal) return 1;
      return a.start.compareTo(b.start);
    });
    
    return availableSlots;
  }

  /// Automatically schedules a task in the best available slot
  Future<SchedulingResult> autoScheduleTask({
    required Task task,
    required DateTime preferredDate,
  }) async {
    final duration = Duration(minutes: task.estimatedMinutes);
    final availableSlots = await findAvailableTimeSlots(
      taskType: task.type,
      taskDuration: duration,
      date: preferredDate,
      maxSuggestions: 1,
    );
    
    if (availableSlots.isEmpty) {
      return SchedulingResult(
        success: false,
        message: 'No available time slots found for this task on the selected date',
        suggestedDates: await _findAlternateDates(task, preferredDate),
      );
    }
    
    final bestSlot = availableSlots.first;
    final scheduledTask = task.copyWith(
      scheduledStart: bestSlot.start,
      scheduledEnd: bestSlot.end,
    );
    
    return SchedulingResult(
      success: true,
      task: scheduledTask,
      message: 'Task scheduled for ${_formatTime(bestSlot.start)} - ${_formatTime(bestSlot.end)}',
    );
  }

  Future<List<SchedulingSuggestion>> _generateSchedulingSuggestions({
    required Task task,
    required DateTime proposedStart,
    required DateTime proposedEnd,
    required UserSettings settings,
    required List<Task> existingTasks,
  }) async {
    final suggestions = <SchedulingSuggestion>[];
    
    // Suggest moving earlier if it's late in the day for deep work
    if (task.type == TaskType.deepWork) {
      final morningSlots = await findAvailableTimeSlots(
        taskType: task.type,
        taskDuration: proposedEnd.difference(proposedStart),
        date: proposedStart,
        maxSuggestions: 2,
      );
      
      for (final slot in morningSlots) {
        if (slot.start.isBefore(proposedStart) && slot.isOptimal) {
          suggestions.add(SchedulingSuggestion(
            timeSlot: slot,
            reason: 'Morning hours are optimal for Deep Work tasks',
            priority: SuggestionPriority.high,
          ));
        }
      }
    }
    
    // Suggest wind-down alternative if scheduling during Apex Hour
    final apexStart = settings.getApexHourStart(proposedStart);
    final apexEnd = settings.getWorkdayEnd(proposedStart);
    
    if (_timesOverlap(proposedStart, proposedEnd, apexStart, apexEnd) && 
        task.type != TaskType.windDown) {
      suggestions.add(SchedulingSuggestion(
        timeSlot: TimeSlot(start: proposedStart, end: proposedEnd, isOptimal: false),
        reason: 'Change to Wind-Down task to allow scheduling during Apex Hour',
        priority: SuggestionPriority.medium,
        alternativeTaskType: TaskType.windDown,
      ));
    }
    
    return suggestions;
  }

  Future<List<DateTime>> _findAlternateDates(Task task, DateTime preferredDate) async {
    final alternateDates = <DateTime>[];
    final duration = Duration(minutes: task.estimatedMinutes);
    
    // Check next 7 days
    for (int i = 1; i <= 7; i++) {
      final date = preferredDate.add(Duration(days: i));
      final slots = await findAvailableTimeSlots(
        taskType: task.type,
        taskDuration: duration,
        date: date,
        maxSuggestions: 1,
      );
      
      if (slots.isNotEmpty) {
        alternateDates.add(date);
        if (alternateDates.length >= 3) break;
      }
    }
    
    return alternateDates;
  }

  bool _timesOverlap(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  bool _isOptimalTimeForTaskType(TaskType taskType, DateTime time, UserSettings settings) {
    final workStart = settings.getWorkdayStart(time);
    final hoursSinceStart = time.difference(workStart).inHours;
    
    switch (taskType) {
      case TaskType.deepWork:
        return hoursSinceStart < 4; // First 4 hours are optimal
      case TaskType.shallowWork:
        return hoursSinceStart >= 2 && hoursSinceStart < 6; // Mid-day optimal
      case TaskType.windDown:
        return hoursSinceStart >= 6; // Later in day optimal
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

// Data classes for scheduling results
class SchedulingValidationResult {
  final bool isValid;
  final List<SchedulingWarning> warnings;
  final List<SchedulingConflict> conflicts;
  final List<SchedulingSuggestion> suggestions;

  SchedulingValidationResult({
    required this.isValid,
    required this.warnings,
    required this.conflicts,
    required this.suggestions,
  });
}

class SchedulingWarning {
  final WarningType type;
  final String message;
  final String suggestion;

  SchedulingWarning({
    required this.type,
    required this.message,
    required this.suggestion,
  });
}

class SchedulingConflict {
  final ConflictType type;
  final String message;
  final ConflictSeverity severity;
  final String suggestedAction;

  SchedulingConflict({
    required this.type,
    required this.message,
    required this.severity,
    required this.suggestedAction,
  });
}

class SchedulingSuggestion {
  final TimeSlot timeSlot;
  final String reason;
  final SuggestionPriority priority;
  final TaskType? alternativeTaskType;

  SchedulingSuggestion({
    required this.timeSlot,
    required this.reason,
    required this.priority,
    this.alternativeTaskType,
  });
}

class TimeSlot {
  final DateTime start;
  final DateTime end;
  final bool isOptimal;

  TimeSlot({
    required this.start,
    required this.end,
    required this.isOptimal,
  });
}

class SchedulingResult {
  final bool success;
  final Task? task;
  final String message;
  final List<DateTime>? suggestedDates;

  SchedulingResult({
    required this.success,
    this.task,
    required this.message,
    this.suggestedDates,
  });
}

enum WarningType {
  closeToApexHour,
  outsideWorkHours,
  suboptimalTiming,
}

enum ConflictType {
  apexHourViolation,
  taskOverlap,
}

enum ConflictSeverity {
  low,
  medium,
  high,
}

enum SuggestionPriority {
  low,
  medium,
  high,
}