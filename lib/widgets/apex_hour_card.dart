import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/user_settings.dart';
import '../services/settings_service.dart';

class ApexHourCard extends StatefulWidget {
  const ApexHourCard({super.key});

  @override
  State<ApexHourCard> createState() => _ApexHourCardState();
}

class _ApexHourCardState extends State<ApexHourCard> {
  UserSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.instance.getSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final isApexHour = _settings!.isApexHour(now);
    final isPastWorkday = _settings!.isPastWorkday(now);
    final minutesUntilEnd = _settings!.getWorkdayEnd(now).difference(now).inMinutes;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isApexHour ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: isApexHour ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isApexHour ? AppColors.primary : AppColors.textSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isApexHour ? Icons.schedule : Icons.access_time,
              color: isApexHour ? Colors.black : Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          
          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isApexHour ? 'Apex Hour Active' : 'Focus Time',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isApexHour)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isPastWorkday
                    ? 'Workday complete • Great job!'
                    : isApexHour 
                      ? 'Wind down • ${minutesUntilEnd}m remaining'
                      : 'Deep work until ${_settings!.workdayEndHour}:${_settings!.workdayEndMinute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),
          
          // Time Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                style: AppTextStyles.h5.copyWith(
                  color: isApexHour ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                width: 40,
                height: 3,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: AppColors.borderLight,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: isApexHour ? 0.85 : 0.75,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isApexHour ? AppColors.primary : AppColors.info,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}