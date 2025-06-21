import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/user_settings.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/ai_recommendation_service.dart';
import '../services/work_pattern_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.instance.getSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings(UserSettings newSettings) async {
    await SettingsService.instance.saveSettings(newSettings);
    setState(() {
      _settings = newSettings;
    });
    
    // Reschedule notifications when settings change
    await NotificationService.instance.rescheduleAllNotifications();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Settings saved successfully',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectTime({
    required String title,
    required TimeOfDay initialTime,
    required Function(TimeOfDay) onTimeSelected,
  }) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: title,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.surface,
              hourMinuteTextColor: AppColors.textPrimary,
              dialHandColor: AppColors.primary,
              dialBackgroundColor: AppColors.surfaceVariant,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onTimeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Settings', style: AppTextStyles.h5),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.h5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWorkHoursSection(),
            const SizedBox(height: 24),
            _buildApexHourSection(),
            const SizedBox(height: 24),
            _buildNotificationSection(),
            const SizedBox(height: 24),
            _buildAIRecommendationSection(),
            const SizedBox(height: 24),
            _buildOtherSettingsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkHoursSection() {
    return _SettingsSection(
      title: 'Work Hours',
      children: [
        _SettingsTile(
          title: 'Work Start Time',
          subtitle: _formatTime(_settings!.workdayStartHour, _settings!.workdayStartMinute),
          icon: Icons.play_arrow_outlined,
          onTap: () => _selectTime(
            title: 'Select work start time',
            initialTime: TimeOfDay(
              hour: _settings!.workdayStartHour,
              minute: _settings!.workdayStartMinute,
            ),
            onTimeSelected: (time) {
              final newSettings = _settings!.copyWith(
                workdayStartHour: time.hour,
                workdayStartMinute: time.minute,
              );
              _saveSettings(newSettings);
            },
          ),
        ),
        _SettingsTile(
          title: 'Work End Time',
          subtitle: _formatTime(_settings!.workdayEndHour, _settings!.workdayEndMinute),
          icon: Icons.stop_outlined,
          onTap: () => _selectTime(
            title: 'Select work end time',
            initialTime: TimeOfDay(
              hour: _settings!.workdayEndHour,
              minute: _settings!.workdayEndMinute,
            ),
            onTimeSelected: (time) {
              final newSettings = _settings!.copyWith(
                workdayEndHour: time.hour,
                workdayEndMinute: time.minute,
              );
              _saveSettings(newSettings);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildApexHourSection() {
    final apexStart = _settings!.getApexHourStart(DateTime.now());
    final workdayEnd = _settings!.getWorkdayEnd(DateTime.now());
    
    return _SettingsSection(
      title: 'Apex Hour',
      subtitle: 'Protected cool-down period before work ends',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Current Apex Hour',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat.jm().format(apexStart)} - ${DateFormat.jm().format(workdayEnd)}',
                style: AppTextStyles.h5.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                '${_settings!.apexHourDurationMinutes} minutes before work ends',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsTile(
          title: 'Apex Hour Duration',
          subtitle: '${_settings!.apexHourDurationMinutes} minutes',
          icon: Icons.timer_outlined,
          onTap: () => _showDurationPicker(),
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return _SettingsSection(
      title: 'Notifications',
      children: [
        _SettingsTile(
          title: 'Enable Notifications',
          subtitle: 'Get reminders about Apex Hour',
          icon: Icons.notifications_outlined,
          trailing: Switch(
            value: _settings!.notificationsEnabled,
            onChanged: (value) {
              final newSettings = _settings!.copyWith(
                notificationsEnabled: value,
              );
              _saveSettings(newSettings);
            },
            activeColor: AppColors.primary,
          ),
        ),
        if (_settings!.notificationsEnabled)
          _SettingsTile(
            title: 'Reminder Time',
            subtitle: '${_settings!.notificationMinutesBefore} minutes before',
            icon: Icons.alarm_outlined,
            onTap: () => _showNotificationTimePicker(),
          ),
      ],
    );
  }

  Widget _buildOtherSettingsSection() {
    return _SettingsSection(
      title: 'Other Settings',
      children: [
        _SettingsTile(
          title: 'Hard Stop',
          subtitle: 'Firm reminder when workday ends',
          icon: Icons.block_outlined,
          trailing: Switch(
            value: _settings!.hardStopEnabled,
            onChanged: (value) {
              final newSettings = _settings!.copyWith(
                hardStopEnabled: value,
              );
              _saveSettings(newSettings);
            },
            activeColor: AppColors.primary,
          ),
        ),
        _SettingsTile(
          title: 'Reset Settings',
          subtitle: 'Return to default configuration',
          icon: Icons.restore_outlined,
          textColor: AppColors.error,
          onTap: () => _showResetDialog(),
        ),
      ],
    );
  }

  Future<void> _showDurationPicker() async {
    final options = [30, 45, 60, 75, 90, 120];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Apex Hour Duration',
              style: AppTextStyles.h5,
            ),
            const SizedBox(height: 20),
            ...options.map((minutes) => ListTile(
              title: Text('$minutes minutes'),
              leading: Radio<int>(
                value: minutes,
                groupValue: _settings!.apexHourDurationMinutes,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = _settings!.copyWith(
                      apexHourDurationMinutes: value,
                    );
                    _saveSettings(newSettings);
                    Navigator.pop(context);
                  }
                },
                activeColor: AppColors.primary,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotificationTimePicker() async {
    final options = [5, 10, 15, 20, 30];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notification Timing',
              style: AppTextStyles.h5,
            ),
            const SizedBox(height: 20),
            ...options.map((minutes) => ListTile(
              title: Text('$minutes minutes before'),
              leading: Radio<int>(
                value: minutes,
                groupValue: _settings!.notificationMinutesBefore,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = _settings!.copyWith(
                      notificationMinutesBefore: value,
                    );
                    _saveSettings(newSettings);
                    Navigator.pop(context);
                  }
                },
                activeColor: AppColors.primary,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Settings', style: AppTextStyles.h5),
        content: Text(
          'Are you sure you want to reset all settings to default values? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await SettingsService.instance.resetSettings();
              await _loadSettings();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendationSection() {
    return _SettingsSection(
      title: 'AI Health Recommendations',
      subtitle: 'Personalized wellness tips powered by AI',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline AI Active',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Private, context-aware health recommendations',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outlined,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PRIVATE',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsTile(
          title: 'Configure API Token',
          subtitle: 'Set up Hugging Face API for personalized recommendations',
          icon: Icons.key_outlined,
          onTap: () => _showAPITokenDialog(),
        ),
        _SettingsTile(
          title: 'View Health Analytics',
          subtitle: 'See your wellness patterns and habit progress',
          icon: Icons.analytics_outlined,
          onTap: () => _showHealthAnalytics(),
        ),
        _SettingsTile(
          title: 'Clear Health Data',
          subtitle: 'Reset all tracked wellness interactions',
          icon: Icons.clear_all_outlined,
          textColor: AppColors.error,
          onTap: () => _showClearHealthDataDialog(),
        ),
      ],
    );
  }

  Future<void> _showAPITokenDialog() async {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hugging Face API Token', style: AppTextStyles.h5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To enable AI-powered health recommendations, add your Hugging Face API token:',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '1. Visit huggingface.co/settings/tokens\n2. Create a new token\n3. Paste it below',
              style: AppTextStyles.labelSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Token',
                hintText: 'hf_...',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Store API token securely
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'API token configuration coming soon!',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  ),
                  backgroundColor: AppColors.info,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHealthAnalytics() async {
    final summary = await WorkPatternService.instance.getWeeklySummary();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Health Analytics', style: AppTextStyles.h5),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAnalyticRow('Work Days This Week', '${summary.totalWorkDays}'),
              _buildAnalyticRow('Average Work Hours', '${summary.averageWorkHours.toStringAsFixed(1)}h'),
              _buildAnalyticRow('Deep Work Tasks', '${summary.totalDeepWorkTasks}'),
              _buildAnalyticRow('Shallow Work Tasks', '${summary.totalShallowWorkTasks}'),
              _buildAnalyticRow('Wind-Down Tasks', '${summary.totalWindDownTasks}'),
              _buildAnalyticRow('Recommendation Follow Rate', '${(summary.recommendationFollowRate * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearHealthDataDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Health Data', style: AppTextStyles.h5),
        content: Text(
          'Are you sure you want to clear all health analytics and recommendation data? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await WorkPatternService.instance.cleanupOldData();
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Health data cleared successfully',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h5),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppTextStyles.labelMedium),
        ],
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? AppColors.textSecondary),
        title: Text(
          title,
          style: AppTextStyles.cardTitle.copyWith(color: textColor),
        ),
        subtitle: Text(subtitle, style: AppTextStyles.cardSubtitle),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
        onTap: onTap,
      ),
    );
  }
}