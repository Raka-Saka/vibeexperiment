import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/song.dart';
import '../../data/batch_find_replace_provider.dart';

class BatchFindReplaceScreen extends ConsumerStatefulWidget {
  final List<Song> songs;

  const BatchFindReplaceScreen({super.key, required this.songs});

  @override
  ConsumerState<BatchFindReplaceScreen> createState() => _BatchFindReplaceScreenState();
}

class _BatchFindReplaceScreenState extends ConsumerState<BatchFindReplaceScreen> {
  late TextEditingController _findController;
  late TextEditingController _replaceController;

  @override
  void initState() {
    super.initState();
    _findController = TextEditingController();
    _replaceController = TextEditingController();
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchFindReplaceProvider(widget.songs));
    final notifier = ref.read(batchFindReplaceProvider(widget.songs).notifier);

    // Listen for success to pop screen
    ref.listen(batchFindReplaceProvider(widget.songs), (previous, next) {
      if (next.successMessage != null && previous?.successMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        notifier.clearSuccess();
        Navigator.pop(context, true);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find & Replace'),
        actions: [
          TextButton.icon(
            onPressed: state.matchCount == 0 || state.isApplying
                ? null
                : () => notifier.applyReplacements(),
            icon: state.isApplying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(state.isApplying
                ? '${state.appliedCount}/${state.totalToApply}'
                : 'Apply (${state.matchCount})'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search options
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.darkCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Field selector
                Row(
                  children: [
                    const Text(
                      'Field:',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: SearchField.values.map((field) {
                            final isSelected = state.searchField == field;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(field.label),
                                selected: isSelected,
                                onSelected: (_) => notifier.setSearchField(field),
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor: AppTheme.darkSurface,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Find field
                TextField(
                  controller: _findController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Find',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
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
                  ),
                  onChanged: notifier.setFindText,
                ),
                const SizedBox(height: 12),

                // Replace field
                TextField(
                  controller: _replaceController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Replace with',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.find_replace, color: AppTheme.textMuted),
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
                  ),
                  onChanged: notifier.setReplaceText,
                ),
                const SizedBox(height: 12),

                // Options
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Case sensitive'),
                      selected: state.caseSensitive,
                      onSelected: (_) => notifier.toggleCaseSensitive(),
                      selectedColor: AppTheme.primaryColor.withValues(alpha:0.3),
                      checkmarkColor: AppTheme.primaryColor,
                      backgroundColor: AppTheme.darkSurface,
                      labelStyle: TextStyle(
                        color: state.caseSensitive
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Whole word'),
                      selected: state.wholeWord,
                      onSelected: (_) => notifier.toggleWholeWord(),
                      selectedColor: AppTheme.primaryColor.withValues(alpha:0.3),
                      checkmarkColor: AppTheme.primaryColor,
                      backgroundColor: AppTheme.darkSurface,
                      labelStyle: TextStyle(
                        color: state.wholeWord
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Error banner
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.withValues(alpha:0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: notifier.clearError,
                      ),
                    ],
                  ),
                  if (state.error!.contains('permission') || state.error!.contains('Permission'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton.icon(
                        onPressed: notifier.openSettings,
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

          // Progress bar
          if (state.isApplying)
            LinearProgressIndicator(
              value: state.totalToApply > 0
                  ? state.appliedCount / state.totalToApply
                  : null,
              backgroundColor: AppTheme.darkSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),

          // Results header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  state.findText.isEmpty
                      ? '${widget.songs.length} songs'
                      : '${state.matchCount} matches in ${widget.songs.length} songs',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (state.matchCount > 0)
                  Text(
                    'Preview changes below',
                    style: TextStyle(
                      color: AppTheme.primaryColor.withValues(alpha:0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // Preview list
          Expanded(
            child: state.previews.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.find_replace,
                          size: 64,
                          color: AppTheme.textMuted.withValues(alpha:0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.findText.isEmpty
                              ? 'Enter text to find'
                              : 'No matches found',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: state.previews.length,
                    itemBuilder: (context, index) {
                      final preview = state.previews[index];
                      if (!preview.willChange) return const SizedBox.shrink();

                      return _buildPreviewTile(preview);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTile(SongReplacePreview preview) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Song title
          Text(
            preview.song.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Before -> After
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Before:',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        preview.originalValue ?? '(empty)',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'After:',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        preview.newValue ?? '(empty)',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
