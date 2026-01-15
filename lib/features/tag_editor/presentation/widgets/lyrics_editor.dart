import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LyricsEditor extends StatelessWidget {
  final String? lyrics;
  final Function(String) onChanged;

  const LyricsEditor({
    super.key,
    this.lyrics,
    required this.onChanged,
  });

  void _openFullEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LyricsEditorScreen(
          initialLyrics: lyrics ?? '',
          onSave: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLyrics = lyrics != null && lyrics!.isNotEmpty;
    final previewLines = hasLyrics
        ? lyrics!.split('\n').take(3).join('\n')
        : 'No lyrics';

    return GestureDetector(
      onTap: () => _openFullEditor(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLyrics ? 'Lyrics' : 'No lyrics',
                    style: TextStyle(
                      color: hasLyrics ? AppTheme.textPrimary : AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hasLyrics) ...[
                    const SizedBox(height: 8),
                    Text(
                      previewLines,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lyrics!.split('\n').length > 3)
                      Text(
                        '...',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.edit_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsEditorScreen extends StatefulWidget {
  final String initialLyrics;
  final Function(String) onSave;

  const _LyricsEditorScreen({
    required this.initialLyrics,
    required this.onSave,
  });

  @override
  State<_LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends State<_LyricsEditorScreen> {
  late TextEditingController _controller;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLyrics);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasChanges = _controller.text != widget.initialLyrics;
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_controller.text);
    Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes to the lyrics.'),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Lyrics'),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: () {
                  _controller.text = widget.initialLyrics;
                },
                child: const Text('Reset'),
              ),
            TextButton.icon(
              onPressed: _hasChanges ? _save : null,
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Paste or type lyrics here...',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.darkSurface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_controller.text.split('\n').length} lines',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              TextButton.icon(
                onPressed: () {
                  _controller.clear();
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
