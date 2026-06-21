import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/planning_provider.dart';
import '../services/ocr_service.dart';
import '../models/planning_models.dart';
import '../utils/app_theme.dart';
import '../widgets/shift_edit_dialog.dart';

class VerificationScreen extends StatefulWidget {
  final OcrResult ocrResult;
  const VerificationScreen({super.key, required this.ocrResult});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late List<ShiftEntry> _shifts;
  bool _showOnlyUncertain = false;

  @override
  void initState() {
    super.initState();
    _shifts = List.from(widget.ocrResult.shifts);
  }

  List<ShiftEntry> get _filteredShifts =>
      _showOnlyUncertain ? _shifts.where((s) => s.needsVerification).toList() : _shifts;

  @override
  Widget build(BuildContext context) {
    final uncertainCount = _shifts.where((s) => s.needsVerification).length;
    final totalConfidence = _shifts.isEmpty
        ? 0.0
        : _shifts.map((s) => s.confidenceScore).reduce((a, b) => a + b) / _shifts.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, uncertainCount, totalConfidence),
            if (uncertainCount > 0) _buildFilterBar(context, uncertainCount),
            Expanded(
              child: _filteredShifts.isEmpty
                  ? _buildEmpty(context)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredShifts.length,
                      itemBuilder: (context, i) {
                        return _ShiftVerificationCard(
                          shift: _filteredShifts[i],
                          onEdit: () => _editShift(context, _filteredShifts[i]),
                          onApprove: () => _approveShift(_filteredShifts[i]),
                          onDelete: () => _deleteShift(_filteredShifts[i]),
                        );
                      },
                    ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int uncertain, double confidence) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Vérification du planning',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                label: '${_shifts.length} jours',
                icon: Icons.calendar_today_rounded,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: '$uncertain à vérifier',
                icon: Icons.warning_amber_rounded,
                color: uncertain > 0 ? AppTheme.warningAmber : AppTheme.successGreen,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: '${(confidence * 100).toInt()}% confiance',
                icon: Icons.verified_rounded,
                color: confidence > 0.8
                    ? AppTheme.successGreen
                    : confidence > 0.6
                        ? AppTheme.warningAmber
                        : AppTheme.errorRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, int uncertainCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          FilterChip(
            label: Text(_showOnlyUncertain
                ? 'Voir tout ($_{ _shifts.length})'
                : '⚠️ Voir seulement à vérifier ($uncertainCount)'),
            selected: _showOnlyUncertain,
            onSelected: (v) => setState(() => _showOnlyUncertain = v),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, size: 64, color: AppTheme.successGreen),
          const SizedBox(height: 16),
          Text('Tout est vérifié !', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_shifts.any((s) => s.needsVerification))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Vous pourrez corriger les éléments incertains plus tard',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmAndSave,
              icon: const Icon(Icons.check_rounded, size: 24),
              label: const Text('Confirmer et enregistrer'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editShift(BuildContext context, ShiftEntry shift) async {
    final result = await showDialog<ShiftEntry>(
      context: context,
      builder: (_) => ShiftEditDialog(shift: shift),
    );
    if (result != null) {
      setState(() {
        final idx = _shifts.indexWhere((s) => s.id == shift.id);
        if (idx >= 0) _shifts[idx] = result;
      });
    }
  }

  void _approveShift(ShiftEntry shift) {
    setState(() {
      final idx = _shifts.indexWhere((s) => s.id == shift.id);
      if (idx >= 0) {
        _shifts[idx] = shift.copyWith(
          needsVerification: false,
          confidenceScore: 1.0,
        );
      }
    });
  }

  void _deleteShift(ShiftEntry shift) {
    setState(() => _shifts.removeWhere((s) => s.id == shift.id));
  }

  Future<void> _confirmAndSave() async {
    final provider = context.read<PlanningProvider>();
    
    // Update all shifts that were modified
    for (final shift in _shifts) {
      await provider.updateShift(shift);
    }

    if (!mounted) return;
    
    // Navigate to home
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Planning enregistré ! ${_shifts.length} jours ajoutés.'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftVerificationCard extends StatelessWidget {
  final ShiftEntry shift;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onDelete;

  const _ShiftVerificationCard({
    required this.shift,
    required this.onEdit,
    required this.onApprove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE d MMM', 'fr_FR').format(shift.date);
    final confidence = shift.confidenceScore;
    
    Color confidenceColor = AppTheme.successGreen;
    if (confidence < 0.6) confidenceColor = AppTheme.errorRed;
    else if (confidence < 0.8) confidenceColor = AppTheme.warningAmber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: shift.needsVerification
              ? AppTheme.warningAmber.withOpacity(0.5)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: shift.needsVerification ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: shift.type.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(shift.type.icon, color: shift.type.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalize(dateStr),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: shift.type.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              shift.type.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: shift.type.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (shift.startTime != null)
                            Text(
                              shift.timeLabel,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Confidence score
                Column(
                  children: [
                    Text(
                      '${(confidence * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: confidenceColor,
                      ),
                    ),
                    Text(
                      'confiance',
                      style: TextStyle(fontSize: 10, color: confidenceColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Raw text if uncertain
          if (shift.needsVerification && shift.rawText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.warningAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Texte lu : "${shift.rawText}"',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.warningAmber,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Actions
                  TextButton(
                    onPressed: onApprove,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('✓ OK', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Corriger', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: AppTheme.errorRed,
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Sup.', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}