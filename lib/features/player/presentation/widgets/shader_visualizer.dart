import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/vibe_audio_service.dart';
import '../../../../services/visualizer_service.dart';
import '../../../../services/log_service.dart';

/// Available shader visualizer types
enum ShaderVisualizerType {
  resonance,    // Cymatics-based, Chladni patterns
  ripples,      // Wave interference, water ripples
  lissajous,    // Lissajous curves / harmonograph
  neonRings,    // Celestial Halos
  aurora,       // Northern lights / Aurora Borealis
}

/// Provider for shader programs - loads them once and caches
final shaderProgramsProvider = FutureProvider<Map<ShaderVisualizerType, ui.FragmentProgram>>((ref) async {
  final programs = <ShaderVisualizerType, ui.FragmentProgram>{};

  // Load Resonance shader (cymatics-based, primary visualizer)
  try {
    programs[ShaderVisualizerType.resonance] = await ui.FragmentProgram.fromAsset('shaders/resonance.frag');
  } catch (e) {
    Log.ui.d('Failed to load resonance shader: $e');
  }

  // Load Ripples shader (wave interference)
  try {
    programs[ShaderVisualizerType.ripples] = await ui.FragmentProgram.fromAsset('shaders/ripples.frag');
  } catch (e) {
    Log.ui.d('Failed to load ripples shader: $e');
  }

  // Load Lissajous shader (harmonograph curves)
  try {
    programs[ShaderVisualizerType.lissajous] = await ui.FragmentProgram.fromAsset('shaders/lissajous.frag');
  } catch (e) {
    Log.ui.d('Failed to load lissajous shader: $e');
  }

  // Load Neon Rings shader (Celestial Halos)
  try {
    programs[ShaderVisualizerType.neonRings] = await ui.FragmentProgram.fromAsset('shaders/neon_rings.frag');
  } catch (e) {
    Log.ui.d('Failed to load neon_rings shader: $e');
  }

  // Load Aurora shader (Northern Lights)
  try {
    programs[ShaderVisualizerType.aurora] = await ui.FragmentProgram.fromAsset('shaders/aurora.frag');
  } catch (e) {
    Log.ui.d('Failed to load aurora shader: $e');
  }

  return programs;
});

/// Shader-based audio visualizer widget
class ShaderVisualizer extends ConsumerStatefulWidget {
  final ShaderVisualizerType type;
  final bool isPlaying;
  final double width;
  final double height;
  final Widget? child;

  const ShaderVisualizer({
    super.key,
    required this.type,
    required this.isPlaying,
    this.width = double.infinity,
    this.height = 300,
    this.child,
  });

  @override
  ConsumerState<ShaderVisualizer> createState() => _ShaderVisualizerState();
}

class _ShaderVisualizerState extends ConsumerState<ShaderVisualizer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  DateTime? _lastTick;

  // Audio data with smoothing
  double _bass = 0.0;
  double _mid = 0.0;
  double _treble = 0.0;
  double _energy = 0.0;
  double _beat = 0.0;
  final List<double> _bands = List.filled(8, 0.0);

  // VibeAudioService subscription
  StreamSubscription<AudioPulseData>? _pulseSubscription;
  AudioPulseData? _latestPulse;

  // Connection health tracking
  int _ticksSinceLastPulse = 0;
  static const int _maxTicksWithoutPulse = 120; // ~2 seconds at 60fps

  // Smoothing factors (0-1, higher = more responsive to music)
  // Different values for different signals - beat needs to be snappy!
  static const double _smoothingBase = 0.35;      // General responsiveness
  static const double _smoothingBeat = 0.7;       // Beat must be punchy
  static const double _smoothingDecay = 0.15;     // Slower decay for smooth falloff

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.isPlaying) {
      _ticker.start();
      _initVisualizer();
    }
  }

  Future<void> _initVisualizer() async {
    // Initialize VibeAudioService (our custom engine with direct PCM access)
    // This will reconnect EventChannels if they were lost on app restart
    await vibeAudioService.initialize();

    // Cancel existing subscription if any
    await _pulseSubscription?.cancel();

    // Subscribe to pulse data from VibeAudioEngine
    _pulseSubscription = vibeAudioService.pulseStream.listen((pulse) {
      _latestPulse = pulse;
      _ticksSinceLastPulse = 0;
    });

    // Reset connection tracking
    _ticksSinceLastPulse = 0;

    // Also try old visualizer service as fallback
    final permissionStatus = await visualizerService.checkPermission();
    if (permissionStatus == VisualizerPermissionStatus.granted) {
      await visualizerService.startCapture(captureRate: 60);
    } else if (permissionStatus != VisualizerPermissionStatus.permanentlyDenied) {
      final granted = await visualizerService.requestPermission();
      if (granted) {
        await visualizerService.startCapture(captureRate: 60);
      }
    }

    Log.ui.d('ShaderVisualizer: Initialized, listening for pulse data');
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastTick != null) {
      final dt = now.difference(_lastTick!).inMicroseconds / 1000000.0;
      _time += dt;
    }
    _lastTick = now;

    // Track connection health - detect if pulse data stops flowing
    _ticksSinceLastPulse++;
    if (widget.isPlaying && _ticksSinceLastPulse > _maxTicksWithoutPulse) {
      // No pulse data for ~2 seconds while playing - try to reconnect
      Log.ui.d('ShaderVisualizer: No pulse data for ${_ticksSinceLastPulse} ticks, reconnecting...');
      _ticksSinceLastPulse = 0; // Reset to avoid spamming
      _initVisualizer(); // This will reconnect EventChannels
    }

    // Priority 1: VibeAudioService (our custom engine with direct PCM access)
    final pulse = _latestPulse;
    if (pulse != null && pulse.energy > 0.001) {
      // Use the rich frequency data from AudioPulse
      final targetBass = pulse.bassTotal;
      final targetMid = pulse.midTotal;
      final targetTreble = pulse.trebleTotal;
      final targetEnergy = pulse.energy;
      final targetBeat = pulse.beat;

      // Asymmetric smoothing: fast attack, slower decay
      // When value goes UP, respond quickly. When going DOWN, decay smoothly.
      _bass = _lerpAsym(_bass, targetBass, _smoothingBase, _smoothingDecay);
      _mid = _lerpAsym(_mid, targetMid, _smoothingBase, _smoothingDecay);
      _treble = _lerpAsym(_treble, targetTreble, _smoothingBase, _smoothingDecay);
      _energy = _lerpAsym(_energy, targetEnergy, _smoothingBase, _smoothingDecay);
      // Beat uses extra fast attack for punchy response
      _beat = _lerpAsym(_beat, targetBeat, _smoothingBeat, _smoothingDecay);

      // Use 32-band spectrum, reduce to 8 bands for shader
      if (pulse.spectrum.isNotEmpty) {
        final bandsPerGroup = pulse.spectrum.length ~/ 8;
        for (int i = 0; i < 8; i++) {
          double sum = 0.0;
          final start = i * bandsPerGroup;
          final end = (i + 1) * bandsPerGroup;
          for (int j = start; j < end && j < pulse.spectrum.length; j++) {
            sum += pulse.spectrum[j];
          }
          final avg = sum / bandsPerGroup;
          _bands[i] = _lerpAsym(_bands[i], avg, _smoothingBase, _smoothingDecay);
        }
      }
    }
    // Priority 2: Old visualizer service (fallback)
    else {
      final data = visualizerService.currentData;
      if (data != null && data.fft.isNotEmpty) {
        final freqBands = data.frequencyBands;
        final targetBass = freqBands['bass'] ?? 0.0;
        final targetMid = freqBands['mid'] ?? 0.0;
        final targetTreble = freqBands['treble'] ?? 0.0;
        final targetEnergy = (targetBass + targetMid + targetTreble) / 3.0;

        _bass = _lerpAsym(_bass, targetBass, _smoothingBase, _smoothingDecay);
        _mid = _lerpAsym(_mid, targetMid, _smoothingBase, _smoothingDecay);
        _treble = _lerpAsym(_treble, targetTreble, _smoothingBase, _smoothingDecay);
        _energy = _lerpAsym(_energy, targetEnergy, _smoothingBase, _smoothingDecay);
        _beat = _lerpAsym(_beat, 0.0, _smoothingBeat, _smoothingDecay);

        final newBands = data.reduceToBands(8);
        for (int i = 0; i < 8 && i < newBands.length; i++) {
          _bands[i] = _lerpAsym(_bands[i], newBands[i], _smoothingBase, _smoothingDecay);
        }
      }
      // Priority 3: Fake data when playing (demo/fallback)
      else if (widget.isPlaying) {
        final targetBass = 0.3 + 0.3 * _sin(_time * 2.0);
        final targetMid = 0.4 + 0.2 * _sin(_time * 3.0 + 1.0);
        final targetTreble = 0.3 + 0.3 * _sin(_time * 5.0 + 2.0);

        _bass = _lerpAsym(_bass, targetBass, _smoothingBase, _smoothingDecay);
        _mid = _lerpAsym(_mid, targetMid, _smoothingBase, _smoothingDecay);
        _treble = _lerpAsym(_treble, targetTreble, _smoothingBase, _smoothingDecay);
        _energy = (_bass + _mid + _treble) / 3.0;
        _beat = _lerpAsym(_beat, 0.0, _smoothingBeat, _smoothingDecay);

        for (int i = 0; i < 8; i++) {
          final target = 0.3 + 0.4 * _sin(_time * (2.0 + i * 0.5) + i);
          _bands[i] = _lerpAsym(_bands[i], target, _smoothingBase, _smoothingDecay);
        }
      }
    }

    setState(() {});
  }

  // Asymmetric lerp: fast attack (going up), slow decay (going down)
  double _lerpAsym(double current, double target, double attack, double decay) {
    if (target > current) {
      // Going UP - use fast attack
      return current + (target - current) * attack;
    } else {
      // Going DOWN - use slower decay
      return current + (target - current) * decay;
    }
  }

  double _sin(double x) => (x - x.floor()) < 0.5 ? (x * 2 % 2) : (2 - x * 2 % 2);

  @override
  void didUpdateWidget(ShaderVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _ticker.start();
        _initVisualizer();
      } else {
        _ticker.stop();
        _pulseSubscription?.cancel();
        _pulseSubscription = null;
        _latestPulse = null;
        visualizerService.stopCapture();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulseSubscription?.cancel();
    visualizerService.stopCapture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadersAsync = ref.watch(shaderProgramsProvider);

    return shadersAsync.when(
      data: (shaders) {
        final program = shaders[widget.type];
        if (program == null) {
          return _buildFallback();
        }

        // Use LayoutBuilder to handle infinite dimensions (full screen)
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = widget.width.isFinite ? widget.width : constraints.maxWidth;
            final height = widget.height.isFinite ? widget.height : constraints.maxHeight;

            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(width, height),
                    painter: _ShaderPainter(
                      program: program,
                      time: _time,
                      bass: _bass,
                      mid: _mid,
                      treble: _treble,
                      energy: _energy,
                      beat: _beat,
                      bands: _bands,
                    ),
                  ),
                  if (widget.child != null) widget.child!,
                ],
              ),
            );
          },
        );
      },
      loading: () => _buildLoading(),
      error: (e, _) => _buildFallback(),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      width: widget.width.isFinite ? widget.width : null,
      height: widget.height.isFinite ? widget.height : null,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: widget.width.isFinite ? widget.width : null,
      height: widget.height.isFinite ? widget.height : null,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color.lerp(Colors.purple, Colors.black, 0.5)!,
            Colors.black,
          ],
        ),
      ),
      child: widget.child,
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final double bass;
  final double mid;
  final double treble;
  final double energy;
  final double beat;
  final List<double> bands;

  _ShaderPainter({
    required this.program,
    required this.time,
    required this.bass,
    required this.mid,
    required this.treble,
    required this.energy,
    required this.beat,
    required this.bands,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // Set uniforms
    int idx = 0;

    // uSize (vec2)
    shader.setFloat(idx++, size.width);
    shader.setFloat(idx++, size.height);

    // uTime (float)
    shader.setFloat(idx++, time);

    // uBass, uMid, uTreble, uEnergy, uBeat (floats)
    shader.setFloat(idx++, bass);
    shader.setFloat(idx++, mid);
    shader.setFloat(idx++, treble);
    shader.setFloat(idx++, energy);
    shader.setFloat(idx++, beat);

    // uBand0-7 (floats)
    for (int i = 0; i < 8; i++) {
      shader.setFloat(idx++, i < bands.length ? bands[i] : 0.0);
    }

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}

/// Extension to get display name for shader types
extension ShaderVisualizerTypeExtension on ShaderVisualizerType {
  String get displayName {
    switch (this) {
      case ShaderVisualizerType.resonance:
        return 'Resonance';
      case ShaderVisualizerType.ripples:
        return 'Ripples';
      case ShaderVisualizerType.lissajous:
        return 'Harmonograph';
      case ShaderVisualizerType.neonRings:
        return 'Celestial Halos';
      case ShaderVisualizerType.aurora:
        return 'Aurora';
    }
  }

  IconData get icon {
    switch (this) {
      case ShaderVisualizerType.resonance:
        return Icons.graphic_eq_rounded;
      case ShaderVisualizerType.ripples:
        return Icons.water_drop_rounded;
      case ShaderVisualizerType.lissajous:
        return Icons.show_chart_rounded;
      case ShaderVisualizerType.neonRings:
        return Icons.lens_blur_rounded;
      case ShaderVisualizerType.aurora:
        return Icons.nights_stay_rounded;
    }
  }
}
