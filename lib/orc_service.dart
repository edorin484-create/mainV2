import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/planning_models.dart';

class OcrResult {
  final List<ShiftEntry> shifts;
  final List<ShiftEntry> uncertainShifts;
  final String rawText;
  final double globalConfidence;

  OcrResult({
    required this.shifts,
    required this.uncertainShifts,
    required this.rawText,
    required this.globalConfidence,
  });
}

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  final _uuid = const Uuid();

  // ── 1. PRÉTRAITEMENT IMAGE ──────────────────────────────────────────────────

  Future<File> preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return imageFile;

    // 1. Augmenter résolution si nécessaire (scale up small images)
    if (image.width < 1500) {
      final scale = 1500 / image.width;
      image = img.copyResize(
        image,
        width: (image.width * scale).toInt(),
        height: (image.height * scale).toInt(),
        interpolation: img.Interpolation.cubic,
      );
    }

    // 2. Correction gamma pour améliorer les zones sombres
    image = img.adjustColor(image, gamma: 0.85);

    // 3. Augmenter le contraste
    image = img.contrast(image, contrast: 130);

    // 4. Netteté (unsharp mask simulé)
    final blurred = img.gaussianBlur(image, radius: 1);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);
        final r = (orig.r + (orig.r - blur.r) * 1.5).clamp(0, 255).toInt();
        final g = (orig.g + (orig.g - blur.g) * 1.5).clamp(0, 255).toInt();
        final b = (orig.b + (orig.b - blur.b) * 1.5).clamp(0, 255).toInt();
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // 5. Binarisation adaptative pour les petits caractères
    image = _adaptiveThreshold(image);

    // Sauvegarder l'image prétraitée
    final processedPath = imageFile.path.replaceAll('.jpg', '_processed.jpg')
        .replaceAll('.jpeg', '_processed.jpeg')
        .replaceAll('.png', '_processed.png');
    
    final processedFile = File(processedPath);
    await processedFile.writeAsBytes(img.encodeJpg(image, quality: 95));
    return processedFile;
  }

  img.Image _adaptiveThreshold(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);
    const blockSize = 25;
    const C = 10;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        // Calculer la moyenne locale
        int sum = 0;
        int count = 0;
        for (int ky = max(0, y - blockSize ~/ 2);
            ky < min(image.height, y + blockSize ~/ 2);
            ky++) {
          for (int kx = max(0, x - blockSize ~/ 2);
              kx < min(image.width, x + blockSize ~/ 2);
              kx++) {
            final p = image.getPixel(kx, ky);
            sum += (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toInt();
            count++;
          }
        }
        final mean = count > 0 ? sum / count : 128;
        final pixel = image.getPixel(x, y);
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();

        if (gray < mean - C) {
          result.setPixelRgb(x, y, 0, 0, 0);
        } else {
          result.setPixelRgb(x, y, 255, 255, 255);
        }
      }
    }
    return result;
  }

  // ── 2. OCR ML KIT ──────────────────────────────────────────────────────────

  Future<OcrResult> analyzeImage(File imageFile, {int? planningId}) async {
    // Prétraitement
    final processedFile = await preprocessImage(imageFile);

    // OCR ML Kit
    final inputImage = InputImage.fromFile(processedFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    RecognizedText recognizedText;
    try {
      recognizedText = await recognizer.processImage(inputImage);
    } finally {
      recognizer.close();
    }

    final rawText = recognizedText.text;

    // Analyser le texte extrait
    return _parseOcrText(rawText, recognizedText, planningId: planningId);
  }

  // ── 3. ANALYSE INTELLIGENTE DU TEXTE ───────────────────────────────────────

  OcrResult _parseOcrText(
    String rawText,
    RecognizedText recognizedText, {
    int? planningId,
  }) {
    final allShifts = <ShiftEntry>[];
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Détecter l'année de référence dans le texte
    int refYear = DateTime.now().year;
    final yearMatch = RegExp(r'\b(202[0-9])\b').firstMatch(rawText);
    if (yearMatch != null) refYear = int.parse(yearMatch.group(1)!);

    // Stratégie 1 : Détecter lignes de dates
    final dateLines = _findDateLines(lines);
    
    if (dateLines.isNotEmpty) {
      // Parsing orienté tableau
      allShifts.addAll(_parseTableFormat(lines, dateLines, refYear, planningId));
    }
    
    // Stratégie 2 : Parsing ligne par ligne
    if (allShifts.isEmpty) {
      allShifts.addAll(_parseLineByLine(lines, refYear, planningId));
    }

    // Supprimer les doublons par date
    final uniqueShifts = _deduplicateShifts(allShifts);

    final uncertainShifts = uniqueShifts.where((s) => s.needsVerification).toList();
    final globalConfidence = uniqueShifts.isEmpty
        ? 0.0
        : uniqueShifts.map((s) => s.confidenceScore).reduce((a, b) => a + b) /
            uniqueShifts.length;

    return OcrResult(
      shifts: uniqueShifts,
      uncertainShifts: uncertainShifts,
      rawText: rawText,
      globalConfidence: globalConfidence,
    );
  }

  List<int> _findDateLines(List<String> lines) {
    final dateLineIndices = <int>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_containsMultipleDates(line) || _isDayHeaderLine(line)) {
        dateLineIndices.add(i);
      }
    }
    return dateLineIndices;
  }

  bool _containsMultipleDates(String line) {
    final datePattern = RegExp(r'\b\d{1,2}[/.\-]\d{1,2}');
    return datePattern.allMatches(line).length >= 3;
  }

  bool _isDayHeaderLine(String line) {
    final days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    final lower = line.toLowerCase();
    int count = 0;
    for (final day in days) {
      if (lower.contains(day)) count++;
    }
    return count >= 3;
  }

  List<ShiftEntry> _parseTableFormat(
    List<String> lines,
    List<int> dateLineIndices,
    int refYear,
    int? planningId,
  ) {
    final shifts = <ShiftEntry>[];

    for (final dateLineIdx in dateLineIndices) {
      final dateLine = lines[dateLineIdx];
      final dates = _extractDates(dateLine, refYear);
      
      if (dates.isEmpty) continue;

      // Chercher les horaires dans les lignes suivantes
      for (int di = 0; di < dates.length; di++) {
        final date = dates[di];
        
        // Chercher dans les 3 lignes suivantes
        String? shiftText;
        for (int offset = 1; offset <= 4; offset++) {
          if (dateLineIdx + offset >= lines.length) break;
          final candidate = lines[dateLineIdx + offset];
          
          // Vérifier si cette ligne contient des infos pour cette colonne
          // (approximation par position dans le texte)
          if (_looksLikeShiftInfo(candidate)) {
            shiftText = candidate;
            break;
          }
        }

        final shift = _createShiftFromText(
          shiftText ?? '',
          date,
          planningId: planningId,
        );
        if (shift != null) shifts.add(shift);
      }
    }

    return shifts;
  }

  List<ShiftEntry> _parseLineByLine(
    List<String> lines,
    int refYear,
    int? planningId,
  ) {
    final shifts = <ShiftEntry>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Chercher une date sur cette ligne
      final dates = _extractDates(line, refYear);
      if (dates.isEmpty) continue;

      // Chercher les infos de shift sur la même ligne ou la suivante
      String shiftText = line;
      if (i + 1 < lines.length && !_extractDates(lines[i + 1], refYear).isNotEmpty) {
        shiftText += ' ' + lines[i + 1];
      }

      for (final date in dates) {
        final shift = _createShiftFromText(shiftText, date, planningId: planningId);
        if (shift != null) shifts.add(shift);
      }
    }

    return shifts;
  }

  List<DateTime> _extractDates(String text, int refYear) {
    final dates = <DateTime>[];

    // Pattern DD/MM/YYYY ou DD/MM/YY
    final fullDate = RegExp(r'\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})\b');
    for (final m in fullDate.allMatches(text)) {
      try {
        final day = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        int year = int.parse(m.group(3)!);
        if (year < 100) year += 2000;
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          dates.add(DateTime(year, month, day));
        }
      } catch (_) {}
    }

    // Pattern DD/MM (sans année)
    if (dates.isEmpty) {
      final shortDate = RegExp(r'\b(\d{1,2})[/.\-](\d{1,2})\b');
      for (final m in shortDate.allMatches(text)) {
        try {
          final day = int.parse(m.group(1)!);
          final month = int.parse(m.group(2)!);
          if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
            dates.add(DateTime(refYear, month, day));
          }
        } catch (_) {}
      }
    }

    // Pattern avec nom du jour + numéro
    final dayPattern = RegExp(
      r'(lun|mar|mer|jeu|ven|sam|dim)[a-z]*\.?\s+(\d{1,2})',
      caseSensitive: false,
    );
    for (final m in dayPattern.allMatches(text)) {
      // On ne peut pas extraire le mois sans contexte complet
      // Sera géré par le contexte des autres dates trouvées
    }

    return dates;
  }

  bool _looksLikeShiftInfo(String text) {
    final timePattern = RegExp(r'\d{1,2}[h:]\d{2}');
    final keywords = ['congé', 'absent', 'repos', 'rtt', 'réunion', 'formation', 'cp', 'am', 'rc'];
    final lower = text.toLowerCase();
    return timePattern.hasMatch(text) || keywords.any((k) => lower.contains(k));
  }

  ShiftEntry? _createShiftFromText(
    String text,
    DateTime date, {
    int? planningId,
  }) {
    if (text.trim().isEmpty) return null;

    final type = ShiftTypeExt.fromString(text);
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    double confidence = 0.85;
    bool needsVerification = false;

    // Extraction des horaires
    final timePattern = RegExp(r'(\d{1,2})[h:](\d{2})');
    final timeMatches = timePattern.allMatches(text).toList();

    if (timeMatches.length >= 2) {
      startTime = TimeOfDay(
        hour: int.parse(timeMatches[0].group(1)!),
        minute: int.parse(timeMatches[0].group(2)!),
      );
      endTime = TimeOfDay(
        hour: int.parse(timeMatches[1].group(1)!),
        minute: int.parse(timeMatches[1].group(2)!),
      );
      confidence = 0.95;
    } else if (timeMatches.length == 1) {
      startTime = TimeOfDay(
        hour: int.parse(timeMatches[0].group(1)!),
        minute: int.parse(timeMatches[0].group(2)!),
      );
      confidence = 0.70;
      needsVerification = true;
    }

    // Valider les horaires
    if (startTime != null) {
      if (startTime.hour > 23 || startTime.minute > 59) {
        startTime = null;
        confidence = 0.40;
        needsVerification = true;
      }
    }

    // Score de confiance basé sur la qualité du texte
    if (text.contains('?') || text.contains('|') || text.length < 3) {
      confidence *= 0.6;
      needsVerification = true;
    }

    if (type == ShiftType.inconnu) {
      confidence *= 0.7;
      needsVerification = true;
    }

    return ShiftEntry(
      id: const Uuid().v4(),
      date: date,
      startTime: startTime,
      endTime: endTime,
      type: type,
      rawText: text,
      confidenceScore: confidence,
      needsVerification: needsVerification,
      planningId: planningId,
    );
  }

  List<ShiftEntry> _deduplicateShifts(List<ShiftEntry> shifts) {
    final byDate = <String, ShiftEntry>{};
    for (final shift in shifts) {
      final key =
          '${shift.date.year}-${shift.date.month}-${shift.date.day}';
      if (!byDate.containsKey(key) ||
          shift.confidenceScore > byDate[key]!.confidenceScore) {
        byDate[key] = shift;
      }
    }
    return byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }
}