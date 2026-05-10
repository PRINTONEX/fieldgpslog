import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/simulation_service.dart';
import '../../../services/database_service.dart';
import '../../../services/log_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final DatabaseService _db = Get.find<DatabaseService>();
  final RxBool _isSimulating = false.obs;
  double _simSpeed = 40.0;
  GoogleMapController? _mapController;
  final RxSet<Marker> _markers = <Marker>{}.obs;
  final Rx<LatLng> _currentSimPos = const LatLng(25.5788, 91.8933).obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Simulation'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Live Map Preview
          Expanded(
            flex: 2,
            child: Obx(() => GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentSimPos.value, zoom: 15),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              onTap: (pos) => _simulateSingleUpdate(pos.latitude, pos.longitude),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )),
          ),
          
          // Simulation Controls
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  const Text('Movement Controls', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildMovementControls(),
                  const SizedBox(height: 24),
                  const Text('Location Jumps (Teleport)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildTeleportControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap anywhere on the map to "teleport" or use the route simulation below.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementControls() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Obx(() => ListTile(
              title: Text(_isSimulating.value ? 'Simulating Movement...' : 'Start Driving Route'),
              subtitle: Text('Moves through a predefined path at ${_simSpeed.toStringAsFixed(0)} km/h'),
              trailing: Switch(
                value: _isSimulating.value,
                onChanged: (val) {
                  if (val) {
                    SimulationService.startMovementSimulation(speedKmh: _simSpeed);
                    _isSimulating.value = true;
                    LogService.log("Manual movement simulation started");
                  } else {
                    SimulationService.stopSimulation();
                    _isSimulating.value = false;
                    LogService.log("Manual movement simulation stopped");
                  }
                },
              ),
            )),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Speed:'),
                  Expanded(
                    child: Slider(
                      value: _simSpeed,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      label: '${_simSpeed.toInt()} km/h',
                      onChanged: (val) => setState(() => _simSpeed = val),
                    ),
                  ),
                  Text('${_simSpeed.toInt()} km/h'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeleportControls() {
    final home = _db.getWorkLocation('Home');
    final office = _db.getWorkLocation('Office');
    final petrol = _db.getWorkLocation('Petrol Pump');

    return Column(
      children: [
        _buildJumpTile('Simulate Home', home?.latitude ?? 25.5788, home?.longitude ?? 91.8933, Icons.home),
        const SizedBox(height: 8),
        _buildJumpTile('Simulate Office', office?.latitude ?? 25.5788, office?.longitude ?? 91.8933, Icons.business),
        const SizedBox(height: 8),
        _buildJumpTile('Simulate Petrol Pump', petrol?.latitude ?? 25.5900, petrol?.longitude ?? 91.9100, Icons.local_gas_station),
        const SizedBox(height: 8),
        _buildJumpTile('Simulate Highway (Outside)', 25.6100, 91.9300, Icons.add_road),
      ],
    );
  }

  Widget _buildJumpTile(String title, double lat, double lng, IconData icon) {
    return ListTile(
      tileColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text('Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}'),
      onTap: () => _simulateSingleUpdate(lat, lng),
    );
  }

  void _simulateSingleUpdate(double lat, double lng) {
    final newPos = LatLng(lat, lng);
    _currentSimPos.value = newPos;
    
    // Update local marker
    _markers.clear();
    _markers.add(Marker(
      markerId: const MarkerId('sim_pos'),
      position: newPos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));

    // Move camera
    _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));

    final service = FlutterBackgroundService();
    service.invoke('update', {
      'latitude': lat,
      'longitude': lng,
      'speed': 0.0,
      'distance': 0.0,
      'fare': 0.0,
    });
    LogService.log("Teleported to: $lat, $lng");
  }
}
