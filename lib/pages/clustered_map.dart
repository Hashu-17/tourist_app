import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Removed google_maps_cluster_manager due to symbol conflicts; manual clustering implemented

class ClusteredMarkersMapPage extends StatefulWidget {
  const ClusteredMarkersMapPage({super.key});

  @override
  State<ClusteredMarkersMapPage> createState() => _ClusteredMarkersMapPageState();
}

class PlaceItem {
  PlaceItem({required this.name, required this.position, required this.count});
  final String name;
  final LatLng position;
  final int count;
}

class _ClusteredMarkersMapPageState extends State<ClusteredMarkersMapPage> {
  final Completer<GoogleMapController> _controller = Completer();
  String? _mapStyle;

  // Core places and coords
  static const Map<String, LatLng> _places = {
    'LAITLUM': LatLng(25.44885, 91.90896),
    'SOHRA': LatLng(25.2841, 91.7308),
    'DAWKI': LatLng(25.2010, 92.0250),
    // Add more places as needed
  };

  // Firestore collection names (adjust to match your DB)
  static const Map<String, String> _placeToCollection = {
    'LAITLUM': 'LAITLUM',
    'SOHRA': 'SOHRA',
    'DAWKI': 'DAWKI',
  };

  // Live counts per place
  final Map<String, int> _counts = {
    for (final k in _places.keys) k: 0,
  };

  final List<StreamSubscription> _subs = [];

  Set<Marker> _markers = <Marker>{};

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(25.5747, 91.8937), // Shillong
    zoom: 9.8,
  );

  @override
  void initState() {
    super.initState();
    _loadStyle();
    _listenCounts();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  List<PlaceItem> _buildItems() => _places.entries
      .map((e) => PlaceItem(name: e.key, position: e.value, count: _counts[e.key] ?? 0))
      .toList();

  Future<void> _loadStyle() async {
    try {
      final s = await rootBundle.loadString('assets/maps_styles.json');
      _mapStyle = s;
      if (_controller.isCompleted) {
        final c = await _controller.future;
        await c.setMapStyle(_mapStyle);
      }
    } catch (_) {}
  }

  void _listenCounts() {
    for (final entry in _placeToCollection.entries) {
      final place = entry.key;
      final col = entry.value;
      final sub = FirebaseFirestore.instance
          .collection(col)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snap) {
        int count = 0;
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          for (final k in const [
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
          if (count == 0) {
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
        _counts[place] = count;
        _rebuildMarkers();
      });
      _subs.add(sub);
    }
  }

  Color _colorForValue(int total) {
    if (total <= 0) return Colors.green;
    if (total < 20) return const Color(0xFF1E88E5); // blue
    if (total < 50) return const Color(0xFF00ACC1); // teal
    return const Color(0xFF2E7D32); // green for big cluster (similar to screenshot)
  }

  Future<BitmapDescriptor> _buildCircleBadge({
    required String label,
    required Color color,
    double diameter = 70,
    Color textColor = Colors.white,
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.bold,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final radius = diameter / 2;
    final center = Offset(radius, radius);

    final paint = Paint()..color = color;
    canvas.drawCircle(center, radius, paint);

    // Inner ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withOpacity(0.2);
    canvas.drawCircle(center, radius - 3, ringPaint);

    // Text
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: fontWeight),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: diameter);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(diameter.toInt(), diameter.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _rebuildMarkers() async {
    if (!_controller.isCompleted) return;
    final ctrl = await _controller.future;
    final items = _buildItems();
    if (items.isEmpty) return;

    // Compute screen positions
    final screenPoints = <PlaceItem, ScreenCoordinate>{};
    for (final it in items) {
      try {
        screenPoints[it] = await ctrl.getScreenCoordinate(it.position);
      } catch (_) {}
    }

    // Group by pixel distance
  const threshold = 143; // px (30% increase over 110)
    final clusters = <List<PlaceItem>>[];
    for (final it in items) {
      final p = screenPoints[it];
      if (p == null) continue;
      bool added = false;
      for (final group in clusters) {
        final ref = group.first;
        final pr = screenPoints[ref];
        if (pr == null) continue;
        final dx = (p.x - pr.x).abs();
        final dy = (p.y - pr.y).abs();
        if (dx * dx + dy * dy <= threshold * threshold) {
          group.add(it);
          added = true;
          break;
        }
      }
      if (!added) clusters.add([it]);
    }

    // Build markers per cluster
    final markers = <Marker>{};
    int clusterId = 0;
    for (final group in clusters) {
      int total = 0;
      for (final it in group) total += it.count;
      final isCluster = group.length > 1;
      final label = isCluster
          ? (total >= 100 ? '100+' : '${total}+')
          : (total <= 0 ? '0' : total.toString());
      final color = _colorForValue(total);
      final icon = await _buildCircleBadge(
        label: label,
        color: color,
        diameter: isCluster ? 120 : 100, // ~30% larger
        fontSize: isCluster ? 38 : 34,   // ~30% larger
      );
      // Center position: average lat/lng of items (simple mean)
      final lat = group.map((e) => e.position.latitude).reduce((a, b) => a + b) / group.length;
      final lng = group.map((e) => e.position.longitude).reduce((a, b) => a + b) / group.length;
      final pos = LatLng(lat, lng);
      markers.add(Marker(
        markerId: MarkerId(isCluster ? 'cluster_${clusterId++}' : 'place_${group.first.name}'),
        position: pos,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        onTap: () async {
          if (isCluster) {
            final z = await ctrl.getZoomLevel();
            await ctrl.animateCamera(CameraUpdate.newLatLngZoom(pos, z + 2));
          }
        },
      ));
    }

    if (!mounted) return;
    setState(() => _markers = markers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            mapType: MapType.normal,
            trafficEnabled: false,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) async {
              if (!_controller.isCompleted) _controller.complete(controller);
              final style = _mapStyle;
              if (style != null) controller.setMapStyle(style);
              // Seed initial markers
              _rebuildMarkers();
            },
            onCameraIdle: _rebuildMarkers,
            padding: EdgeInsets.zero,
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
                    color: Colors.black.withOpacity(0.70),
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
