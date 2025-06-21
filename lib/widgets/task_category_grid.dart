import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../screens/task_management_screen.dart';

class TaskCategoryGrid extends StatefulWidget {
  const TaskCategoryGrid({super.key});

  @override
  State<TaskCategoryGrid> createState() => _TaskCategoryGridState();
}

class _TaskCategoryGridState extends State<TaskCategoryGrid> {
  Map<TaskType, int> _taskCounts = {};
  Map<TaskType, int> _completedCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTaskData();
  }

  Future<void> _loadTaskData() async {
    final today = DateTime.now();
    final taskCounts = await TaskService.instance.getTaskCountsByType(date: today);
    final completedCounts = await TaskService.instance.getCompletedTaskCountsByType(date: today);
    
    if (mounted) {
      setState(() {
        _taskCounts = taskCounts;
        _completedCounts = completedCounts;
        _isLoading = false;
      });
    }
  }

  double _getProgress(TaskType type) {
    final total = _taskCounts[type] ?? 0;
    final completed = _completedCounts[type] ?? 0;
    return total > 0 ? completed / total : 0.0;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Tasks',
            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Tasks',
          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: TaskType.values.map((type) {
            final count = _taskCounts[type] ?? 0;
            final progress = _getProgress(type);
            final color = _getTypeColor(type);
            
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type != TaskType.values.last ? 8 : 0,
                ),
                child: _TaskCategoryCard(
                  title: type == TaskType.shallowWork ? 'Shallow' : type.displayName,
                  count: count.toString(),
                  icon: type.icon,
                  color: color,
                  progress: progress,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskManagementScreen(filterType: type),
                      ),
                    );
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TaskCategoryCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final double progress;
  final VoidCallback onTap;

  const _TaskCategoryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            
            // Count
            Text(
              count,
              style: AppTextStyles.h4.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            
            // Title
            Text(
              title,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            
            // Progress bar
            Container(
              width: double.infinity,
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: AppColors.borderLight,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}