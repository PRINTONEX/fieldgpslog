import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/fuel_settings_service.dart';
import '../controllers/analytics_controller.dart';

class FuelSettingsWidget extends StatefulWidget {
  const FuelSettingsWidget({super.key});

  @override
  State<FuelSettingsWidget> createState() => _FuelSettingsWidgetState();
}

class _FuelSettingsWidgetState extends State<FuelSettingsWidget> {
  late TextEditingController mileageController;
  late TextEditingController priceController;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    mileageController = TextEditingController();
    priceController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await FuelSettingsService.getAllSettings();
      setState(() {
        mileageController.text = settings['mileage']!.toStringAsFixed(1);
        priceController.text = settings['price']!.toStringAsFixed(2);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        Get.snackbar('Error', 'Failed to load settings: $e',
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final mileage = double.tryParse(mileageController.text) ?? 40.0;
      final price = double.tryParse(priceController.text) ?? 100.0;

      if (mileage <= 0 || price <= 0) {
        Get.snackbar('Invalid Input', 'Values must be greater than 0',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red);
        return;
      }

      await FuelSettingsService.setMileage(mileage);
      await FuelSettingsService.setFuelPrice(price);

      // Update analytics controller if available
      if (Get.isRegistered<AnalyticsController>()) {
        final analyticsCtrl = Get.find<AnalyticsController>();
        analyticsCtrl.updateFuelSettings(mileage, price);
      }

      if (mounted) {
        Get.snackbar(
          'Success',
          'Fuel settings updated. Analytics will refresh with new calculations.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'Failed to save settings: $e',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _resetToDefaults() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will reset fuel settings to defaults:\n'
          '• Mileage: 40 km/liter\n'
          '• Price: ₹100 per liter',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FuelSettingsService.resetToDefaults();
                await _loadSettings();

                // Update analytics controller
                if (Get.isRegistered<AnalyticsController>()) {
                  final analyticsCtrl = Get.find<AnalyticsController>();
                  analyticsCtrl.updateFuelSettings(40.0, 100.0);
                }

                if (mounted) {
                  Get.snackbar(
                    'Reset',
                    'Settings reset to defaults',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.blue,
                  );
                }
              } catch (e) {
                if (mounted) {
                  Get.snackbar('Error', 'Failed to reset: $e',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red);
                }
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mileageController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fuel Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reset to Defaults',
                onPressed: _resetToDefaults,
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Text(
            'Configure these settings for accurate fuel cost calculations in daily analytics.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),

          const SizedBox(height: 20),

          // ================= MILEAGE INPUT =================
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Vehicle Mileage',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: mileageController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '40',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('km/l',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Example: If your bike gives 40 km per liter, enter 40',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ================= PRICE INPUT =================
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Fuel Price Per Liter',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('₹',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '100',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Current fuel price in your area (e.g., ₹100 per liter)',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ================= INFO BOX =================
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Colors.blue[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calculation Method',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daily Fuel Cost = (Total Distance ÷ Mileage) × Fuel Price',
                        style: TextStyle(fontSize: 11, color: Colors.blue[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ================= BUTTONS =================
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loadSettings,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save Settings',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
