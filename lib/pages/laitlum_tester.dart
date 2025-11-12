import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LaitlumVideoTester extends StatefulWidget {
  const LaitlumVideoTester({super.key});

  @override
  State<LaitlumVideoTester> createState() => _LaitlumVideoTesterState();
}

class _LaitlumVideoTesterState extends State<LaitlumVideoTester> with TickerProviderStateMixin {
  // Assets
  static const String _sunnyLoop   = 'assets/videos/laitlum/laitlum_sunny.mp4';
  static const String _rainyLoop   = 'assets/videos/laitlum/laitlum_rainy.mp4';
  static const String _sunToRain   = 'assets/videos/laitlum/suntorain_trans.mp4';
  static const String _rainToSun   = 'assets/videos/laitlum/raintosun_trans.mp4';

  // Video state
  VideoPlayerController? _current;
  VideoPlayerController? _next; // used only when safe mode is off to crossfade
  bool _currentReady = false;
  String _state = 'sunny'; // 'sunny' | 'rainy'
  bool _transitioning = false;
  String? _pendingTarget;

  // Crossfade (disabled in safe mode)
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _fadeCtrl,
    curve: Curves.easeInOut,
  );

  // Emulator-safe mode: keep only one decoder alive at a time
  bool _safeMode = true;

  @override
  void initState() {
    super.initState();
    // start with sunny loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _switchLoop('sunny');
    });
  }

  @override
  void dispose() {
    _current?.removeListener(_onVideoEndCheck);
    _current?.dispose();
    _next?.removeListener(_onVideoEndCheck);
    _next?.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // -------------- Core helpers --------------

  Future<VideoPlayerController> _createController(String asset, {required bool loop}) async {
    final c = VideoPlayerController.asset(
      asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..setLooping(loop)
     ..setVolume(0);
    await c.initialize();
    if (loop) {
      await c.seekTo(Duration.zero);
    }
    return c;
  }

  // Safe mode path: dispose previous before creating next (best for emulator)
  Future<void> _swapSafe(String asset, {required bool loop}) async {
    final old = _current;
    _current = null;
    _currentReady = false;
    if (mounted) setState(() {});
    try {
      old?.removeListener(_onVideoEndCheck);
      await old?.dispose();
    } catch (_) {}

    try {
      final c = await _createController(asset, loop: loop);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _current = c;
        _currentReady = true;
      });
      await c.play();
    } catch (e, st) {
      debugPrint('[Tester] init/play failed for $asset: $e\n$st');
      if (mounted) setState(() => _currentReady = false);
    }
  }

  // Crossfade path: hold both for a short time (use on physical device)
  Future<void> _swapCrossfade(String asset, {required bool loop}) async {
    // Prepare next
    try {
      final n = await _createController(asset, loop: loop);
      _next?.removeListener(_onVideoEndCheck);
      await _next?.dispose();
      _next = n;
    } catch (e, st) {
      debugPrint('[Tester] next init failed for $asset: $e\n$st');
      // Fallback to safe swap
      return _swapSafe(asset, loop: loop);
    }

    if (!mounted) {
      await _next?.dispose();
      _next = null;
      return;
    }

    // Start next hidden, then fade
    try {
      await _next!.play();
    } catch (e, st) {
      debugPrint('[Tester] next play failed: $e\n$st');
      await _next?.dispose();
      _next = null;
      return _swapSafe(asset, loop: loop);
    }

    // Crossfade
    _fadeCtrl.reset();
    setState(() {});
    await _fadeCtrl.forward();

    // After fade completes, drop old and make next current
    final old = _current;
    _current = _next;
    _currentReady = true;
    _next = null;
    if (mounted) setState(() {});
    try {
      old?.removeListener(_onVideoEndCheck);
      await old?.dispose();
    } catch (_) {}
  }

  Future<void> _setController(String asset, {required bool loop}) {
    return _safeMode
        ? _swapSafe(asset, loop: loop)
        : _swapCrossfade(asset, loop: loop);
  }

  Future<void> _switchLoop(String weather) async {
    _transitioning = false;
    _state = weather;
    final asset = (weather == 'rainy') ? _rainyLoop : _sunnyLoop;
    await _setController(asset, loop: true);
  }

  Future<void> _playTransition(String transitionAsset, {required String targetLoop}) async {
    _transitioning = true;
    _pendingTarget = targetLoop;

    // Play the transition (non-loop)
    await _setController(transitionAsset, loop: false);

    // End-of-transition detection
    _current?.addListener(_onVideoEndCheck);

    // Safety timeout: switch anyway after (duration + 200ms)
    // If duration isn't known, fallback to 2s.
    final dur = _current?.value.duration;
    final switchAfter = (dur == null || dur == Duration.zero)
        ? const Duration(seconds: 2)
        : dur + const Duration(milliseconds: 200);
    Future.delayed(switchAfter, () {
      if (!mounted) return;
      if (_transitioning) {
        debugPrint('[Tester] timeout -> force switch to $_pendingTarget');
        _completeTransition();
      }
    });
  }

  void _onVideoEndCheck() {
    final c = _current;
    if (c == null) return;
    final v = c.value;
    if (!v.isInitialized || v.duration == Duration.zero) return;

    const epsilon = Duration(milliseconds: 250);
    if (v.position >= v.duration - epsilon) {
      c.removeListener(_onVideoEndCheck);
      if (_transitioning) {
        _completeTransition();
      }
    }
  }

  void _completeTransition() {
    final target = _pendingTarget ?? _state;
    _pendingTarget = null;
    _transitioning = false;
    debugPrint('[Tester] transition end -> loop: $target');
    _switchLoop(target);
  }

  // -------------- UI --------------

  @override
  Widget build(BuildContext context) {
    final isPlaying = _current?.value.isPlaying == true;
    final ratio = _current?.value.isInitialized == true
        ? _current!.value.aspectRatio
        : 16 / 9;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laitlum Video Tester'),
        actions: [
          Row(
            children: [
              const Text('Safe mode', style: TextStyle(fontSize: 12)),
              Switch(
                value: _safeMode,
                onChanged: (v) => setState(() => _safeMode = v),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Current
                if (_current != null && _currentReady)
                  VideoPlayer(_current!)
                else
                  Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text('Video fallback', style: TextStyle(color: Colors.white)),
                    ),
                  ),

                // Crossfade overlay (only when _next exists and safe mode is off)
                if (!_safeMode && _next != null)
                  FadeTransition(
                    opacity: _fade,
                    child: VideoPlayer(_next!),
                  ),

                // Debug overlay
                Positioned(
                  left: 8,
                  bottom: 8,
                  right: 8,
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        'state: $_state | transitioning: $_transitioning | playing: $isPlaying\n'
                        'safeMode: $_safeMode | current: ${_label(_current)} | next: ${_label(_next)}',
                        maxLines: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _transitioning ? null : () => _switchLoop('sunny'),
                child: const Text('Sunny loop'),
              ),
              ElevatedButton(
                onPressed: _transitioning ? null : () => _switchLoop('rainy'),
                child: const Text('Rainy loop'),
              ),
              ElevatedButton(
                onPressed: _transitioning ? null : () => _playTransition(_sunToRain, targetLoop: 'rainy'),
                child: const Text('Sun → Rain'),
              ),
              ElevatedButton(
                onPressed: _transitioning ? null : () => _playTransition(_rainToSun, targetLoop: 'sunny'),
                child: const Text('Rain → Sun'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Quick restart current to recover from a stall
                  final target = _state;
                  await _switchLoop(target);
                },
                child: const Text('Recover current'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Tip: Keep Safe mode ON on emulator to avoid decoder errors (one controller at a time). '
              'For smoother visuals on a real device, turn Safe mode OFF to enable short crossfades.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
      floatingActionButton: (_current != null)
          ? FloatingActionButton.small(
              onPressed: () async {
                if (_current!.value.isPlaying) {
                  await _current!.pause();
                } else {
                  await _current!.play();
                }
                if (mounted) setState(() {});
              },
              child: Icon(_current!.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }

  String _label(VideoPlayerController? c) {
    if (c == null) return 'null';
    final ds = c.dataSource.toLowerCase();
    if (ds.contains('suntorain')) return 'sun→rain';
    if (ds.contains('raintosun')) return 'rain→sun';
    if (ds.contains('rainy')) return 'rainy';
    if (ds.contains('sunny')) return 'sunny';
    return c.dataSource;
  }
}