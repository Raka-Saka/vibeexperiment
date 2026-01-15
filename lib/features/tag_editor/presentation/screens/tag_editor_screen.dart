import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/song.dart';
import '../../data/tag_editor_provider.dart';
import '../widgets/artwork_picker.dart';
import '../widgets/genre_picker.dart';
import '../widgets/lyrics_editor.dart';

class TagEditorScreen extends ConsumerStatefulWidget {
  final Song song;

  const TagEditorScreen({super.key, required this.song});

  @override
  ConsumerState<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends ConsumerState<TagEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _albumArtistController;
  late TextEditingController _genreController;
  late TextEditingController _yearController;
  late TextEditingController _trackController;
  late TextEditingController _totalTracksController;
  late TextEditingController _discController;
  late TextEditingController _totalDiscsController;
  late TextEditingController _composerController;
  late TextEditingController _bpmController;
  late TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _initControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tagEditorProvider.notifier).startEditing(widget.song);
    });
  }

  void _initControllers() {
    _titleController = TextEditingController();
    _artistController = TextEditingController();
    _albumController = TextEditingController();
    _albumArtistController = TextEditingController();
    _genreController = TextEditingController();
    _yearController = TextEditingController();
    _trackController = TextEditingController();
    _totalTracksController = TextEditingController();
    _discController = TextEditingController();
    _totalDiscsController = TextEditingController();
    _composerController = TextEditingController();
    _bpmController = TextEditingController();
    _commentController = TextEditingController();
  }

  void _updateControllers(TagEditorState state) {
    final tags = state.currentTags;
    _titleController.text = tags.title ?? '';
    _artistController.text = tags.artist ?? '';
    _albumController.text = tags.album ?? '';
    _albumArtistController.text = tags.albumArtist ?? '';
    _genreController.text = tags.genre ?? '';
    _yearController.text = tags.year?.toString() ?? '';
    _trackController.text = tags.trackNumber?.toString() ?? '';
    _totalTracksController.text = tags.totalTracks?.toString() ?? '';
    _discController.text = tags.discNumber?.toString() ?? '';
    _totalDiscsController.text = tags.totalDiscs?.toString() ?? '';
    _composerController.text = tags.composer ?? '';
    _bpmController.text = tags.bpm?.toString() ?? '';
    _commentController.text = tags.comment ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _albumArtistController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _trackController.dispose();
    _totalTracksController.dispose();
    _discController.dispose();
    _totalDiscsController.dispose();
    _composerController.dispose();
    _bpmController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(tagEditorProvider);
    if (state?.hasChanges ?? false) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Discard changes?'),
          content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  Future<void> _save() async {
    final notifier = ref.read(tagEditorProvider.notifier);
    final success = await notifier.saveChanges();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tags saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tagEditorProvider);

    // Update controllers when state loads
    ref.listen(tagEditorProvider, (previous, next) {
      if (previous?.isLoading == true && next?.isLoading == false && next != null) {
        _updateControllers(next);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          ref.read(tagEditorProvider.notifier).stopEditing();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Tags'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                ref.read(tagEditorProvider.notifier).stopEditing();
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (state?.hasChanges ?? false)
              TextButton(
                onPressed: () {
                  ref.read(tagEditorProvider.notifier).resetChanges();
                  if (state != null) _updateControllers(state);
                },
                child: const Text('Reset'),
              ),
            TextButton.icon(
              onPressed: state?.isSaving == true || !(state?.hasChanges ?? false)
                  ? null
                  : _save,
              icon: state?.isSaving == true
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save'),
            ),
          ],
        ),
        body: state == null || state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && !state.hasChanges
                ? _buildErrorState(state.error!)
                : _buildForm(state),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(TagEditorState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error banner
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.error!, style: const TextStyle(color: Colors.red))),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => ref.read(tagEditorProvider.notifier).clearError(),
                      ),
                    ],
                  ),
                  if (state.error!.contains('permission') || state.error!.contains('Permission'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton.icon(
                        onPressed: () => ref.read(tagEditorProvider.notifier).openSettings(),
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Open Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Artwork section
          _buildSection(
            'Artwork',
            ArtworkPicker(
              artwork: state.currentTags.artwork,
              onPickFromFile: () => ref.read(tagEditorProvider.notifier).pickArtworkFromFile(),
              onRemove: state.currentTags.artwork != null
                  ? () => ref.read(tagEditorProvider.notifier).removeArtwork()
                  : null,
            ),
          ),

          const SizedBox(height: 24),

          // Basic Info
          _buildSection('Basic Info', Column(
            children: [
              _buildTextField(
                controller: _titleController,
                label: 'Title',
                onChanged: ref.read(tagEditorProvider.notifier).updateTitle,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _artistController,
                label: 'Artist',
                onChanged: ref.read(tagEditorProvider.notifier).updateArtist,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _albumController,
                label: 'Album',
                onChanged: ref.read(tagEditorProvider.notifier).updateAlbum,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _albumArtistController,
                label: 'Album Artist',
                onChanged: ref.read(tagEditorProvider.notifier).updateAlbumArtist,
              ),
            ],
          )),

          const SizedBox(height: 24),

          // Details
          _buildSection('Details', Column(
            children: [
              GenrePicker(
                controller: _genreController,
                onChanged: ref.read(tagEditorProvider.notifier).updateGenre,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _yearController,
                label: 'Year',
                keyboardType: TextInputType.number,
                onChanged: ref.read(tagEditorProvider.notifier).updateYear,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _trackController,
                      label: 'Track #',
                      keyboardType: TextInputType.number,
                      onChanged: ref.read(tagEditorProvider.notifier).updateTrackNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _totalTracksController,
                      label: 'of',
                      keyboardType: TextInputType.number,
                      onChanged: ref.read(tagEditorProvider.notifier).updateTotalTracks,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _discController,
                      label: 'Disc #',
                      keyboardType: TextInputType.number,
                      onChanged: ref.read(tagEditorProvider.notifier).updateDiscNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _totalDiscsController,
                      label: 'of',
                      keyboardType: TextInputType.number,
                      onChanged: ref.read(tagEditorProvider.notifier).updateTotalDiscs,
                    ),
                  ),
                ],
              ),
            ],
          )),

          const SizedBox(height: 24),

          // Additional
          _buildSection('Additional', Column(
            children: [
              _buildTextField(
                controller: _composerController,
                label: 'Composer',
                onChanged: ref.read(tagEditorProvider.notifier).updateComposer,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _bpmController,
                label: 'BPM',
                keyboardType: TextInputType.number,
                onChanged: ref.read(tagEditorProvider.notifier).updateBpm,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _commentController,
                label: 'Comment',
                maxLines: 3,
                onChanged: ref.read(tagEditorProvider.notifier).updateComment,
              ),
            ],
          )),

          const SizedBox(height: 24),

          // Lyrics
          _buildSection('Lyrics', Column(
            children: [
              LyricsEditor(
                lyrics: state.currentTags.lyrics,
                onChanged: ref.read(tagEditorProvider.notifier).updateLyrics,
              ),
            ],
          )),

          const SizedBox(height: 32),

          // File info (read-only)
          _buildSection('File Info', Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Format', widget.song.fileExtension?.toUpperCase() ?? 'Unknown'),
              _buildInfoRow('Duration', widget.song.durationFormatted),
              if (widget.song.size != null)
                _buildInfoRow('Size', _formatFileSize(widget.song.size!)),
              _buildInfoRow('Path', widget.song.path ?? 'Unknown', selectable: true),
            ],
          )),

          const SizedBox(height: 24),

          // Cleanup actions
          _buildSection('Cleanup', Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: state.isSaving
                      ? null
                      : () async {
                          final success = await ref.read(tagEditorProvider.notifier).removeUrls();
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('URL frames removed'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Remove URL Tags'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.textMuted),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          )),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildInfoRow(String label, String value, {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(
                    value,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  )
                : Text(
                    value,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
