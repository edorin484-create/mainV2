import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/planning_models.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../services/notification_service.dart';

enum ProcessingState { idle, preprocessing, analyzing, saving, done, error }

class PlanningProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;
  final _ocr = OcrService.instance;
  final _notif = NotificationService.instance;

  // State
  ProcessingState _processingState = ProcessingState.idle;
  String? _processingMessage;
  String? _errorMessage;
  double _processingProgress = 0.0;

  // Data
  List<ShiftEntry> _currentMonthShifts = [];
  List<PlanningRecord> _plannings = [];
  List<ShiftEntry> _upcomingShifts = [];
  ShiftEntry? _nextShift;
  List<ShiftEntry> _uncertainShifts = [];
  NotificationSettings _notifSettings = const NotificationSettings();

  // Pagination
  DateTime _selectedMonth = DateTime.now();

  // Getters
  ProcessingState get processingState => _processingState;
  String? get processingMessage => _processingMessage;
  String? get errorMessage => _errorMessage;
  double get processingProgress => _processingProgress;
  List<ShiftEntry> get currentMonthShifts => _currentMonthShifts;
  List<PlanningRecord> get plannings => _plannings;
  List<ShiftEntry> get upcomingShifts => _upcomingShifts;
  ShiftEntry? get nextShift => _nextShift;
  List<ShiftEntry> get uncertainShifts => _uncertainShifts;
  NotificationSettings get notifSettings => _notifSettings;
  DateTime get selectedMonth => _selectedMonth;
  bool get isProcessing => _processingState != ProcessingState.idle &&
      _processingState != ProcessingState.done &&
      _processingState != ProcessingState.error;

  // OcrResult temporaire (pour écran de vérification)
  OcrResult? _lastOcrResult;
  OcrResult? get lastOcrResult => _lastOcrResult;

  Future<void> init() async {
    await loadCurrentMonth();
    await loadPlannings();
    await loadUpcoming();
    await loadUncertain();
    await _loadNotifSettings();
  }

  // ── CHARGEMENT ──────────────────────────────────────────────────────────────

  Future<void> loadCurrentMonth() async {
    _currentMonthShifts = await _db.getShiftsByMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    notifyListeners();
  }

  Future<void> setSelectedMonth(DateTime month) async {
    _selectedMonth = month;
    await loadCurrentMonth();
  }

  Future<void> loadPlannings() async {
    _plannings = await _db.getAllPlannings();
    notifyListeners();
  }

  Future<void> loadUpcoming() async {
    _upcomingShifts = await _db.getUpcomingShifts(limit: 15);
    _nextShift = await _db.getNextShift();
    notifyListeners();
  }

  Future<void> loadUncertain() async {
    _uncertainShifts = await _db.getUncertainShifts();
    notifyListeners();
  }

  // ── TRAITEMENT IMAGE ────────────────────────────────────────────────────────

  Future<void> processImage(File imageFile) async {
    try {
      _setState(ProcessingState.preprocessing, 'Amélioration de l\'image...', 0.1);

      // Analyse OCR
      _setState(ProcessingState.analyzing, 'Lecture intelligente du tableau...', 0.35);
      
      final ocrResult = await _ocr.analyzeImage(imageFile);
      _lastOcrResult = ocrResult;

      _setState(ProcessingState.analyzing, 'Détection des horaires...', 0.60);
      await Future.delayed(const Duration(milliseconds: 500));

      _setState(ProcessingState.analyzing, 'Analyse des congés et absences...', 0.75);
      await Future.delayed(const Duration(milliseconds: 300));

      _setState(ProcessingState.saving, 'Enregistrement du planning...', 0.88);

      if (ocrResult.shifts.isNotEmpty) {
        await _savePlanningAndShifts(imageFile.path, ocrResult);
      }

      _setState(ProcessingState.done, 'Planning analysé avec succès !', 1.0);

      await loadCurrentMonth();
      await loadPlannings();
      await loadUpcoming();
      await loadUncertain();

      // Planifier les notifications
      await _scheduleNotifications();

    } catch (e) {
      _errorMessage = 'Erreur lors de l\'analyse : $e';
      _processingState = ProcessingState.error;
      notifyListeners();
    }
  }

  Future<void> _savePlanningAndShifts(String imagePath, OcrResult result) async {
    final shifts = result.shifts;
    DateTime? minDate = shifts.isEmpty ? null : shifts.map((s) => s.date).reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    DateTime? maxDate = shifts.isEmpty ? null : shifts.map((s) => s.date).reduce(
      (a, b) => a.isAfter(b) ? a : b,
    );

    final record = PlanningRecord(
      captureDate: DateTime.now(),
      imagePath: imagePath,
      startDate: minDate,
      endDate: maxDate,
      totalShifts: shifts.length,
      uncertainShifts: result.uncertainShifts.length,
    );

    final planningId = await _db.insertPlanning(record);

    final shiftsWithId = shifts
        .map((s) => s.copyWith(planningId: planningId))
        .toList();
    await _db.insertShifts(shiftsWithId);
  }

  Future<void> _scheduleNotifications() async {
    final upcoming = await _db.getUpcomingShifts(limit: 50);
    await _notif.scheduleShiftNotifications(upcoming, _notifSettings);
  }

  // ── MODIFICATION MANUELLE ───────────────────────────────────────────────────

  Future<void> updateShift(ShiftEntry shift) async {
    final updated = shift.copyWith(
      needsVerification: false,
      confidenceScore: 1.0,
    );
    await _db.updateShift(updated);
    await loadCurrentMonth();
    await loadUpcoming();
    await loadUncertain();
    await _scheduleNotifications();
  }

  Future<void> deleteShift(String id) async {
    await _db.deleteShift(id);
    await loadCurrentMonth();
    await loadUpcoming();
    await loadUncertain();
  }

  Future<void> addShift(ShiftEntry shift) async {
    await _db.insertShift(shift);
    await loadCurrentMonth();
    await loadUpcoming();
    await _scheduleNotifications();
  }

  Future<void> deletePlanning(int id) async {
    await _db.deletePlanning(id);
    await loadPlannings();
    await loadCurrentMonth();
    await loadUpcoming();
  }

  // ── PARAMÈTRES ──────────────────────────────────────────────────────────────

  Future<void> updateNotifSettings(NotificationSettings settings) async {
    _notifSettings = settings;
    await _db.saveSetting('notif_settings', 
      '${settings.enabledDayBefore ? 1 : 0}|${settings.enabledBeforeShift ? 1 : 0}|'
      '${settings.minutesBeforeShift}|${settings.dayBeforeTime.hour}|${settings.dayBeforeTime.minute}');
    await _scheduleNotifications();
    notifyListeners();
  }

  Future<void> _loadNotifSettings() async {
    final raw = await _db.getSetting('notif_settings');
    if (raw == null) return;
    final parts = raw.split('|');
    if (parts.length >= 5) {
      _notifSettings = NotificationSettings(
        enabledDayBefore: parts[0] == '1',
        enabledBeforeShift: parts[1] == '1',
        minutesBeforeShift: int.tryParse(parts[2]) ?? 60,
        dayBeforeTime: TimeOfDay(
          hour: int.tryParse(parts[3]) ?? 20,
          minute: int.tryParse(parts[4]) ?? 0,
        ),
      );
    }
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────────

  void _setState(ProcessingState state, String message, double progress) {
    _processingState = state;
    _processingMessage = message;
    _processingProgress = progress;
    notifyListeners();
  }

  void resetProcessingState() {
    _processingState = ProcessingState.idle;
    _processingMessage = null;
    _errorMessage = null;
    _processingProgress = 0.0;
    _lastOcrResult = null;
    notifyListeners();
  }

  Map<DateTime, List<ShiftEntry>> get shiftsByDay {
    final map = <DateTime, List<ShiftEntry>>{};
    for (final shift in _currentMonthShifts) {
      final day = DateTime(shift.date.year, shift.date.month, shift.date.day);
      map[day] ??= [];
      map[day]!.add(shift);
    }
    return map;
  }

  List<ShiftEntry> getShiftsForDay(DateTime day) {
    return _currentMonthShifts.where((s) =>
      s.date.year == day.year &&
      s.date.month == day.month &&
      s.date.day == day.day,
    ).toList();
  }
}