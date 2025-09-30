import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// Map UI names to Firestore collections
const Map<String, String> kPlaceToCollection = {
  'LAITLUM': 'LAITLUM',
  'SOHRA': 'SOHRA',
  'DAWKI': 'DAWKI',
  "Ward's Lake": 'WardsLake', // example collection id without space/apostrophe
};


// Video demo and helpers removed.


// Replace the simulated stream with Firestore
Stream<double?> getTemperatureStream(String placeName) {
  final collection = kPlaceToCollection[placeName];
  if (collection == null) return const Stream<double?>.empty();

  return FirebaseFirestore.instance
      .collection(collection)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        final data = snap.docs.first.data();
        final value = data['temperature'];
        return (value is num) ? value.toDouble() : null;
      });
}

Stream<String?> getWeatherStream(String placeName) {
  final collection = kPlaceToCollection[placeName];
  if (collection == null) return const Stream<String?>.empty();

  return FirebaseFirestore.instance
      .collection(collection)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        final data = snap.docs.first.data();
        final value = data['weather'];
        return (value is String) ? value : null;
      });
}

/// Live stream of visitor count for a place.
///
/// Looks for common field names:
/// - people_count_total (preferred)
/// - people_count / visitor_count / visitors
/// If a nested map `people_counts` exists, sums numeric values inside it.
Stream<int?> getVisitorCountStream(String placeName) {
  final collection = kPlaceToCollection[placeName];
  if (collection == null) return const Stream<int?>.empty();

  return FirebaseFirestore.instance
      .collection(collection)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        final data = snap.docs.first.data();

        // Preferred flat fields
        final candidates = [
          'people_count_total',
          'people_count',
          'visitor_count',
          'visitors',
        ];
        for (final key in candidates) {
          final v = data[key];
          if (v is num) return v.toInt();
        }

        // Fallback: sum nested `people_counts` values if present
        final nested = data['people_counts'];
        if (nested is Map<String, dynamic>) {
          int sum = 0;
          nested.forEach((_, value) {
            if (value is num) sum += value.toInt();
          });
          return sum;
        }

        return null;
      });
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final List<Map<String, String>> destinations = [
    {
      "name": "LAITLUM",
      "image": "images/laitlum.jpg",
      "visitors": "500+",
      "weather": "Sunny",
      "temp": "18°C",
    },
    {
      "name": "SOHRA",
      "image": "images/sohra.jpg",
      "visitors": "320+",
      "weather": "Rainy",
    },
    {
      "name": "DAWKI",
      "image": "images/dawki.jpg",
      "visitors": "210+",
      "weather": "Sunny",
    },
    {
      "name": "Ward's Lake",
      "image": "images/wards2.jpg",
      "visitors": "90+",
      "weather": "Sunny",
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  // Cache the last known visitor count per place so the UI can keep showing it
  // even when the stream is waiting, null, or temporarily errors.
  final Map<String, int?> _lastVisitorCount = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Filter destinations based on search query
    final filteredDestinations = _searchQuery.isEmpty
        ? destinations
        : destinations
              .where(
                (place) => place["name"]!.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: screenWidth,
                  height: screenHeight / 2.5,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageHeight = constraints.maxHeight;
                      final imageWidth = constraints.maxWidth;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            "images/home2.jpg",
                            width: screenWidth,
                            height: screenHeight / 2.5,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: screenHeight * 0.053,
                            left: screenHeight * 0.017,
                            right: screenHeight * 0.017,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Thematic map icon (inverted colors)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      // TODO: Navigate to thematic map page
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(
                                        Icons.map,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                // User icon (inverted colors)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      "images/user.png",
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                      color: Colors.white,
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: imageHeight * 0.280,
                            left: imageWidth * 0.05,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "MegTourism",
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 48.0 : imageWidth * 0.130,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                                Text(
                                  "A tourist's guide",
                                  style: TextStyle(
                                    fontSize: kIsWeb
                                        ? 20.0
                                        : (imageWidth * 0.05).clamp(12.0, 24.0),
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                    fontFamily: 'Lato',
                                    height: 1.0, // Use a normal line height
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: -25,
                            left: screenWidth * 0.08,
                            right: screenWidth * 0.08,
                            child: Material(
                              elevation: 5.0,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(width: 1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Search your destination',
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontFamily: 'Lato',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: filteredDestinations.map((place) {
                      return SizedBox(
                        width: double.infinity,
                        child: Card(
                          margin: const EdgeInsets.only(
                            bottom: 20,
                          ),
                          color: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  // Background media: always show image (video removed)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      place["image"]!,
                                      width: double.infinity,
                                      height: 260,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Container(
                                    height: 260,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.4),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 260,
                                    padding: const EdgeInsets.all(15.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              place["name"]!,
                                              style: const TextStyle(
                                                fontSize: 30,
                                                fontFamily: 'Lato',
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                StreamBuilder<double?>(
                                                  stream: getTemperatureStream(
                                                    place["name"]!,
                                                  ),
                                                  builder: (context, snapshot) {
                                                    if (snapshot
                                                            .connectionState ==
                                                        ConnectionState.waiting) {
                                                      return const Text(
                                                        '...',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 30,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      );
                                                    } else if (snapshot
                                                        .hasError) {
                                                      return const Text(
                                                        '--',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 30,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      );
                                                    } else {
                                                      return Text(
                                                        '${snapshot.data?.toStringAsFixed(2) ?? "--"}°C',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 30,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                                StreamBuilder<String?>(
                                                  stream: getWeatherStream(
                                                    place["name"]!,
                                                  ),
                                                  builder: (context, snapshot) {
                                                    final weather =
                                                        snapshot.data ??
                                                            place["weather"];
                                                    if (weather == "Sunny") {
                                                      return Lottie.asset(
                                                        'animations/Sunny.json',
                                                        width: 40,
                                                        height: 40,
                                                        fit: BoxFit.cover,
                                                      );
                                                    } else if (weather == "Cloudy") {
                                                      return Lottie.asset(
                                                        'animations/Windy.json',
                                                        width: 40,
                                                        height: 40,
                                                        fit: BoxFit.cover,
                                                      );
                                                    } else if (weather == "Rainy") {
                                                      return Lottie.asset(
                                                        'animations/ThunderStorm.json',
                                                        width: 40,
                                                        height: 40,
                                                        fit: BoxFit.cover,
                                                      );
                                                    } else {
                                                      return const Icon(
                                                        Icons.help_outline,
                                                        color: Colors.white,
                                                        size: 28,
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.people,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 6),
                                            StreamBuilder<int?>(
                                              stream: getVisitorCountStream(place["name"]!),
                                              initialData: _lastVisitorCount[place["name"]!],
                                              builder: (context, snapshot) {
                                                final placeName = place["name"]!;
                                                final latest = snapshot.data;
                                                // Persist latest non-null value without forcing rebuild
                                                if (latest != null) {
                                                  _lastVisitorCount[placeName] = latest;
                                                }
                                                final cached = _lastVisitorCount[placeName];

                                                String display;
                                                if (cached != null) {
                                                  // Always show last known value if we have one
                                                  display = 'Visitors today: $cached';
                                                } else if (snapshot.connectionState == ConnectionState.waiting) {
                                                  display = 'Visitors today: ...';
                                                } else if (snapshot.hasError) {
                                                  display = 'Visitors today: --';
                                                } else {
                                                  display = 'Visitors today: --';
                                                }

                                                return Text(
                                                  display,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
