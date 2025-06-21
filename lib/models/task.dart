import 'package:flutter/material.dart';

enum TaskType {
  deepWork('Deep Work', 'Algorithm design, debugging, complex coding', Icons.psychology_outlined),
  shallowWork('Shallow Work', 'Emails, meetings, code reviews', Icons.email_outlined),
  windDown('Wind-Down', 'Documentation, planning, refactoring', Icons.self_improvement_outlined);

  const TaskType(this.displayName, this.description, this.icon);
  final String displayName;
  final String description;
  final IconData icon;
}

enum TaskStatus {
  pending('Pending'),
  inProgress('In Progress'), 
  completed('Completed'),
  cancelled('Cancelled');

  const TaskStatus(this.displayName);
  final String displayName;
}

class Task {
  final String id;
  final String title;
  final String description;
  final TaskType type;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final int estimatedMinutes;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String> tags;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    this.scheduledStart,
    this.scheduledEnd,
    this.estimatedMinutes = 30,
    this.status = TaskStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.tags = const [],
  });

  // Check if task can be scheduled during Apex Hour
  bool get canScheduleDuringApexHour {
    return type == TaskType.windDown;
  }

  // Check if task is scheduled for today
  bool isScheduledToday(DateTime date) {
    if (scheduledStart == null) return false;
    final start = scheduledStart!;
    return start.year == date.year && 
           start.month == date.month && 
           start.day == date.day;
  }

  // Check if task conflicts with Apex Hour timing
  bool conflictsWithApexHour(DateTime apexStart, DateTime apexEnd) {
    if (scheduledStart == null || scheduledEnd == null) return false;
    if (canScheduleDuringApexHour) return false;

    // Check if task overlaps with Apex Hour
    return scheduledStart!.isBefore(apexEnd) && scheduledEnd!.isAfter(apexStart);
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskType? type,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    int? estimatedMinutes,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    List<String>? tags,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'scheduledStart': scheduledStart?.millisecondsSinceEpoch,
      'scheduledEnd': scheduledEnd?.millisecondsSinceEpoch,
      'estimatedMinutes': estimatedMinutes,
      'status': status.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'tags': tags,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      type: TaskType.values.firstWhere((e) => e.name == json['type']),
      scheduledStart: json['scheduledStart'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['scheduledStart'])
          : null,
      scheduledEnd: json['scheduledEnd'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['scheduledEnd'])
          : null,
      estimatedMinutes: json['estimatedMinutes'] ?? 30,
      status: TaskStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}