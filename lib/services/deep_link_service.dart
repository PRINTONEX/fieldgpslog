import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../features/dashboard/controllers/dashboard_map_controller.dart';
import '../services/log_service.dart';

class DeepLinkService extends GetxService {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Future<DeepLinkService> init() async {
    _appLinks = AppLinks();

    // Check initial link if the app was opened via a link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      LogService.log("DeepLink Error (Initial): $e");
    }

    // Handle links while the app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      LogService.log("DeepLink Error (Stream): $err");
    });

    return this;
  }

  void _handleDeepLink(Uri uri) {
    LogService.log("🔗 Deep Link Received: $uri");

    // Handle geo: URIs
    if (uri.scheme == 'geo') {
      _parseGeoUri(uri);
    } 
    // Handle Google Maps URIs
    else if (uri.host.contains('google.com') || uri.host.contains('goo.gl')) {
      _parseGoogleMapsUri(uri);
    }
    // Handle Apple Maps URIs
    else if (uri.host.contains('apple.com') && uri.path.contains('maps')) {
      _parseAppleMapsUri(uri);
    }
  }

  void _parseGeoUri(Uri uri) {
    try {
      // geo:lat,lon or geo:0,0?q=lat,lon
      String path = uri.path;
      if (path.isEmpty || path.startsWith('0,0')) {
        if (uri.queryParameters.containsKey('q')) {
          path = uri.queryParameters['q']!;
        }
      }

      final parts = path.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0]);
        // Remove any labels in parentheses
        final lonString = parts[1].contains('(') ? parts[1].split('(')[0] : parts[1];
        final lon = double.tryParse(lonString);

        if (lat != null && lon != null) {
          _markLocation(LatLng(lat, lon));
        }
      }
    } catch (e) {
      LogService.log("Error parsing geo URI: $e");
    }
  }

  void _parseGoogleMapsUri(Uri uri) {
    try {
      // Check query parameter first (search or dir)
      final query = uri.queryParameters['query'] ?? uri.queryParameters['daddr'] ?? uri.queryParameters['q'];
      if (query != null) {
        final parts = query.split(',');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0]);
          final lon = double.tryParse(parts[1]);
          if (lat != null && lon != null) {
            _markLocation(LatLng(lat, lon));
            return;
          }
        }
      }

      // Check path (e.g. /maps/@24.655,94.019,15z)
      final pathParts = uri.path.split('@');
      if (pathParts.length > 1) {
        final coordParts = pathParts[1].split(',');
        if (coordParts.length >= 2) {
          final lat = double.tryParse(coordParts[0]);
          final lon = double.tryParse(coordParts[1]);
          if (lat != null && lon != null) {
            _markLocation(LatLng(lat, lon));
            return;
          }
        }
      }
    } catch (e) {
      LogService.log("Error parsing Google Maps URI: $e");
    }
  }

  void _parseAppleMapsUri(Uri uri) {
    try {
      final query = uri.queryParameters['q'] ?? uri.queryParameters['daddr'] ?? uri.queryParameters['ll'];
      if (query != null) {
        final parts = query.split(',');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0]);
          final lon = double.tryParse(parts[1]);
          if (lat != null && lon != null) {
            _markLocation(LatLng(lat, lon));
          }
        }
      }
    } catch (e) {
      LogService.log("Error parsing Apple Maps URI: $e");
    }
  }

  LatLng? _pendingLocation;

  void _markLocation(LatLng location) {
    if (Get.isRegistered<DashboardMapController>()) {
      final mapCtrl = Get.find<DashboardMapController>();
      _applyMarker(mapCtrl, location);
    } else {
      _pendingLocation = location;
      LogService.log("⏳ DashboardMapController not ready, storing pending location");
      
      // Try to apply when controller becomes available
      _waitForController();
    }
  }

  void _waitForController() async {
    int attempts = 0;
    while (!Get.isRegistered<DashboardMapController>() && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    if (Get.isRegistered<DashboardMapController>() && _pendingLocation != null) {
      final mapCtrl = Get.find<DashboardMapController>();
      _applyMarker(mapCtrl, _pendingLocation!);
      _pendingLocation = null;
    }
  }

  void _applyMarker(DashboardMapController mapCtrl, LatLng location) {
    // Add a special marker for the requested location
    final destinationMarker = Marker(
      markerId: const MarkerId("destination"),
      position: location,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: "Shared Location"),
    );

    mapCtrl.markers.removeWhere((m) => m.markerId.value == "destination");
    mapCtrl.markers.add(destinationMarker);

    // Center the camera on the new location
    mapCtrl.updateCamera(location);
    
    LogService.log("📍 Marked shared location: ${location.latitude}, ${location.longitude}");
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }
}
