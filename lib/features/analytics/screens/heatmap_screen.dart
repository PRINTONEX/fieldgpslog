import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/database_service.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final DatabaseService _db = Get.find<DatabaseService>();
  final RxSet<Circle> _heatmapCircles = <Circle>{}.obs;
  final RxBool _isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _generateHeatmap();
  }

  Future<void> _generateHeatmap() async {
    _isLoading.value = true;
    try {
      final logs = _db.getAllLogs();
      final circles = <Circle>{};
      
      int id = 0;
      for (var log in logs) {
        for (var stay in log.stays) {
          if (stay.latitude != null && stay.longitude != null) {
            final type = stay.label?.toLowerCase() ?? 'delivery';
            
            // Heatmap logic: Overlapping circles create denser colors
            circles.add(
              Circle(
                circleId: CircleId('heat_${id++}'),
                center: LatLng(stay.latitude!, stay.longitude!),
                radius: 100, // 100 meters
                fillColor: (type == 'delivery' ? Colors.blue : Colors.orange).withValues(alpha: 0.15),
                strokeWidth: 0,
              ),
            );
          }
        }
      }
      
      _heatmapCircles.assignAll(circles);
    } catch (e) {
      debugPrint("Error generating heatmap: $e");
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Heatmap'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _generateHeatmap),
        ],
      ),
      body: Obx(() {
        if (_isLoading.value) return const Center(child: CircularProgressIndicator());
        if (_heatmapCircles.isEmpty) return const Center(child: Text("No delivery history found for heatmap"));

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _heatmapCircles.first.center,
            zoom: 12,
          ),
          circles: _heatmapCircles,
          onMapCreated: (controller) {},
          myLocationEnabled: true,
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.back(),
        label: const Text("CLOSE HEATMAP"),
        icon: const Icon(Icons.close),
      ),
    );
  }
}
