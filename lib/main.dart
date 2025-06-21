import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'widgets/apex_hour_card.dart';
import 'widgets/task_category_grid.dart';
import 'widgets/health_recommendation_card.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/task_service.dart';
import 'services/work_pattern_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize core services
  await SettingsService.instance.initialize();
  await NotificationService.instance.initialize();
  await TaskService.instance.initialize();
  await WorkPatternService.instance.initialize();
  
  // Check if first launch and request permissions
  final isFirstLaunch = await SettingsService.instance.isFirstLaunch();
  if (isFirstLaunch) {
    await NotificationService.instance.requestPermissions();
    await TaskService.instance.createSampleTasks();
    await SettingsService.instance.setFirstLaunchComplete();
  }
  
  runApp(const ApexHourApp());
}

class ApexHourApp extends StatelessWidget {
  const ApexHourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apex Hour',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _scheduleNotifications();
  }

  Future<void> _scheduleNotifications() async {
    // Schedule notifications based on current settings
    await NotificationService.instance.scheduleApexHourReminder();
    await NotificationService.instance.scheduleWorkdayEndReminder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Apex Hour',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ApexHourCard(),
            SizedBox(height: 16),
            TaskCategoryGrid(),
            SizedBox(height: 16),
            Expanded(
              child: HealthRecommendationCard(),
            ),
          ],
        ),
      ),
    );
  }
}
