import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // add

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  String? _mapStyle;

  // Labels
  static const Map<String, LatLng> _emphasizedPlaces = {
    'Shillong City': LatLng(25.5747, 91.8937),
    'Laitlum': LatLng(25.44885, 91.90896),
    'Sohra': LatLng(25.2841, 91.7308),
    'Dawki': LatLng(25.2010, 92.0250),
    'Guwahati City': LatLng(26.1445, 91.7362),
    'Nongpoh': LatLng(25.9024, 91.8783),
    'Umsning': LatLng(25.7478, 91.8889), // corrected earlier
    'Umiam Lake': LatLng(25.6500, 91.8889),
    'Mawphlang': LatLng(
      25.4646,
      91.7305,
    ), // Mawphlang Sacred Forest (adjust if needed)
  };

  static const Map<String, double> _labelFontSizes = {
    'Shillong City': 40,
    'Laitlum': 38,
    'Sohra': 38,
    'Dawki': 38,
    'Guwahati City': 40,
    'Nongpoh': 34,
    'Umsning': 34,
    'Umiam Lake': 36,
    'Mawphlang': 34,
  };

  final Set<Marker> _labelMarkers = {};

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(25.5747, 91.8937), // Shillong City
    zoom: 10.5,
  );

  int? _laitlumVisitorsToday; // Firestore-driven
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _laitlumSub; // add

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadStyle();
    _listenLaitlumVisitors(); // start Firestore listener
  }

  @override
  void dispose() {
    _laitlumSub?.cancel(); // cancel listener
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

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

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // Listen to latest LAITLUM doc and extract a visitor count (mirrors home.dart logic)
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
            _refreshLaitlumMarker(); // update only that marker
          }
        });
  }

  // Rebuild only Laitlum marker when count changes
  Future<void> _refreshLaitlumMarker() async {
    final pos = _emphasizedPlaces['Laitlum'];
    if (pos == null) return;
    final label = _laitlumLabelText();
    final icon = await _createTextIcon(
      label,
      fontSize: _labelFontSizes['Laitlum'] ?? 38,
    );
    final updated = Marker(
      markerId: const MarkerId('label_Laitlum'),
      position: pos,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      flat: true,
      zIndex: 100,
    );
    if (!mounted) return;
    setState(() {
      _labelMarkers
        ..removeWhere((m) => m.markerId.value == 'label_Laitlum')
        ..add(updated);
    });
  }

  String _laitlumLabelText() {
    final v = _laitlumVisitorsToday;
    final display = (v == null) ? '--' : v.toString();
    return 'Laitlum  $display'; // two spaces gap
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
            markers: _labelMarkers, // only your labels
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) _controller.complete(controller);
              final style = _mapStyle;
              if (style != null) controller.setMapStyle(style);
              _buildLabelMarkers();
            },
            // Remove padding so it truly fills edge-to-edge
            padding: EdgeInsets.zero,
          ),
          // Black back button overlay
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: _onBack,
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

  Future<void> _buildLabelMarkers() async {
    final markers = <Marker>{};
    for (final entry in _emphasizedPlaces.entries) {
      final name = entry.key;
      final isLaitlum = name == 'Laitlum';
      final text = isLaitlum ? _laitlumLabelText() : name;
      final icon = await _createTextIcon(
        text,
        fontSize: _labelFontSizes[name] ?? 38,
      );
      markers.add(
        Marker(
          markerId: MarkerId('label_$name'),
          position: entry.value,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 100,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _labelMarkers
        ..clear()
        ..addAll(markers);
    });
  }

  Future<BitmapDescriptor> _createTextIcon(
    String text, {
    double fontSize = 26,
  }) async {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
          shadows: const [
            Shadow(color: Colors.white, blurRadius: 6),
            Shadow(color: Colors.white, blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    const pad = 6.0;
    final width = (painter.width + pad * 2).ceil();
    final height = (painter.height + pad * 2).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    final offset = Offset(
      (width - painter.width) / 2,
      (height - painter.height) / 2,
    );
    painter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}
