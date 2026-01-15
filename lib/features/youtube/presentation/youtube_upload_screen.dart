import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/song.dart';
import '../../../services/youtube_upload_service.dart';

class YouTubeUploadScreen extends ConsumerStatefulWidget {
  final Song song;

  const YouTubeUploadScreen({super.key, required this.song});

  @override
  ConsumerState<YouTubeUploadScreen> createState() => _YouTubeUploadScreenState();
}

class _YouTubeUploadScreenState extends ConsumerState<YouTubeUploadScreen> {
  bool _isUploading = false;
  UploadProgress? _progress;
  final _titleController = TextEditingController();
  String _privacy = 'public';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.song.title;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload to YouTube'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkSurface,
              AppTheme.darkBackground,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // YouTube branding
              _buildYouTubeHeader().animate().fadeIn().slideY(begin: -0.2),

              const SizedBox(height: 32),

              // Song preview
              _buildSongPreview().animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),

              const SizedBox(height: 32),

              // Upload settings
              if (!_isUploading) ...[
                _buildUploadSettings().animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 32),

                // Upload button
                _buildUploadButton().animate().fadeIn(delay: 300.ms).scale(),
              ],

              // Progress indicator
              if (_isUploading) _buildProgressIndicator(),

              // Success/Error message
              if (_progress?.isComplete == true) _buildSuccessMessage(),
              if (_progress?.hasError == true) _buildErrorMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha:0.2),
            Colors.red.withValues(alpha:0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YouTube Upload',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload as: ${YouTubeConfig.channelName}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Waveform preview
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha:0.3),
                  AppTheme.secondaryColor.withValues(alpha:0.3),
                ],
              ),
            ),
            child: CustomPaint(
              painter: _WaveformPreviewPainter(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.song.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${widget.song.durationFormatted}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Waveform video will be generated',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Title
        TextField(
          controller: _titleController,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Video Title',
            labelStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.title_rounded, color: AppTheme.textMuted),
          ),
        ),

        const SizedBox(height: 16),

        // Privacy setting
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Privacy',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPrivacyOption('public', 'Public', Icons.public_rounded),
                  const SizedBox(width: 8),
                  _buildPrivacyOption('unlisted', 'Unlisted', Icons.link_rounded),
                  const SizedBox(width: 8),
                  _buildPrivacyOption('private', 'Private', Icons.lock_rounded),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Artist info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    children: [
                      const TextSpan(text: 'This video will be uploaded with '),
                      TextSpan(
                        text: '"${YouTubeConfig.channelName}"',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' as the artist.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyOption(String value, String label, IconData icon) {
    final isSelected = _privacy == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _privacy = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                    ],
                  )
                : null,
            color: isSelected ? null : AppTheme.darkSurface,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textMuted,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startUpload,
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text('Upload to YouTube'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Share option as alternative
        TextButton.icon(
          onPressed: _shareAudioFile,
          icon: const Icon(Icons.share_rounded, size: 18),
          label: const Text('Or share audio file'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  void _shareAudioFile() async {
    final file = File(widget.song.path!);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(widget.song.path!)],
        text: '${widget.song.title} by ${YouTubeConfig.channelName}',
      );
    }
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progress?.progress,
                      strokeWidth: 8,
                      backgroundColor: AppTheme.darkSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.red,
                      ),
                    ),
                    Text(
                      '${((_progress?.progress ?? 0) * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _progress?.status ?? 'Uploading...',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ).animate().fadeIn().scale(),
      ],
    );
  }

  Widget _buildSuccessMessage() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withValues(alpha:0.3)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload Complete!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your video is now ${_privacy == 'public' ? 'live' : 'available'} on YouTube',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openVideo(_progress?.videoId),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('View Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.done_rounded),
                    label: const Text('Done'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().scale(),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha:0.3)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_rounded,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _progress?.errorMessage ?? 'An error occurred',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _startUpload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ).animate().fadeIn().shake(),
      ],
    );
  }

  void _startUpload() async {
    setState(() {
      _isUploading = true;
      _progress = const UploadProgress();
    });

    final service = ref.read(youtubeUploadServiceProvider);

    await for (final progress in service.uploadSong(widget.song, privacy: _privacy)) {
      if (mounted) {
        setState(() => _progress = progress);

        if (progress.isComplete || progress.hasError) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  void _openVideo(String? videoId) async {
    if (videoId == null) return;

    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

// Waveform preview painter
class _WaveformPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color(0xFF6366f1),
          Color(0xFFa855f7),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final random = [0.3, 0.7, 0.5, 0.9, 0.4, 0.8, 0.6, 0.85, 0.45, 0.75];
    final barWidth = size.width / random.length * 0.7;
    final spacing = size.width / random.length * 0.3;

    for (int i = 0; i < random.length; i++) {
      final barHeight = size.height * random[i] * 0.8;
      final x = i * (barWidth + spacing) + spacing / 2;
      final y = (size.height - barHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
