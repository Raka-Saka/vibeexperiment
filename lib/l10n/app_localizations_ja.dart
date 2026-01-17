// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'VibePlay';

  @override
  String get appTagline => 'Your Music Library';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonShare => 'Share';

  @override
  String get commonInfo => 'Info';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonNone => 'None';

  @override
  String get commonAll => 'All';

  @override
  String get commonAny => 'Any';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonDiscard => 'Discard';

  @override
  String get commonGoBack => 'Go Back';

  @override
  String get commonOpenSettings => 'Open Settings';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSkip => 'Skip';

  @override
  String get navLibrary => 'Library';

  @override
  String get navNowPlaying => 'Now Playing';

  @override
  String get navQueue => 'Queue';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSearch => 'Search';

  @override
  String get librarySongs => 'Songs';

  @override
  String get libraryAlbums => 'Albums';

  @override
  String get libraryArtists => 'Artists';

  @override
  String get libraryGenres => 'Genres';

  @override
  String get libraryPlaylists => 'Playlists';

  @override
  String get libraryFolders => 'Folders';

  @override
  String get librarySearchHint => 'Search for songs, artists, or albums';

  @override
  String get libraryNoResults => 'No results found';

  @override
  String get libraryErrorSearching => 'Error searching';

  @override
  String get libraryNoSongs => 'No songs found';

  @override
  String get libraryNoAlbums => 'No Albums Found';

  @override
  String get libraryNoArtists => 'No Artists Found';

  @override
  String get libraryNoGenres => 'No Genres Found';

  @override
  String get libraryNoPlaylists => 'No Playlists';

  @override
  String get libraryScanningLibrary => 'Scanning library...';

  @override
  String get libraryRefreshLibrary => 'Refresh Library';

  @override
  String librarySongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String libraryAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
      zero: 'No albums',
    );
    return '$_temp0';
  }

  @override
  String libraryArtistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String libraryTrackCount(int count) {
    return '$count tracks';
  }

  @override
  String get libraryUnknownArtist => 'Unknown Artist';

  @override
  String get libraryUnknownAlbum => 'Unknown Album';

  @override
  String get libraryDuplicates => 'Duplicates';

  @override
  String get libraryFindDuplicates => 'Find Duplicates';

  @override
  String get libraryNoDuplicates => 'No duplicate songs found';

  @override
  String get libraryScanningFiles => 'Scanning files...';

  @override
  String libraryScanProgress(int current, int total) {
    return 'Scanning $current/$total...';
  }

  @override
  String libraryDuplicateGroups(int count) {
    return '$count groups of duplicates found';
  }

  @override
  String get playerNowPlaying => 'NOW PLAYING';

  @override
  String get playerFromLibrary => 'From Library';

  @override
  String get playerNoSongPlaying => 'No song playing';

  @override
  String get playerQueue => 'Queue';

  @override
  String get playerUpNext => 'Up Next';

  @override
  String get playerHistory => 'History';

  @override
  String playerVisualizerLabel(String style) {
    return 'Visualizer: $style';
  }

  @override
  String get playerTapToChangeVisualizer => 'Tap album art to cycle visualizers';

  @override
  String get playerSleepTimer => 'Sleep Timer';

  @override
  String get playerSleepTimerOff => 'Off';

  @override
  String playerSleepTimerSet(String duration) {
    return 'Sleep timer set for $duration';
  }

  @override
  String get playerSleepTimerCancelled => 'Sleep timer cancelled';

  @override
  String playerMinutes(int count) {
    return '$count min';
  }

  @override
  String get playerHour => '1 hour';

  @override
  String playerHours(int count) {
    return '$count hours';
  }

  @override
  String get playerEndOfTrack => 'End of track';

  @override
  String get playerCustom => 'Custom';

  @override
  String playerAddTime(int minutes) {
    return '+$minutes min';
  }

  @override
  String get playbackPlay => 'Play';

  @override
  String get playbackPause => 'Pause';

  @override
  String get playbackStop => 'Stop';

  @override
  String get playbackNext => 'Next';

  @override
  String get playbackPrevious => 'Previous';

  @override
  String get playbackShuffle => 'Shuffle';

  @override
  String get playbackShuffleOn => 'Shuffle On';

  @override
  String get playbackShuffleOff => 'Shuffle Off';

  @override
  String get playbackRepeat => 'Repeat';

  @override
  String get playbackRepeatOff => 'Repeat Off';

  @override
  String get playbackRepeatOne => 'Repeat One';

  @override
  String get playbackRepeatAll => 'Repeat All';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get playbackSpeedNormal => 'Normal';

  @override
  String get playbackPitch => 'Pitch';

  @override
  String get playbackSemitones => 'semitones';

  @override
  String get queueAddToQueue => 'Add to Queue';

  @override
  String get queuePlayNext => 'Play Next';

  @override
  String get queueRemoveFromQueue => 'Remove from Queue';

  @override
  String get queueClearQueue => 'Clear Queue';

  @override
  String queueAddedToQueue(String title) {
    return 'Added \"$title\" to queue';
  }

  @override
  String queueWillPlayNext(String title) {
    return '\"$title\" will play next';
  }

  @override
  String queueSongsInQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs in queue',
      one: '1 song in queue',
    );
    return '$_temp0';
  }

  @override
  String get playlistCreate => 'Create Playlist';

  @override
  String get playlistNew => 'New Playlist';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get playlistAddTo => 'Add to Playlist';

  @override
  String get playlistAddToPlaylist => 'Add to Playlist';

  @override
  String get playlistRemoveFrom => 'Remove from Playlist';

  @override
  String get playlistDelete => 'Delete Playlist';

  @override
  String get playlistRename => 'Rename Playlist';

  @override
  String get playlistFavorites => 'Favorites';

  @override
  String get playlistRecentlyPlayed => 'Recently Played';

  @override
  String get playlistMostPlayed => 'Most Played';

  @override
  String get playlistRecentlyAdded => 'Recently Added';

  @override
  String get playlistHeavyRotation => 'Heavy Rotation';

  @override
  String get playlistRediscover => 'Rediscover';

  @override
  String playlistCreated(String name) {
    return 'Playlist \"$name\" created';
  }

  @override
  String get playlistDeleted => 'Playlist deleted';

  @override
  String playlistAddedTo(String playlist) {
    return 'Added to $playlist';
  }

  @override
  String playlistRemovedFrom(String playlist) {
    return 'Removed from $playlist';
  }

  @override
  String get smartPlaylistTitle => 'Smart Playlists';

  @override
  String get smartPlaylistCreate => 'Create Smart Playlist';

  @override
  String get smartPlaylistEdit => 'Edit Smart Playlist';

  @override
  String get smartPlaylistRuleBased => 'Rule-Based Playlists';

  @override
  String get smartPlaylistNoRulePlaylists => 'No rule-based playlists yet';

  @override
  String get smartPlaylistDescription => 'Create playlists that automatically update based on rules like artist, genre, play count, and more.';

  @override
  String get smartPlaylistAddRule => 'Add Rule';

  @override
  String get smartPlaylistMatchAll => 'Match all rules';

  @override
  String get smartPlaylistMatchAny => 'Match any rule';

  @override
  String get smartPlaylistLimitTo => 'Limit to';

  @override
  String get smartPlaylistSongs => 'songs';

  @override
  String smartPlaylistRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String get smartPlaylistFilterArtist => 'Artist';

  @override
  String get smartPlaylistFilterAlbum => 'Album';

  @override
  String get smartPlaylistFilterGenre => 'Genre';

  @override
  String get smartPlaylistFilterYear => 'Year';

  @override
  String get smartPlaylistFilterPlayCount => 'Play Count';

  @override
  String get smartPlaylistFilterDuration => 'Duration';

  @override
  String get smartPlaylistFilterTitle => 'Title';

  @override
  String get smartPlaylistContains => 'contains';

  @override
  String get smartPlaylistEquals => 'equals';

  @override
  String get smartPlaylistStartsWith => 'starts with';

  @override
  String get smartPlaylistEndsWith => 'ends with';

  @override
  String get smartPlaylistGreaterThan => 'greater than';

  @override
  String get smartPlaylistLessThan => 'less than';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAudio => 'Audio';

  @override
  String get settingsSectionLibrary => 'Library';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsEqualizerTitle => 'Equalizer';

  @override
  String get settingsEqualizerSubtitle => 'Adjust audio frequencies';

  @override
  String get settingsPlaybackSpeedTitle => 'Playback Speed';

  @override
  String get settingsPlaybackSpeedSubtitle => 'Adjust playback tempo';

  @override
  String get settingsReverbTitle => 'Reverb';

  @override
  String get settingsReverbSubtitle => 'Add spatial depth to audio';

  @override
  String get settingsReverbMix => 'Reverb Mix';

  @override
  String get settingsReverbDecay => 'Decay';

  @override
  String get settingsAudioQualityTitle => 'Audio Quality';

  @override
  String get settingsAudioQualitySubtitle => 'High quality (native decoding)';

  @override
  String get settingsGaplessTitle => 'Gapless Playback';

  @override
  String get settingsGaplessSubtitle => 'Always enabled for seamless transitions';

  @override
  String get settingsGaplessMessage => 'Gapless playback is always enabled with native audio engine';

  @override
  String get settingsCrossfadeTitle => 'Crossfade';

  @override
  String get settingsCrossfadeSubtitle => 'Smoothly blend between songs';

  @override
  String get settingsCrossfadeOff => 'Off';

  @override
  String settingsCrossfadeFixed(int seconds) {
    return 'Fixed (${seconds}s)';
  }

  @override
  String settingsCrossfadeSmart(int seconds) {
    return 'Smart (${seconds}s)';
  }

  @override
  String get settingsCrossfadeModeLabel => 'Mode';

  @override
  String get settingsCrossfadeOffDescription => 'No crossfade between tracks';

  @override
  String get settingsCrossfadeFixedDescription => 'Fade at fixed time before track ends';

  @override
  String get settingsCrossfadeSmartDescription => 'Detect silence, skip live albums, sync to BPM';

  @override
  String get settingsCrossfadeDurationLabel => 'Duration';

  @override
  String get settingsCrossfadeQuick => 'Quick';

  @override
  String get settingsCrossfadeSmooth => 'Smooth';

  @override
  String get settingsCrossfadeSmartInfo => 'Smart mode adjusts timing based on track endings and skips crossfade for live albums';

  @override
  String get settingsNormalizationTitle => 'Volume Normalization';

  @override
  String get settingsNormalizationSubtitle => 'Consistent volume across tracks';

  @override
  String get settingsNormalizationOff => 'Off';

  @override
  String get settingsNormalizationTrack => 'Track';

  @override
  String get settingsNormalizationAlbum => 'Album';

  @override
  String get settingsNormalizationTarget => 'Target Loudness';

  @override
  String get settingsNormalizationPreventClipping => 'Prevent Clipping';

  @override
  String get settingsSortTitle => 'Default Sort';

  @override
  String get settingsSortSubtitle => 'Library sorting preference';

  @override
  String get settingsSortByTitle => 'Title';

  @override
  String get settingsSortByArtist => 'Artist';

  @override
  String get settingsSortByAlbum => 'Album';

  @override
  String get settingsSortByDateAdded => 'Date Added';

  @override
  String get settingsSortByDuration => 'Duration';

  @override
  String get settingsSortAscending => 'Ascending (A-Z)';

  @override
  String get settingsSortDescending => 'Descending (Z-A)';

  @override
  String get settingsRescanTitle => 'Rescan Library';

  @override
  String get settingsRescanSubtitle => 'Scan device for new music';

  @override
  String get settingsRescanConfirm => 'Rescan Library?';

  @override
  String get settingsRescanMessage => 'This will clear cached song data and rescan your library. This may take a while for large libraries.';

  @override
  String get settingsRescanButton => 'Rescan';

  @override
  String get settingsVisualizerTitle => 'Visualizer';

  @override
  String get settingsVisualizerSubtitle => 'Enable visual effects';

  @override
  String get settingsVisualizerEnabled => 'Enabled (uses more battery)';

  @override
  String get settingsVisualizerDisabled => 'Disabled (saves battery)';

  @override
  String get settingsVisualizerBatterySaving => 'Disable visualizer to save battery';

  @override
  String get settingsDynamicColorsTitle => 'Dynamic Colors';

  @override
  String get settingsDynamicColorsSubtitle => 'Coming soon - colors adapt to album art';

  @override
  String get settingsDynamicColorsComingSoon => 'Coming soon';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeSubtitle => 'App appearance';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLightComingSoon => 'Light theme support coming in a future update!';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'App language';

  @override
  String get settingsLanguageSystem => 'System Default';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutBuild => 'Build';

  @override
  String get settingsAboutLicenses => 'Licenses';

  @override
  String get settingsAboutPrivacy => 'Privacy Policy';

  @override
  String get settingsAboutTerms => 'Terms of Service';

  @override
  String get settingsResetTitle => 'Reset Settings';

  @override
  String get settingsResetSubtitle => 'Restore default values';

  @override
  String get settingsResetConfirm => 'Reset Settings?';

  @override
  String get settingsResetMessage => 'This will restore all settings to their default values. Your playlists and favorites will not be affected.';

  @override
  String get settingsResetSuccess => 'Settings reset to defaults';

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get settingsPlaybackSpeed => 'Playback Speed';

  @override
  String get settingsAudioQuality => 'Audio Quality';

  @override
  String get settingsAudioQualityHigh => 'High quality (native decoding)';

  @override
  String get settingsGaplessPlayback => 'Gapless Playback';

  @override
  String get settingsGaplessPlaybackSubtitle => 'Always enabled for seamless transitions';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get settingsNormalization => 'Volume Normalization';

  @override
  String get settingsReverb => 'Reverb';

  @override
  String get settingsPitch => 'Pitch Adjustment';

  @override
  String get settingsStatistics => 'Statistics';

  @override
  String get settingsStatisticsSubtitle => 'Play counts, listening time, smart playlists';

  @override
  String get settingsAiGenre => 'AI Genre Detection';

  @override
  String get settingsAiGenreSubtitle => 'Batch classify songs by genre';

  @override
  String get settingsRescan => 'Rescan Library';

  @override
  String get settingsClearCache => 'Clear Library Cache';

  @override
  String get settingsClearCacheSubtitle => 'Reset library data (files not deleted)';

  @override
  String get settingsDefaultSort => 'Default Sort';

  @override
  String get settingsSortDirection => 'Sort Direction';

  @override
  String get settingsStripComments => 'Strip Comments on Import';

  @override
  String get settingsStripCommentsEnabled => 'Enabled - comments removed from new songs';

  @override
  String get settingsStripCommentsLibrary => 'Strip Comments from Library';

  @override
  String get settingsStripCommentsLibrarySubtitle => 'Remove all comment metadata from songs';

  @override
  String get settingsVisualizer => 'Visualizer Animations';

  @override
  String get settingsDynamicColors => 'Dynamic Colors';

  @override
  String get settingsDynamicColorsDescription => 'This feature will automatically adapt the app\'s colors based on the currently playing album art.';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsAppVersion => 'App Version';

  @override
  String get settingsLicenses => 'Open Source Licenses';

  @override
  String get settingsLicensesSubtitle => 'View third-party licenses';

  @override
  String get settingsReset => 'Reset Settings';

  @override
  String get toastGaplessAlwaysEnabled => 'Gapless playback is always enabled';

  @override
  String get equalizerTitle => 'Equalizer';

  @override
  String get equalizerPresets => 'Presets';

  @override
  String get equalizerCustom => 'Custom';

  @override
  String get equalizerFlat => 'Flat';

  @override
  String get equalizerBassBooster => 'Bass Booster';

  @override
  String get equalizerBassReducer => 'Bass Reducer';

  @override
  String get equalizerTrebleBooster => 'Treble Booster';

  @override
  String get equalizerTrebleReducer => 'Treble Reducer';

  @override
  String get equalizerVocalBooster => 'Vocal Booster';

  @override
  String get equalizerRock => 'Rock';

  @override
  String get equalizerPop => 'Pop';

  @override
  String get equalizerJazz => 'Jazz';

  @override
  String get equalizerClassical => 'Classical';

  @override
  String get equalizerHipHop => 'Hip-Hop';

  @override
  String get equalizerElectronic => 'Electronic';

  @override
  String get equalizerAcoustic => 'Acoustic';

  @override
  String get equalizerRnB => 'R&B';

  @override
  String get equalizerLatin => 'Latin';

  @override
  String get equalizerPiano => 'Piano';

  @override
  String get equalizerSmallSpeakers => 'Small Speakers';

  @override
  String get equalizerLoudness => 'Loudness';

  @override
  String get equalizerLounge => 'Lounge';

  @override
  String get equalizerSpokenWord => 'Spoken Word';

  @override
  String get equalizerSavePreset => 'Save Preset';

  @override
  String get equalizerPresetName => 'Preset name';

  @override
  String equalizerPresetSaved(String name) {
    return 'Preset \"$name\" saved';
  }

  @override
  String get equalizerDeletePreset => 'Delete Preset';

  @override
  String get equalizerRenamePreset => 'Rename Preset';

  @override
  String get equalizerPresetDeleted => 'Preset deleted';

  @override
  String get equalizerBandCount => '10-band equalizer';

  @override
  String get equalizerBand60Hz => '60 Hz';

  @override
  String get equalizerBand230Hz => '230 Hz';

  @override
  String get equalizerBand910Hz => '910 Hz';

  @override
  String get equalizerBand3600Hz => '3.6 kHz';

  @override
  String get equalizerBand14000Hz => '14 kHz';

  @override
  String get equalizerBass => 'Bass';

  @override
  String get equalizerMidrange => 'Midrange';

  @override
  String get equalizerTreble => 'Treble';

  @override
  String get equalizerEffects => 'Effects';

  @override
  String get equalizerBassBoost => 'Bass Boost';

  @override
  String get equalizerVirtualizer => 'Virtualizer';

  @override
  String get equalizerSpatialAudio => 'Spatial Audio';

  @override
  String get equalizerSpatialDescription => 'Immersive 3D sound experience';

  @override
  String get equalizerSpatialTip => 'For best results, use headphones or earbuds with spatial audio support.';

  @override
  String get equalizerPerSongTitle => 'Per-Song EQ';

  @override
  String get equalizerPerSongSubtitle => 'Remember EQ per Song';

  @override
  String get equalizerPerSongDescription => 'Auto-load saved EQ for each song';

  @override
  String get equalizerCurrentSong => 'Current Song';

  @override
  String get equalizerSaveForSong => 'Save EQ for This Song';

  @override
  String get equalizerClearForSong => 'Clear Song EQ';

  @override
  String equalizerSongEqSaved(String title) {
    return 'EQ saved for \"$title\"';
  }

  @override
  String get equalizerSongEqCleared => 'Song EQ cleared';

  @override
  String get equalizerCustomEqLoaded => 'Custom EQ loaded for this song';

  @override
  String get equalizerResetToDefault => 'Reset to Default';

  @override
  String get reverbTitle => 'Reverb';

  @override
  String get reverbOff => 'Off';

  @override
  String get reverbSmallRoom => 'Small Room';

  @override
  String get reverbMediumRoom => 'Medium Room';

  @override
  String get reverbLargeRoom => 'Large Room';

  @override
  String get reverbMediumHall => 'Medium Hall';

  @override
  String get reverbLargeHall => 'Large Hall';

  @override
  String get reverbPlate => 'Plate';

  @override
  String get visualizerTitle => 'Visualizer';

  @override
  String get visualizerOff => 'Off';

  @override
  String get visualizerResonance => 'Resonance';

  @override
  String get visualizerRipples => 'Ripples';

  @override
  String get visualizerHarmonograph => 'Harmonograph';

  @override
  String get visualizerCelestialHalos => 'Celestial Halos';

  @override
  String get visualizerAurora => 'Aurora';

  @override
  String get visualizerSpirograph => 'Spirograph';

  @override
  String get visualizerVoronoi => 'Voronoi';

  @override
  String get visualizerSunflower => 'Sunflower';

  @override
  String get visualizerAttractors => 'Attractors';

  @override
  String get visualizerMoire => 'Moiré';

  @override
  String get visualizerPendulum => 'Pendulum';

  @override
  String get visualizerFlames => 'Flames';

  @override
  String get visualizerFractal => 'Fractal';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsOverview => 'Overview';

  @override
  String get statsTotalListening => 'Total Listening';

  @override
  String get statsThisWeek => 'This Week';

  @override
  String get statsSongsPlayed => 'Songs Played';

  @override
  String get statsUniqueSongs => 'Unique Songs';

  @override
  String get statsLast7Days => 'Last 7 Days';

  @override
  String get statsSmartPlaylists => 'Smart Playlists';

  @override
  String get statsNoSongsYet => 'No songs yet';

  @override
  String get statsNoDataYet => 'No listening data yet';

  @override
  String get statsDayMon => 'Mon';

  @override
  String get statsDayTue => 'Tue';

  @override
  String get statsDayWed => 'Wed';

  @override
  String get statsDayThu => 'Thu';

  @override
  String get statsDayFri => 'Fri';

  @override
  String get statsDaySat => 'Sat';

  @override
  String get statsDaySun => 'Sun';

  @override
  String statsHours(int count) {
    return '$count hours';
  }

  @override
  String statsMinutes(int count) {
    return '$count min';
  }

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsNotFound => 'No lyrics found';

  @override
  String get lyricsInstructions => 'Place a .lrc file with the same name as the audio file to see lyrics';

  @override
  String get lyricsUnsynchronized => 'Unsynchronized lyrics';

  @override
  String get lyricsEmbedded => 'Embedded lyrics';

  @override
  String get lyricsExternal => 'External .lrc file';

  @override
  String get tagEditorTitle => 'Edit Tags';

  @override
  String get tagEditorFieldTitle => 'Title';

  @override
  String get tagEditorFieldArtist => 'Artist';

  @override
  String get tagEditorFieldAlbum => 'Album';

  @override
  String get tagEditorFieldGenre => 'Genre';

  @override
  String get tagEditorFieldYear => 'Year';

  @override
  String get tagEditorFieldTrack => 'Track #';

  @override
  String get tagEditorFieldComposer => 'Composer';

  @override
  String get tagEditorFieldBpm => 'BPM';

  @override
  String get tagEditorFieldLyrics => 'Lyrics';

  @override
  String get tagEditorArtwork => 'Artwork';

  @override
  String get tagEditorChangeArtwork => 'Change Artwork';

  @override
  String get tagEditorRemoveArtwork => 'Remove Artwork';

  @override
  String get tagEditorSaveChanges => 'Save Changes';

  @override
  String get tagEditorDiscardChanges => 'Discard changes?';

  @override
  String get tagEditorUnsavedMessage => 'You have unsaved changes. Do you want to discard them?';

  @override
  String get tagEditorSaveSuccess => 'Tags saved successfully';

  @override
  String get tagEditorSaveError => 'Failed to save tags';

  @override
  String get tagEditorPermissionRequired => 'Permission Required';

  @override
  String get tagEditorPermissionMessage => 'To modify music files, VibePlay needs \"All files access\" permission.';

  @override
  String get tagEditorPermissionInstruction => 'Tap \"Open Settings\" and enable \"Allow access to manage all files\".';

  @override
  String get tagEditorFindReplace => 'Find & Replace';

  @override
  String get tagEditorFind => 'Find';

  @override
  String get tagEditorReplace => 'Replace';

  @override
  String get tagEditorReplaceWith => 'Replace with';

  @override
  String get tagEditorCaseSensitive => 'Case sensitive';

  @override
  String get tagEditorWholeWord => 'Whole word';

  @override
  String get tagEditorInTitle => 'In Title';

  @override
  String get tagEditorInArtist => 'In Artist';

  @override
  String get tagEditorInAlbum => 'In Album';

  @override
  String tagEditorMatchesFound(int count) {
    return '$count matches found';
  }

  @override
  String get tagEditorNoMatches => 'No matches found';

  @override
  String get tagEditorReplaceAll => 'Replace All';

  @override
  String tagEditorReplaceSuccess(int count) {
    return 'Replaced $count occurrences';
  }

  @override
  String get tagEditorRemoveUrls => 'Remove URL Tags';

  @override
  String get tagEditorRemoveUrlsMessage => 'Remove WOAS, WOAR and other URL tags from the selected song?';

  @override
  String get tagEditorUrlsRemoved => 'URL tags removed';

  @override
  String get genreDetection => 'Genre Detection';

  @override
  String get genreDetecting => 'Detecting genre...';

  @override
  String genreDetected(String genre) {
    return 'Detected: $genre';
  }

  @override
  String get genreDetectionFailed => 'Could not detect genre';

  @override
  String get genreApply => 'Apply Genre';

  @override
  String genreApplied(String genre) {
    return 'Genre applied: $genre';
  }

  @override
  String get youtubeUploadTitle => 'Upload to YouTube';

  @override
  String get youtubeSignIn => 'Sign in with Google';

  @override
  String get youtubeSignOut => 'Sign Out';

  @override
  String youtubeSignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get youtubeGeneratingVideo => 'Generating video...';

  @override
  String get youtubeUploading => 'Uploading to YouTube...';

  @override
  String youtubeUploadProgress(int percent) {
    return 'Uploading: $percent%';
  }

  @override
  String get youtubeUploadComplete => 'Upload complete!';

  @override
  String get youtubeUploadFailed => 'Upload failed';

  @override
  String get youtubeViewVideo => 'View Video';

  @override
  String get youtubeShareAudio => 'Or share audio file';

  @override
  String get youtubePrivacyPublic => 'Public';

  @override
  String get youtubePrivacyUnlisted => 'Unlisted';

  @override
  String get youtubePrivacyPrivate => 'Private';

  @override
  String get songInfoTitle => 'Song Info';

  @override
  String get songInfoDuration => 'Duration';

  @override
  String get songInfoBitrate => 'Bitrate';

  @override
  String get songInfoSampleRate => 'Sample Rate';

  @override
  String get songInfoFormat => 'Format';

  @override
  String get songInfoSize => 'File Size';

  @override
  String get songInfoPath => 'Path';

  @override
  String get songInfoPlayCount => 'Play Count';

  @override
  String get songInfoLastPlayed => 'Last Played';

  @override
  String get songInfoDateAdded => 'Date Added';

  @override
  String get songInfoCopyPath => 'Copy Path';

  @override
  String get songInfoPathCopied => 'Path copied to clipboard';

  @override
  String get dialogDeleteSong => 'Delete Song';

  @override
  String get dialogDeleteSongMessage => 'Are you sure you want to delete this song? This cannot be undone.';

  @override
  String get dialogDeletePlaylist => 'Delete Playlist?';

  @override
  String dialogDeletePlaylistMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get dialogPermissionRequired => 'Permission Required';

  @override
  String get dialogPermissionStorageMessage => 'VibePlay needs storage permission to access your music library.';

  @override
  String get dialogPermissionMicrophoneMessage => 'VibePlay needs microphone permission for the audio visualizer.';

  @override
  String get dialogResetConfirm => 'Are you sure?';

  @override
  String get toastAddedToFavorites => 'Added to Favorites';

  @override
  String get toastRemovedFromFavorites => 'Removed from Favorites';

  @override
  String get toastLibraryScanComplete => 'Library scan complete!';

  @override
  String get toastLibraryCacheCleared => 'Library cache cleared. Rescanning...';

  @override
  String get toastNoInternetConnection => 'No internet connection';

  @override
  String get toastFeatureComingSoon => 'This feature is coming soon!';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorLoadFailed => 'Failed to load';

  @override
  String get errorSaveFailed => 'Failed to save';

  @override
  String get errorNetworkError => 'Network error';

  @override
  String get errorPermissionDenied => 'Permission denied';

  @override
  String get errorFileNotFound => 'File not found';

  @override
  String get errorPlaybackFailed => 'Playback failed';

  @override
  String get errorInvalidFormat => 'Invalid format';

  @override
  String get timeHours => 'hours';

  @override
  String get timeMinutes => 'minutes';

  @override
  String get timeSeconds => 'seconds';

  @override
  String timeAgo(String time) {
    return '$time ago';
  }

  @override
  String get timeNever => 'Never';

  @override
  String get timeJustNow => 'Just now';

  @override
  String get timeToday => 'Today';

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get menuAddToPlaylist => 'Add to Playlist';

  @override
  String get menuAddToQueue => 'Add to Queue';

  @override
  String get menuPlayNext => 'Play Next';

  @override
  String get menuGoToArtist => 'Go to Artist';

  @override
  String get menuGoToAlbum => 'Go to Album';

  @override
  String get menuSongInfo => 'Song Info';

  @override
  String get menuEditTags => 'Edit Tags';

  @override
  String get menuShare => 'Share';

  @override
  String get menuDelete => 'Delete';

  @override
  String get menuUploadToYoutube => 'Upload to YouTube';
}
