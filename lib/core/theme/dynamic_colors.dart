import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class DynamicColors {
  Color primary;
  Color secondary;
  Color background;
  Color textColor;

  DynamicColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.textColor,
  });

  // Default colors when no image is available
  factory DynamicColors.defaultColors() {
    return DynamicColors(
      primary: const Color(0xFF6366F1),
      secondary: const Color(0xFFEC4899),
      background: const Color(0xFF0F0F1A),
      textColor: Colors.white,
    );
  }

  // Extract colors from image bytes
  static Future<DynamicColors> fromImageBytes(Uint8List bytes) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        MemoryImage(bytes),
        size: const Size(100, 100),
        maximumColorCount: 16,
      );

      final vibrant = paletteGenerator.vibrantColor?.color;
      final darkVibrant = paletteGenerator.darkVibrantColor?.color;
      final dominant = paletteGenerator.dominantColor?.color;
      final muted = paletteGenerator.mutedColor?.color;

      return DynamicColors(
        primary: vibrant ?? dominant ?? const Color(0xFF6366F1),
        secondary: darkVibrant ?? muted ?? const Color(0xFFEC4899),
        background: _darken(dominant ?? const Color(0xFF0F0F1A), 0.7),
        textColor: _getContrastColor(vibrant ?? dominant ?? Colors.white),
      );
    } catch (e) {
      return DynamicColors.defaultColors();
    }
  }

  // Extract colors from ImageProvider
  static Future<DynamicColors> fromImageProvider(ImageProvider imageProvider) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100),
        maximumColorCount: 16,
      );

      final vibrant = paletteGenerator.vibrantColor?.color;
      final darkVibrant = paletteGenerator.darkVibrantColor?.color;
      final dominant = paletteGenerator.dominantColor?.color;
      final muted = paletteGenerator.mutedColor?.color;

      return DynamicColors(
        primary: vibrant ?? dominant ?? const Color(0xFF6366F1),
        secondary: darkVibrant ?? muted ?? const Color(0xFFEC4899),
        background: _darken(dominant ?? const Color(0xFF0F0F1A), 0.7),
        textColor: _getContrastColor(vibrant ?? dominant ?? Colors.white),
      );
    } catch (e) {
      return DynamicColors.defaultColors();
    }
  }

  // Darken a color by a factor
  static Color _darken(Color color, double factor) {
    // Use new Color API (.a, .r, .g, .b return doubles 0.0-1.0)
    return Color.fromARGB(
      (color.a * 255).round(),
      ((color.r * 255) * (1 - factor)).round(),
      ((color.g * 255) * (1 - factor)).round(),
      ((color.b * 255) * (1 - factor)).round(),
    );
  }

  // Get contrasting text color
  static Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Generate animated gradient
  LinearGradient get gradient {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primary.withValues(alpha: 0.8),
        secondary.withValues(alpha: 0.4),
        background,
      ],
      stops: const [0.0, 0.4, 1.0],
    );
  }

  // Glassmorphism overlay color
  Color get glassColor => Colors.white.withValues(alpha: 0.1);
}
