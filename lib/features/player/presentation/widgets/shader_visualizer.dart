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
  resonance,          // Cymatics-based, Chladni patterns
  ripples,            // Wave interference, water ripples
  lissajous,          // Lissajous curves / harmonograph
  neonRings,          // Celestial Halos
  aurora,             // Northern lights / Aurora Borealis
  spirograph,         // Spirograph epicycles / Fourier patterns
  voronoi,            // Voronoi flow fields
  phyllotaxis,        // Sunflower spirals / Golden angle
  attractors,         // Strange attractors (Lorenz, Clifford)
  moire,              // Moiré interference patterns
  pendulum,           // Pendulum waves
  fractalFlames,      // Fractal flames / IFS
  mandelbrot,         // Mandelbrot/Julia set morphing
  // Pendulum variations
  pendulumCircular,   // Radial starburst pendulums
  pendulumCradle,     // Newton's cradle
  pendulumMetronome,  // Inverted metronomes
  pendulumDouble,     // Chaotic double pendulum
  pendulumLissajous,  // 2D sand pendulum / Lissajous
  pendulumSpring,     // Spring/bouncy pendulums
  pendulumFirefly,    // Glowing particle pendulums
  pendulumWave,       // Wave machine
  pendulumMirror,     // Mirrored reflection pendulums
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

  // Load Spirograph shader (Epicycles)
  try {
    programs[ShaderVisualizerType.spirograph] = await ui.FragmentProgram.fromAsset('shaders/spirograph.frag');
  } catch (e) {
    Log.ui.d('Failed to load spirograph shader: $e');
  }

  // Load Voronoi shader (Flow Fields)
  try {
    programs[ShaderVisualizerType.voronoi] = await ui.FragmentProgram.fromAsset('shaders/voronoi.frag');
  } catch (e) {
    Log.ui.d('Failed to load voronoi shader: $e');
  }

  // Load Phyllotaxis shader (Sunflower Spirals)
  try {
    programs[ShaderVisualizerType.phyllotaxis] = await ui.FragmentProgram.fromAsset('shaders/phyllotaxis.frag');
  } catch (e) {
    Log.ui.d('Failed to load phyllotaxis shader: $e');
  }

  // Load Attractors shader (Strange Attractors)
  try {
    programs[ShaderVisualizerType.attractors] = await ui.FragmentProgram.fromAsset('shaders/attractors.frag');
  } catch (e) {
    Log.ui.d('Failed to load attractors shader: $e');
  }

  // Load Moire shader (Interference Patterns)
  try {
    programs[ShaderVisualizerType.moire] = await ui.FragmentProgram.fromAsset('shaders/moire.frag');
  } catch (e) {
    Log.ui.d('Failed to load moire shader: $e');
  }

  // Load Pendulum shader (Pendulum Waves)
  try {
    programs[ShaderVisualizerType.pendulum] = await ui.FragmentProgram.fromAsset('shaders/pendulum.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum shader: $e');
  }

  // Load Fractal Flames shader
  try {
    programs[ShaderVisualizerType.fractalFlames] = await ui.FragmentProgram.fromAsset('shaders/fractal_flames.frag');
  } catch (e) {
    Log.ui.d('Failed to load fractal_flames shader: $e');
  }

  // Load Mandelbrot shader (Julia/Mandelbrot Sets)
  try {
    programs[ShaderVisualizerType.mandelbrot] = await ui.FragmentProgram.fromAsset('shaders/mandelbrot.frag');
  } catch (e) {
    Log.ui.d('Failed to load mandelbrot shader: $e');
  }

  // Pendulum variations
  try {
    programs[ShaderVisualizerType.pendulumCircular] = await ui.FragmentProgram.fromAsset('shaders/pendulum_circular.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_circular shader: $e');
  }

  try {
    programs[ShaderVisualizerType.pendulumCradle] = await ui.FragmentProgram.fromAsset('shaders/pendulum_cradle.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_cradle shader: $e');
  }

  try {
    programs[ShaderVisualizerType.pendulumMetronome] = await ui.FragmentProgram.fromAsset('shaders/pendulum_metronome.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_metronome shader: $e');
  }

  try {
    programs[ShaderVisualizerType.pendulumDouble] = await ui.FragmentProgram.fromAsset('shaders/pendulum_double.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_double shader: $e');
  }

  try {
    programs[ShaderVisualizerType.pendulumLissajous] = await ui.FragmentProgram.fromAsset('shaders/pendulum_lissajous.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_lissajous shader: $e');
  }

  try {
    programs[ShaderVisualizerType.pendulumSpring] = await ui.FragmentProgram.fromAsset('shaders/pendulum_spring.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_spring shader: $e');
  }

  try {
    programs[ShaderVisualizerType.pendulumFirefly] = await ui.FragmentProgram.fromAsset('shaders/pendulum_firefly.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_firefly shader: $e');
  }

  try {
    programs[ShaderVisualizerType.pendulumWave] = await ui.FragmentProgram.fromAsset('shaders/pendulum_wave.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_wave shader: $e');
  }

  try {
    programs[ShaderVisualizerType.pendulumMirror] = await ui.FragmentProgram.fromAsset('shaders/pendulum_mirror.frag');
  } catch (e) {
    Log.ui.d('Failed to load pendulum_mirror shader: $e');
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
  // NOTE: Kotlin AudioPulse already applies smoothing (0.7-0.85 range), so these
  // values represent the ADDITIONAL Flutter-side smoothing. Higher = more responsive.
  // Previous values (0.35/0.7/0.15) caused ~50-100ms latency from double-smoothing.
  static const double _smoothingBase = 0.65;      // General responsiveness (was 0.35 - too slow)
  static const double _smoothingBeat = 0.85;      // Beat must be punchy (was 0.7)
  static const double _smoothingDecay = 0.25;     // Decay for smooth falloff (was 0.15)

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
      case ShaderVisualizerType.spirograph:
        return 'Spirograph';
      case ShaderVisualizerType.voronoi:
        return 'Voronoi';
      case ShaderVisualizerType.phyllotaxis:
        return 'Sunflower';
      case ShaderVisualizerType.attractors:
        return 'Attractors';
      case ShaderVisualizerType.moire:
        return 'Moiré';
      case ShaderVisualizerType.pendulum:
        return 'Pendulum';
      case ShaderVisualizerType.fractalFlames:
        return 'Flames';
      case ShaderVisualizerType.mandelbrot:
        return 'Fractal';
      // Pendulum variations
      case ShaderVisualizerType.pendulumCircular:
        return 'Circular Pendulum';
      case ShaderVisualizerType.pendulumCradle:
        return 'Newton\'s Cradle';
      case ShaderVisualizerType.pendulumMetronome:
        return 'Metronome';
      case ShaderVisualizerType.pendulumDouble:
        return 'Double Pendulum';
      case ShaderVisualizerType.pendulumLissajous:
        return 'Sand Pendulum';
      case ShaderVisualizerType.pendulumSpring:
        return 'Spring Pendulum';
      case ShaderVisualizerType.pendulumFirefly:
        return 'Firefly';
      case ShaderVisualizerType.pendulumWave:
        return 'Wave Machine';
      case ShaderVisualizerType.pendulumMirror:
        return 'Mirror Pendulum';
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
      case ShaderVisualizerType.spirograph:
        return Icons.motion_photos_on_rounded;
      case ShaderVisualizerType.voronoi:
        return Icons.blur_on_rounded;
      case ShaderVisualizerType.phyllotaxis:
        return Icons.local_florist_rounded;
      case ShaderVisualizerType.attractors:
        return Icons.all_inclusive_rounded;
      case ShaderVisualizerType.moire:
        return Icons.blur_circular_rounded;
      case ShaderVisualizerType.pendulum:
        return Icons.swap_vert_rounded;
      case ShaderVisualizerType.fractalFlames:
        return Icons.local_fire_department_rounded;
      case ShaderVisualizerType.mandelbrot:
        return Icons.auto_awesome_rounded;
      // Pendulum variations
      case ShaderVisualizerType.pendulumCircular:
        return Icons.radio_button_unchecked_rounded;
      case ShaderVisualizerType.pendulumCradle:
        return Icons.sports_baseball_rounded;
      case ShaderVisualizerType.pendulumMetronome:
        return Icons.timer_rounded;
      case ShaderVisualizerType.pendulumDouble:
        return Icons.link_rounded;
      case ShaderVisualizerType.pendulumLissajous:
        return Icons.beach_access_rounded;
      case ShaderVisualizerType.pendulumSpring:
        return Icons.expand_rounded;
      case ShaderVisualizerType.pendulumFirefly:
        return Icons.auto_awesome_rounded;
      case ShaderVisualizerType.pendulumWave:
        return Icons.waves_rounded;
      case ShaderVisualizerType.pendulumMirror:
        return Icons.flip_rounded;
    }
  }
}
