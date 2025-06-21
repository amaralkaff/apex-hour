import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'work_pattern_service.dart';

class TaskService {
  static TaskService? _instance;
  static TaskService get instance => _instance ??= TaskService._();
  TaskService._();

  static const String _tasksKey = 'tasks';
  SharedPreferences? _prefs;
  List<Task>? _cachedTasks;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<Task>> getTasks() async {
    await initialize();
    
    if (_cachedTasks != null) {
      return _cachedTasks!;
    }

    final tasksJson = _prefs!.getStringList(_tasksKey) ?? [];
    _cachedTasks = tasksJson.map((taskJson) {
      try {
        final Map<String, dynamic> json = jsonDecode(taskJson);
        return Task.fromJson(json);
      } catch (e) {
        return null;
      }
    }).where((task) => task != null).cast<Task>().toList();

    return _cachedTasks!;
  }

  Future<void> saveTasks(List<Task> tasks) async {
    await initialize();
    
    _cachedTasks = tasks;
    final tasksJson = tasks.map((task) => jsonEncode(task.toJson())).toList();
    await _prefs!.setStringList(_tasksKey, tasksJson);
  }

  Future<void> addTask(Task task) async {
    final tasks = await getTasks();
    tasks.add(task);
    await saveTasks(tasks);
  }

  Future<void> updateTask(Task updatedTask) async {
    final tasks = await getTasks();
    final index = tasks.indexWhere((task) => task.id == updatedTask.id);
    if (index != -1) {
      final oldTask = tasks[index];
      tasks[index] = updatedTask;
      await saveTasks(tasks);
      
      // Track task completion in work patterns
      if (oldTask.status != TaskStatus.completed && 
          updatedTask.status == TaskStatus.completed) {
        await WorkPatternService.instance.recordTaskCompletion(updatedTask);
      }
    }
  }

  Future<void> deleteTask(String taskId) async {
    final tasks = await getTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await saveTasks(tasks);
  }

  Future<List<Task>> getTasksForDate(DateTime date) async {
    final tasks = await getTasks();
    return tasks.where((task) => task.isScheduledToday(date)).toList();
  }

  Future<List<Task>> getTasksByType(TaskType type) async {
    final tasks = await getTasks();
    return tasks.where((task) => task.type == type).toList();
  }

  Future<List<Task>> getTasksByStatus(TaskStatus status) async {
    final tasks = await getTasks();
    return tasks.where((task) => task.status == status).toList();
  }

  Future<Map<TaskType, List<Task>>> getTasksGroupedByType() async {
    final tasks = await getTasks();
    final Map<TaskType, List<Task>> grouped = {};
    
    for (final type in TaskType.values) {
      grouped[type] = tasks.where((task) => task.type == type).toList();
    }
    
    return grouped;
  }

  Future<Map<TaskType, int>> getTaskCountsByType({DateTime? date}) async {
    final tasks = date != null 
        ? await getTasksForDate(date)
        : await getTasks();
    
    final Map<TaskType, int> counts = {};
    for (final type in TaskType.values) {
      counts[type] = tasks.where((task) => task.type == type).length;
    }
    
    return counts;
  }

  Future<Map<TaskType, int>> getCompletedTaskCountsByType({DateTime? date}) async {
    final tasks = date != null 
        ? await getTasksForDate(date)
        : await getTasks();
    
    final completedTasks = tasks.where((task) => task.status == TaskStatus.completed);
    final Map<TaskType, int> counts = {};
    
    for (final type in TaskType.values) {
      counts[type] = completedTasks.where((task) => task.type == type).length;
    }
    
    return counts;
  }

  String generateTaskId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Create sample tasks for demo purposes
  Future<void> createSampleTasks() async {
    final existingTasks = await getTasks();
    if (existingTasks.isNotEmpty) return; // Don't create if tasks already exist
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final sampleTasks = [
      Task(
        id: generateTaskId(),
        title: 'Implement OAuth authentication',
        description: 'Add OAuth 2.0 login flow for the application',
        type: TaskType.deepWork,
        scheduledStart: today.add(const Duration(hours: 9)),
        scheduledEnd: today.add(const Duration(hours: 11)),
        estimatedMinutes: 120,
        status: TaskStatus.completed,
        createdAt: now.subtract(const Duration(days: 1)),
        completedAt: now.subtract(const Duration(hours: 2)),
        tags: ['authentication', 'security'],
      ),
      Task(
        id: generateTaskId(),
        title: 'Code review for PR #123',
        description: 'Review changes for the new dashboard feature',
        type: TaskType.shallowWork,
        scheduledStart: today.add(const Duration(hours: 14)),
        scheduledEnd: today.add(const Duration(hours: 14, minutes: 30)),
        estimatedMinutes: 30,
        status: TaskStatus.completed,
        createdAt: now.subtract(const Duration(hours: 6)),
        completedAt: now.subtract(const Duration(hours: 1)),
        tags: ['review', 'frontend'],
      ),
      Task(
        id: generateTaskId(),
        title: 'Debug memory leak in background service',
        description: 'Investigate and fix memory leak reported in production',
        type: TaskType.deepWork,
        scheduledStart: today.add(const Duration(hours: 10)),
        scheduledEnd: today.add(const Duration(hours: 12)),
        estimatedMinutes: 120,
        status: TaskStatus.inProgress,
        createdAt: now.subtract(const Duration(hours: 3)),
        tags: ['bug', 'performance'],
      ),
      Task(
        id: generateTaskId(),
        title: 'Team standup meeting',
        description: 'Daily standup with the development team',
        type: TaskType.shallowWork,
        scheduledStart: today.add(const Duration(hours: 9, minutes: 30)),
        scheduledEnd: today.add(const Duration(hours: 10)),
        estimatedMinutes: 30,
        status: TaskStatus.completed,
        createdAt: now.subtract(const Duration(days: 1)),
        completedAt: now.subtract(const Duration(hours: 7)),
        tags: ['meeting', 'team'],
      ),
      Task(
        id: generateTaskId(),
        title: 'Update API documentation',
        description: 'Document new endpoints added last week',
        type: TaskType.windDown,
        scheduledStart: today.add(const Duration(hours: 17)),
        scheduledEnd: today.add(const Duration(hours: 17, minutes: 45)),
        estimatedMinutes: 45,
        status: TaskStatus.pending,
        createdAt: now.subtract(const Duration(hours: 1)),
        tags: ['documentation', 'api'],
      ),
      Task(
        id: generateTaskId(),
        title: 'Plan next sprint tasks',
        description: 'Review backlog and plan tasks for next sprint',
        type: TaskType.windDown,
        scheduledStart: today.add(const Duration(hours: 16, minutes: 30)),
        scheduledEnd: today.add(const Duration(hours: 17)),
        estimatedMinutes: 30,
        status: TaskStatus.pending,
        createdAt: now,
        tags: ['planning', 'sprint'],
      ),
      Task(
        id: generateTaskId(),
        title: 'Respond to client emails',
        description: 'Reply to pending client questions and requests',
        type: TaskType.shallowWork,
        scheduledStart: today.add(const Duration(hours: 15)),
        scheduledEnd: today.add(const Duration(hours: 15, minutes: 30)),
        estimatedMinutes: 30,
        status: TaskStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 30)),
        tags: ['email', 'communication'],
      ),
    ];
    
    await saveTasks(sampleTasks);
  }
}