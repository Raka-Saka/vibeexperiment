import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ArtworkPicker extends StatelessWidget {
  final Uint8List? artwork;
  final VoidCallback onPickFromFile;
  final VoidCallback? onRemove;

  const ArtworkPicker({
    super.key,
    this.artwork,
    required this.onPickFromFile,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Artwork preview
        GestureDetector(
          onTap: onPickFromFile,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.textMuted.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: artwork != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      artwork!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    ),
                  )
                : _buildPlaceholder(),
          ),
        ),
        const SizedBox(width: 16),
        // Actions
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: onPickFromFile,
                icon: const Icon(Icons.folder_rounded, size: 18),
                label: const Text('Choose Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Tap artwork or button to change',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 4),
          Text(
            'No artwork',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
