import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'services/database_service.dart';
import 'services/background_service.dart';
import 'features/vehicles/controllers/vehicle_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Database as a permanent service
  final dbService = Get.put(DatabaseService(), permanent: true);
  await dbService.init();

  // Initialize Vehicle Controller
  Get.put(VehicleController(), permanent: true);

  // Initialize Background Service configuration
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
      home: const DashboardScreen(),
      // Add named routes for navigation
      getPages: [
        GetPage(name: '/', page: () => const DashboardScreen()),
        // Other pages like /settings, /vehicles can be added here
      ],
    );
  }
}
