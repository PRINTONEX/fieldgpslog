import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/log_service.dart';

class DashboardMapController extends GetxController {
  GoogleMapController? mapController;

  // 🔥 REQUIRED VARIABLES
  final RxSet<Polyline> polylines = <Polyline>{}.obs;
  final RxSet<Marker> markers = <Marker>{}.obs;
  final List<LatLng> routePoints = [];
  final RxBool isNavMode = true.obs;
  final RxnString mapStyle = RxnString();

  BitmapDescriptor? bikeIcon;
  BitmapDescriptor? navMarkerIcon;
  LatLng? _lastBikePosition;
  double _lastRotation = 0;

  @override
  void onInit() {
    super.onInit();
    if (isNavMode.value) {
      _applyNavigationTheme();
    }
  }

  // ✅ Initial default position (Imphal area based on coordinates)
  final Rx<LatLng> initialPosition = const LatLng(24.6557166, 94.0190683).obs;
  final Rx<MapType> currentMapType = MapType.normal.obs;

  // ---------------- MAP ----------------
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    LogService.log("🗺️ Map Created and Controller bound.");
    if (_lastBikePosition != null) {
      updateBikeMarker(_lastBikePosition!, rotation: _lastRotation);
    }
  }

  void toggleNavMode() {
    isNavMode.value = !isNavMode.value;
    LogService.log("🧭 Nav Mode Toggled: ${isNavMode.value}");
    if (isNavMode.value) {
      _applyNavigationTheme();
    } else {
      mapStyle.value = null;
    }
    // Refresh polylines to apply glow
    if (routePoints.isNotEmpty) {
      updateRoute(routePoints.last);
    }
    // Refresh marker to switch between bike and nav icon
    if (_lastBikePosition != null) {
      updateBikeMarker(_lastBikePosition!, rotation: _lastRotation);
    }
  }

  void _applyNavigationTheme() {
    // Futuristic Dark Navigation Theme
    const darkStyle = '['
      '  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},'
      '  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},'
      '  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},'
      '  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},'
      '  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},'
      '  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},'
      '  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},'
      '  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}'
      ']';
    mapStyle.value = darkStyle;
  }

  void toggleMapType() {
    if (currentMapType.value == MapType.normal) {
      currentMapType.value = MapType.satellite;
    } else if (currentMapType.value == MapType.satellite) {
      currentMapType.value = MapType.terrain;
    } else if (currentMapType.value == MapType.terrain) {
      currentMapType.value = MapType.hybrid;
    } else {
      currentMapType.value = MapType.normal;
    }
    LogService.log("🗺️ Map Type changed to: ${currentMapType.value.name}");
  }

  // ✅ Set initial position (used for live location on app open)
  void setInitialPosition(LatLng position) {
    initialPosition.value = position;
    _lastBikePosition = position;
    LogService.log("📍 Initial Position set: ${position.latitude}, ${position.longitude}");
  }

  // ✅ Set bike icon and refresh marker
  void setBikeIcon(BitmapDescriptor? icon) {
    bikeIcon = icon;
    LogService.log("🛵 Bike Icon loaded into controller: ${icon != null ? 'SUCCESS' : 'NULL'}");
    if (_lastBikePosition != null) {
      updateBikeMarker(_lastBikePosition!, rotation: _lastRotation);
    }
  }

  // ---------------- CAMERA ----------------
  void updateCamera(LatLng position, {double bearing = 0, double speedKmh = 0}) {
    if (mapController == null) {
      return;
    }

    double zoom = isNavMode.value ? 19.0 : 18.0;
    double tilt = isNavMode.value ? 60.0 : 45.0;

    // Dynamic Zoom based on speed
    if (isNavMode.value) {
      if (speedKmh > 60) {
        zoom = 16.5;
      } else if (speedKmh > 30) {
        zoom = 17.5;
      } else {
        zoom = 19.0;
      }
    }

    try {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: zoom,
            bearing: bearing,
            tilt: tilt,
          ),
        ),
      );
    } catch (e) {
      // Silence error
    }
  }

  // 🔥 LIVE ROUTE (Dual Layer Glowing Cyan)
  void updateRoute(LatLng point) {
    if (routePoints.isEmpty || routePoints.last != point) {
      routePoints.add(point);
    }

    if (isNavMode.value) {
      // Create copy to trigger reactive update
      final List<LatLng> pointsCopy = List.from(routePoints);
      
      polylines.removeWhere((p) => p.polylineId.value == "route" || p.polylineId.value == "route_glow");
      
      // Outer Glow
      polylines.add(
        Polyline(
          polylineId: const PolylineId("route_glow"),
          points: pointsCopy,
          color: const Color(0x4000FFFF), // Transparent Cyan
          width: 14,
          jointType: JointType.round,
        ),
      );
      // Inner Main Line
      polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: pointsCopy,
          color: const Color(0xFF00E5FF), // Bright Cyan
          width: 6,
          jointType: JointType.round,
        ),
      );
    } else {
      polylines.removeWhere((p) => p.polylineId.value == "route_glow");
      polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: List.from(routePoints),
          color: const Color(0xFF2196F3),
          width: 6,
          jointType: JointType.round,
        ),
      );
    }
  }

  // ✅ Professional Marker Update
  void updateBikeMarker(LatLng position, {double rotation = 0}) {
    _lastBikePosition = position;
    _lastRotation = rotation;

    final BitmapDescriptor iconToUse = (isNavMode.value && navMarkerIcon != null) 
        ? navMarkerIcon! 
        : (bikeIcon ?? BitmapDescriptor.defaultMarker);

    final bikeMarker = Marker(
      markerId: const MarkerId("bike"),
      position: position,
      icon: iconToUse,
      rotation: rotation,
      anchor: const Offset(0.5, 0.5),
      flat: true,
      zIndexInt: 100,
    );

    markers.removeWhere((m) => m.markerId.value == "bike");
    markers.add(bikeMarker);
    
    // Log for debugging
    if (markers.length % 5 == 0 || markers.length == 1) {
       LogService.log("🛵 Bike Marker updated at ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}. Icon: ${bikeIcon != null ? 'Custom' : 'Default'}. Total Markers: ${markers.length}");
    }
  }

  // ✅ Jump to current position
  Future<void> centerOnUser() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final loc = LatLng(position.latitude, position.longitude);
      updateCamera(loc);
      updateBikeMarker(loc);
      LogService.log("🎯 Centered map on user: ${loc.latitude}, ${loc.longitude}");
    } catch (e) {
      LogService.log("⚠️ Could not center on user: $e");
    }
  }

  @override
  void onClose() {
    mapController = null;
    super.onClose();
  }
}
