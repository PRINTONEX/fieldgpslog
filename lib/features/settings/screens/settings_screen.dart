import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/database_service.dart';
import '../../../models/work_location.dart';
import '../../../services/analytics_service.dart';
import '../../../services/pdf_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _saveCurrentLocation(String name) async {
    try {
      final db = Get.find<DatabaseService>();
      final position = await Geolocator.getCurrentPosition();

      final location = WorkLocation(
        name: name,
        latitude: position.latitude,
        longitude: position.longitude,
        radius: 100.0,
      );

      await db.saveWorkLocation(location);
      Get.snackbar("Success", "$name location saved successfully");
    } catch (e) {
      Get.snackbar("Error", "Could not get current location: $e");
    }
  }

  Future<void> _exportRangeReport(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Theme.of(context).colorScheme.onPrimary,
                  surface: Theme.of(context).colorScheme.surface,
                  onSurface: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      try {
        final analyticsService = Get.find<AnalyticsService>();
        final pdfService = PdfService();

        final summaries = await analyticsService.getAnalyticsRange(picked.start, picked.end);

        Get.back(); // Close loading dialog

        if (summaries.isEmpty) {
          Get.snackbar("No Data", "No trips found for the selected date range.");
          return;
        }

        await pdfService.shareRangeReport(summaries, picked.start, picked.end);
      } catch (e) {
        Get.back(); // Close loading dialog
        Get.snackbar("Error", "Failed to generate report: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.directions_bike),
            title: const Text('Vehicle Management'),
            subtitle: const Text('Add vehicles and set per km rates'),
            onTap: () => Get.toNamed('/vehicles'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Set Home Location'),
            subtitle: const Text('Use current location as Home'),
            onTap: () => _saveCurrentLocation('Home'),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Set Office Location'),
            subtitle: const Text('Use current location as Office'),
            onTap: () => _saveCurrentLocation('Office'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('Google Maps API'),
            subtitle: const Text('Configure your API Key'),
            onTap: () {
              Get.defaultDialog(
                title: "Google Maps API",
                content: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "API Key",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                textConfirm: "Save",
                onConfirm: () => Get.back(),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Appearance'),
            subtitle: Text('Current: ${Get.isDarkMode ? 'Dark' : 'Light'} Mode'),
            onTap: () {
              Get.defaultDialog(
                title: "Appearance",
                titleStyle: const TextStyle(fontWeight: FontWeight.bold),
                content: Column(
                  children: [
                    ListTile(
                      title: const Text("System Default"),
                      leading: const Icon(Icons.brightness_auto),
                      onTap: () {
                        Get.changeThemeMode(ThemeMode.system);
                        Get.back();
                      },
                    ),
                    ListTile(
                      title: const Text("Light Mode"),
                      leading: const Icon(Icons.light_mode),
                      onTap: () {
                        Get.changeThemeMode(ThemeMode.light);
                        Get.back();
                      },
                    ),
                    ListTile(
                      title: const Text("Dark Mode"),
                      leading: const Icon(Icons.dark_mode),
                      onTap: () {
                        Get.changeThemeMode(ThemeMode.dark);
                        Get.back();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Export Reports'),
            subtitle: const Text('Generate PDF of your driving logs'),
            onTap: () => _exportRangeReport(context),
          ),
        ],
      ),
    );
  }
}
