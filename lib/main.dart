import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/planning_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init timezone pour les notifications
  tz.initializeTimeZones();

  // Init services
  await DatabaseService.instance.init();
  await NotificationService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlanningProvider()),
      ],
      child: const PlanningCCASApp(),
    ),
  );
}

class PlanningCCASApp extends StatefulWidget {
  const PlanningCCASApp({super.key});

  @override
  State<PlanningCCASApp> createState() => _PlanningCCASAppState();
}

class _PlanningCCASAppState extends State<PlanningCCASApp> {
  bool _isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planning CCAS AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
    );
  }
}