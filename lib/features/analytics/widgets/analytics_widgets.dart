import 'package:flutter/material.dart';
import '../../../models/delivery_analytics.dart';

class QuickAnalyticsCard extends StatelessWidget {
  final DailyTravelSummary summary;

  const QuickAnalyticsCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Stats',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${summary.totalStops} stops',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat(
                '📍',
                '${summary.totalDistanceKm.toStringAsFixed(1)} km',
                'Distance',
              ),
              _buildQuickStat(
                '⏱️',
                summary.formattedWorkingTime,
                'Time',
              ),
              _buildQuickStat(
                '⛽',
                '₹${summary.totalFuelCost.toStringAsFixed(0)}',
                'Fuel Cost',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class EfficiencyGauge extends StatelessWidget {
  final double efficiency;
  final int rating;

  const EfficiencyGauge({
    super.key,
    required this.efficiency,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final gaugeColor = efficiency >= 80
        ? Colors.green
        : efficiency >= 60
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            'Efficiency Score',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: gaugeColor,
                        width: 12,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${efficiency.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: gaugeColor,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (index) => Icon(
                              Icons.star,
                              size: 16,
                              color: index < rating
                                  ? Colors.amber
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getEfficiencyLabel(efficiency),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: gaugeColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getEfficiencyLabel(double efficiency) {
    if (efficiency >= 80) return 'Excellent Performance';
    if (efficiency >= 70) return 'Good Performance';
    if (efficiency >= 60) return 'Average Performance';
    if (efficiency >= 40) return 'Below Average';
    return 'Poor Performance';
  }
}

class StopsGrid extends StatelessWidget {
  final List<DeliveryStop> stops;

  const StopsGrid({
    super.key,
    required this.stops,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        final stopColor = stop.stopType == 'home'
            ? Colors.red
            : stop.stopType == 'office'
                ? Colors.green
                : Colors.blue;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: stopColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _getStopEmoji(stop.stopType),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stop.stopType.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: stopColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${stop.durationMinutes}m',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${stop.distanceFromPreviousStop.toStringAsFixed(1)}km away',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStopEmoji(String stopType) {
    return stopType == 'home'
        ? '🏠'
        : stopType == 'office'
            ? '🏢'
            : '📦';
  }
}

class FuelCostBreakdown extends StatelessWidget {
  final double totalDistance;
  final double fuelUsed;
  final double fuelCost;
  final double costPerKm;

  const FuelCostBreakdown({
    super.key,
    required this.totalDistance,
    required this.fuelUsed,
    required this.fuelCost,
    required this.costPerKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fuel Cost Breakdown',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            '📍 Total Distance',
            '${totalDistance.toStringAsFixed(2)} km',
          ),
          const Divider(),
          _buildBreakdownRow(
            '⛽ Fuel Used',
            '${fuelUsed.toStringAsFixed(2)} L',
          ),
          const Divider(),
          _buildBreakdownRow(
            '💰 Total Cost',
            '₹${fuelCost.toStringAsFixed(2)}',
            color: Colors.green,
          ),
          const Divider(),
          _buildBreakdownRow(
            '🎯 Cost per KM',
            '₹${costPerKm.toStringAsFixed(2)}',
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    Color? color,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
