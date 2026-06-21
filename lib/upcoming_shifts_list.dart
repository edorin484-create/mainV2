// ─── upcoming_shifts_list.dart ───────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/planning_models.dart';
import '../utils/app_theme.dart';

class UpcomingShiftsList extends StatelessWidget {
  final List<ShiftEntry> shifts;
  const UpcomingShiftsList({super.key, required this.shifts});

  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Aucun horaire à venir',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shifts.length,
      itemBuilder: (context, i) => _ShiftListItem(shift: shifts[i]),
    );
  }
}

class _ShiftListItem extends StatelessWidget {
  final ShiftEntry shift;
  const _ShiftListItem({required this.shift});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shiftDay = DateTime(shift.date.year, shift.date.month, shift.date.day);
    final diff = shiftDay.difference(today).inDays;

    String dayLabel;
    if (diff == 0) dayLabel = "Auj.";
    else if (diff == 1) dayLabel = 'Dem.';
    else dayLabel = DateFormat('EEE d', 'fr_FR').format(shift.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  dayLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: diff == 0 ? AppTheme.primaryBlue : null,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${shift.date.day}/${shift.date.month}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          // Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: shift.type.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(shift.type.icon, color: shift.type.color, size: 16),
          ),
          const SizedBox(width: 10),
          // Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.timeLabel, style: Theme.of(context).textTheme.titleMedium),
                if (shift.duration != null)
                  Text(
                    '${shift.duration!.inHours}h de travail',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
              ],
            ),
          ),
          if (shift.needsVerification)
            const Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 18),
        ],
      ),
    );
  }
}