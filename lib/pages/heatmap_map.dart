import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';

class HeatmapMapPage extends StatefulWidget {
  const HeatmapMapPage({super.key});

  @override
  State<HeatmapMapPage> createState() => _HeatmapMapPageState();
}

class _HeatmapMapPageState extends State<HeatmapMapPage> {
  final MapController _mapController = MapController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<WeightedLatLng> _points = const [];

  // Emphasized place labels (same as Google Map page)
  static const Map<String, LatLng> _emphasizedPlaces = {
    'Shillong City': LatLng(25.5747, 91.8937),
    'Laitlum': LatLng(25.44885, 91.90896),
    'Sohra': LatLng(25.2841, 91.7308),
    'Dawki': LatLng(25.2010, 92.0250),
    'Guwahati City': LatLng(26.1445, 91.7362),
    'Nongpoh': LatLng(25.9024, 91.8783),
    'Umsning': LatLng(25.7478, 91.8889),
    'Umiam Lake': LatLng(25.6500, 91.8889),
    'Mawphlang': LatLng(25.4646, 91.7305),
  };

  static const Map<String, double> _labelFontSizes = {
    'Shillong City': 30,
    'Laitlum': 28,
    'Sohra': 28,
    'Dawki': 28,
    'Guwahati City': 30,
    'Nongpoh': 24,
    'Umsning': 24,
    'Umiam Lake': 26,
    'Mawphlang': 24,
  };

  final List<Marker> _labelMarkers = <Marker>[];

  int? _laitlumVisitorsToday; // Live visitor count for Laitlum
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _laitlumSub;
  bool _showHeatmap = false; // off by default; match Google Map UI focus on labels

  @override
  void initState() {
    super.initState();
    _listenPoints();
    _listenLaitlumVisitors();
    _buildLabelMarkers();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _laitlumSub?.cancel();
    super.dispose();
  }

  void _listenPoints() {
    // Example: listen to a collection where you store geo points + weights.
    // Adjust to your schema. For demo, this tries LAITLUM collection with optional lat/lng.
    _sub = FirebaseFirestore.instance
        .collection('LAITLUM')
        .orderBy('timestamp', descending: true)
        .limit(2000)
        .snapshots()
        .listen((snap) {
      final next = <WeightedLatLng>[];
      for (final d in snap.docs) {
        final data = d.data();
        final lat = (data['lat'] ?? data['latitude']);
        final lng = (data['lng'] ?? data['longitude']);
        final w = data['weight'] ?? data['people_count'] ?? data['visitors'];
        if (lat is num && lng is num) {
          final intensity = (w is num) ? w.toDouble() : 1.0;
          next.add(WeightedLatLng(
            LatLng(lat.toDouble(), lng.toDouble()),
            intensity,
          ));
        }
      }
      setState(() => _points = next);
    });
  }

  void _listenLaitlumVisitors() {
    _laitlumSub = FirebaseFirestore.instance
        .collection('LAITLUM')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      int? count;
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        for (final k in [
          'people_count_total',
          'people_count',
          'visitor_count',
          'visitors',
        ]) {
          final v = data[k];
          if (v is num) {
            count = v.toInt();
            break;
          }
        }
        if (count == null) {
          final nested = data['people_counts'];
          if (nested is Map<String, dynamic>) {
            int sum = 0;
            nested.forEach((_, v) {
              if (v is num) sum += v.toInt();
            });
            count = sum;
          }
        }
      }
      if (count != _laitlumVisitorsToday) {
        setState(() {
          _laitlumVisitorsToday = count;
        });
        _buildLabelMarkers();
      }
    });
  }

  String _laitlumLabelText() {
    // Show only the place name to avoid overlap with nearby labels.
    return 'Laitlum';
  }

  void _buildLabelMarkers() {
    final markers = <Marker>[];
    for (final entry in _emphasizedPlaces.entries) {
      final name = entry.key;
      final isLaitlum = name == 'Laitlum';
      final text = isLaitlum ? _laitlumLabelText() : name;
      final fontSize = _labelFontSizes[name] ?? 36;
      markers.add(
        Marker(
          point: entry.value,
          width: (text.length * (fontSize * 0.6)).clamp(120, 420).toDouble(),
          height: fontSize + 18,
          rotate: false,
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                shadows: const [
                  Shadow(color: Colors.white, blurRadius: 6),
                  Shadow(color: Colors.white, blurRadius: 6),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      );
    }
    setState(() {
      _labelMarkers
        ..clear()
        ..addAll(markers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(25.5747, 91.8937), // Shillong
              initialZoom: 9.8,
            ),
            children: [
              // Use any tile provider you prefer; OpenStreetMap is a safe default.
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tourist_app',
              ),
              // Big font place labels, mimicking your Google Map UI
              MarkerLayer(markers: _labelMarkers),
              if (_showHeatmap && _points.isNotEmpty)
                HeatMapLayer(
                  heatMapDataSource: InMemoryHeatMapDataSource(data: _points),
                  heatMapOptions: HeatMapOptions(
                    minOpacity: 0.15,
                    radius: 25.0,
                  ),
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.70),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
