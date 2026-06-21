import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/planning_provider.dart';
import '../models/planning_models.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text('Réglages', style: Theme.of(context).textTheme.headlineLarge),
              floating: true,
              snap: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionTitle('Apparence'),
                  _SettingsTile(
                    icon: Icons.dark_mode_rounded,
                    title: 'Mode sombre',
                    subtitle: isDarkMode ? 'Activé' : 'Désactivé',
                    trailing: Switch(
                      value: isDarkMode,
                      onChanged: (_) => onToggleTheme(),
                      activeColor: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle('Notifications'),
                  Consumer<PlanningProvider>(
                    builder: (context, provider, _) {
                      return Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.notifications_rounded,
                            title: 'Rappel avant la prise de poste',
                            subtitle: provider.notifSettings.enabledBeforeShift
                                ? '${provider.notifSettings.minutesBeforeShift} min avant'
                                : 'Désactivé',
                            trailing: Switch(
                              value: provider.notifSettings.enabledBeforeShift,
                              onChanged: (v) => provider.updateNotifSettings(
                                NotificationSettings(
                                  enabledDayBefore: provider.notifSettings.enabledDayBefore,
                                  enabledBeforeShift: v,
                                  minutesBeforeShift: provider.notifSettings.minutesBeforeShift,
                                  dayBeforeTime: provider.notifSettings.dayBeforeTime,
                                ),
                              ),
                              activeColor: AppTheme.primaryBlue,
                            ),
                          ),
                          if (provider.notifSettings.enabledBeforeShift)
                            _SettingsTile(
                              icon: Icons.timer_rounded,
                              title: 'Délai de rappel',
                              subtitle: '${provider.notifSettings.minutesBeforeShift} minutes',
                              onTap: () => _pickReminderDelay(context, provider),
                            ),
                          _SettingsTile(
                            icon: Icons.tonight_rounded,
                            title: 'Rappel la veille',
                            subtitle: provider.notifSettings.enabledDayBefore
                                ? 'à ${provider.notifSettings.dayBeforeTime.hour}h${provider.notifSettings.dayBeforeTime.minute.toString().padLeft(2, '0')}'
                                : 'Désactivé',
                            trailing: Switch(
                              value: provider.notifSettings.enabledDayBefore,
                              onChanged: (v) => provider.updateNotifSettings(
                                NotificationSettings(
                                  enabledDayBefore: v,
                                  enabledBeforeShift: provider.notifSettings.enabledBeforeShift,
                                  minutesBeforeShift: provider.notifSettings.minutesBeforeShift,
                                  dayBeforeTime: provider.notifSettings.dayBeforeTime,
                                ),
                              ),
                              activeColor: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle('À propos'),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Planning CCAS AI',
                    subtitle: 'Version 1.0.0 • CCAS de Belfort',
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminderDelay(
    BuildContext context,
    PlanningProvider provider,
  ) async {
    final options = [15, 30, 45, 60, 90, 120];
    final current = provider.notifSettings.minutesBeforeShift;

    final result = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Délai de rappel'),
        children: options
            .map((mins) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, mins),
                  child: Row(
                    children: [
                      if (mins == current)
                        const Icon(Icons.check_rounded, color: AppTheme.primaryBlue, size: 18),
                      if (mins != current) const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text('$mins minutes'),
                    ],
                  ),
                ))
            .toList(),
      ),
    );

    if (result != null) {
      await provider.updateNotifSettings(
        NotificationSettings(
          enabledDayBefore: provider.notifSettings.enabledDayBefore,
          enabledBeforeShift: provider.notifSettings.enabledBeforeShift,
          minutesBeforeShift: result,
          dayBeforeTime: provider.notifSettings.dayBeforeTime,
        ),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle != null
            ? Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)
            : null,
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}