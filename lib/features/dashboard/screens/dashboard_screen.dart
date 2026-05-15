import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../services/image_marker.dart';
import '../../../services/location_service.dart';
import '../../tracking/controllers/tracking_controller.dart';
import '../controllers/dashboard_map_controller.dart';
import '../../analytics/controllers/analytics_controller.dart';
import '../../analytics/screens/route_timeline_screen.dart';
import '../../../models/delivery_analytics.dart';
import '../../../services/log_service.dart';
import '../../../services/database_service.dart';
import '../../../services/pdf_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late final TrackingController trackingCtrl;
  late final DashboardMapController mapCtrl;
  late final AnalyticsController analyticsCtrl;
  late final LocationService locationService;
  late final TabController _tabController;
  BitmapDescriptor? bikeIcon;
  BitmapDescriptor? navMarkerIcon;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    trackingCtrl = Get.isRegistered<TrackingController>()
        ? Get.find<TrackingController>()
        : Get.put(TrackingController());

    mapCtrl = Get.isRegistered<DashboardMapController>()
        ? Get.find<DashboardMapController>()
        : Get.put(DashboardMapController());

    analyticsCtrl = Get.isRegistered<AnalyticsController>()
        ? Get.find<AnalyticsController>()
        : Get.put(AnalyticsController());

    locationService = LocationService();
    
    _initializeUI();
    
    analyticsCtrl.loadAnalyticsForDate(DateTime.now());

    // Show Default Map Prompt if not shown before
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDefaultMapPrompt();
    });
  }

  void _checkDefaultMapPrompt() async {
    final db = Get.find<DatabaseService>();
    if (!db.hasShownDefaultMapPrompt) {
      _showDefaultMapDialog();
    }
  }

  void _showDefaultMapDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.map_rounded, color: Colors.blueAccent),
            SizedBox(width: 12),
            Text("Set as Default Map?"),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("To automatically open delivery locations in this app:"),
            SizedBox(height: 16),
            Text("1. Click 'Go to Settings' below."),
            Text("2. Find 'Open by default'."),
            Text("3. Enable 'Open supported links'."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.find<DatabaseService>().setShownDefaultMapPrompt(true);
              Get.back();
            },
            child: const Text("LATER", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.find<DatabaseService>().setShownDefaultMapPrompt(true);
              Get.back();
              // Open App Info settings
              // This is a common way to lead users to the "Open by default" section
              // Since there's no direct intent for 'Open by default' sub-page across all OEMs
              await Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("GO TO SETTINGS"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _initializeUI() async {
    await loadIcons();
    await _setInitialMapPosition();
  }

  Future<void> _setInitialMapPosition() async {
    try {
      final hasPermission = await locationService.handlePermission();
      if (!hasPermission) {
        LogService.log("⚠️ No location permission for initial position");
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final loc = LatLng(position.latitude, position.longitude);
      mapCtrl.setInitialPosition(loc);
      mapCtrl.updateCamera(loc);
      mapCtrl.updateBikeMarker(loc);
      LogService.log("📍 Initial map position found: ${loc.latitude}, ${loc.longitude}");
    } catch (e) {
      debugPrint("Error setting initial map position: $e");
    }
  }

  Future<void> loadIcons() async {
    try {
      // Use local asset for bike icon
      bikeIcon = await bitmapFromAsset(
        "assets/images/gpsMarker.png",
        targetWidth: 50,
      );
      
      // Use Material Icon for navigation marker instead of URL
      navMarkerIcon = await getBitmapDescriptorFromIconData(
        Icons.navigation_rounded,
        size: 80,
        color: Colors.blueAccent,
      );
      
      mapCtrl.setBikeIcon(bikeIcon);
      mapCtrl.navMarkerIcon = navMarkerIcon;
    } catch (e) {
      debugPrint("Error loading local icons: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Disable swipe to keep map gestures
            children: [
              KeepAliveWrapper(child: _buildLiveTrackingTab()),
              KeepAliveWrapper(child: _buildDailySummaryTab()),
            ],
          ),
          // Custom Floating App Bar / Tab Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassAppBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 10, left: 16, right: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
            border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    labelColor: Theme.of(context).colorScheme.onPrimary,
                    unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                    tabs: const [
                      Tab(text: 'Live View'),
                      Tab(text: 'Analytics'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                child: IconButton(
                  icon: const Icon(Icons.list_alt_rounded),
                  onPressed: () => Get.toNamed('/logs'),
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Get.toNamed('/settings'),
                  color: Theme.of(context).iconTheme.color,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ================= LIVE TRACKING TAB =================
  Widget _buildLiveTrackingTab() {
    return Stack(
      children: [
        // Edge-to-edge map
        Obx(() {
          final markers = mapCtrl.markers.toSet();
          final polylines = mapCtrl.polylines.toSet();
          final initialPos = mapCtrl.initialPosition.value;
          final mapType = mapCtrl.currentMapType.value;
          final mapStyle = mapCtrl.mapStyle.value;

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPos,
              zoom: 15,
            ),
            onMapCreated: mapCtrl.onMapCreated,
            mapType: mapType,
            style: mapStyle,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            markers: markers,
            polylines: polylines,
            padding: const EdgeInsets.only(top: 100, bottom: 120), // ✅ Reduced padding for better visibility
          );
        }),
        
        // Floating Stats Panel (HUD in Nav Mode)
        Obx(() => mapCtrl.isNavMode.value 
          ? const SizedBox.shrink() 
          : Positioned(
              top: 100, // Below the app bar
              left: 16,
              right: 16,
              child: _buildGlassStatsPanel(trackingCtrl),
            )),

        // Control Buttons (Map Type, Nav Mode & Voice Note)
        Positioned(
          bottom: 110,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMyLocationButton(),
              const SizedBox(height: 12),
              _buildNavModeButton(),
              const SizedBox(height: 12),
              _buildMapTypeButton(),
            ],
          ),
        ),

        // Futuristic Navigation HUD
        Obx(() => mapCtrl.isNavMode.value 
          ? Positioned.fill(child: _buildNavigationHUD()) 
          : const SizedBox.shrink()),

        // Floating Action Button
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: _buildModernControlPanel(trackingCtrl),
        ),
      ],
    );
  }

  Widget _buildNavModeButton() {
    return Obx(() => FloatingActionButton.small(
      heroTag: 'nav_mode',
      onPressed: () => mapCtrl.toggleNavMode(),
      backgroundColor: mapCtrl.isNavMode.value ? Colors.cyanAccent : Colors.white,
      child: Icon(
        mapCtrl.isNavMode.value ? Icons.navigation_rounded : Icons.explore_rounded,
        color: mapCtrl.isNavMode.value ? Colors.black : Colors.blueGrey[800],
      ),
    ));
  }

  Widget _buildMyLocationButton() {
    return FloatingActionButton.small(
      heroTag: 'my_location',
      onPressed: () => mapCtrl.centerOnUser(),
      backgroundColor: Colors.white,
      child: Icon(Icons.my_location_rounded, color: Colors.blueGrey[800]),
    );
  }

  Widget _buildNavigationHUD() {
    return Stack(
      children: [
        // Top Left: Instructions
        Positioned(
          top: 100,
          left: 16,
          child: _buildGlassHUDCard(
            width: 200,
            child: const Row(
              children: [
                Icon(Icons.turn_slight_right_rounded, color: Colors.cyanAccent, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("500 m", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text("Next Delivery Point", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Top Right: Speedometer
        Positioned(
          top: 100,
          right: 16,
          child: _buildGlassHUDCard(
            width: 100,
            child: Column(
              children: [
                Obx(() => Text(
                  trackingCtrl.currentSpeed.value.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 28, fontWeight: FontWeight.bold),
                )),
                const Text("km/h", style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ),

        // Bottom Panel: Trip Stats
        Positioned(
          bottom: 100,
          left: 16,
          right: 16,
          child: _buildGlassHUDCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Obx(() => _buildHUDStat("Trip", "${trackingCtrl.totalDistance.value.toStringAsFixed(1)} km")),
                Obx(() => _buildHUDStat("Time", trackingCtrl.tripDuration.value)),
                Obx(() => _buildHUDStat("Orders", "${analyticsCtrl.dailySummary.value?.totalDeliveriesCompleted ?? 0}")),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHUDStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildGlassHUDCard({required Widget child, double? width}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMapTypeButton() {
    return Obx(() => FloatingActionButton.small(
      heroTag: 'map_type',
      onPressed: () => mapCtrl.toggleMapType(),
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      child: Icon(_getMapTypeIcon(mapCtrl.currentMapType.value), color: Colors.blueGrey[800]),
    ));
  }

  IconData _getMapTypeIcon(MapType type) {
    switch (type) {
      case MapType.normal: return Icons.map_outlined;
      case MapType.satellite: return Icons.satellite_alt_outlined;
      case MapType.terrain: return Icons.terrain_outlined;
      case MapType.hybrid: return Icons.layers_outlined;
      default: return Icons.map_outlined;
    }
  }

  Widget _buildGlassStatsPanel(TrackingController ctrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Obx(() => _buildModernStat('Speed', ctrl.currentSpeed.value.toStringAsFixed(0), 'km/h', Icons.speed_rounded, Colors.blueAccent))),
                  Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(child: Obx(() => _buildModernStat('Distance', ctrl.totalDistance.value.toStringAsFixed(1), 'km', Icons.route_rounded, Colors.greenAccent))),
                  Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(child: Obx(() => _buildModernStat('Fare', ctrl.totalFare.value.toStringAsFixed(0), '₹', Icons.account_balance_wallet_rounded, Colors.orangeAccent))),
                  Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(child: Obx(() => _buildModernStat('Time', ctrl.tripDuration.value, '', Icons.timer_rounded, Colors.purpleAccent))),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() => _buildActivityChip(ctrl.currentActivity.value)),
                  Obx(() => Text(ctrl.trackingStatus.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))),
                  Obx(() => _buildDirectionIndicator(ctrl.currentBearing.value)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStat(String label, String value, String unit, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (unit.isNotEmpty) const SizedBox(width: 2),
              if (unit.isNotEmpty) Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActivityChip(String activity) {
    String act = activity.toLowerCase();
    IconData icon = Icons.directions_walk;
    Color color = Colors.grey;
    String label = activity;

    if (act.contains('vehicle')) { 
      icon = Icons.directions_car; 
      color = Colors.blue; 
      label = "IN VEHICLE";
    }
    else if (act.contains('bicycle') || act.contains('bike')) { 
      icon = Icons.pedal_bike; 
      color = Colors.orange; 
      label = "ON BICYCLE";
    }
    else if (act.contains('still')) { 
      icon = Icons.chair_rounded; 
      color = Colors.green; 
      label = "STILL";
    }
    else if (act.contains('walking') || act.contains('foot')) {
      icon = Icons.directions_walk;
      color = Colors.indigo;
      label = "WALKING";
    }
    else if (act.contains('running')) {
      icon = Icons.directions_run;
      color = Colors.red;
      label = "RUNNING";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDirectionIndicator(double bearing) {
    return Row(
      children: [
        const Text('HEADING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: bearing * math.pi / 180,
          child: Icon(Icons.navigation_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
      ],
    );
  }

  Widget _buildModernControlPanel(TrackingController ctrl) {
    return Obx(() {
      final isTracking = ctrl.isTracking.value;
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: (isTracking ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ]
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTracking ? Colors.redAccent : Colors.greenAccent[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                  elevation: 0,
                ),
                onPressed: isTracking ? ctrl.stopTracking : ctrl.startTracking,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        isTracking ? 'END TRIP' : 'START TRACKING',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isTracking) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 65,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                    elevation: 5,
                  ),
                  onPressed: () => _showEndDaySummary(),
                  child: const FittedBox(child: Text('END DAY', style: TextStyle(fontWeight: FontWeight.bold))),
                ),
              ),
            ),
          ]
        ],
      );
    });
  }

  void _showEndDaySummary() {
    analyticsCtrl.loadAnalyticsForDate(DateTime.now());
    final pdfService = PdfService();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                const Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                IconButton(
                  onPressed: () {
                    final summary = analyticsCtrl.dailySummary.value;
                    if (summary != null) {
                      pdfService.shareDailyReport(summary);
                    }
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.blueAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Daily Journey Summary", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat("Distance", "${analyticsCtrl.dailySummary.value?.totalDistanceKm.toStringAsFixed(1)} km"),
                _buildSummaryStat("Deliveries", "${analyticsCtrl.dailySummary.value?.totalDeliveriesCompleted}"),
                _buildSummaryStat("Working Time", "${analyticsCtrl.dailySummary.value?.formattedWorkingTime}"),
              ],
            )),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final summary = analyticsCtrl.dailySummary.value;
                  if (summary != null) {
                    await pdfService.shareDailyReport(summary);
                    Get.back();
                  }
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("GENERATE & SHARE REPORT", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Get.back(), child: const Text("CLOSE")),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ================= DAILY SUMMARY TAB =================
  Widget _buildDailySummaryTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70), // Avoid app bar
      child: Obx(() {
        final primaryColor = Theme.of(context).colorScheme.primary;
        final cardColor = Theme.of(context).cardColor;
        final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

        if (analyticsCtrl.isLoading.value) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final summary = analyticsCtrl.dailySummary.value;

        return RefreshIndicator(
          onRefresh: () => analyticsCtrl.loadAnalyticsForDate(analyticsCtrl.selectedDate.value),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModernDateSelector(context, primaryColor, cardColor, subTextColor),
                
                if (summary == null)
                  _buildEmptyState(primaryColor, subTextColor)
                else ...[
                  // 1. PERFORMANCE GRID
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    child: Text('Performance Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _buildModernMetricsGrid(summary, cardColor, subTextColor),

                  // 2. TIME ALLOCATION (New Detailing)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Text('Time Allocation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _buildCategoryBreakdown(summary),

                  // 3. FUEL & EFFICIENCY
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Text('Fuel & Efficiency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),

                  _buildModernFuelCard(summary, subTextColor),

                  const SizedBox(height: 20),
                  // 5. VIEW DETAILED ROUTE BUTTON
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Get.to(() => const RouteTimelineScreen()),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 65),
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_rounded),
                            SizedBox(width: 12),
                            Text('VIEW DETAILED ROUTE MAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCategoryBreakdown(DailyTravelSummary summary) {
    // Calculate totals for the 4 categories
    int home = 0, office = 0, delivery = 0, rest = 0;
    for (var stop in summary.stops) {
      final type = stop.stopType.toLowerCase();
      if (type == 'home') home += stop.durationMinutes;
      else if (type == 'office') office += stop.durationMinutes;
      else if (type == 'rest') rest += stop.durationMinutes;
      else if (type == 'delivery') delivery += stop.durationMinutes;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCategoryStat('🏠 HOME', home, Colors.green),
          _buildCategoryStat('🏢 OFFICE', office, Colors.blue),
          _buildCategoryStat('📦 DELIV.', delivery, Colors.deepPurple),
          _buildCategoryStat('☕ REST', rest, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildCategoryStat(String label, int mins, Color color) {
    final hours = mins ~/ 60;
    final remaining = mins % 60;
    final timeStr = hours > 0 ? "${hours}h ${remaining}m" : "${remaining}m";

    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Text(timeStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildActivityTimeline() {
    return Obx(() {
      final logs = analyticsCtrl.activityLogs;
      if (logs.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text("No background events recorded yet.", style: TextStyle(color: Colors.grey, fontSize: 12)),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length > 5 ? 5 : logs.length, // Only show last 5 events for cleaner dashboard
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final log = logs[index];
          final time = DateFormat('hh:mm a').format(log.timestamp);
          
          return IntrinsicHeight(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getEventColor(log.event),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (index != (logs.length > 5 ? 4 : logs.length - 1))
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(log.event, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                        if (log.note != null && log.note!.isNotEmpty)
                          Text(log.note!, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }


  Color _getEventColor(String event) {
    if (event.contains('Reached')) {
      return Colors.green;
    }
    if (event.contains('Left')) {
      return Colors.orange;
    }
    if (event.contains('Delivery')) {
      return Colors.blue;
    }
    if (event.contains('Petrol')) {
      return Colors.purple;
    }
    return Colors.grey;
  }



  Widget _buildModernDateSelector(BuildContext context, Color primaryColor, Color cardColor, Color? subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Previous Day Button
          _buildDateNavButton(Icons.chevron_left_rounded, analyticsCtrl.goToPreviousDay),
          
          const SizedBox(width: 12),
          
          // Date Display Capsule
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: analyticsCtrl.selectedDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  await analyticsCtrl.loadAnalyticsForDate(picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(analyticsCtrl.selectedDate.value).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: subTextColor?.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(analyticsCtrl.selectedDate.value),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: subTextColor?.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Next Day Button
          _buildDateNavButton(Icons.chevron_right_rounded, analyticsCtrl.goToNextDay),
        ],
      ),
    );
  }

  Widget _buildDateNavButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }

  Widget _buildModernMetricsGrid(DailyTravelSummary summary, Color cardColor, Color? subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.3,
        children: [
          _buildPremiumCard('Distance', summary.totalDistanceKm.toStringAsFixed(1), 'km', Icons.map_rounded, Colors.blue),
          _buildPremiumCard('Duration', summary.formattedWorkingTime, '', Icons.timer_rounded, Colors.green),
          _buildPremiumCard('Stops', '${summary.totalStops}', 'places', Icons.place_rounded, Colors.orange),
          _buildPremiumCard('Avg Speed', summary.averageSpeed.toStringAsFixed(1), 'km/h', Icons.speed_rounded, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(String title, String value, String unit, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Subtle Background Gradient/Accent
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (unit.isNotEmpty) const SizedBox(width: 4),
                          if (unit.isNotEmpty)
                            Text(
                              unit,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.withValues(alpha: 0.6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFuelCard(DailyTravelSummary summary, Color? subTextColor) {
    final efficiency = summary.efficiencyPercentage;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.8), Theme.of(context).colorScheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Overall Efficiency', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('${efficiency.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: efficiency / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFuelMetric('Used', '${summary.totalFuelLiters.toStringAsFixed(1)} L'),
              _buildFuelMetric('Cost', '₹${summary.totalFuelCost.toStringAsFixed(0)}'),
              _buildFuelMetric('Mileage', '${(summary.totalDistanceKm / (summary.totalFuelLiters > 0 ? summary.totalFuelLiters : 1)).toStringAsFixed(1)} km/l'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFuelMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyState(Color primaryColor, Color? subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: Icon(Icons.analytics_outlined, size: 60, color: primaryColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text('No trips recorded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: subTextColor)),
            const SizedBox(height: 8),
            const Text('Start tracking to see your daily analytics here.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
