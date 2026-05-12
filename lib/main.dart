import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/vehicles/screens/vehicle_list_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/analytics/screens/heatmap_screen.dart';
import 'features/debug/screens/debug_screen.dart';
import 'features/analytics/screens/daily_travel_summary_screen.dart';
import 'services/database_service.dart';
import 'services/background_service.dart';
import 'services/analytics_service.dart';
import 'services/log_service.dart';
import 'features/vehicles/controllers/vehicle_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Fix: SIGABRT 'Image is already closed' on Android (Samsungs)
  final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  // Diagnostic: Print app paths to debug data loss
  if (Platform.isAndroid) {
    getApplicationDocumentsDirectory().then((dir) {
      debugPrint('📦 App Documents Path: ${dir.path}');
    });
    getExternalStorageDirectory().then((dir) {
      debugPrint('📂 External Storage Path: ${dir?.path}');
    });
  }

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

  // ✅ Register Background Service as a singleton to avoid re-instantiation errors
  Get.put(FlutterBackgroundService());

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
        GetPage(name: '/heatmap', page: () => const HeatmapScreen()),
        GetPage(name: '/debug', page: () => const DebugScreen()),
        GetPage(name: '/analytics', page: () => const DailyTravelSummaryScreen()),
      ],
    );
  }
}
