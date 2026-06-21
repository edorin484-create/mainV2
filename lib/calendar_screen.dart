import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/planning_provider.dart';
import '../models/planning_models.dart';
import '../widgets/shift_detail_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<PlanningProvider>(
          builder: (context, provider, _) {
            final events = provider.shiftsByDay;
            final selectedShifts = _selectedDay != null
                ? provider.getShiftsForDay(_selectedDay!)
                : [];

            return Column(
              children: [
                _buildHeader(context, provider),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildCalendar(context, events, provider),
                      ),
                      if (_selectedDay != null && selectedShifts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildDayDetail(context, _selectedDay!, selectedShifts.cast<ShiftEntry>()),
                        ),
                      if (_selectedDay != null && selectedShifts.isEmpty)
                        SliverToBoxAdapter(
                          child: _buildEmptyDay(context),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PlanningProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Calendrier', style: Theme.of(context).textTheme.headlineLarge),
          Row(
            children: [
              _FormatButton(
                label: 'Semaine',
                icon: Icons.view_week_rounded,
                isSelected: _calendarFormat == CalendarFormat.week,
                onTap: () => setState(() => _calendarFormat = CalendarFormat.week),
              ),
              const SizedBox(width: 8),
              _FormatButton(
                label: 'Mois',
                icon: Icons.calendar_month_rounded,
                isSelected: _calendarFormat == CalendarFormat.month,
                onTap: () => setState(() => _calendarFormat = CalendarFormat.month),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    Map<DateTime, List<ShiftEntry>> events,
    PlanningProvider provider,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return TableCalendar<ShiftEntry>(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) {
        final key = DateTime(day.year, day.month, day.day);
        return events[key] ?? [];
      },
      calendarFormat: _calendarFormat,
      onFormatChanged: (format) => setState(() => _calendarFormat = format),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
      },
      onPageChanged: (focused) {
        _focusedDay = focused;
        provider.setSelectedMonth(focused);
      },
      locale: 'fr_FR',
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: theme.textTheme.titleLarge!,
        leftChevronIcon: Icon(Icons.chevron_left_rounded, color: colors.onSurface),
        rightChevronIcon: Icon(Icons.chevron_right_rounded, color: colors.onSurface),
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: true,
        outsideTextStyle: TextStyle(color: colors.onSurface.withOpacity(0.3)),
        defaultTextStyle: theme.textTheme.bodyLarge!,
        weekendTextStyle: theme.textTheme.bodyLarge!.copyWith(
          color: colors.onSurface.withOpacity(0.7),
        ),
        todayDecoration: BoxDecoration(
          color: colors.primary.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
        selectedDecoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        markersMaxCount: 1,
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;
          final shift = events.first as ShiftEntry;
          return Positioned(
            bottom: 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: shift.type.color,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
        defaultBuilder: (context, day, focusedDay) {
          final key = DateTime(day.year, day.month, day.day);
          final dayEvents = events[key] ?? [];
          if (dayEvents.isEmpty) return null;
          final shift = dayEvents.first;
          return _CalendarDayCell(
            day: day,
            shift: shift,
            isSelected: isSameDay(_selectedDay, day),
            isToday: isSameDay(DateTime.now(), day),
          );
        },
      ),
    );
  }

  Widget _buildDayDetail(
    BuildContext context,
    DateTime day,
    List<ShiftEntry> shifts,
  ) {
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(day);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _capitalize(dateStr),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...shifts.map((shift) => _ShiftDetailItem(
            shift: shift,
            onEdit: () => _editShift(context, shift),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyDay(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun horaire ce jour',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _editShift(BuildContext context, ShiftEntry shift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShiftDetailSheet(shift: shift),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final ShiftEntry shift;
  final bool isSelected;
  final bool isToday;

  const _CalendarDayCell({
    required this.day,
    required this.shift,
    required this.isSelected,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final bg = shift.type.color.withOpacity(isSelected ? 1.0 : 0.15);
    final textColor = isSelected ? Colors.white : shift.type.color;

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: shift.type.color, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (shift.startTime != null)
            Text(
              '${shift.startTime!.hour}h${shift.startTime!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 9,
                color: textColor.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftDetailItem extends StatelessWidget {
  final ShiftEntry shift;
  final VoidCallback onEdit;

  const _ShiftDetailItem({required this.shift, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: shift.type.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(shift.type.icon, color: shift.type.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.type.label, style: Theme.of(context).textTheme.titleMedium),
                if (shift.startTime != null)
                  Text(shift.timeLabel, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (shift.needsVerification)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB830).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFFB830)),
                  const SizedBox(width: 4),
                  Text(
                    'À vérifier',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFFFB830),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}