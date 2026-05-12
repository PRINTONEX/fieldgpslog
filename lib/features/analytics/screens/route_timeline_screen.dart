import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/delivery_analytics.dart';
import '../controllers/analytics_controller.dart';

class RouteTimelineScreen extends StatefulWidget {
  const RouteTimelineScreen({super.key});

  @override
  State<RouteTimelineScreen> createState() => _RouteTimelineScreenState();
}

class _RouteTimelineScreenState extends State<RouteTimelineScreen>
    with TickerProviderStateMixin {
  late final AnalyticsController analyticsCtrl;
  final Completer<GoogleMapController> _mapController = Completer();

  // Animation & State variables
  int _selectedStopIndex = -1;
  bool _isPlaying = false;
  bool _followBike = true;
  double _playbackSpeed = 1.0;
  LatLng? _movingBikePosition;
  double _bikeRotation = 0.0;
  
  AnimationController? _movementController;
  final ScrollController _timelineScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    analyticsCtrl = Get.find<AnalyticsController>();
    
    // Auto-start animation after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _startBikeAnimation();
      });
    });
  }

  @override
  void dispose() {
    _movementController?.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  // =========================================================
  // HELPER METHODS
  // =========================================================

  LatLng interpolate(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }

  double calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lon1 = start.longitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double lon2 = end.longitude * math.pi / 180;

    double dLon = lon2 - lon1;

    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double radians = math.atan2(y, x);
    return (radians * 180 / math.pi + 360) % 360;
  }

  Future<void> focusStop(DeliveryStop stop, int index) async {
    setState(() {
      _selectedStopIndex = index;
    });

    final GoogleMapController controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(stop.latitude, stop.longitude),
          zoom: 17,
          tilt: 45,
          bearing: 45,
        ),
      ),
    );
    
    // Scroll timeline to this item
    _scrollToTimelineItem(index);
  }

  void _scrollToTimelineItem(int index) {
    if (_timelineScrollController.hasClients) {
      _timelineScrollController.animateTo(
        index * 200.0, // Approximate height of item
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _startBikeAnimation() async {
    final summary = analyticsCtrl.dailySummary.value;
    if (summary == null || summary.stops.length < 2 || _isPlaying) return;

    setState(() {
      _isPlaying = true;
      _selectedStopIndex = 0;
    });

    final stops = summary.stops;

    for (int i = 0; i < stops.length - 1; i++) {
      if (!_isPlaying) break;

      final start = LatLng(stops[i].latitude, stops[i].longitude);
      final end = LatLng(stops[i + 1].latitude, stops[i + 1].longitude);

      setState(() {
        _selectedStopIndex = i;
        _bikeRotation = calculateBearing(start, end);
      });

      // Pause at delivery stop (Blinkit/Uber style)
      await Future.delayed(Duration(milliseconds: (1500 / _playbackSpeed).round()));
      
      _movementController?.dispose();
      _movementController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (3000 / _playbackSpeed).round()),
      );

      final animation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _movementController!, curve: Curves.linear),
      );

      animation.addListener(() async {
        if (!mounted) return;
        final pos = interpolate(start, end, animation.value);
        setState(() {
          _movingBikePosition = pos;
        });

        if (_followBike) {
          final GoogleMapController controller = await _mapController.future;
          controller.moveCamera(CameraUpdate.newLatLng(pos));
        }
      });

      await _movementController!.forward();
    }

    setState(() {
      _isPlaying = false;
      _selectedStopIndex = stops.length - 1;
      _movingBikePosition = null;
    });
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _movementController?.stop();
      setState(() => _isPlaying = false);
    } else {
      _startBikeAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyLarge?.color;
    final subTextColor = theme.textTheme.bodyMedium?.color;
    final borderColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Route Replay',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cardColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_followBike ? Icons.videocam : Icons.videocam_off),
            onPressed: () => setState(() => _followBike = !_followBike),
            tooltip: 'Follow Vehicle',
          ),
        ],
      ),
      body: Obx(() {
        final summary = analyticsCtrl.dailySummary.value;

        if (summary == null || summary.stops.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timeline_outlined,
                  size: 100,
                  color: subTextColor?.withValues(alpha: 0.3) ?? borderColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'No route data available',
                  style: TextStyle(color: subTextColor, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                // ================= MAP CONTAINER =================
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: borderColor.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: _buildInteractiveMap(summary, primaryColor, isDark),
                    ),
                  ),
                ),

                // ================= TIMELINE SECTION =================
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTimeline(
                      summary,
                      textColor,
                      subTextColor,
                      borderColor,
                      cardColor,
                      isDark,
                    ),
                  ),
                ),
              ],
            ),

            // ================= CONTROLS OVERLAY =================
            _buildPlaybackControls(isDark, cardColor, primaryColor),
          ],
        );
      }),
    );
  }

  // =========================================================
  // UI COMPONENTS
  // =========================================================

  Widget _buildPlaybackControls(bool isDark, Color cardColor, Color primaryColor) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speed Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              children: [1.0, 2.0, 4.0].map((s) {
                final isSelected = _playbackSpeed == s;
                return GestureDetector(
                  onTap: () => setState(() => _playbackSpeed = s),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${s.toInt()}x',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Play/Pause
          FloatingActionButton(
            heroTag: 'play_pause',
            onPressed: _togglePlayback,
            backgroundColor: primaryColor,
            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(height: 12),
          // Replay
          FloatingActionButton.small(
            heroTag: 'replay',
            onPressed: () {
              _movementController?.stop();
              setState(() {
                _isPlaying = false;
                _movingBikePosition = null;
              });
              _startBikeAnimation();
            },
            backgroundColor: cardColor,
            child: Icon(Icons.replay, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMap(DailyTravelSummary summary, Color primaryColor, bool isDark) {
    final stops = summary.stops;
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final isSelected = i == _selectedStopIndex;

      markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(stop.latitude, stop.longitude),
          onTap: () => focusStop(stop, i),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            stop.stopType == 'home' ? BitmapDescriptor.hueRed : 
            stop.stopType == 'office' ? BitmapDescriptor.hueGreen : 
            BitmapDescriptor.hueBlue
          ),
          alpha: isSelected ? 1.0 : 0.7,
          infoWindow: InfoWindow(
            title: '${stop.stopType.toUpperCase()} #${i + 1}',
            snippet: DateFormat('hh:mm a').format(stop.arrivalTime),
          ),
        ),
      );
    }

    // Moving Bike Marker
    if (_movingBikePosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('moving_bike'),
          position: _movingBikePosition!,
          rotation: _bikeRotation,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          zIndexInt: 2,
        ),
      );
    }

    final polylinePoints = stops.map((e) => LatLng(e.latitude, e.longitude)).toList();

    if (polylinePoints.length > 1) {
      // Completed path
      if (_selectedStopIndex > 0) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('completed'),
            points: polylinePoints.sublist(0, _selectedStopIndex + 1),
            color: Colors.green,
            width: 5,
            geodesic: true,
          ),
        );
      }
      // Remaining path
      polylines.add(
        Polyline(
          polylineId: const PolylineId('upcoming'),
          points: polylinePoints.sublist(_selectedStopIndex != -1 ? _selectedStopIndex : 0),
          color: primaryColor.withValues(alpha: 0.4),
          width: 5,
          geodesic: true,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(stops[0].latitude, stops[0].longitude),
        zoom: 14,
      ),
      markers: markers,
      polylines: polylines,
      zoomControlsEnabled: false,
      myLocationEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) => _mapController.complete(controller),
      style: isDark ? _darkMapStyle : null,
    );
  }

  Widget _buildTimeline(
    DailyTravelSummary summary,
    Color? textColor,
    Color? subTextColor,
    Color borderColor,
    Color cardColor,
    bool isDark,
  ) {
    final stops = summary.stops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Journey Timeline',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            controller: _timelineScrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              final isLast = index == stops.length - 1;
              final isSelected = index == _selectedStopIndex;

              return _buildTimelineItem(
                context: context,
                index: index,
                stop: stop,
                nextStop: !isLast ? stops[index + 1] : null,
                isLast: isLast,
                isSelected: isSelected,
                textColor: textColor,
                subTextColor: subTextColor,
                borderColor: borderColor,
                cardColor: cardColor,
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required int index,
    required DeliveryStop stop,
    required DeliveryStop? nextStop,
    required bool isLast,
    required bool isSelected,
    required Color? textColor,
    required Color? subTextColor,
    required Color borderColor,
    required Color cardColor,
    required bool isDark,
  }) {
    final stopColor = stop.stopType == 'home'
        ? Colors.redAccent
        : stop.stopType == 'office'
            ? Colors.greenAccent[700]!
            : Colors.blueAccent;

    final stopIcon = stop.stopType == 'home'
        ? Icons.home_rounded
        : stop.stopType == 'office'
            ? Icons.business_rounded
            : Icons.local_shipping_rounded;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicator column
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSelected ? 56 : 48,
                height: isSelected ? 56 : 48,
                decoration: BoxDecoration(
                  color: isSelected ? stopColor : stopColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : stopColor.withValues(alpha: 0.4),
                    width: isSelected ? 3 : 2
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(color: stopColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)
                  ] : [],
                ),
                child: Icon(
                  stopIcon, 
                  color: isSelected ? Colors.white : stopColor, 
                  size: isSelected ? 28 : 24
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          stopColor.withValues(alpha: 0.5),
                          borderColor.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Content Column
          Expanded(
            child: GestureDetector(
              onTap: () => focusStop(stop, index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? stopColor.withValues(alpha: 0.1) : cardColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? stopColor.withValues(alpha: 0.3) : borderColor.withValues(alpha: 0.1),
                    width: isSelected ? 2 : 1
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${stop.stopType.toUpperCase()} #${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? stopColor : subTextColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.gps_fixed, size: 16, color: stopColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${DateFormat('hh:mm a').format(stop.arrivalTime)} – ${DateFormat('hh:mm a').format(stop.departureTime)}',
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTimelineChip(
                          Icons.timer_outlined,
                          stop.formattedDuration,
                          Colors.orange,
                          isDark,
                        ),
                        if (stop.distanceFromPreviousStop > 0)
                          _buildTimelineChip(
                            Icons.map_outlined,
                            '${stop.distanceFromPreviousStop.toStringAsFixed(1)} km',
                            Colors.blue,
                            isDark,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Dark Map Style JSON
  final String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#212121"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#212121"}]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{"color": "#181818"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#2c2c2c"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#000000"}]
  }
]
''';
}
