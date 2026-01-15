import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/visualizer_service.dart';

/// Provider for visualizer data stream
final visualizerDataProvider = StreamProvider<VisualizerData>((ref) {
  return visualizerService.dataStream;
});

/// Available visualizer styles
enum VisualizerStyle {
  bars,
  wave,
  circular,
  particles,
  blob,
  mirrored,
}

/// Main audio visualizer widget that supports multiple styles
class AudioVisualizer extends ConsumerStatefulWidget {
  final bool isPlaying;
  final VisualizerStyle style;
  final double height;
  final double? width;
  final Color? primaryColor;
  final Color? secondaryColor;
  final int barCount;
  final Widget? child; // For circular visualizer

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.style = VisualizerStyle.bars,
    this.height = 120,
    this.width,
    this.primaryColor,
    this.secondaryColor,
    this.barCount = 32,
    this.child,
  });

  @override
  ConsumerState<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends ConsumerState<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _fallbackController;
  List<double> _fallbackData = [];
  final math.Random _random = math.Random();
  bool _permissionRequested = false;
  bool _usingRealVisualizer = false;

  @override
  void initState() {
    super.initState();
    _fallbackData = List.generate(widget.barCount, (_) => 0.2);

    _fallbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateFallbackData);

    _initVisualizer();
  }

  Future<void> _initVisualizer() async {
    if (!widget.isPlaying) return;

    // Check current permission status
    final permissionStatus = await visualizerService.checkPermission();

    if (permissionStatus == VisualizerPermissionStatus.granted) {
      // Permission already granted, start visualizer
      await _startRealVisualizer();
    } else if (permissionStatus == VisualizerPermissionStatus.permanentlyDenied) {
      // User permanently denied, use fallback
      _fallbackController.repeat();
    } else if (!_permissionRequested) {
      // Request permission once
      _permissionRequested = true;
      final granted = await visualizerService.requestPermission();
      if (granted) {
        await _startRealVisualizer();
      } else {
        _fallbackController.repeat();
      }
    } else {
      // Already requested and denied, use fallback
      _fallbackController.repeat();
    }
  }

  Future<void> _startRealVisualizer() async {
    final available = await visualizerService.isAvailable();
    if (available) {
      final started = await visualizerService.startCapture();
      _usingRealVisualizer = started;
      if (!started) {
        _fallbackController.repeat();
      }
    } else {
      _fallbackController.repeat();
    }
  }

  void _updateFallbackData() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _fallbackData.length; i++) {
        if (_random.nextDouble() > 0.7) {
          final target = widget.isPlaying
              ? 0.2 + _random.nextDouble() * 0.8
              : 0.1 + _random.nextDouble() * 0.1;
          _fallbackData[i] += (target - _fallbackData[i]) * 0.3;
        }
      }
    });
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _initVisualizer();
      } else {
        if (_usingRealVisualizer) {
          visualizerService.stopCapture();
        }
        _fallbackController.stop();
      }
    }
  }

  @override
  void dispose() {
    _fallbackController.dispose();
    if (_usingRealVisualizer) {
      visualizerService.stopCapture();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualizerData = ref.watch(visualizerDataProvider);
    final primaryColor = widget.primaryColor ?? AppTheme.primaryColor;
    final secondaryColor = widget.secondaryColor ?? AppTheme.secondaryColor;

    // Get data - use real data if available, otherwise fallback
    List<double> data = visualizerData.when(
      data: (d) => d.reduceToBands(widget.barCount),
      loading: () => _fallbackData,
      error: (_, __) => _fallbackData,
    );

    if (data.isEmpty) {
      data = _fallbackData;
    }

    switch (widget.style) {
      case VisualizerStyle.bars:
        return _BarsVisualizer(
          data: data,
          height: widget.height,
          width: widget.width,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isPlaying: widget.isPlaying,
        );
      case VisualizerStyle.wave:
        return _WaveVisualizer(
          data: data,
          height: widget.height,
          width: widget.width,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isPlaying: widget.isPlaying,
        );
      case VisualizerStyle.circular:
        return _CircularVisualizer(
          data: data,
          size: widget.height,
          primaryColor: primaryColor,
          isPlaying: widget.isPlaying,
          child: widget.child,
        );
      case VisualizerStyle.particles:
        return _ParticleVisualizer(
          data: data,
          height: widget.height,
          width: widget.width,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isPlaying: widget.isPlaying,
        );
      case VisualizerStyle.blob:
        return _BlobVisualizer(
          data: data,
          size: widget.height,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isPlaying: widget.isPlaying,
          child: widget.child,
        );
      case VisualizerStyle.mirrored:
        return _MirroredBarsVisualizer(
          data: data,
          height: widget.height,
          width: widget.width,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isPlaying: widget.isPlaying,
        );
    }
  }
}

/// Classic frequency bars visualizer
class _BarsVisualizer extends StatelessWidget {
  final List<double> data;
  final double height;
  final double? width;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isPlaying;

  const _BarsVisualizer({
    required this.data,
    required this.height,
    this.width,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (index) {
          final normalizedIndex = index / data.length;
          final color = Color.lerp(primaryColor, secondaryColor, normalizedIndex)!;
          final barHeight = height * data[index].clamp(0.05, 1.0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            width: width != null ? (width! / data.length) - 2 : 4,
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  color.withValues(alpha:0.6),
                  color,
                ],
              ),
              boxShadow: isPlaying && data[index] > 0.5
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha:0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

/// Mirrored bars visualizer (bars go up and down)
class _MirroredBarsVisualizer extends StatelessWidget {
  final List<double> data;
  final double height;
  final double? width;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isPlaying;

  const _MirroredBarsVisualizer({
    required this.data,
    required this.height,
    this.width,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(data.length, (index) {
          final normalizedIndex = index / data.length;
          final color = Color.lerp(primaryColor, secondaryColor, normalizedIndex)!;
          final barHeight = (height / 2) * data[index].clamp(0.05, 1.0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            width: width != null ? (width! / data.length) - 2 : 4,
            height: barHeight * 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.topCenter,
                colors: [
                  color,
                  color.withValues(alpha:0.6),
                ],
              ),
              boxShadow: isPlaying && data[index] > 0.5
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha:0.4),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

/// Waveform line visualizer
class _WaveVisualizer extends StatelessWidget {
  final List<double> data;
  final double height;
  final double? width;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isPlaying;

  const _WaveVisualizer({
    required this.data,
    required this.height,
    this.width,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _WavePainter(
          data: data,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isPlaying: isPlaying,
        ),
        size: Size(width ?? double.infinity, height),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> data;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isPlaying;

  _WavePainter({
    required this.data,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    if (isPlaying) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    }

    final path = Path();
    final stepX = size.width / (data.length - 1);
    final centerY = size.height / 2;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = centerY + (data[i] - 0.5) * size.height * 0.8;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve using quadratic bezier
        final prevX = (i - 1) * stepX;
        final prevY = centerY + (data[i - 1] - 0.5) * size.height * 0.8;
        final midX = (prevX + x) / 2;
        path.quadraticBezierTo(prevX, prevY, midX, (prevY + y) / 2);
      }
    }

    canvas.drawPath(path, paint);

    // Draw fill below the wave
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha:0.3),
          primaryColor.withValues(alpha:0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}

/// Circular spectrum visualizer
class _CircularVisualizer extends StatefulWidget {
  final List<double> data;
  final double size;
  final Color primaryColor;
  final bool isPlaying;
  final Widget? child;

  const _CircularVisualizer({
    required this.data,
    required this.size,
    required this.primaryColor,
    required this.isPlaying,
    this.child,
  });

  @override
  State<_CircularVisualizer> createState() => _CircularVisualizerState();
}

class _CircularVisualizerState extends State<_CircularVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(_CircularVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _CircularPainter(
                    data: widget.data,
                    color: widget.primaryColor,
                    isPlaying: widget.isPlaying,
                  ),
                ),
              );
            },
          ),
          if (widget.child != null)
            SizedBox(
              width: widget.size * 0.7,
              height: widget.size * 0.7,
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _CircularPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isPlaying;

  _CircularPainter({
    required this.data,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final innerRadius = size.width * 0.36;
    final maxBarHeight = size.width * 0.12;

    for (int i = 0; i < data.length; i++) {
      final angle = (2 * math.pi / data.length) * i - math.pi / 2;
      final barHeight = maxBarHeight * data[i].clamp(0.1, 1.0);

      final startX = center.dx + innerRadius * math.cos(angle);
      final startY = center.dy + innerRadius * math.sin(angle);
      final endX = center.dx + (innerRadius + barHeight) * math.cos(angle);
      final endY = center.dy + (innerRadius + barHeight) * math.sin(angle);

      final paint = Paint()
        ..color = color.withValues(alpha:0.5 + data[i] * 0.5)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      if (isPlaying && data[i] > 0.5) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      }

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularPainter oldDelegate) => true;
}

/// Particle effect visualizer
class _ParticleVisualizer extends StatefulWidget {
  final List<double> data;
  final double height;
  final double? width;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isPlaying;

  const _ParticleVisualizer({
    required this.data,
    required this.height,
    this.width,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isPlaying,
  });

  @override
  State<_ParticleVisualizer> createState() => _ParticleVisualizerState();
}

class _ParticleVisualizerState extends State<_ParticleVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateParticles);

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  void _updateParticles() {
    if (!mounted) return;

    // Add new particles based on audio intensity
    if (widget.isPlaying && widget.data.isNotEmpty) {
      final intensity = widget.data.reduce((a, b) => a + b) / widget.data.length;
      if (_random.nextDouble() < intensity * 0.5) {
        _particles.add(_Particle(
          x: _random.nextDouble(),
          y: 1.0,
          vx: (_random.nextDouble() - 0.5) * 0.02,
          vy: -_random.nextDouble() * 0.03 - 0.01,
          size: _random.nextDouble() * 4 + 2,
          life: 1.0,
          color: Color.lerp(widget.primaryColor, widget.secondaryColor, _random.nextDouble())!,
        ));
      }
    }

    // Update existing particles
    setState(() {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.life -= 0.02;
      }
      _particles.removeWhere((p) => p.life <= 0 || p.y < 0);
    });
  }

  @override
  void didUpdateWidget(_ParticleVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: CustomPaint(
        painter: _ParticlePainter(particles: _particles),
        size: Size(widget.width ?? double.infinity, widget.height),
      ),
    );
  }
}

class _Particle {
  double x, y, vx, vy, size, life;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha:p.life * 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * p.life,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

/// Blob visualizer with morphing shape
class _BlobVisualizer extends StatefulWidget {
  final List<double> data;
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isPlaying;
  final Widget? child;

  const _BlobVisualizer({
    required this.data,
    required this.size,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isPlaying,
    this.child,
  });

  @override
  State<_BlobVisualizer> createState() => _BlobVisualizerState();
}

class _BlobVisualizerState extends State<_BlobVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_BlobVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _BlobPainter(
                  data: widget.data,
                  primaryColor: widget.primaryColor,
                  secondaryColor: widget.secondaryColor,
                  phase: _controller.value,
                  isPlaying: widget.isPlaying,
                ),
              );
            },
          ),
          if (widget.child != null)
            SizedBox(
              width: widget.size * 0.6,
              height: widget.size * 0.6,
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final List<double> data;
  final Color primaryColor;
  final Color secondaryColor;
  final double phase;
  final bool isPlaying;

  _BlobPainter({
    required this.data,
    required this.primaryColor,
    required this.secondaryColor,
    required this.phase,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.35;

    final intensity = data.isEmpty ? 0.5 : data.reduce((a, b) => a + b) / data.length;

    final path = Path();
    const points = 60;

    for (int i = 0; i <= points; i++) {
      final angle = (2 * math.pi / points) * i;
      final dataIndex = (i * data.length ~/ points).clamp(0, data.length - 1);
      final dataValue = data.isEmpty ? 0.5 : data[dataIndex];

      final noise = math.sin(angle * 3 + phase * 2 * math.pi) * 0.1;
      final radius = baseRadius * (1 + dataValue * 0.3 + noise * (isPlaying ? 1 : 0.3));

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha:0.6 + intensity * 0.4),
          secondaryColor.withValues(alpha:0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.5));

    if (isPlaying) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + intensity * 10);
    }

    canvas.drawPath(path, paint);

    // Inner glow
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = primaryColor.withValues(alpha:0.8);

    canvas.drawPath(path, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => true;
}
