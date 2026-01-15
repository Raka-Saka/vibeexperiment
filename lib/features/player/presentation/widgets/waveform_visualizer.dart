import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class WaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final Color? primaryColor;
  final Color? secondaryColor;

  const WaveformVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 32,
    this.height = 120,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _barHeights;
  late List<double> _targetHeights;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(widget.barCount, (_) => 0.2);
    _targetHeights = List.generate(widget.barCount, (_) => 0.2);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateBars);

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  void _updateBars() {
    if (!mounted) return;

    setState(() {
      for (int i = 0; i < widget.barCount; i++) {
        // Smoothly interpolate towards target
        _barHeights[i] += (_targetHeights[i] - _barHeights[i]) * 0.3;

        // Generate new targets periodically
        if (_random.nextDouble() > 0.7) {
          _targetHeights[i] = widget.isPlaying
              ? 0.2 + _random.nextDouble() * 0.8
              : 0.1 + _random.nextDouble() * 0.1;
        }
      }
    });
  }

  @override
  void didUpdateWidget(WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        // Animate bars to low state
        setState(() {
          for (int i = 0; i < widget.barCount; i++) {
            _targetHeights[i] = 0.1 + _random.nextDouble() * 0.1;
          }
        });
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
    final primaryColor = widget.primaryColor ?? AppTheme.primaryColor;
    final secondaryColor = widget.secondaryColor ?? AppTheme.secondaryColor;

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (index) {
          final normalizedIndex = index / widget.barCount;
          final color = Color.lerp(primaryColor, secondaryColor, normalizedIndex)!;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            width: 4,
            height: widget.height * _barHeights[index],
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
              boxShadow: widget.isPlaying
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

// Circular waveform for the now playing screen
class CircularWaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final Widget? child;
  final Color? color;

  const CircularWaveformVisualizer({
    super.key,
    required this.isPlaying,
    this.size = 280,
    this.child,
    this.color,
  });

  @override
  State<CircularWaveformVisualizer> createState() => _CircularWaveformVisualizerState();
}

class _CircularWaveformVisualizerState extends State<CircularWaveformVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _rotationController;
  late List<double> _amplitudes;
  final Random _random = Random();
  static const int barCount = 60;

  @override
  void initState() {
    super.initState();
    _amplitudes = List.generate(barCount, (_) => 0.3);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..addListener(_updateAmplitudes);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );

    if (widget.isPlaying) {
      _controller.repeat();
      _rotationController.repeat();
    }
  }

  void _updateAmplitudes() {
    if (!mounted) return;

    setState(() {
      for (int i = 0; i < barCount; i++) {
        if (_random.nextDouble() > 0.6) {
          final target = widget.isPlaying
              ? 0.3 + _random.nextDouble() * 0.7
              : 0.2 + _random.nextDouble() * 0.1;
          _amplitudes[i] += (target - _amplitudes[i]) * 0.4;
        }
      }
    });
  }

  @override
  void didUpdateWidget(CircularWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
        _rotationController.repeat();
      } else {
        _controller.stop();
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
          // Waveform ring
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * pi,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _CircularWaveformPainter(
                    amplitudes: _amplitudes,
                    color: widget.color ?? AppTheme.primaryColor,
                    isPlaying: widget.isPlaying,
                  ),
                ),
              );
            },
          ),
          // Child (album art)
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

class _CircularWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final bool isPlaying;

  _CircularWaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final innerRadius = size.width * 0.36;
    final maxBarHeight = size.width * 0.12;

    for (int i = 0; i < amplitudes.length; i++) {
      final angle = (2 * pi / amplitudes.length) * i - pi / 2;
      final barHeight = maxBarHeight * amplitudes[i];

      final startX = center.dx + innerRadius * cos(angle);
      final startY = center.dy + innerRadius * sin(angle);
      final endX = center.dx + (innerRadius + barHeight) * cos(angle);
      final endY = center.dy + (innerRadius + barHeight) * sin(angle);

      final paint = Paint()
        ..color = color.withValues(alpha:0.5 + amplitudes[i] * 0.5)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      if (isPlaying) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      }

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularWaveformPainter oldDelegate) {
    return true;
  }
}
