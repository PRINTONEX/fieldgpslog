import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;

  Future<bool> handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // ✅ Request to enable GPS
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // ✅ Request Background Location Permission (Android 10+)
    if (Platform.isAndroid) {
      final backgroundStatus = await Permission.locationAlways.request();
      if (backgroundStatus.isDenied) {
        // We can still track in foreground, but background might be limited
        // However, for this app, background is critical.
        // Let's not fail, but log it.
      }

      // ✅ Request Notification Permission (Android 13+)
      final notificationStatus = await Permission.notification.request();
      if (notificationStatus.isDenied) {
        // Notifications are needed for foreground service
      }

      // ✅ Request Activity Recognition Permission
      final activityStatus = await Permission.activityRecognition.request();
      if (activityStatus.isDenied) {
        return false;
      }
    }

    return true;
  }

  void startTracking(Function(Position) onLocationChanged) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(onLocationChanged);
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
  }
}
