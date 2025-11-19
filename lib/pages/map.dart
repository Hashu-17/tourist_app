import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'route_api.dart';
import 'route_api_v1.dart';

enum _Metric { people, vehicles }

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Set<Polyline> _polylines = {};
  bool _showTrafficRoute = false;
  bool _trafficEnabled = false;
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  String? _mapStyle;

  // Thematic clustering of key places (Oak Hall removed from counter markers)
  static const Map<String, LatLng> _places = {
    'LAITLUM': LatLng(25.44885, 91.90896),
    'SOHRA': LatLng(25.2841, 91.7308),
    'DAWKI': LatLng(25.2010, 92.0250),
    // 'OAK HALL': LatLng(25.52606898117032, 91.86558777893559),
  };

  // Decorative place-name labels (original labels)
  static const Map<String, LatLng> _labelPlaces = {
    'Shillong City': LatLng(25.5747, 91.8937),
    'Laitlum': LatLng(25.44885, 91.90896),
    'Sohra': LatLng(25.2841, 91.7308),
    'Dawki': LatLng(25.2010, 92.0250),
    // 'Oak Hall': LatLng(25.52606898117032, 91.86558777893559),
    'Guwahati City': LatLng(26.1445, 91.7362),
    'Nongpoh': LatLng(25.9024, 91.8783),
    'Umsning': LatLng(25.7478, 91.8889),
    'Umiam Lake': LatLng(25.6500, 91.8889),
    'Mawphlang': LatLng(25.4646, 91.7305),
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

  static const Map<String, String> _placeToCollection = {
    'LAITLUM': 'LAITLUM',
    'SOHRA': 'SOHRA',
    'DAWKI': 'DAWKI',
  };

  final Map<String, int> _counts = {for (final k in _places.keys) k: 0};
  final List<StreamSubscription> _subs = [];
  Set<Marker> _markers = <Marker>{};
  final Set<Marker> _labelMarkers = <Marker>{};

  // Metric toggle: people or vehicles (vehicles: empty for now)
  _Metric _metric = _Metric.people;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(25.5747, 91.8937), // Shillong City
    zoom: 10.5,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadStyle();
    _listenCounts();
    // Do not fetch route initially; only fetch when vehicle metric toggled on
  }

  /// Fetch routes from the origin to each destination separately
  Future<void> _fetchAndDrawRoute() async {
    // Draw all custom route polylines in #22B573
    const apiKey = 'AIzaSyCHSq6ITZdGYydce409Zbc16Bmp5sNME40';
    const double originLat = 25.571640748292545;
    const double originLng = 91.87114536797505;

    final Set<Polyline> newPolylines = {};

    // --- Laitlum route: Shillong to Laitlum ---
    final laitlumSteps = await fetchRouteStepsWithTraffic(
      apiKey: apiKey,
      originLat: originLat, // Shillong
      originLng: originLng,
      destLat: 25.44885,    // Laitlum
      destLng: 91.90896,
      waypoints: [],
    );
    int laitlumSeg = 0;
    for (final step in laitlumSteps) {
      final polyline = step['polyline'] as String?;
      if (polyline == null) continue;
      final points = _decodePolyline(polyline);
      newPolylines.add(
        Polyline(
          polylineId: PolylineId('laitlum_seg_${laitlumSeg++}'),
          color: const Color(0xFF22B573), // Darker green
          width: 6,
          points: points,
        ),
      );
    }

    // Oak Hall route removed

    if (!mounted) return;
    setState(() {
      _polylines = newPolylines;
    });
  }

  // Polyline decoder (Google encoded polyline algorithm)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
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

  /// Rebuilds `_markers` from `_places` and `_counts`.
  Future<void> _rebuildMarkers() async {
    final markers = <Marker>{};

    for (final entry in _places.entries) {
      final code = entry.key;
      final pos = entry.value;
      final total = _counts[code] ?? 0;

      final label = total >= 100 ? '100+' : (total <= 0 ? '0' : '$total');
      final color = _colorForValue(total);

      final icon = await _buildCircleBadge(
        label: label,
        color: color,
        diameter: 100,
        fontSize: 34,
      );

      markers.add(Marker(
        markerId: MarkerId('place_$code'),
        position: pos,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        zIndex: 100.0,
        onTap: () async {
          final c = await _controller.future;
          try {
            final z = await c.getZoomLevel();
            await c.animateCamera(CameraUpdate.newLatLngZoom(pos, z + 2));
          } catch (_) {}
        },
      ));

      // Add a label marker above the place marker (custom offset for Shillong City and Laitlum)
      final displayName = _displayNameForPlace(code);
      final textIcon = await _createTextIcon(
        displayName,
        fontSize: _labelFontSizes[displayName] ?? 36,
      );

      LatLng labelPos;
      // Offset values to avoid overlap when zoomed out
      if (displayName == 'Shillong City') {
        // Move Shillong City label much further left and up
        labelPos = LatLng(pos.latitude + 0.035, pos.longitude + 0.005);
      } else if (displayName == 'Laitlum') {
        // Move Laitlum label further right and down
        labelPos = LatLng(pos.latitude - 0.015, pos.longitude + 0.045);
      } else if (displayName == 'Sohra') {
        // Move Sohra label further up
        labelPos = LatLng(pos.latitude + 0.035, pos.longitude);
      } else if (displayName == 'Dawki') {
        // Move Dawki label further up
        labelPos = LatLng(pos.latitude + 0.035, pos.longitude);
      } else if (displayName == 'Oak Hall') {
        // Skip Oak Hall label for now
        continue;
      } else {
        // Default: move label further up
        labelPos = LatLng(pos.latitude + 0.035, pos.longitude);
      }

      markers.add(Marker(
        markerId: MarkerId('label_$code'),
        position: labelPos,
        icon: textIcon,
        anchor: const Offset(0.5, 1.0),
        flat: true,
        zIndex: 1000.0,
      ));
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
    });
  }

  Color _colorForValue(int total) {
    if (total <= 0) return Colors.green;
    if (total < 20) return const Color(0xFF1E88E5); // blue
    if (total < 50) return const Color(0xFF00ACC1); // teal
    return const Color(0xFF2E7D32); // deep green for high
  }

  Future<BitmapDescriptor> _buildCircleBadge({
    required String label,
    required Color color,
    double diameter = 100,
    Color textColor = Colors.white,
    double fontSize = 34,
    FontWeight fontWeight = FontWeight.bold,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final radius = diameter / 2;
    final center = Offset(radius, radius);

    final paint = Paint()..color = color;
    canvas.drawCircle(center, radius, paint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withOpacity(0.2);
    canvas.drawCircle(center, radius - 3, ringPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style:
            TextStyle(color: textColor, fontSize: fontSize, fontWeight: fontWeight),
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

  Future<void> _buildLabelMarkers() async {
    final markers = <Marker>{};
    for (final entry in _labelPlaces.entries) {
      final name = entry.key;
      final pos = entry.value;
      // Skip dynamic-labeled places to avoid duplicates
      if (name == 'Laitlum' || name == 'Sohra' || name == 'Dawki') {
        continue;
      }
      final icon = await _createTextIcon(
        name,
        fontSize: _labelFontSizes[name] ?? 36,
      );
      markers.add(
        Marker(
          markerId: MarkerId('label_$name'),
          position: pos,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 1000.0, // draw above clustered markers
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

  String _displayNameForPlace(String code) {
    switch (code) {
      case 'LAITLUM':
        return 'Laitlum';
      case 'SOHRA':
        return 'Sohra';
      case 'DAWKI':
        return 'Dawki';
      default:
        return code;
    }
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

  /// Handles tapping the vehicle metric button (async flow separated)
  Future<void> _handleVehicleTap() async {
    if (_metric != _Metric.vehicles) {
      // switch into vehicle metric and enable routes
      setState(() {
        _metric = _Metric.vehicles;
        _showTrafficRoute = true;
      });
      await _fetchAndDrawRoute();
    } else {
      // already in vehicles — toggle routes off
      setState(() {
        _showTrafficRoute = false;
        _polylines = {};
      });
    }
    await _rebuildMarkers();
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
            trafficEnabled: true, // Show traffic overlay everywhere
            markers: {..._markers, ..._labelMarkers},
            polylines: _showTrafficRoute ? _polylines : {},
            onMapCreated: (GoogleMapController controller) async {
              if (!_controller.isCompleted) _controller.complete(controller);
              final style = _mapStyle;
              if (style != null) await controller.setMapStyle(style);
              _rebuildMarkers();
              await _buildLabelMarkers();
            },
            onCameraIdle: () async {
              await _rebuildMarkers();
            },
          ),

          // Metric toggle buttons (top-right)
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Row(
                children: [
                  _MetricButton(
                    icon: Icons.people_alt,
                    active: _metric == _Metric.people,
                    onTap: () {
                      if (_metric != _Metric.people) {
                        setState(() {
                          _metric = _Metric.people;
                          _showTrafficRoute = false;
                          _polylines = {};
                        });
                        _rebuildMarkers();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // Vehicle icon now controls routes: tapping switches metric and toggles routes
                  _MetricButton(
                    icon: Icons.directions_car,
                    active: _metric == _Metric.vehicles,
                    onTap: () {
                      _handleVehicleTap();
                    },
                  ),
                ],
              ),
            ),
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
}

class _MetricButton extends StatelessWidget {
  const _MetricButton({required this.icon, required this.active, required this.onTap});

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: active ? Colors.grey.shade300 : Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          color: active ? Colors.black87 : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _PlaceItem {
  _PlaceItem({required this.name, required this.position, required this.count});
  final String name;
  final LatLng position;
  final int count;
}
