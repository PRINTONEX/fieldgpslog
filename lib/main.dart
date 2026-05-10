import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/vehicles/screens/vehicle_list_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/settings/screens/simulation_screen.dart';
import 'features/analytics/screens/heatmap_screen.dart';
import 'features/proof/screens/delivery_proof_screen.dart';
import 'services/database_service.dart';
import 'services/background_service.dart';
import 'services/analytics_service.dart';
import 'services/log_service.dart';
import 'features/vehicles/controllers/vehicle_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbService = Get.put(DatabaseService(), permanent: true);
  await dbService.initHive();
  await dbService.openBoxes();

  // Initialize LogService for debug logging
  await LogService.init();

  // Initialize Analytics Service
  final analyticsService =
      Get.put(AnalyticsService(dbService), permanent: true);
  await analyticsService.init();

  Get.put(VehicleController(), permanent: true);

  await initializeBackgroundService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Field GPS Log',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const DashboardScreen()),
        GetPage(name: '/vehicles', page: () => const VehicleListScreen()),
        GetPage(name: '/settings', page: () => const SettingsScreen()),
        GetPage(name: '/simulation', page: () => const SimulationScreen()),
        GetPage(name: '/heatmap', page: () => const HeatmapScreen()),
      ],
    );
  }
}
