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

class _RouteTimelineScreenState extends State<RouteTimelineScreen> {
  late final AnalyticsController analyticsCtrl;
  GoogleMapController? _mapController;
  final ScrollController _scrollController = ScrollController();
  bool _isMapExpanded = false;

  @override
  void initState() {
    super.initState();
    analyticsCtrl = Get.find<AnalyticsController>();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onStopSelected(int index, LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16),
      ),
    );
    if (_isMapExpanded) {
      setState(() {
        _isMapExpanded = false;
      });
    }
  }

  void _scrollToIndex(int index) {
    final double targetOffset = index * 200.0; // Estimate height per item
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final borderColor = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Route Timeline',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cardColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_isMapExpanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded),
            onPressed: () {
              setState(() {
                _isMapExpanded = !_isMapExpanded;
              });
            },
          )
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
                  color: subTextColor?.withValues(alpha: 0.2) ?? borderColor,
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  height: _isMapExpanded ? MediaQuery.of(context).size.height - 100 : 280,
                  margin: _isMapExpanded ? EdgeInsets.zero : const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_isMapExpanded ? 0 : 24),
                    border: Border.all(color: borderColor.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_isMapExpanded ? 0 : 24),
                    child: _buildRouteMapPreview(summary, primaryColor),
                  ),
                ),
                if (!_isMapExpanded)
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: summary.stops.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Journey Timeline',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        
                        final stopIndex = index - 1;
                        final stop = summary.stops[stopIndex];
                        final isLast = stopIndex == summary.stops.length - 1;

                        return GestureDetector(
                          onTap: () => _onStopSelected(stopIndex, LatLng(stop.latitude, stop.longitude)),
                          child: _buildTimelineItem(
                            context: context,
                            index: stopIndex,
                            stop: stop,
                            nextStop: !isLast ? summary.stops[stopIndex + 1] : null,
                            isLast: isLast,
                            subTextColor: subTextColor,
                            borderColor: borderColor,
                            cardColor: cardColor,
                            isDark: isDark,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            if (_isMapExpanded)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: summary.stops.length,
                    itemBuilder: (context, index) {
                      final stop = summary.stops[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: ActionChip(
                          label: Text('Stop ${index + 1}'),
                          onPressed: () => _onStopSelected(index, LatLng(stop.latitude, stop.longitude)),
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  double getMarkerHue(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return BitmapDescriptor.hueRed;
      case 'office':
        return BitmapDescriptor.hueGreen;
      case 'rest':
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueBlue;
    }
  }

  Widget _buildRouteMapPreview(DailyTravelSummary summary, Color primaryColor) {
    final stops = summary.stops;
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final hue = getMarkerHue(stop.stopType);

      markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(stop.latitude, stop.longitude),
          infoWindow: InfoWindow(
            title: '${stop.stopType.toUpperCase()} #${i + 1}',
            snippet: stop.note ?? DateFormat('hh:mm a').format(stop.arrivalTime),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () => _scrollToIndex(i),
        ),
      );
    }

    final polylinePoints = stops.map((e) => LatLng(e.latitude, e.longitude)).toList();

    if (polylinePoints.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: polylinePoints,
          color: primaryColor,
          width: 5,
          geodesic: true,
        ),
      );
    }

    double minLat = stops[0].latitude;
    double maxLat = stops[0].latitude;
    double minLon = stops[0].longitude;
    double maxLon = stops[0].longitude;

    for (final stop in stops) {
      if (stop.latitude < minLat) minLat = stop.latitude;
      if (stop.latitude > maxLat) maxLat = stop.latitude;
      if (stop.longitude < minLon) minLon = stop.longitude;
      if (stop.longitude > maxLon) maxLon = stop.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 12),
      onMapCreated: (controller) => _mapController = controller,
      markers: markers,
      polylines: polylines,
      zoomControlsEnabled: _isMapExpanded,
      myLocationEnabled: false,
      mapToolbarEnabled: _isMapExpanded,
    );
  }

  Widget _buildTimeline(
    DailyTravelSummary summary,
    Color? subTextColor,
    Color borderColor,
    Color cardColor,
    bool isDark,
  ) {
    // This method is now replaced by ListView.builder in build()
    return const SizedBox.shrink();
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required int index,
    required DeliveryStop stop,
    required DeliveryStop? nextStop,
    required bool isLast,
    required Color? subTextColor,
    required Color borderColor,
    required Color cardColor,
    required bool isDark,
  }) {
    final type = stop.stopType.toLowerCase();
    final isNote = type.contains('note');
    
    final stopColor = isNote
        ? Colors.purpleAccent
        : type == 'home'
            ? Colors.redAccent
            : type == 'office'
                ? Colors.greenAccent[700]!
                : type == 'rest'
                    ? Colors.orangeAccent
                    : Colors.blueAccent;

    final stopIcon = isNote
        ? Icons.note_alt_rounded
        : type == 'home'
            ? Icons.home_rounded
            : type == 'office'
                ? Icons.business_rounded
                : type == 'rest'
                    ? Icons.hotel_rounded
                    : Icons.local_shipping_rounded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: stopColor.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: stopColor.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(stopIcon, color: stopColor, size: 24),
            ),
            if (!isLast)
              Container(
                width: 2.5,
                height: isNote ? 80 : 140,
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
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNote ? 'QUICK NOTE' : '${stop.stopType.toUpperCase()} #${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: stopColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: subTextColor),
                  const SizedBox(width: 6),
                  Text(
                    isNote 
                      ? DateFormat('hh:mm a').format(stop.arrivalTime)
                      : '${DateFormat('hh:mm a').format(stop.arrivalTime)} – ${DateFormat('hh:mm a').format(stop.departureTime)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (stop.note != null || isNote) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: stopColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stopColor.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    stop.note ?? stop.stopType,
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              if (!isNote) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTimelineChip(
                      context,
                      Icons.timer_outlined,
                      stop.formattedDuration,
                      Theme.of(context).colorScheme.secondary.withValues(alpha: isDark ? 0.2 : 0.1),
                      Theme.of(context).colorScheme.secondary,
                    ),
                    if (stop.distanceFromPreviousStop > 0)
                      _buildTimelineChip(
                        context,
                        Icons.map_outlined,
                        '${stop.distanceFromPreviousStop.toStringAsFixed(1)} km',
                        Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                        Colors.blue,
                      ),
                  ],
                ),
              ],
              if (nextStop != null && !isNote) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car_filled_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        '${nextStop.arrivalTime.difference(stop.departureTime).inMinutes} min transit',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineChip(
    BuildContext context,
    IconData icon,
    String label,
    Color bgColor,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
