import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches a route polyline from Google Maps Routes API (TRAFFIC_AWARE_OPTIMAL)
Future<String?> fetchRoutePolyline({
  required String apiKey,
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  List<Map<String, double>> waypoints = const [],
}) async {
  final url = Uri.parse(
    'https://routes.googleapis.com/directions/v2:computeRoutes',
  );
  final body = jsonEncode({
    "origin": {
      "location": {
        "latLng": {"latitude": originLat, "longitude": originLng}
      }
    },
    "destination": {
      "location": {
        "latLng": {"latitude": destLat, "longitude": destLng}
      }
    },
    if (waypoints.isNotEmpty)
      "intermediates": waypoints
          .map((wp) => {"location": {"latLng": {"latitude": wp["latitude"], "longitude": wp["longitude"]}}})
          .toList(),
    "travelMode": "DRIVE",
    "routingPreference": "TRAFFIC_AWARE_OPTIMAL"
  });

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': 'routes.polyline.encodedPolyline'
    },
    body: body,
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final polyline = data['routes']?[0]?['polyline']?['encodedPolyline'];
    return polyline;
  } else {
    print('Failed to fetch route: \\n${response.body}');
    return null;
  }
}
