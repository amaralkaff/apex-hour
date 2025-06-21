class UserSettings {
  final int workdayStartHour; // 24-hour format
  final int workdayStartMinute;
  final int workdayEndHour; // 24-hour format
  final int workdayEndMinute;
  final int apexHourDurationMinutes; // Duration of Apex Hour (default 60)
  final int notificationMinutesBefore; // Minutes before Apex Hour to notify (default 15)
  final bool notificationsEnabled;
  final bool hardStopEnabled;
  final String timezone;

  const UserSettings({
    this.workdayStartHour = 9,
    this.workdayStartMinute = 0,
    this.workdayEndHour = 18, // 6:00 PM
    this.workdayEndMinute = 0,
    this.apexHourDurationMinutes = 60,
    this.notificationMinutesBefore = 15,
    this.notificationsEnabled = true,
    this.hardStopEnabled = true,
    this.timezone = 'local',
  });

  // Calculate Apex Hour start time based on workday end
  DateTime getApexHourStart(DateTime date) {
    final workdayEnd = DateTime(
      date.year,
      date.month,
      date.day,
      workdayEndHour,
      workdayEndMinute,
    );
    return workdayEnd.subtract(Duration(minutes: apexHourDurationMinutes));
  }

  DateTime getWorkdayEnd(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      workdayEndHour,
      workdayEndMinute,
    );
  }

  DateTime getWorkdayStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      workdayStartHour,
      workdayStartMinute,
    );
  }

  // Check if current time is within Apex Hour
  bool isApexHour(DateTime now) {
    final apexStart = getApexHourStart(now);
    final workdayEnd = getWorkdayEnd(now);
    return now.isAfter(apexStart) && now.isBefore(workdayEnd);
  }

  // Check if current time is past workday end
  bool isPastWorkday(DateTime now) {
    final workdayEnd = getWorkdayEnd(now);
    return now.isAfter(workdayEnd);
  }

  UserSettings copyWith({
    int? workdayStartHour,
    int? workdayStartMinute,
    int? workdayEndHour,
    int? workdayEndMinute,
    int? apexHourDurationMinutes,
    int? notificationMinutesBefore,
    bool? notificationsEnabled,
    bool? hardStopEnabled,
    String? timezone,
  }) {
    return UserSettings(
      workdayStartHour: workdayStartHour ?? this.workdayStartHour,
      workdayStartMinute: workdayStartMinute ?? this.workdayStartMinute,
      workdayEndHour: workdayEndHour ?? this.workdayEndHour,
      workdayEndMinute: workdayEndMinute ?? this.workdayEndMinute,
      apexHourDurationMinutes: apexHourDurationMinutes ?? this.apexHourDurationMinutes,
      notificationMinutesBefore: notificationMinutesBefore ?? this.notificationMinutesBefore,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hardStopEnabled: hardStopEnabled ?? this.hardStopEnabled,
      timezone: timezone ?? this.timezone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workdayStartHour': workdayStartHour,
      'workdayStartMinute': workdayStartMinute,
      'workdayEndHour': workdayEndHour,
      'workdayEndMinute': workdayEndMinute,
      'apexHourDurationMinutes': apexHourDurationMinutes,
      'notificationMinutesBefore': notificationMinutesBefore,
      'notificationsEnabled': notificationsEnabled,
      'hardStopEnabled': hardStopEnabled,
      'timezone': timezone,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      workdayStartHour: json['workdayStartHour'] ?? 9,
      workdayStartMinute: json['workdayStartMinute'] ?? 0,
      workdayEndHour: json['workdayEndHour'] ?? 18,
      workdayEndMinute: json['workdayEndMinute'] ?? 0,
      apexHourDurationMinutes: json['apexHourDurationMinutes'] ?? 60,
      notificationMinutesBefore: json['notificationMinutesBefore'] ?? 15,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      hardStopEnabled: json['hardStopEnabled'] ?? true,
      timezone: json['timezone'] ?? 'local',
    );
  }
}