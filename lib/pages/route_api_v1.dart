import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches route steps with traffic info from Google Directions API v1
Future<List<Map<String, dynamic>>> fetchRouteStepsWithTraffic({
  required String apiKey,
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  List<Map<String, double>> waypoints = const [],
}) async {
    final origin = '$originLat,$originLng';
    final destination = '$destLat,$destLng';
  final waypointsStr = waypoints.isNotEmpty
      ? '&waypoints=' + waypoints.map((wp) => '${wp["latitude"]},${wp["longitude"]}').join('|')
      : '';
  // Add mode=driving for traffic data
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypointsStr&departure_time=now&mode=driving&key=$apiKey',
  );
  print('Fetching Directions API: ' + url.toString());

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('Directions API response:');
    print(data);
    final steps = <Map<String, dynamic>>[];
    final legs = data['routes']?[0]?['legs'] ?? [];
    for (final leg in legs) {
      for (final step in leg['steps']) {
        // Support all possible congestion/traffic fields
        final congestion = step['traffic_segment'] ?? step['traffic_speed_entry'] ?? step['congestion'] ?? null;
        steps.add({
          'polyline': step['polyline']['points'],
          'congestion': congestion,
          'html_instructions': step['html_instructions'],
          'end_location': step['end_location'],
        });
      }
    }
    return steps;
  } else {
    print('Failed to fetch v1 route: ${response.body}');
    return [];
  }
}
