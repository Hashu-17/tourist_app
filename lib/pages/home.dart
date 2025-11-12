import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import 'package:tourist_app/pages/laitlum_tester.dart';

// Firestore collection mapping
const Map<String, String> kPlaceToCollection = {
  'LAITLUM': 'LAITLUM',
  'SOHRA': 'SOHRA',
  'DAWKI': 'DAWKI',
  "Ward's Lake": 'WardsLake',
};

// LAITLUM rain sensor doc id
const String kLaitlumRainDocId = 'raspberrypi';

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

    for (final k in ['people_count_total', 'people_count', 'visitor_count', 'visitors']) {
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

// LAITLUM: rain_detected boolean stream
Stream<bool> getLaitlumRainDetectedStream() {
  return FirebaseFirestore.instance
      .collection('LAITLUM')
      .doc(kLaitlumRainDocId)
      .snapshots()
      .map((d) {
        final data = d.data();
        if (data == null) return false; // default to sunny
        final rd = data['rain_detected'];
        if (rd is bool) return rd;
        // Fallbacks if boolean missing
        final weather = (data['weather'] as String?)?.toLowerCase();
        final kind = (data['kind'] as String?)?.toLowerCase();
        if (weather != null) return weather.contains('rain');
        if (kind != null) return kind.contains('rain');
        return false;
      })
      .distinct();
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

  // ------- LAITLUM video state -------
  // REMOVE caching to keep only one decoder alive.
  // final Map<String, VideoPlayerController> _laitlumCache = {};
  VideoPlayerController? _laitlumController;
  bool _laitlumReady = false;
  String _laitlumState = 'sunny'; // 'sunny' | 'rainy'
  bool _laitlumTransitioning = false;
  String? _laitlumPending;
  StreamSubscription<bool>? _laitlumSub;
  Completer<void>? _laitlumTransitionCompleter;

  // Reuse the boolean stream for both icon and video
  late final Stream<bool> _laitlumRain$ = getLaitlumRainDetectedStream();

  @override
  void initState() {
    super.initState();

    // Start with sunny loop (no preloading of other clips)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _switchLaitlumLoop('sunny');
    });

    _laitlumSub = _laitlumRain$.listen(
      (isRaining) => _setLaitlumWeather(isRaining ? 'rainy' : 'sunny'),
      onError: (e) => debugPrint('LAITLUM rain stream error: $e'),
    );
  }

  @override
  void dispose() {
    _laitlumSub?.cancel();
    _laitlumController?.removeListener(_laitlumEndListener);
    _laitlumController?.dispose();
    // REMOVE cache disposal
    // for (final c in _laitlumCache.values) { c.dispose(); }
    // _laitlumCache.clear();
    _searchController.dispose();
    super.dispose();
  }

  // -------- Laitlum helpers --------

  // Create a fresh controller each time; dispose the previous one first
  Future<void> _setLaitlumController(String asset, {required bool loop, bool restart = true}) async {
    final old = _laitlumController;
    _laitlumController = null;
    _laitlumReady = false;
    if (mounted) setState(() {}); // show fallback image while switching

    // Fully dispose the old decoder to free emulator resources
    try {
      old?.removeListener(_laitlumEndListener);
      await old?.dispose();
    } catch (_) {}

    final next = VideoPlayerController.asset(
      asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true), // removed const
    )..setLooping(loop)
     ..setVolume(0);

    try {
      await next.initialize();
      if (restart) await next.seekTo(Duration.zero);
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _laitlumController = next;
        _laitlumReady = true;
      });
      await next.play();
    } catch (e, st) {
      debugPrint('[LAITLUM] init/play failed for $asset: $e\n$st');
      try { await next.dispose(); } catch (_) {}
      if (mounted) setState(() => _laitlumReady = false);
    }
  }

  Future<void> _switchLaitlumLoop(String weather) async {
    _laitlumTransitioning = false;
    _laitlumState = weather;
    final asset = (weather == 'rainy')
        ? 'assets/videos/laitlum/laitlum_rainy.mp4'
        : 'assets/videos/laitlum/laitlum_sunny.mp4';
    await _setLaitlumController(asset, loop: true);
  }

  Future<void> _playLaitlumTransition(String transitionAsset, {required String targetLoop}) async {
    _laitlumTransitioning = true;
    _laitlumPending = targetLoop;
    _laitlumTransitionCompleter = Completer<void>();
    await _setLaitlumController(transitionAsset, loop: false, restart: true);
    _laitlumController?.addListener(_laitlumEndListener);
    return _laitlumTransitionCompleter!.future;
  }

  Future<void> _setLaitlumWeather(String next) async {
    final state = (next.toLowerCase().contains('rain')) ? 'rainy' : 'sunny';

    // If already in a transition, just queue the target and exit to avoid races
    if (_laitlumTransitioning) {
      _laitlumPending = state;
      debugPrint('[LAITLUM] queued while transitioning -> $state');
      return;
    }

    if (state == _laitlumState) {
      debugPrint('[LAITLUM] no change ($state)');
      return;
    }

    final from = _laitlumState;
    _laitlumState = state; // set early to prevent re-entry oscillations

    debugPrint('[LAITLUM] $from -> $state');

    if (from == 'sunny' && state == 'rainy') {
      await _playLaitlumTransition('assets/videos/laitlum/suntorain_trans.mp4', targetLoop: 'rainy');
    } else if (from == 'rainy' && state == 'sunny') {
      await _playLaitlumTransition('assets/videos/laitlum/raintosun_trans.mp4', targetLoop: 'sunny');
    } else {
      await _switchLaitlumLoop(state);
    }
  }

  void _laitlumEndListener() {
    final c = _laitlumController;
    if (c == null) return;
    final v = c.value;
    if (!v.isInitialized || v.duration == Duration.zero) return;

    const epsilon = Duration(milliseconds: 300);
    if (v.position >= v.duration - epsilon) {
      c.removeListener(_laitlumEndListener);
      if (mounted && _laitlumTransitioning) {
        final target = _laitlumPending ?? _laitlumState;
        debugPrint('[LAITLUM] transition end -> switch to loop: $target');
        _laitlumPending = null;
        _switchLaitlumLoop(target).whenComplete(() {
          _laitlumTransitionCompleter?.complete();
          _laitlumTransitionCompleter = null;
        });
      }
    }
  }

  Widget _buildDestinationCard(Map<String, String> place) {
    const double cardHeight = 260;
    final name = place['name']!;
    final imagePath = place['image']!;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: cardHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: (name == 'LAITLUM' && (_laitlumController?.value.isInitialized ?? false))
                  ? _CoverVideo(controller: _laitlumController!)
                  : Image.asset(imagePath, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
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
                                if (snap.connectionState == ConnectionState.waiting) {
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
                            // Weather icon:
                            // - LAITLUM: driven by rain_detected stream
                            // - Others: generic weather stream
                            if (name == 'LAITLUM')
                              StreamBuilder<bool>(
                                stream: _laitlumRain$,
                                builder: (context, snap) {
                                  final isRaining = snap.data ?? false;
                                  final anim = isRaining
                                      ? 'animations/ThunderStorm.json'
                                      : 'animations/Sunny.json';
                                  return Lottie.asset(
                                    anim,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                            else
                              StreamBuilder<String?>(
                                stream: getWeatherStream(name),
                                builder: (context, snap) {
                                  final weather = (snap.data ?? place['weather'] ?? '').toLowerCase();
                                  String anim = 'animations/Sunny.json';
                                  if (weather.contains('rain') || weather.contains('storm')) {
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
                            } else if (snap.connectionState == ConnectionState.waiting) {
                              display = 'Visitors today: ...';
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

    // Keep tester page on tap for LAITLUM
    if (name == 'LAITLUM') {
      return InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LaitlumVideoTester()),
          );
        },
        child: card,
      );
    }
    return card;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final filtered = _searchQuery.isEmpty
        ? destinations
        : destinations
            .where((p) => p['name']!.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
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
                                    onTap: () {},
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: const Icon(Icons.map, color: Colors.white, size: 28),
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
                                    fontSize: kIsWeb ? 48.0 : imageWidth * 0.130,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                                Text(
                                  "A tourist's guide",
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 20.0 : (imageWidth * 0.05).clamp(12.0, 24.0),
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
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Search your destination',
                                    hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Lato'),
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
                    children: filtered.map(_buildDestinationCard).toList(growable: false),
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
      aspectRatio: controller.value.isInitialized ? controller.value.aspectRatio : 16 / 9,
      child: VideoPlayer(controller),
    );
  }
}