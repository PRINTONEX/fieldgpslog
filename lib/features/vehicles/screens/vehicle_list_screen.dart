import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/vehicle.dart';
import '../controllers/vehicle_controller.dart';

class VehicleListScreen extends StatelessWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VehicleController>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicles')),
      body: Obx(
        () => ListView.builder(
          itemCount: controller.vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = controller.vehicles[index];
            return ListTile(
              leading: const Icon(Icons.directions_bike),
              title: Text(vehicle.name),
              subtitle: Text('Rate: Rs ${vehicle.ratePerKm}/km'),
              trailing: vehicle.isDefault
                  ? const Chip(
                      label: Text('Default'),
                      backgroundColor: Colors.greenAccent,
                    )
                  : null,
              onTap: () => _showEditDialog(controller, vehicle),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(controller),
        label: const Text('Add Vehicle'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(VehicleController controller) {
    final nameController = TextEditingController();
    final rateController = TextEditingController();
    var isDefault = controller.vehicles.isEmpty;

    Get.defaultDialog(
      title: 'Add New Vehicle',
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Name',
                ),
              ),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                  labelText: 'Rate per KM',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as Default'),
                value: isDefault,
                onChanged: (value) {
                  setState(() => isDefault = value ?? false);
                },
              ),
            ],
          );
        },
      ),
      textCancel: 'Cancel',
      textConfirm: 'Save',
      onConfirm: () async {
        final rate = double.tryParse(rateController.text);
        if (nameController.text.trim().isEmpty || rate == null) {
          Get.snackbar('Invalid vehicle', 'Enter a name and valid rate.');
          return;
        }

        await controller.addVehicle(nameController.text, rate, isDefault);
        Get.back();
      },
    );
  }

  void _showEditDialog(
    VehicleController controller,
    Vehicle vehicle,
  ) {
    final nameController = TextEditingController(text: vehicle.name);
    final rateController = TextEditingController(
      text: vehicle.ratePerKm.toString(),
    );
    var isDefault = vehicle.isDefault;

    Get.defaultDialog(
      title: 'Edit Vehicle',
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Vehicle Name'),
              ),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(labelText: 'Rate per KM'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as Default'),
                value: isDefault,
                onChanged: (value) {
                  setState(() => isDefault = value ?? false);
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  onPressed: () async {
                    await controller.deleteVehicle(vehicle);
                    Get.back();
                  },
                ),
              ),
            ],
          );
        },
      ),
      textCancel: 'Cancel',
      textConfirm: 'Update',
      onConfirm: () async {
        final rate = double.tryParse(rateController.text);
        if (nameController.text.trim().isEmpty || rate == null) {
          Get.snackbar('Invalid vehicle', 'Enter a name and valid rate.');
          return;
        }

        await controller.updateVehicle(
          vehicle,
          nameController.text,
          rate,
          isDefault,
        );
        Get.back();
      },
    );
  }
}
