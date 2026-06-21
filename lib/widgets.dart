// ─── scan_fab.dart ───────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../screens/scan_screen.dart';

class ScanFab extends StatelessWidget {
  final VoidCallback onScanPressed;
  const ScanFab({super.key, required this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppTheme.primaryBlue, Color(0xFF0A4FBB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x661A6FE8),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

// ─── uncertain_banner.dart ───────────────────────────────────────────────────

class UncertainBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const UncertainBanner({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.warningAmber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.warningAmber.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count ${count == 1 ? 'horaire doit être vérifié' : 'horaires doivent être vérifiés'}',
                style: const TextStyle(
                  color: AppTheme.warningAmber,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.warningAmber),
          ],
        ),
      ),
    );
  }
}

// ─── shift_detail_sheet.dart ─────────────────────────────────────────────────

class ShiftDetailSheet extends StatelessWidget {
  final ShiftEntry shift;
  const ShiftDetailSheet({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Détail de l\'horaire',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: shift.type.icon,
            color: shift.type.color,
            label: 'Type',
            value: shift.type.label,
          ),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            color: AppTheme.primaryBlue,
            label: 'Date',
            value: '${shift.date.day}/${shift.date.month}/${shift.date.year}',
          ),
          if (shift.startTime != null)
            _InfoRow(
              icon: Icons.schedule_rounded,
              color: AppTheme.accentTeal,
              label: 'Horaire',
              value: shift.timeLabel,
            ),
          if (shift.duration != null)
            _InfoRow(
              icon: Icons.timer_rounded,
              color: AppTheme.successGreen,
              label: 'Durée',
              value: '${shift.duration!.inHours}h${(shift.duration!.inMinutes % 60).toString().padLeft(2, '0')}',
            ),
          _InfoRow(
            icon: Icons.verified_rounded,
            color: shift.confidenceScore > 0.8 ? AppTheme.successGreen : AppTheme.warningAmber,
            label: 'Confiance IA',
            value: '${(shift.confidenceScore * 100).toInt()}%',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

// ─── shift_edit_dialog.dart ──────────────────────────────────────────────────

class ShiftEditDialog extends StatefulWidget {
  final ShiftEntry shift;
  const ShiftEditDialog({super.key, required this.shift});

  @override
  State<ShiftEditDialog> createState() => _ShiftEditDialogState();
}

class _ShiftEditDialogState extends State<ShiftEditDialog> {
  late ShiftType _type;
  late DateTime _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _type = widget.shift.type;
    _date = widget.shift.date;
    _startTime = widget.shift.startTime;
    _endTime = widget.shift.endTime;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier l\'horaire'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ShiftType.values
                  .where((t) => t != ShiftType.inconnu)
                  .map((t) => ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        selectedColor: t.color,
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text('Horaire', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(_startTime != null
                        ? '${_startTime!.hour}h${_startTime!.minute.toString().padLeft(2, '0')}'
                        : 'Début'),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
                      );
                      if (t != null) setState(() => _startTime = t);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_filled_rounded),
                    label: Text(_endTime != null
                        ? '${_endTime!.hour}h${_endTime!.minute.toString().padLeft(2, '0')}'
                        : 'Fin'),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _endTime ?? const TimeOfDay(hour: 16, minute: 30),
                      );
                      if (t != null) setState(() => _endTime = t);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final updated = widget.shift.copyWith(
              type: _type,
              date: _date,
              startTime: _startTime,
              endTime: _endTime,
              needsVerification: false,
              confidenceScore: 1.0,
            );
            Navigator.pop(context, updated);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// Import ShiftEntry where needed
import '../models/planning_models.dart';