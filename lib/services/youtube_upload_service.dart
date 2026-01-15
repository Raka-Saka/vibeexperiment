import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart' as yt;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../shared/models/song.dart';
import '../config/secrets.dart';
import '../config/app_config.dart';
import 'log_service.dart';

// YouTube configuration - pulls from secure config
class YouTubeConfig {
  static String get clientId => Secrets.youtubeClientId;
  static String get channelName => Secrets.youtubeChannelName;
  static String get defaultPrivacy => AppConfig.defaultYouTubePrivacy;
}

class UploadProgress {
  final double progress;
  final String status;
  final bool isComplete;
  final bool hasError;
  final String? videoId;
  final String? errorMessage;

  const UploadProgress({
    this.progress = 0.0,
    this.status = 'Preparing...',
    this.isComplete = false,
    this.hasError = false,
    this.videoId,
    this.errorMessage,
  });

  UploadProgress copyWith({
    double? progress,
    String? status,
    bool? isComplete,
    bool? hasError,
    String? videoId,
    String? errorMessage,
  }) {
    return UploadProgress(
      progress: progress ?? this.progress,
      status: status ?? this.status,
      isComplete: isComplete ?? this.isComplete,
      hasError: hasError ?? this.hasError,
      videoId: videoId ?? this.videoId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class YouTubeUploadService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      yt.YouTubeApi.youtubeUploadScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  http.Client? _authClient;
  yt.YouTubeApi? _youtubeApi;

  // Check if authenticated
  bool get isAuthenticated => _currentUser != null && _authClient != null;

  // Authenticate with Google/YouTube
  Future<bool> authenticate() async {
    try {
      // Try silent sign in first
      _currentUser = await _googleSignIn.signInSilently();

      // If not signed in, prompt user
      if (_currentUser == null) {
        _currentUser = await _googleSignIn.signIn();
      }

      if (_currentUser == null) {
        Log.i('User cancelled sign in');
        return false;
      }

      // Get authenticated HTTP client
      _authClient = await _googleSignIn.authenticatedClient();

      if (_authClient == null) {
        Log.i('Failed to get authenticated client');
        return false;
      }

      _youtubeApi = yt.YouTubeApi(_authClient!);
      Log.i('YouTube API initialized successfully');
      return true;
    } catch (e) {
      Log.i('YouTube auth error: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _authClient = null;
    _youtubeApi = null;
  }

  static const _videoChannel = MethodChannel('com.vibeplay/video_generator');

  // Generate waveform video from audio
  Future<String?> generateWaveformVideo(
    Song song,
    void Function(double progress, String status) onProgress,
  ) async {
    try {
      onProgress(0.1, 'Checking audio file...');

      // Validate song path
      if (song.path == null || song.path!.isEmpty) {
        throw Exception('Song path is missing');
      }

      // Check if audio file exists
      final audioFile = File(song.path!);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found at: ${song.path}');
      }

      onProgress(0.2, 'Generating waveform video...');

      // Get temp directory for output
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/vibeplay_${song.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      onProgress(0.3, 'Creating video with waveform...');

      // Call native video generator
      try {
        final success = await _videoChannel.invokeMethod<bool>('generateVideo', {
          'audioPath': song.path,
          'outputPath': outputPath,
          'title': song.title,
          'artist': YouTubeConfig.channelName,
        });

        if (success == true && await File(outputPath).exists()) {
          final fileSize = await File(outputPath).length();
          Log.i('Video generated successfully: $outputPath (${fileSize} bytes)');
          onProgress(1.0, 'Video ready!');
          return outputPath;
        } else {
          throw Exception('Video generation returned false or file not created');
        }
      } on PlatformException catch (e) {
        Log.i('Platform error during video generation: ${e.code} - ${e.message}');
        throw Exception('Video generation failed: ${e.message}');
      }
    } catch (e) {
      Log.i('Video generation error: $e');
      rethrow;
    }
  }

  // Upload to YouTube
  Future<String?> uploadToYouTube(
    Song song,
    String videoPath,
    String privacy,
    void Function(double progress, String status) onProgress,
  ) async {
    if (_youtubeApi == null) {
      throw Exception('YouTube API not initialized');
    }

    try {
      onProgress(0.0, 'Preparing upload...');

      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        throw Exception('Video file not found at: $videoPath');
      }

      // Create video metadata
      final video = yt.Video();
      video.snippet = yt.VideoSnippet()
        ..title = song.title
        ..description = '''${song.title}
Artist: ${YouTubeConfig.channelName}
${song.album != null ? 'Album: ${song.album}' : ''}

Uploaded with VibePlay'''
        ..tags = ['music', 'audio', YouTubeConfig.channelName, song.title]
        ..categoryId = '10'; // Music category

      video.status = yt.VideoStatus()
        ..privacyStatus = privacy
        ..selfDeclaredMadeForKids = false;

      onProgress(0.2, 'Uploading to YouTube...');

      // Upload the generated video file
      final fileLength = await videoFile.length();
      final media = yt.Media(
        videoFile.openRead(),
        fileLength,
      );

      onProgress(0.5, 'Uploading... This may take a while');

      final response = await _youtubeApi!.videos.insert(
        video,
        ['snippet', 'status'],
        uploadMedia: media,
      );

      onProgress(1.0, 'Upload complete!');

      // Clean up temp video file
      try {
        await videoFile.delete();
      } catch (e) {
        Log.i('Failed to delete temp video: $e');
      }

      return response.id;
    } catch (e) {
      Log.i('YouTube upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }

  // Full upload flow
  Stream<UploadProgress> uploadSong(Song song, {String privacy = 'public'}) async* {
    try {
      // Validate song first
      if (song.path == null || song.path!.isEmpty) {
        yield const UploadProgress(
          hasError: true,
          errorMessage: 'Cannot upload: Song has no file path',
        );
        return;
      }

      yield const UploadProgress(
        progress: 0.0,
        status: 'Starting...',
      );

      // Check authentication
      if (!isAuthenticated) {
        yield const UploadProgress(
          progress: 0.05,
          status: 'Signing in to Google...',
        );

        try {
          final authenticated = await authenticate();
          if (!authenticated) {
            yield const UploadProgress(
              hasError: true,
              errorMessage: 'Sign in was cancelled or failed. Please try again.',
            );
            return;
          }
        } catch (e) {
          String errorMsg = e.toString();
          // Provide helpful error for common issues
          if (errorMsg.contains('PlatformException') || errorMsg.contains('sign_in_failed')) {
            errorMsg = 'Google Sign-In failed. Please ensure:\n'
                '1. You have internet connection\n'
                '2. Google Play Services is installed\n'
                '3. The app is properly configured';
          }
          yield UploadProgress(
            hasError: true,
            errorMessage: errorMsg,
          );
          return;
        }
      }

      yield const UploadProgress(
        progress: 0.1,
        status: 'Generating waveform video...',
      );

      // Generate video with waveform
      String? videoPath;
      try {
        videoPath = await generateWaveformVideo(song, (progress, status) {
          Log.i('Video generation: $progress - $status');
        });
      } catch (e) {
        yield UploadProgress(
          hasError: true,
          errorMessage: 'Video generation failed: ${e.toString().replaceAll('Exception: ', '')}',
        );
        return;
      }

      if (videoPath == null) {
        yield const UploadProgress(
          hasError: true,
          errorMessage: 'Failed to generate video. The audio file may be corrupted or unsupported.',
        );
        return;
      }

      // Verify video was created
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        yield const UploadProgress(
          hasError: true,
          errorMessage: 'Video file was not created. Please try again.',
        );
        return;
      }

      final videoSize = await videoFile.length();
      Log.i('Generated video size: ${(videoSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Upload to YouTube
      yield UploadProgress(
        progress: 0.5,
        status: 'Uploading to YouTube (${(videoSize / 1024 / 1024).toStringAsFixed(1)} MB)...',
      );

      try {
        final videoId = await uploadToYouTube(song, videoPath, privacy, (progress, status) {
          Log.i('Upload: $progress - $status');
        });

        if (videoId != null) {
          yield UploadProgress(
            progress: 1.0,
            status: 'Upload complete!',
            isComplete: true,
            videoId: videoId,
          );
        } else {
          yield const UploadProgress(
            hasError: true,
            errorMessage: 'Upload completed but no video ID was returned',
          );
        }
      } catch (e) {
        // Clean up video file on error
        try {
          await videoFile.delete();
        } catch (_) {}

        String errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('quotaExceeded')) {
          errorMsg = 'YouTube API quota exceeded. Please try again tomorrow.';
        } else if (errorMsg.contains('forbidden') || errorMsg.contains('403')) {
          errorMsg = 'Upload not allowed. Please check your YouTube account permissions.';
        }
        yield UploadProgress(
          hasError: true,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      yield UploadProgress(
        hasError: true,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void dispose() {
    _authClient?.close();
  }
}

// Provider
final youtubeUploadServiceProvider = Provider<YouTubeUploadService>((ref) {
  final service = YouTubeUploadService();
  ref.onDispose(() => service.dispose());
  return service;
});
