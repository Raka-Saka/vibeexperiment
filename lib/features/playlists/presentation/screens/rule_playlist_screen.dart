import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/playlist_rule.dart';
import '../../../../services/rule_playlist_service.dart';
import '../../../library/data/media_scanner.dart';
import '../../../player/data/player_provider.dart';
import '../../../library/presentation/widgets/song_tile.dart';

/// Screen for viewing and managing rule-based playlists
class RulePlaylistsScreen extends ConsumerWidget {
  const RulePlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(rulePlaylistServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Playlists'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: playlists.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return _RulePlaylistTile(playlist: playlist)
                    .animate(delay: (50 * index).ms)
                    .fadeIn()
                    .slideX(begin: 0.1);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No Smart Playlists',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Create playlists that auto-update\nbased on rules you define',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateDialog(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Smart Playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RulePlaylistEditorScreen(),
      ),
    );
  }
}

class _RulePlaylistTile extends ConsumerWidget {
  final RuleBasedPlaylist playlist;

  const _RulePlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppTheme.darkCard,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.3),
                AppTheme.secondaryColor.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${playlist.rules.length} ${playlist.rules.length == 1 ? 'rule' : 'rules'} • ${playlist.logic == RuleLogic.and ? 'Match all' : 'Match any'}',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RulePlaylistEditorScreen(playlist: playlist),
                  ),
                );
                break;
              case 'delete':
                _confirmDelete(context, ref);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RulePlaylistDetailScreen(playlist: playlist),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Delete Playlist?'),
        content: Text('Are you sure you want to delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(rulePlaylistServiceProvider.notifier).deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Screen for creating/editing a rule-based playlist
class RulePlaylistEditorScreen extends ConsumerStatefulWidget {
  final RuleBasedPlaylist? playlist;

  const RulePlaylistEditorScreen({super.key, this.playlist});

  @override
  ConsumerState<RulePlaylistEditorScreen> createState() => _RulePlaylistEditorScreenState();
}

class _RulePlaylistEditorScreenState extends ConsumerState<RulePlaylistEditorScreen> {
  late TextEditingController _nameController;
  late List<PlaylistRule> _rules;
  late RuleLogic _logic;
  int? _maxSongs;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist?.name ?? '');
    _rules = widget.playlist?.rules.toList() ?? [];
    _logic = widget.playlist?.logic ?? RuleLogic.and;
    _maxSongs = widget.playlist?.maxSongs;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.playlist != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Smart Playlist' : 'New Smart Playlist'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          TextButton(
            onPressed: _canSave() ? _save : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _canSave() ? AppTheme.primaryColor : AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Playlist Name',
              filled: true,
              fillColor: AppTheme.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          // Logic selector
          Text(
            'Match Rules',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<RuleLogic>(
            segments: const [
              ButtonSegment(value: RuleLogic.and, label: Text('All (AND)')),
              ButtonSegment(value: RuleLogic.or, label: Text('Any (OR)')),
            ],
            selected: {_logic},
            onSelectionChanged: (selection) {
              setState(() => _logic = selection.first);
            },
          ),
          const SizedBox(height: 24),

          // Rules
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rules',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              TextButton.icon(
                onPressed: _addRule,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Rule'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_rules.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.rule_rounded, color: AppTheme.textMuted, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'No rules yet',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add rules to filter songs',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ..._rules.asMap().entries.map((entry) {
              final index = entry.key;
              final rule = entry.value;
              return _RuleEditor(
                rule: rule,
                onChanged: (newRule) {
                  setState(() => _rules[index] = newRule);
                },
                onDelete: () {
                  setState(() => _rules.removeAt(index));
                },
              );
            }),

          const SizedBox(height: 24),

          // Max songs limit
          Text(
            'Limit (Optional)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _maxSongs != null,
                onChanged: (checked) {
                  setState(() {
                    _maxSongs = checked == true ? 50 : null;
                  });
                },
              ),
              const Text('Limit to'),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  enabled: _maxSongs != null,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.darkCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  controller: TextEditingController(text: _maxSongs?.toString() ?? ''),
                  onChanged: (value) {
                    final num = int.tryParse(value);
                    if (num != null && num > 0) {
                      _maxSongs = num;
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('songs'),
            ],
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    return _nameController.text.trim().isNotEmpty && _rules.isNotEmpty;
  }

  void _addRule() {
    setState(() {
      _rules.add(const PlaylistRule(
        field: RuleField.genre,
        operator: RuleOperator.contains,
        value: '',
      ));
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _rules.isEmpty) return;

    final service = ref.read(rulePlaylistServiceProvider.notifier);

    if (widget.playlist != null) {
      await service.updatePlaylist(widget.playlist!.copyWith(
        name: name,
        rules: _rules,
        logic: _logic,
        maxSongs: _maxSongs,
      ));
    } else {
      await service.createPlaylist(
        name: name,
        rules: _rules,
        logic: _logic,
        maxSongs: _maxSongs,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

/// Widget for editing a single rule
class _RuleEditor extends StatefulWidget {
  final PlaylistRule rule;
  final ValueChanged<PlaylistRule> onChanged;
  final VoidCallback onDelete;

  const _RuleEditor({
    required this.rule,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late TextEditingController _valueController;
  late TextEditingController _value2Controller;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.rule.value);
    _value2Controller = TextEditingController(text: widget.rule.value2 ?? '');
  }

  @override
  void dispose() {
    _valueController.dispose();
    _value2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validOperators = PlaylistRule.operatorsForField(widget.rule.field);

    return Card(
      color: AppTheme.darkCard,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Field dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<RuleField>(
                    value: widget.rule.field,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: RuleField.values.map((field) {
                      return DropdownMenuItem(
                        value: field,
                        child: Text(
                          PlaylistRule.fieldDisplayName(field),
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (field) {
                      if (field != null) {
                        final newOperators = PlaylistRule.operatorsForField(field);
                        final newOperator = newOperators.contains(widget.rule.operator)
                            ? widget.rule.operator
                            : newOperators.first;
                        widget.onChanged(PlaylistRule(
                          field: field,
                          operator: newOperator,
                          value: widget.rule.value,
                          value2: widget.rule.value2,
                        ));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Delete button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onDelete,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                // Operator dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<RuleOperator>(
                    value: validOperators.contains(widget.rule.operator)
                        ? widget.rule.operator
                        : validOperators.first,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: validOperators.map((op) {
                      return DropdownMenuItem(
                        value: op,
                        child: Text(
                          PlaylistRule.operatorDisplayName(op),
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (op) {
                      if (op != null) {
                        widget.onChanged(PlaylistRule(
                          field: widget.rule.field,
                          operator: op,
                          value: widget.rule.value,
                          value2: widget.rule.value2,
                        ));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Value input
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      hintText: 'Value',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      widget.onChanged(PlaylistRule(
                        field: widget.rule.field,
                        operator: widget.rule.operator,
                        value: value,
                        value2: widget.rule.value2,
                      ));
                    },
                  ),
                ),
              ],
            ),

            // Second value for 'between' operator
            if (widget.rule.operator == RuleOperator.between) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(flex: 2, child: Center(child: Text('and'))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _value2Controller,
                      decoration: const InputDecoration(
                        hintText: 'Value 2',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        widget.onChanged(PlaylistRule(
                          field: widget.rule.field,
                          operator: widget.rule.operator,
                          value: widget.rule.value,
                          value2: value,
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Screen for viewing songs in a rule-based playlist
class RulePlaylistDetailScreen extends ConsumerWidget {
  final RuleBasedPlaylist playlist;

  const RulePlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    final service = ref.read(rulePlaylistServiceProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RulePlaylistEditorScreen(playlist: playlist),
                ),
              );
            },
          ),
        ],
      ),
      body: songsAsync.when(
        data: (allSongs) {
          return FutureBuilder<List<dynamic>>(
            future: service.generateSongs(playlist, allSongs),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                );
              }

              final songs = snapshot.data ?? [];

              if (songs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.music_off_rounded,
                        size: 64,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No matching songs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your rules',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Header with count and shuffle
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            final shuffled = List.of(songs)..shuffle();
                            await ref.read(playerProvider.notifier).playSong(
                              shuffled.first,
                              shuffled.cast(),
                            );
                          },
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle'),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await ref.read(playerProvider.notifier).playSong(
                              songs.first,
                              songs.cast(),
                            );
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                        ),
                      ],
                    ),
                  ),

                  // Songs list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return SongTile(
                          song: song,
                          onTap: () async {
                            await ref.read(playerProvider.notifier).playSong(
                              song,
                              songs.cast(),
                            );
                          },
                        ).animate(delay: (30 * (index % 15)).ms)
                            .fadeIn(duration: 200.ms);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (_, __) => const Center(
          child: Text('Failed to load songs'),
        ),
      ),
    );
  }
}
