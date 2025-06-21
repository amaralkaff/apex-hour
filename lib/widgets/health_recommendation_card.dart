import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/ai_recommendation_service.dart';
import '../services/work_pattern_service.dart';
import '../services/settings_service.dart';
import '../services/task_service.dart';

class HealthRecommendationCard extends StatefulWidget {
  const HealthRecommendationCard({super.key});

  @override
  State<HealthRecommendationCard> createState() => _HealthRecommendationCardState();
}

class _HealthRecommendationCardState extends State<HealthRecommendationCard> {
  String _currentRecommendation = 'Take a 10-minute screen break';
  String _currentRecommendationDetail = 'Look away, stretch, or grab some water';
  bool _isLoading = false;
  bool _hasBeenFollowed = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendation();
  }

  Future<void> _loadRecommendation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await SettingsService.instance.getSettings();
      final todaysTasks = await TaskService.instance.getTasks();
      final currentTime = DateTime.now();

      final recommendation = await AIRecommendationService.instance.generateHealthRecommendation(
        settings: settings,
        todaysTasks: todaysTasks,
        currentTime: currentTime,
      );

      if (mounted) {
        setState(() {
          final parts = recommendation.split('.');
          _currentRecommendation = parts.first.trim();
          _currentRecommendationDetail = parts.length > 1 
              ? parts.skip(1).join('.').trim()
              : 'Take a moment to focus on your wellbeing';
          _hasBeenFollowed = false;
        });
      }
    } catch (e) {
      print('Error loading recommendation: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsFollowed() async {
    if (_hasBeenFollowed) return;

    setState(() {
      _hasBeenFollowed = true;
    });

    // Record the interaction
    await WorkPatternService.instance.recordRecommendationInteraction(
      recommendation: '$_currentRecommendation. $_currentRecommendationDetail',
      wasFollowed: true,
    );

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Great job! Keep up the healthy habits 🎉',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );

      // Load a new recommendation after a short delay
      Future.delayed(const Duration(seconds: 3), _loadRecommendation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'AI Health Tips',
              style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.offline_bolt,
                    size: 12,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'OFFLINE',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Main recommendation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.healthMind.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.healthMind.withValues(alpha: 0.2)),
          ),
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.healthMind,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.psychology_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentRecommendation,
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_currentRecommendationDetail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _currentRecommendationDetail,
                              style: AppTextStyles.labelSmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _hasBeenFollowed ? null : _markAsFollowed,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _hasBeenFollowed ? AppColors.success : AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          _hasBeenFollowed ? Icons.check_circle : Icons.check,
                          color: _hasBeenFollowed ? Colors.white : Colors.black,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        
        // Quick actions row
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                '💪',
                'Stretch',
                AppColors.healthBody,
                'Do some stretching exercises to relieve muscle tension',
                () => _handleQuickAction('stretching'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickAction(
                '👁️',
                '20-20-20',
                AppColors.info,
                'Look at something 20 feet away for 20 seconds',
                () => _handleQuickAction('eye_break'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickAction(
                '💧',
                'Hydrate',
                AppColors.healthNutrition,
                'Drink a glass of water to stay hydrated',
                () => _handleQuickAction('hydration'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleQuickAction(String actionType) async {
    final actionMessages = {
      'stretching': 'Great! Take your time with those stretches 🧘',
      'eye_break': 'Perfect! Give your eyes the rest they need 👀',
      'hydration': 'Excellent! Stay hydrated throughout the day 💧',
    };

    // Record the quick action as a recommendation interaction
    final actionDescription = {
      'stretching': 'Did some stretching exercises to relieve muscle tension',
      'eye_break': 'Took a 20-20-20 eye break to reduce eye strain',
      'hydration': 'Drank water to stay hydrated',
    };

    await WorkPatternService.instance.recordRecommendationInteraction(
      recommendation: actionDescription[actionType] ?? 'Completed quick health action',
      wasFollowed: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actionMessages[actionType] ?? 'Great job on staying healthy!',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildQuickAction(String emoji, String title, Color color, String description, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}