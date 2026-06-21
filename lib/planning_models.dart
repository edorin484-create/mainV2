import 'package:flutter/material.dart';

enum ShiftType {
  travail,
  conge,
  absence,
  reunion,
  formation,
  repos,
  inconnu,
}

extension ShiftTypeExt on ShiftType {
  String get label {
    switch (this) {
      case ShiftType.travail: return 'Travail';
      case ShiftType.conge: return 'Congé';
      case ShiftType.absence: return 'Absence';
      case ShiftType.reunion: return 'Réunion';
      case ShiftType.formation: return 'Formation';
      case ShiftType.repos: return 'Repos';
      case ShiftType.inconnu: return 'Inconnu';
    }
  }

  Color get color {
    switch (this) {
      case ShiftType.travail: return const Color(0xFF1A6FE8);
      case ShiftType.conge: return const Color(0xFF00C6AE);
      case ShiftType.absence: return const Color(0xFFFF4757);
      case ShiftType.reunion: return const Color(0xFFFFB830);
      case ShiftType.formation: return const Color(0xFF9B59B6);
      case ShiftType.repos: return const Color(0xFF8A9BB5);
      case ShiftType.inconnu: return const Color(0xFF636E72);
    }
  }

  IconData get icon {
    switch (this) {
      case ShiftType.travail: return Icons.work_rounded;
      case ShiftType.conge: return Icons.beach_access_rounded;
      case ShiftType.absence: return Icons.person_off_rounded;
      case ShiftType.reunion: return Icons.groups_rounded;
      case ShiftType.formation: return Icons.school_rounded;
      case ShiftType.repos: return Icons.hotel_rounded;
      case ShiftType.inconnu: return Icons.help_outline_rounded;
    }
  }

  static ShiftType fromString(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('congé') || lower.contains('cp') || lower.contains('conge')) {
      return ShiftType.conge;
    }
    if (lower.contains('absent') || lower.contains('maladie') || lower.contains('am')) {
      return ShiftType.absence;
    }
    if (lower.contains('réunion') || lower.contains('reunion') || lower.contains('rdc')) {
      return ShiftType.reunion;
    }
    if (lower.contains('formation') || lower.contains('stage')) {
      return ShiftType.formation;
    }
    if (lower.contains('repos') || lower.contains('rtt') || lower.contains('rc')) {
      return ShiftType.repos;
    }
    if (RegExp(r'\d{1,2}[h:]\d{2}').hasMatch(lower)) {
      return ShiftType.travail;
    }
    return ShiftType.inconnu;
  }
}

class ShiftEntry {
  final String id;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final ShiftType type;
  final String rawText;
  final double confidenceScore; // 0.0 - 1.0
  final bool needsVerification;
  final String? note;
  final int? planningId;

  ShiftEntry({
    required this.id,
    required this.date,
    this.startTime,
    this.endTime,
    required this.type,
    required this.rawText,
    this.confidenceScore = 1.0,
    this.needsVerification = false,
    this.note,
    this.planningId,
  });

  Duration? get duration {
    if (startTime == null || endTime == null) return null;
    final start = startTime!.hour * 60 + startTime!.minute;
    final end = endTime!.hour * 60 + endTime!.minute;
    if (end > start) {
      return Duration(minutes: end - start);
    }
    return null;
  }

  String get timeLabel {
    if (startTime == null) return type.label;
    final start = '${startTime!.hour.toString().padLeft(2, '0')}h${startTime!.minute.toString().padLeft(2, '0')}';
    if (endTime == null) return start;
    final end = '${endTime!.hour.toString().padLeft(2, '0')}h${endTime!.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'start_hour': startTime?.hour,
    'start_minute': startTime?.minute,
    'end_hour': endTime?.hour,
    'end_minute': endTime?.minute,
    'type': type.name,
    'raw_text': rawText,
    'confidence_score': confidenceScore,
    'needs_verification': needsVerification ? 1 : 0,
    'note': note,
    'planning_id': planningId,
  };

  factory ShiftEntry.fromMap(Map<String, dynamic> map) {
    return ShiftEntry(
      id: map['id'],
      date: DateTime.parse(map['date']),
      startTime: map['start_hour'] != null
          ? TimeOfDay(hour: map['start_hour'], minute: map['start_minute'] ?? 0)
          : null,
      endTime: map['end_hour'] != null
          ? TimeOfDay(hour: map['end_hour'], minute: map['end_minute'] ?? 0)
          : null,
      type: ShiftType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ShiftType.inconnu,
      ),
      rawText: map['raw_text'] ?? '',
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 1.0,
      needsVerification: (map['needs_verification'] ?? 0) == 1,
      note: map['note'],
      planningId: map['planning_id'],
    );
  }

  ShiftEntry copyWith({
    String? id,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    ShiftType? type,
    String? rawText,
    double? confidenceScore,
    bool? needsVerification,
    String? note,
    int? planningId,
  }) {
    return ShiftEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      rawText: rawText ?? this.rawText,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      needsVerification: needsVerification ?? this.needsVerification,
      note: note ?? this.note,
      planningId: planningId ?? this.planningId,
    );
  }
}

class PlanningRecord {
  final int? id;
  final DateTime captureDate;
  final String imagePath;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? label;
  final int totalShifts;
  final int uncertainShifts;

  PlanningRecord({
    this.id,
    required this.captureDate,
    required this.imagePath,
    this.startDate,
    this.endDate,
    this.label,
    this.totalShifts = 0,
    this.uncertainShifts = 0,
  });

  String get periodLabel {
    if (label != null) return label!;
    if (startDate != null && endDate != null) {
      return 'Semaine du ${_fmt(startDate!)} au ${_fmt(endDate!)}';
    }
    return 'Planning du ${_fmt(captureDate)}';
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Map<String, dynamic> toMap() => {
    'capture_date': captureDate.toIso8601String(),
    'image_path': imagePath,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'label': label,
    'total_shifts': totalShifts,
    'uncertain_shifts': uncertainShifts,
  };

  factory PlanningRecord.fromMap(Map<String, dynamic> map) {
    return PlanningRecord(
      id: map['id'],
      captureDate: DateTime.parse(map['capture_date']),
      imagePath: map['image_path'],
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date']) : null,
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      label: map['label'],
      totalShifts: map['total_shifts'] ?? 0,
      uncertainShifts: map['uncertain_shifts'] ?? 0,
    );
  }
}

class NotificationSettings {
  final bool enabledDayBefore;
  final bool enabledBeforeShift;
  final int minutesBeforeShift; // minutes
  final TimeOfDay dayBeforeTime;

  const NotificationSettings({
    this.enabledDayBefore = true,
    this.enabledBeforeShift = true,
    this.minutesBeforeShift = 60,
    this.dayBeforeTime = const TimeOfDay(hour: 20, minute: 0),
  });

  Map<String, dynamic> toMap() => {
    'enabled_day_before': enabledDayBefore ? 1 : 0,
    'enabled_before_shift': enabledBeforeShift ? 1 : 0,
    'minutes_before_shift': minutesBeforeShift,
    'day_before_hour': dayBeforeTime.hour,
    'day_before_minute': dayBeforeTime.minute,
  };

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabledDayBefore: (map['enabled_day_before'] ?? 1) == 1,
      enabledBeforeShift: (map['enabled_before_shift'] ?? 1) == 1,
      minutesBeforeShift: map['minutes_before_shift'] ?? 60,
      dayBeforeTime: TimeOfDay(
        hour: map['day_before_hour'] ?? 20,
        minute: map['day_before_minute'] ?? 0,
      ),
    );
  }
}