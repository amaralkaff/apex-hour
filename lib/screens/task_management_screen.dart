import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/task.dart';
import '../models/user_settings.dart';
import '../services/task_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/scheduling_service.dart';

class TaskManagementScreen extends StatefulWidget {
  final TaskType? filterType;
  
  const TaskManagementScreen({super.key, this.filterType});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  List<Task> _tasks = [];
  UserSettings? _settings;
  bool _isLoading = true;
  TaskType _selectedFilter = TaskType.deepWork;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filterType ?? TaskType.deepWork;
    _loadData();
  }

  Future<void> _loadData() async {
    final tasks = await TaskService.instance.getTasks();
    final settings = await SettingsService.instance.getSettings();
    
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _settings = settings;
        _isLoading = false;
      });
    }
  }

  List<Task> get _filteredTasks {
    final today = DateTime.now();
    return _tasks.where((task) {
      final matchesType = task.type == _selectedFilter;
      final isToday = task.isScheduledToday(today);
      return matchesType && isToday;
    }).toList()
      ..sort((a, b) {
        if (a.scheduledStart == null && b.scheduledStart == null) return 0;
        if (a.scheduledStart == null) return 1;
        if (b.scheduledStart == null) return -1;
        return a.scheduledStart!.compareTo(b.scheduledStart!);
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Task Management', style: AppTextStyles.h5),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Task Management', style: AppTextStyles.h5),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTaskDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _filteredTasks.isEmpty 
              ? _buildEmptyState()
              : _buildTaskList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: TaskType.values.map((type) {
          final isSelected = type == _selectedFilter;
          final color = _getTypeColor(type);
          
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: type != TaskType.values.last ? 8 : 0,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = type;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        type.icon,
                        color: isSelected ? Colors.white : color,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.displayName,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected ? Colors.white : color,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedFilter.icon,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No ${_selectedFilter.displayName} tasks today',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to add a new task',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTasks.length,
      itemBuilder: (context, index) {
        final task = _filteredTasks[index];
        return _TaskCard(
          task: task,
          settings: _settings!,
          onTap: () => _showTaskDetails(task),
          onStatusChanged: (newStatus) => _updateTaskStatus(task, newStatus),
          onEdit: () => _showEditTaskDialog(task),
          onDelete: () => _deleteTask(task),
        );
      },
    );
  }

  Future<void> _showAddTaskDialog() async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => _TaskDialog(
        taskType: _selectedFilter,
        settings: _settings!,
      ),
    );
    
    if (result != null) {
      await TaskService.instance.addTask(result);
      await _loadData();
      
      // Check for scheduling conflicts and warn if needed
      await _checkSchedulingConflicts(result);
    }
  }

  Future<void> _showEditTaskDialog(Task task) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => _TaskDialog(
        task: task,
        taskType: task.type,
        settings: _settings!,
      ),
    );
    
    if (result != null) {
      await TaskService.instance.updateTask(result);
      await _loadData();
      await _checkSchedulingConflicts(result);
    }
  }

  Future<void> _showTaskDetails(Task task) async {
    await showDialog(
      context: context,
      builder: (context) => _TaskDetailsDialog(task: task, settings: _settings!),
    );
  }

  Future<void> _updateTaskStatus(Task task, TaskStatus newStatus) async {
    final updatedTask = task.copyWith(
      status: newStatus,
      completedAt: newStatus == TaskStatus.completed ? DateTime.now() : null,
    );
    
    await TaskService.instance.updateTask(updatedTask);
    await _loadData();
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Task', style: AppTextStyles.h5),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await TaskService.instance.deleteTask(task.id);
      await _loadData();
    }
  }

  Future<void> _checkSchedulingConflicts(Task task) async {
    if (task.scheduledStart == null || task.scheduledEnd == null) return;
    if (task.type == TaskType.windDown) return; // Wind-down tasks are allowed in Apex Hour
    
    final apexStart = _settings!.getApexHourStart(task.scheduledStart!);
    final apexEnd = _settings!.getWorkdayEnd(task.scheduledStart!);
    
    if (task.conflictsWithApexHour(apexStart, apexEnd)) {
      await NotificationService.instance.scheduleDeepWorkWarning(
        scheduledTime: task.scheduledStart!,
        taskTitle: task.title,
      );
    }
  }

  Color _getTypeColor(TaskType type) {
    switch (type) {
      case TaskType.deepWork:
        return AppColors.deepWork;
      case TaskType.shallowWork:
        return AppColors.shallowWork;
      case TaskType.windDown:
        return AppColors.windDown;
    }
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final UserSettings settings;
  final VoidCallback onTap;
  final Function(TaskStatus) onStatusChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.settings,
    required this.onTap,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final isConflict = _hasApexHourConflict();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isConflict 
              ? Border.all(color: AppColors.warning, width: 2)
              : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => onStatusChanged(
                      isCompleted ? TaskStatus.pending : TaskStatus.completed
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isCompleted ? _getTypeColor() : Colors.transparent,
                        border: Border.all(
                          color: _getTypeColor(),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: isCompleted ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AppTextStyles.cardTitle.copyWith(
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? AppColors.textSecondary : null,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style: AppTextStyles.cardSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outlined, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (task.scheduledStart != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeRange(),
                      style: AppTextStyles.labelSmall,
                    ),
                    if (isConflict) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.warning_outlined,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Conflicts with Apex Hour',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (task.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: task.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getTypeColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: AppTextStyles.caption.copyWith(
                        color: _getTypeColor(),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasApexHourConflict() {
    if (task.scheduledStart == null || task.scheduledEnd == null) return false;
    if (task.type == TaskType.windDown) return false;
    
    final apexStart = settings.getApexHourStart(task.scheduledStart!);
    final apexEnd = settings.getWorkdayEnd(task.scheduledStart!);
    
    return task.conflictsWithApexHour(apexStart, apexEnd);
  }

  String _formatTimeRange() {
    if (task.scheduledStart == null) return '';
    
    final start = DateFormat.jm().format(task.scheduledStart!);
    if (task.scheduledEnd == null) return start;
    
    final end = DateFormat.jm().format(task.scheduledEnd!);
    return '$start - $end';
  }

  Color _getTypeColor() {
    switch (task.type) {
      case TaskType.deepWork:
        return AppColors.deepWork;
      case TaskType.shallowWork:
        return AppColors.shallowWork;
      case TaskType.windDown:
        return AppColors.windDown;
    }
  }
}

class _TaskDialog extends StatefulWidget {
  final Task? task;
  final TaskType taskType;
  final UserSettings settings;

  const _TaskDialog({
    this.task,
    required this.taskType,
    required this.settings,
  });

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TaskType _selectedType;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _estimatedMinutes = 30;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _selectedType = widget.task?.type ?? widget.taskType;
    _selectedDate = widget.task?.scheduledStart != null 
      ? DateTime(
          widget.task!.scheduledStart!.year,
          widget.task!.scheduledStart!.month,
          widget.task!.scheduledStart!.day,
        )
      : DateTime.now();
    _startTime = widget.task?.scheduledStart != null
      ? TimeOfDay.fromDateTime(widget.task!.scheduledStart!)
      : null;
    _endTime = widget.task?.scheduledEnd != null
      ? TimeOfDay.fromDateTime(widget.task!.scheduledEnd!)
      : null;
    _estimatedMinutes = widget.task?.estimatedMinutes ?? 30;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.task == null ? 'Add Task' : 'Edit Task',
        style: AppTextStyles.h5,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter task title',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter task description',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    'Start Time',
                    _startTime,
                    (time) => setState(() => _startTime = time),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeSelector(
                    'End Time',
                    _endTime,
                    (time) => setState(() => _endTime = time),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSave ? _saveTask : null,
          child: Text(widget.task == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay? time, Function(TimeOfDay) onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.labelSmall),
            const SizedBox(height: 4),
            Text(
              time?.format(context) ?? 'Select time',
              style: AppTextStyles.bodyMedium.copyWith(
                color: time != null ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave => _titleController.text.trim().isNotEmpty;

  void _saveTask() async {
    final now = DateTime.now();
    final scheduledStart = _startTime != null && _selectedDate != null
      ? DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        )
      : null;
    
    final scheduledEnd = _endTime != null && _selectedDate != null
      ? DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        )
      : null;

    final task = Task(
      id: widget.task?.id ?? TaskService.instance.generateTaskId(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      estimatedMinutes: _estimatedMinutes,
      status: widget.task?.status ?? TaskStatus.pending,
      createdAt: widget.task?.createdAt ?? now,
      completedAt: widget.task?.completedAt,
    );

    // Validate scheduling if times are set
    if (scheduledStart != null && scheduledEnd != null) {
      final validation = await SchedulingService.instance.validateTaskScheduling(
        task: task,
        proposedStart: scheduledStart,
        proposedEnd: scheduledEnd,
      );

      if (!validation.isValid) {
        // Show scheduling conflicts
        final shouldProceed = await _showSchedulingConflictsDialog(validation);
        if (!shouldProceed) return;
      } else if (validation.warnings.isNotEmpty) {
        // Show warnings but allow to proceed
        await _showSchedulingWarningsDialog(validation);
      }
    }

    if (mounted) {
      Navigator.pop(context, task);
    }
  }

  Future<bool> _showSchedulingConflictsDialog(SchedulingValidationResult validation) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Scheduling Conflicts', style: AppTextStyles.h5),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...validation.conflicts.map((conflict) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(conflict.message, style: AppTextStyles.bodySmall),
                  ),
                ],
              ),
            )),
            if (validation.suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Suggestions:', style: AppTextStyles.labelMedium),
              ...validation.suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(suggestion.reason, style: AppTextStyles.bodySmall),
                ),
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showSchedulingWarningsDialog(SchedulingValidationResult validation) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.warning),
            const SizedBox(width: 8),
            Text('Scheduling Tips', style: AppTextStyles.h5),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: validation.warnings.map((warning) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(warning.message, style: AppTextStyles.bodySmall),
                      if (warning.suggestion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tip: ${warning.suggestion}',
                          style: AppTextStyles.caption.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _TaskDetailsDialog extends StatelessWidget {
  final Task task;
  final UserSettings settings;

  const _TaskDetailsDialog({
    required this.task,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(task.title, style: AppTextStyles.h5),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.description.isNotEmpty) ...[
            Text('Description:', style: AppTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text(task.description, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
          ],
          Text('Type:', style: AppTextStyles.labelLarge),
          const SizedBox(height: 4),
          Text(task.type.displayName, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          Text('Status:', style: AppTextStyles.labelLarge),
          const SizedBox(height: 4),
          Text(task.status.displayName, style: AppTextStyles.bodyMedium),
          if (task.scheduledStart != null) ...[
            const SizedBox(height: 16),
            Text('Scheduled:', style: AppTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, y \'at\' h:mm a').format(task.scheduledStart!),
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}