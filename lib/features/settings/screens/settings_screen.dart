import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.directions_bike),
            title: const Text('Vehicle Management'),
            subtitle: const Text('Add vehicles and set per km rates'),
            onTap: () {
              // Navigate to Vehicle List
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('Google Maps API'),
            subtitle: const Text('Configure your API Key'),
            onTap: () {
              // Show API Key Dialog
            },
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (value) {
              // Toggle Theme
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Export Reports'),
            subtitle: const Text('Generate PDF of your driving logs'),
            onTap: () {
              // Navigate to Reports screen
            },
          ),
        ],
      ),
    );
  }
}
