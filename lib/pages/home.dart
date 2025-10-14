import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import 'package:tourist_app/pages/map.dart';

// Firestore collection mapping
const Map<String, String> kPlaceToCollection = {
  'LAITLUM': 'LAITLUM',
  'SOHRA': 'SOHRA',
  'DAWKI': 'DAWKI',
  "Ward's Lake": 'WardsLake',
};

// Streams
Stream<double?> getTemperatureStream(String placeName) {
  final c = kPlaceToCollection[placeName];
  if (c == null) return const Stream<double?>.empty();
  return FirebaseFirestore.instance
      .collection(c)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((s) {
        if (s.docs.isEmpty) return null;
        final v = s.docs.first.data()['temperature'];
        return (v is num) ? v.toDouble() : null;
      });
}

Stream<String?> getWeatherStream(String placeName) {
  final c = kPlaceToCollection[placeName];
  if (c == null) return const Stream<String?>.empty();
  return FirebaseFirestore.instance
      .collection(c)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((s) {
        if (s.docs.isEmpty) return null;
        final v = s.docs.first.data()['weather'];
        return (v is String) ? v : null;
      });
}

Stream<int?> getVisitorCountStream(String placeName) {
  final c = kPlaceToCollection[placeName];
  if (c == null) return const Stream<int?>.empty();
  return FirebaseFirestore.instance
      .collection(c)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((s) {
        if (s.docs.isEmpty) return null;
        final data = s.docs.first.data();

        for (final k in [
          'people_count_total',
          'people_count',
          'visitor_count',
          'visitors',
        ]) {
          final v = data[k];
          if (v is num) return v.toInt();
        }

        final nested = data['people_counts'];
        if (nested is Map<String, dynamic>) {
          int sum = 0;
          nested.forEach((_, v) {
            if (v is num) sum += v.toInt();
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
    {"name": "LAITLUM", "image": "images/laitlum.jpg", "weather": "Sunny"},
    {"name": "SOHRA", "image": "images/sohra.jpg", "weather": "Rainy"},
    {"name": "DAWKI", "image": "images/dawki.jpg", "weather": "Sunny"},
    {"name": "Ward's Lake", "image": "images/wards2.jpg", "weather": "Sunny"},
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, int?> _lastVisitorCount = {};

  late final VideoPlayerController _laitlumVideoController;
  bool _laitlumVideoReady = false;

  late final VideoPlayerController _sohraVideoController; // NEW
  bool _sohraVideoReady = false; // NEW

  @override
  void initState() {
    super.initState();

    _laitlumVideoController =
        VideoPlayerController.asset(
            'assets/videos/laitlum/laitlum_gen.mp4', // UPDATED path
          )
          ..setLooping(true)
          ..setVolume(0)
          ..initialize()
              .then((_) {
                if (!mounted) return;
                _laitlumVideoController.play();
                setState(() => _laitlumVideoReady = true);
              })
              .catchError((e) => debugPrint('LAITLUM video init failed: $e'));

    _sohraVideoController =
        VideoPlayerController.asset(
            // NEW
            'assets/videos/sohra/sohra_gen.mp4', // NEW
          )
          ..setLooping(true)
          ..setVolume(0)
          ..initialize()
              .then((_) {
                if (!mounted) return;
                _sohraVideoController.play();
                setState(() => _sohraVideoReady = true);
              })
              .catchError((e) => debugPrint('SOHRA video init failed: $e'));
  }

  @override
  void dispose() {
    _laitlumVideoController.dispose();
    _sohraVideoController.dispose(); // NEW
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildDestinationCard(Map<String, String> place) {
    const double cardHeight = 260;
    final name = place['name']!;
    final imagePath = place['image']!;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: cardHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: (name == 'LAITLUM' && _laitlumVideoReady)
                  ? _CoverVideo(controller: _laitlumVideoController)
                  : (name == 'SOHRA' && _sohraVideoReady) // NEW
                  ? _CoverVideo(controller: _sohraVideoController) // NEW
                  : Image.asset(imagePath, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.45),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 30,
                              fontFamily: 'Lato',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StreamBuilder<double?>(
                              stream: getTemperatureStream(name),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text(
                                    '...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                if (snap.hasError) {
                                  return const Text(
                                    '--',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return Text(
                                  '${snap.data?.toStringAsFixed(2) ?? "--"}°C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                            StreamBuilder<String?>(
                              stream: getWeatherStream(name),
                              builder: (context, snap) {
                                final weather =
                                    (snap.data ?? place['weather'] ?? '')
                                        .toLowerCase();
                                String anim = 'animations/Sunny.json';
                                if (weather.contains('rain') ||
                                    weather.contains('storm')) {
                                  anim = 'animations/ThunderStorm.json';
                                } else if (weather.contains('cloud') ||
                                    weather.contains('overcast') ||
                                    weather.contains('wind')) {
                                  anim = 'animations/Windy.json';
                                }
                                return Lottie.asset(
                                  anim,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        StreamBuilder<int?>(
                          stream: getVisitorCountStream(name),
                          initialData: _lastVisitorCount[name],
                          builder: (context, snap) {
                            final latest = snap.data;
                            if (latest != null) {
                              _lastVisitorCount[name] = latest;
                            }
                            final cached = _lastVisitorCount[name];
                            String display;
                            if (cached != null) {
                              display = 'Visitors today: $cached';
                            } else if (snap.connectionState ==
                                ConnectionState.waiting) {
                              display = 'Visitors today: ...';
                            } else if (snap.hasError) {
                              display = 'Visitors today: --';
                            } else {
                              display = 'Visitors today: --';
                            }
                            return Text(
                              display,
                              style: const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final filtered = _searchQuery.isEmpty
        ? destinations
        : destinations
              .where(
                (p) => p['name']!.toLowerCase().contains(
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
                            'images/home2.jpg',
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
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const MapPage(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: const Icon(
                                        Icons.map,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'images/user.png',
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
                                  'MegTourism',
                                  style: TextStyle(
                                    fontSize: kIsWeb
                                        ? 48.0
                                        : imageWidth * 0.130,
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
                                    height: 1.0,
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
                              elevation: 5,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(width: 1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                  decoration: const InputDecoration(
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
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: filtered
                        .map(_buildDestinationCard)
                        .toList(growable: false),
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

class _CoverVideo extends StatelessWidget {
  final VideoPlayerController controller;
  const _CoverVideo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: controller.value.isInitialized
          ? controller.value.aspectRatio
          : 16 / 9,
      child: VideoPlayer(controller),
    );
  }
}
