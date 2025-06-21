import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/task.dart';
import '../models/user_settings.dart';
import 'offline_ai_service.dart';

class AIRecommendationService {
  static final AIRecommendationService _instance = AIRecommendationService._internal();
  static AIRecommendationService get instance => _instance;
  AIRecommendationService._internal();

  // Hugging Face API configuration from environment variables
  static String get _baseUrl => dotenv.env['HUGGING_FACE_API_BASE_URL'] ?? 'https://api-inference.huggingface.co/models';
  static String get _modelId => dotenv.env['HUGGING_FACE_MODEL_ID'] ?? 'microsoft/Phi-3-medium-128k-instruct';
  static String get _apiUrl => '$_baseUrl/$_modelId';
  static String get _apiToken => dotenv.env['HUGGING_FACE_API_TOKEN'] ?? '';

  // Fallback recommendations for when API is unavailable
  static const List<String> _fallbackRecommendations = [
    'Take a 10-minute screen break and look at something 20 feet away',
    'Stand up and do some light stretching for 5 minutes',
    'Stay hydrated - grab a glass of water',
    'Practice deep breathing for 2 minutes to reduce stress',
    'Take a quick walk around your workspace',
    'Check your posture and adjust your chair height',
    'Do some neck and shoulder rolls to release tension',
    'Step outside for a few minutes of fresh air',
  ];

  /// Generates a health recommendation based on current work context
  /// Uses offline AI as primary method, with cloud AI as optional enhancement
  Future<String> generateHealthRecommendation({
    required UserSettings settings,
    required List<Task> todaysTasks,
    required DateTime currentTime,
  }) async {
    try {
      // Primary: Use offline AI (always available, private, fast)
      print('Generating recommendation using offline AI');
      final offlineRecommendation = OfflineAIService.instance.generateSmartRecommendation(
        settings: settings,
        todaysTasks: todaysTasks,
        currentTime: currentTime,
      );
      
      print('Successfully generated offline AI recommendation');
      return offlineRecommendation;
      
      // Note: Cloud AI is available but offline AI is preferred for privacy
      // Uncomment below to try cloud enhancement as fallback
      /*
      // Optional: Try to enhance with cloud AI if configured
      if (isAPIConfigured) {
        try {
          print('Attempting cloud AI enhancement');
          final context = _buildWorkContext(settings, todaysTasks, currentTime);
          final prompt = _buildHealthPrompt(context);
          final cloudRecommendation = await _callHuggingFaceAPI(prompt);
          final cleaned = _cleanRecommendation(cloudRecommendation);
          
          if (cleaned.isNotEmpty) {
            print('Enhanced with cloud AI');
            return cleaned;
          }
        } catch (e) {
          print('Cloud enhancement failed, using offline recommendation: $e');
        }
      }
      */
          
    } catch (e) {
      print('Offline AI Error: $e, falling back to curated recommendations');
      return _getFallbackRecommendation();
    }
  }

  /// Builds work context from current state
  String _buildWorkContext(UserSettings settings, List<Task> todaysTasks, DateTime currentTime) {
    final workdayStart = settings.getWorkdayStart(currentTime);
    final workdayEnd = settings.getWorkdayEnd(currentTime);
    final apexHourStart = settings.getApexHourStart(currentTime);
    
    final hoursWorked = currentTime.difference(workdayStart).inMinutes / 60.0;
    final hoursUntilEnd = workdayEnd.difference(currentTime).inMinutes / 60.0;
    
    final deepWorkTasks = todaysTasks.where((t) => t.type == TaskType.deepWork).length;
    final completedTasks = todaysTasks.where((t) => t.status == TaskStatus.completed).length;
    
    final isInApexHour = currentTime.isAfter(apexHourStart) && currentTime.isBefore(workdayEnd);
    
    return '''
Work Context:
- Hours worked today: ${hoursWorked.toStringAsFixed(1)}
- Hours until end of workday: ${hoursUntilEnd.toStringAsFixed(1)}
- Deep work tasks today: $deepWorkTasks
- Completed tasks: $completedTasks of ${todaysTasks.length}
- Currently in Apex Hour: $isInApexHour
- Current time: ${currentTime.hour}:${currentTime.minute.toString().padLeft(2, '0')}
''';
  }

  /// Builds the health recommendation prompt
  String _buildHealthPrompt(String context) {
    return '''You are a health and wellness assistant for programmers. Based on the current work context, provide a single, specific, actionable health tip that takes 1-5 minutes to complete.

$context

Generate a brief health recommendation (1-2 sentences) focused on:
- Physical wellness (posture, movement, eye strain)
- Mental wellness (stress relief, focus breaks)
- Workplace ergonomics
- Hydration and nutrition

Keep it concise, practical, and appropriate for a programmer's workspace. Do not include any disclaimers or medical advice warnings.

Recommendation:''';
  }

  /// Calls the Hugging Face API
  Future<String> _callHuggingFaceAPI(String prompt) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Authorization': 'Bearer $_apiToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'inputs': prompt,
        'parameters': {
          'max_new_tokens': 100,
          'temperature': 0.7,
          'top_p': 0.9,
          'do_sample': true,
          'return_full_text': false,
        },
        'options': {
          'wait_for_model': true,
          'use_cache': false,
        }
      }),
    );

    print('API Response Status: ${response.statusCode}');
    print('API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        return data[0]['generated_text'] ?? '';
      } else if (data is Map && data.containsKey('generated_text')) {
        return data['generated_text'] ?? '';
      }
      
      // Handle error responses
      if (data is Map && data.containsKey('error')) {
        throw Exception('API Error: ${data['error']}');
      }
    } else if (response.statusCode == 404) {
      throw Exception('Model not found. The model "$_modelId" may not be available via Inference API.');
    } else if (response.statusCode == 503) {
      throw Exception('Model is loading. Please try again in a few moments.');
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded. Please try again later.');
    }
    
    throw Exception('API call failed with status: ${response.statusCode}, body: ${response.body}');
  }

  /// Cleans and validates the AI response
  String _cleanRecommendation(String rawRecommendation) {
    // Remove the original prompt if it's included
    String cleaned = rawRecommendation.replaceAll(RegExp(r'^.*Recommendation:\s*'), '');
    
    // Remove extra whitespace and newlines
    cleaned = cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Limit length to reasonable size
    if (cleaned.length > 200) {
      cleaned = cleaned.substring(0, 200);
      // Try to end at a sentence boundary
      final lastPeriod = cleaned.lastIndexOf('.');
      if (lastPeriod > 100) {
        cleaned = cleaned.substring(0, lastPeriod + 1);
      }
    }
    
    // Ensure it ends with proper punctuation
    if (cleaned.isNotEmpty && !cleaned.endsWith('.') && !cleaned.endsWith('!')) {
      cleaned += '.';
    }
    
    return cleaned;
  }

  /// Returns a random fallback recommendation
  String _getFallbackRecommendation() {
    final random = Random();
    return _fallbackRecommendations[random.nextInt(_fallbackRecommendations.length)];
  }

  /// Checks if API is available and configured
  bool get isAPIConfigured => _apiToken.isNotEmpty && _apiToken != 'your_token_here';

  /// Gets current model ID
  String get currentModelId => _modelId;

  /// Tests if the current model is available via the API
  Future<bool> testModelAvailability() async {
    if (!isAPIConfigured) return false;
    
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': 'Test prompt',
          'parameters': {'max_new_tokens': 10},
          'options': {'wait_for_model': false}
        }),
      );
      
      print('Model availability test: Status ${response.statusCode}');
      
      // 200 means model is working, 503 means model exists but is loading
      return response.statusCode == 200 || response.statusCode == 503;
    } catch (e) {
      print('Model availability test failed: $e');
      return false;
    }
  }
}