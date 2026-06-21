import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/planning_provider.dart';
import '../models/planning_models.dart';
import '../widgets/next_shift_card.dart';
import '../widgets/upcoming_shifts_list.dart';
import '../widgets/uncertain_banner.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<PlanningProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(context),
                if (provider.uncertainShifts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: UncertainBanner(
                      count: provider.uncertainShifts.length,
                      onTap: () => Navigator.pushNamed(context, '/verify'),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: NextShiftCard(shift: provider.nextShift),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSectionTitle(context, 'Prochains horaires', Icons.schedule_rounded),
                  ),
                ),
                SliverToBoxAdapter(
                  child: UpcomingShiftsList(shifts: provider.upcomingShifts),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(now);
    
    return SliverAppBar(
      floating: true,
      snap: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planning CCAS',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            _capitalize(dateStr),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded),
          onPressed: () {},
          iconSize: 28,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}