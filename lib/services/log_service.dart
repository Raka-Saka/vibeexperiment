import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized logging service for VibePlay
///
/// Usage:
///   Log.d('Debug message');
///   Log.i('Info message');
///   Log.w('Warning message');
///   Log.e('Error message', error, stackTrace);
///
/// Tagged logging:
///   Log.audio.d('Audio-specific debug');
///   Log.eq.i('Equalizer info');
class Log {
  static late final Logger _logger;
  static late final Logger _audioLogger;
  static late final Logger _eqLogger;
  static late final Logger _uiLogger;
  static late final Logger _storageLogger;

  static bool _initialized = false;
  static File? _logFile;

  /// Initialize the logging system
  static Future<void> init() async {
    if (_initialized) return;

    // Configure output based on build mode
    final output = kDebugMode
        ? ConsoleOutput()
        : MultiOutput([ConsoleOutput(), await _createFileOutput()]);

    // Main logger
    _logger = Logger(
      printer: _VibeLogPrinter('VibePlay'),
      output: output,
      level: kDebugMode ? Level.debug : Level.info,
    );

    // Tagged loggers for different subsystems
    _audioLogger = Logger(
      printer: _VibeLogPrinter('Audio'),
      output: output,
      level: kDebugMode ? Level.debug : Level.info,
    );

    _eqLogger = Logger(
      printer: _VibeLogPrinter('EQ'),
      output: output,
      level: kDebugMode ? Level.debug : Level.info,
    );

    _uiLogger = Logger(
      printer: _VibeLogPrinter('UI'),
      output: output,
      level: kDebugMode ? Level.debug : Level.warning,
    );

    _storageLogger = Logger(
      printer: _VibeLogPrinter('Storage'),
      output: output,
      level: kDebugMode ? Level.debug : Level.info,
    );

    _initialized = true;
    _logger.i('Logging initialized');
  }

  static Future<LogOutput> _createFileOutput() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Rotate logs - keep last 5
      await _rotateLogs(logDir);

      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      _logFile = File('${logDir.path}/vibeplay_$timestamp.log');

      return FileOutput(file: _logFile!);
    } catch (e) {
      // Fall back to console only if file output fails
      return ConsoleOutput();
    }
  }

  static Future<void> _rotateLogs(Directory logDir) async {
    try {
      final files = await logDir.list().where((f) => f.path.endsWith('.log')).toList();
      if (files.length > 5) {
        files.sort((a, b) => a.path.compareTo(b.path));
        for (var i = 0; i < files.length - 5; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      // Ignore rotation errors
    }
  }

  /// Get the current log file path (for sharing crash logs)
  static String? get logFilePath => _logFile?.path;

  // Main logger methods
  static void d(String message) => _logger.d(message);
  static void i(String message) => _logger.i(message);
  static void w(String message) => _logger.w(message);
  static void e(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  // Tagged loggers
  static _TaggedLog get audio => _TaggedLog(_audioLogger);
  static _TaggedLog get eq => _TaggedLog(_eqLogger);
  static _TaggedLog get ui => _TaggedLog(_uiLogger);
  static _TaggedLog get storage => _TaggedLog(_storageLogger);
}

/// Helper class for tagged logging
class _TaggedLog {
  final Logger _logger;
  _TaggedLog(this._logger);

  void d(String message) => _logger.d(message);
  void i(String message) => _logger.i(message);
  void w(String message) => _logger.w(message);
  void e(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}

/// Custom log printer for VibePlay
class _VibeLogPrinter extends LogPrinter {
  final String tag;

  _VibeLogPrinter(this.tag);

  @override
  List<String> log(LogEvent event) {
    final emoji = _getEmoji(event.level);
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final message = event.message;

    final output = <String>['$emoji [$timestamp] [$tag] $message'];

    if (event.error != null) {
      output.add('  Error: ${event.error}');
    }
    if (event.stackTrace != null) {
      output.add('  Stack: ${event.stackTrace.toString().split('\n').take(5).join('\n         ')}');
    }

    return output;
  }

  String _getEmoji(Level level) {
    return switch (level) {
      Level.trace => '🔍',
      Level.debug => '🐛',
      Level.info => '💡',
      Level.warning => '⚠️',
      Level.error => '❌',
      Level.fatal => '💀',
      _ => '📝',
    };
  }
}

/// File output for logger
class FileOutput extends LogOutput {
  final File file;
  IOSink? _sink;

  FileOutput({required this.file});

  @override
  Future<void> init() async {
    _sink = file.openWrite(mode: FileMode.append);
  }

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      _sink?.writeln(line);
    }
  }

  @override
  Future<void> destroy() async {
    await _sink?.close();
  }
}
