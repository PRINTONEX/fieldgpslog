import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/database_service.dart';
import '../../../models/work_location.dart';

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
            subtitle: const Text('Switch between Dark and Light mode'),
            trailing: IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () {
                Get.changeThemeMode(
                  Get.isDarkMode ? ThemeMode.light : ThemeMode.dark,
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Export Reports'),
            subtitle: const Text('Generate PDF of your driving logs'),
            onTap: () {
              Get.snackbar(
                  "Coming Soon", "PDF reporting interface is being finalized.");
            },
          ),
        ],
      ),
    );
  }
}
