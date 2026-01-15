import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../player/data/player_provider.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../../data/media_scanner.dart';
import 'songs_screen.dart';
import 'albums_screen.dart';
import 'artists_screen.dart';
import '../widgets/mini_player.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);

    return Scaffold(
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
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Tab bar
              _buildTabBar(),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    SongsScreen(),
                    AlbumsScreen(),
                    ArtistsScreen(),
                  ],
                ),
              ),

              // Mini player
              if (currentSong != null) const MiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VibePlay',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ).createShader(const Rect.fromLTWH(0, 0, 150, 40)),
                ),
              ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2),
              const SizedBox(height: 4),
              Text(
                'Your Music Library',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => _showSearch(context),
              ).animate().fadeIn(delay: 300.ms).scale(),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ).animate().fadeIn(delay: 400.ms).scale(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.secondaryColor,
            ],
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Songs'),
          Tab(text: 'Albums'),
          Tab(text: 'Artists'),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2);
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: SongSearchDelegate(ref),
    );
  }
}

// Search delegate
class SongSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;

  SongSearchDelegate(this.ref);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.darkSurface,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppTheme.textMuted),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Search for songs, artists, or albums',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final searchResults = ref.watch(searchResultsProvider(query));

    return searchResults.when(
      data: (songs) {
        if (songs.isEmpty) {
          return const Center(
            child: Text(
              'No results found',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          );
        }

        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha:0.3),
                      AppTheme.secondaryColor.withValues(alpha:0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppTheme.textPrimary,
                ),
              ),
              title: Text(
                song.title,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artistDisplay,
                style: const TextStyle(color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                final playerNotifier = ref.read(playerProvider.notifier);
                await playerNotifier.playSong(song, songs);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error searching')),
    );
  }
}
