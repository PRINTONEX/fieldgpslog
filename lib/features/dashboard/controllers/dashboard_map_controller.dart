import 'dart:ui';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DashboardMapController extends GetxController {
  GoogleMapController? mapController;

  // 🔥 REQUIRED VARIABLES
  final RxSet<Polyline> polylines = <Polyline>{}.obs;
  final RxSet<Marker> markers = <Marker>{}.obs;
  final List<LatLng> routePoints = [];

  BitmapDescriptor? bikeIcon;

  // ✅ ADD THIS
  final Rx<LatLng> initialPosition = const LatLng(25.5788, 91.8933).obs;

  // ---------------- MAP ----------------
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // ✅ Set initial position (used for live location on app open)
  void setInitialPosition(LatLng position) {
    initialPosition.value = position;
  }

  // ✅ Set bike icon
  void setBikeIcon(BitmapDescriptor? icon) {
    bikeIcon = icon;
  }

  // ---------------- CAMERA ----------------
  void updateCamera(LatLng position, {double bearing = 0}) {
    try {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 18, // ✅ Closer zoom for professional tracking
            bearing: bearing, // ✅ Rotate camera with vehicle
            tilt: 45, // ✅ Professional 3D view
          ),
        ),
      );
    } catch (e) {
      mapController = null; 
    }
  }

  // 🔥 LIVE ROUTE
  void updateRoute(LatLng point) {
    // Only add if point is different from last to save memory
    if (routePoints.isEmpty || routePoints.last != point) {
      routePoints.add(point);
    }

    polylines.add(
      Polyline(
        polylineId: const PolylineId("route"),
        points: List.from(routePoints), // Create copy to trigger update
        color: const Color(0xFF2196F3),
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
  }

  // ✅ Professional Marker Update
  void updateBikeMarker(LatLng position, {double rotation = 0}) {
    // We update the set directly. Since Marker is immutable, we replace it.
    final bikeMarker = Marker(
      markerId: const MarkerId("bike"),
      position: position,
      icon: bikeIcon ?? BitmapDescriptor.defaultMarker,
      rotation: rotation,
      anchor: const Offset(0.5, 0.5), // ✅ Center icon correctly
      flat: true, // ✅ Flat on map for professional look
      zIndexInt: 100, // ✅ Ensure it's always on top
    );

    // Efficiently update the set
    markers.removeWhere((m) => m.markerId.value == "bike");
    markers.add(bikeMarker);
  }

  @override
  void onClose() {
    mapController = null;
    super.onClose();
  }
// =================================================

// ==================================================
}
