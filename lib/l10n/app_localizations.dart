import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_my.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('my'),
    Locale('pt')
  ];

  /// The app name
  ///
  /// In en, this message translates to:
  /// **'VibePlay'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your Music Library'**
  String get appTagline;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get commonInfo;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabled;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get commonAny;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonDiscard;

  /// No description provided for @commonGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get commonGoBack;

  /// No description provided for @commonOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get commonOpenSettings;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get navNowPlaying;

  /// No description provided for @navQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get navQueue;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @librarySongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get librarySongs;

  /// No description provided for @libraryAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get libraryAlbums;

  /// No description provided for @libraryArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryArtists;

  /// No description provided for @libraryGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get libraryGenres;

  /// No description provided for @libraryPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get libraryPlaylists;

  /// No description provided for @libraryFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libraryFolders;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for songs, artists, or albums'**
  String get librarySearchHint;

  /// No description provided for @libraryNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get libraryNoResults;

  /// No description provided for @libraryErrorSearching.
  ///
  /// In en, this message translates to:
  /// **'Error searching'**
  String get libraryErrorSearching;

  /// No description provided for @libraryNoSongs.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get libraryNoSongs;

  /// No description provided for @libraryNoAlbums.
  ///
  /// In en, this message translates to:
  /// **'No Albums Found'**
  String get libraryNoAlbums;

  /// No description provided for @libraryNoArtists.
  ///
  /// In en, this message translates to:
  /// **'No Artists Found'**
  String get libraryNoArtists;

  /// No description provided for @libraryNoGenres.
  ///
  /// In en, this message translates to:
  /// **'No Genres Found'**
  String get libraryNoGenres;

  /// No description provided for @libraryNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No Playlists'**
  String get libraryNoPlaylists;

  /// No description provided for @libraryScanningLibrary.
  ///
  /// In en, this message translates to:
  /// **'Scanning library...'**
  String get libraryScanningLibrary;

  /// No description provided for @libraryRefreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh Library'**
  String get libraryRefreshLibrary;

  /// No description provided for @librarySongCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String librarySongCount(int count);

  /// No description provided for @libraryAlbumCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No albums} =1{1 album} other{{count} albums}}'**
  String libraryAlbumCount(int count);

  /// No description provided for @libraryArtistCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 artist} other{{count} artists}}'**
  String libraryArtistCount(int count);

  /// No description provided for @libraryTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String libraryTrackCount(int count);

  /// No description provided for @libraryUnknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown Artist'**
  String get libraryUnknownArtist;

  /// No description provided for @libraryUnknownAlbum.
  ///
  /// In en, this message translates to:
  /// **'Unknown Album'**
  String get libraryUnknownAlbum;

  /// No description provided for @libraryDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get libraryDuplicates;

  /// No description provided for @libraryFindDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Find Duplicates'**
  String get libraryFindDuplicates;

  /// No description provided for @libraryNoDuplicates.
  ///
  /// In en, this message translates to:
  /// **'No duplicate songs found'**
  String get libraryNoDuplicates;

  /// No description provided for @libraryScanningFiles.
  ///
  /// In en, this message translates to:
  /// **'Scanning files...'**
  String get libraryScanningFiles;

  /// No description provided for @libraryScanProgress.
  ///
  /// In en, this message translates to:
  /// **'Scanning {current}/{total}...'**
  String libraryScanProgress(int current, int total);

  /// No description provided for @libraryDuplicateGroups.
  ///
  /// In en, this message translates to:
  /// **'{count} groups of duplicates found'**
  String libraryDuplicateGroups(int count);

  /// No description provided for @playerNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'NOW PLAYING'**
  String get playerNowPlaying;

  /// No description provided for @playerFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'From Library'**
  String get playerFromLibrary;

  /// No description provided for @playerNoSongPlaying.
  ///
  /// In en, this message translates to:
  /// **'No song playing'**
  String get playerNoSongPlaying;

  /// No description provided for @playerQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get playerQueue;

  /// No description provided for @playerUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get playerUpNext;

  /// No description provided for @playerHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get playerHistory;

  /// No description provided for @playerVisualizerLabel.
  ///
  /// In en, this message translates to:
  /// **'Visualizer: {style}'**
  String playerVisualizerLabel(String style);

  /// No description provided for @playerTapToChangeVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Tap album art to cycle visualizers'**
  String get playerTapToChangeVisualizer;

  /// No description provided for @playerSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get playerSleepTimer;

  /// No description provided for @playerSleepTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerSleepTimerOff;

  /// No description provided for @playerSleepTimerSet.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer set for {duration}'**
  String playerSleepTimerSet(String duration);

  /// No description provided for @playerSleepTimerCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer cancelled'**
  String get playerSleepTimerCancelled;

  /// No description provided for @playerMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String playerMinutes(int count);

  /// No description provided for @playerHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get playerHour;

  /// No description provided for @playerHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hours'**
  String playerHours(int count);

  /// No description provided for @playerEndOfTrack.
  ///
  /// In en, this message translates to:
  /// **'End of track'**
  String get playerEndOfTrack;

  /// No description provided for @playerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get playerCustom;

  /// No description provided for @playerAddTime.
  ///
  /// In en, this message translates to:
  /// **'+{minutes} min'**
  String playerAddTime(int minutes);

  /// No description provided for @playbackPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playbackPlay;

  /// No description provided for @playbackPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playbackPause;

  /// No description provided for @playbackStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get playbackStop;

  /// No description provided for @playbackNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playbackNext;

  /// No description provided for @playbackPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playbackPrevious;

  /// No description provided for @playbackShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playbackShuffle;

  /// No description provided for @playbackShuffleOn.
  ///
  /// In en, this message translates to:
  /// **'Shuffle On'**
  String get playbackShuffleOn;

  /// No description provided for @playbackShuffleOff.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Off'**
  String get playbackShuffleOff;

  /// No description provided for @playbackRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get playbackRepeat;

  /// No description provided for @playbackRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat Off'**
  String get playbackRepeatOff;

  /// No description provided for @playbackRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat One'**
  String get playbackRepeatOne;

  /// No description provided for @playbackRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat All'**
  String get playbackRepeatAll;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// No description provided for @playbackSpeedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playbackSpeedNormal;

  /// No description provided for @playbackPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get playbackPitch;

  /// No description provided for @playbackSemitones.
  ///
  /// In en, this message translates to:
  /// **'semitones'**
  String get playbackSemitones;

  /// No description provided for @queueAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get queueAddToQueue;

  /// No description provided for @queuePlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get queuePlayNext;

  /// No description provided for @queueRemoveFromQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove from Queue'**
  String get queueRemoveFromQueue;

  /// No description provided for @queueClearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear Queue'**
  String get queueClearQueue;

  /// No description provided for @queueAddedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\" to queue'**
  String queueAddedToQueue(String title);

  /// No description provided for @queueWillPlayNext.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will play next'**
  String queueWillPlayNext(String title);

  /// No description provided for @queueSongsInQueue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song in queue} other{{count} songs in queue}}'**
  String queueSongsInQueue(int count);

  /// No description provided for @playlistCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get playlistCreate;

  /// No description provided for @playlistNew.
  ///
  /// In en, this message translates to:
  /// **'New Playlist'**
  String get playlistNew;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @playlistAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get playlistAddTo;

  /// No description provided for @playlistAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get playlistAddToPlaylist;

  /// No description provided for @playlistRemoveFrom.
  ///
  /// In en, this message translates to:
  /// **'Remove from Playlist'**
  String get playlistRemoveFrom;

  /// No description provided for @playlistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get playlistDelete;

  /// No description provided for @playlistRename.
  ///
  /// In en, this message translates to:
  /// **'Rename Playlist'**
  String get playlistRename;

  /// No description provided for @playlistFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get playlistFavorites;

  /// No description provided for @playlistRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get playlistRecentlyPlayed;

  /// No description provided for @playlistMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get playlistMostPlayed;

  /// No description provided for @playlistRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get playlistRecentlyAdded;

  /// No description provided for @playlistHeavyRotation.
  ///
  /// In en, this message translates to:
  /// **'Heavy Rotation'**
  String get playlistHeavyRotation;

  /// No description provided for @playlistRediscover.
  ///
  /// In en, this message translates to:
  /// **'Rediscover'**
  String get playlistRediscover;

  /// No description provided for @playlistCreated.
  ///
  /// In en, this message translates to:
  /// **'Playlist \"{name}\" created'**
  String playlistCreated(String name);

  /// No description provided for @playlistDeleted.
  ///
  /// In en, this message translates to:
  /// **'Playlist deleted'**
  String get playlistDeleted;

  /// No description provided for @playlistAddedTo.
  ///
  /// In en, this message translates to:
  /// **'Added to {playlist}'**
  String playlistAddedTo(String playlist);

  /// No description provided for @playlistRemovedFrom.
  ///
  /// In en, this message translates to:
  /// **'Removed from {playlist}'**
  String playlistRemovedFrom(String playlist);

  /// No description provided for @smartPlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Playlists'**
  String get smartPlaylistTitle;

  /// No description provided for @smartPlaylistCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Smart Playlist'**
  String get smartPlaylistCreate;

  /// No description provided for @smartPlaylistEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Smart Playlist'**
  String get smartPlaylistEdit;

  /// No description provided for @smartPlaylistRuleBased.
  ///
  /// In en, this message translates to:
  /// **'Rule-Based Playlists'**
  String get smartPlaylistRuleBased;

  /// No description provided for @smartPlaylistNoRulePlaylists.
  ///
  /// In en, this message translates to:
  /// **'No rule-based playlists yet'**
  String get smartPlaylistNoRulePlaylists;

  /// No description provided for @smartPlaylistDescription.
  ///
  /// In en, this message translates to:
  /// **'Create playlists that automatically update based on rules like artist, genre, play count, and more.'**
  String get smartPlaylistDescription;

  /// No description provided for @smartPlaylistAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add Rule'**
  String get smartPlaylistAddRule;

  /// No description provided for @smartPlaylistMatchAll.
  ///
  /// In en, this message translates to:
  /// **'Match all rules'**
  String get smartPlaylistMatchAll;

  /// No description provided for @smartPlaylistMatchAny.
  ///
  /// In en, this message translates to:
  /// **'Match any rule'**
  String get smartPlaylistMatchAny;

  /// No description provided for @smartPlaylistLimitTo.
  ///
  /// In en, this message translates to:
  /// **'Limit to'**
  String get smartPlaylistLimitTo;

  /// No description provided for @smartPlaylistSongs.
  ///
  /// In en, this message translates to:
  /// **'songs'**
  String get smartPlaylistSongs;

  /// No description provided for @smartPlaylistRuleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule} other{{count} rules}}'**
  String smartPlaylistRuleCount(int count);

  /// No description provided for @smartPlaylistFilterArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get smartPlaylistFilterArtist;

  /// No description provided for @smartPlaylistFilterAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get smartPlaylistFilterAlbum;

  /// No description provided for @smartPlaylistFilterGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get smartPlaylistFilterGenre;

  /// No description provided for @smartPlaylistFilterYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get smartPlaylistFilterYear;

  /// No description provided for @smartPlaylistFilterPlayCount.
  ///
  /// In en, this message translates to:
  /// **'Play Count'**
  String get smartPlaylistFilterPlayCount;

  /// No description provided for @smartPlaylistFilterDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get smartPlaylistFilterDuration;

  /// No description provided for @smartPlaylistFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get smartPlaylistFilterTitle;

  /// No description provided for @smartPlaylistContains.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get smartPlaylistContains;

  /// No description provided for @smartPlaylistEquals.
  ///
  /// In en, this message translates to:
  /// **'equals'**
  String get smartPlaylistEquals;

  /// No description provided for @smartPlaylistStartsWith.
  ///
  /// In en, this message translates to:
  /// **'starts with'**
  String get smartPlaylistStartsWith;

  /// No description provided for @smartPlaylistEndsWith.
  ///
  /// In en, this message translates to:
  /// **'ends with'**
  String get smartPlaylistEndsWith;

  /// No description provided for @smartPlaylistGreaterThan.
  ///
  /// In en, this message translates to:
  /// **'greater than'**
  String get smartPlaylistGreaterThan;

  /// No description provided for @smartPlaylistLessThan.
  ///
  /// In en, this message translates to:
  /// **'less than'**
  String get smartPlaylistLessThan;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsSectionAudio;

  /// No description provided for @settingsSectionLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsSectionLibrary;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsEqualizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get settingsEqualizerTitle;

  /// No description provided for @settingsEqualizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust audio frequencies'**
  String get settingsEqualizerSubtitle;

  /// No description provided for @settingsPlaybackSpeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get settingsPlaybackSpeedTitle;

  /// No description provided for @settingsPlaybackSpeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust playback tempo'**
  String get settingsPlaybackSpeedSubtitle;

  /// No description provided for @settingsReverbTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverb'**
  String get settingsReverbTitle;

  /// No description provided for @settingsReverbSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add spatial depth to audio'**
  String get settingsReverbSubtitle;

  /// No description provided for @settingsReverbMix.
  ///
  /// In en, this message translates to:
  /// **'Reverb Mix'**
  String get settingsReverbMix;

  /// No description provided for @settingsReverbDecay.
  ///
  /// In en, this message translates to:
  /// **'Decay'**
  String get settingsReverbDecay;

  /// No description provided for @settingsAudioQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Quality'**
  String get settingsAudioQualityTitle;

  /// No description provided for @settingsAudioQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'High quality (native decoding)'**
  String get settingsAudioQualitySubtitle;

  /// No description provided for @settingsGaplessTitle.
  ///
  /// In en, this message translates to:
  /// **'Gapless Playback'**
  String get settingsGaplessTitle;

  /// No description provided for @settingsGaplessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always enabled for seamless transitions'**
  String get settingsGaplessSubtitle;

  /// No description provided for @settingsGaplessMessage.
  ///
  /// In en, this message translates to:
  /// **'Gapless playback is always enabled with native audio engine'**
  String get settingsGaplessMessage;

  /// No description provided for @settingsCrossfadeTitle.
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get settingsCrossfadeTitle;

  /// No description provided for @settingsCrossfadeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Smoothly blend between songs'**
  String get settingsCrossfadeSubtitle;

  /// No description provided for @settingsCrossfadeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsCrossfadeOff;

  /// No description provided for @settingsCrossfadeFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed ({seconds}s)'**
  String settingsCrossfadeFixed(int seconds);

  /// No description provided for @settingsCrossfadeSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart ({seconds}s)'**
  String settingsCrossfadeSmart(int seconds);

  /// No description provided for @settingsCrossfadeModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get settingsCrossfadeModeLabel;

  /// No description provided for @settingsCrossfadeOffDescription.
  ///
  /// In en, this message translates to:
  /// **'No crossfade between tracks'**
  String get settingsCrossfadeOffDescription;

  /// No description provided for @settingsCrossfadeFixedDescription.
  ///
  /// In en, this message translates to:
  /// **'Fade at fixed time before track ends'**
  String get settingsCrossfadeFixedDescription;

  /// No description provided for @settingsCrossfadeSmartDescription.
  ///
  /// In en, this message translates to:
  /// **'Detect silence, skip live albums, sync to BPM'**
  String get settingsCrossfadeSmartDescription;

  /// No description provided for @settingsCrossfadeDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get settingsCrossfadeDurationLabel;

  /// No description provided for @settingsCrossfadeQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get settingsCrossfadeQuick;

  /// No description provided for @settingsCrossfadeSmooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get settingsCrossfadeSmooth;

  /// No description provided for @settingsCrossfadeSmartInfo.
  ///
  /// In en, this message translates to:
  /// **'Smart mode adjusts timing based on track endings and skips crossfade for live albums'**
  String get settingsCrossfadeSmartInfo;

  /// No description provided for @settingsNormalizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Volume Normalization'**
  String get settingsNormalizationTitle;

  /// No description provided for @settingsNormalizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Consistent volume across tracks'**
  String get settingsNormalizationSubtitle;

  /// No description provided for @settingsNormalizationOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsNormalizationOff;

  /// No description provided for @settingsNormalizationTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get settingsNormalizationTrack;

  /// No description provided for @settingsNormalizationAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get settingsNormalizationAlbum;

  /// No description provided for @settingsNormalizationTarget.
  ///
  /// In en, this message translates to:
  /// **'Target Loudness'**
  String get settingsNormalizationTarget;

  /// No description provided for @settingsNormalizationPreventClipping.
  ///
  /// In en, this message translates to:
  /// **'Prevent Clipping'**
  String get settingsNormalizationPreventClipping;

  /// No description provided for @settingsSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Default Sort'**
  String get settingsSortTitle;

  /// No description provided for @settingsSortSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Library sorting preference'**
  String get settingsSortSubtitle;

  /// No description provided for @settingsSortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get settingsSortByTitle;

  /// No description provided for @settingsSortByArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get settingsSortByArtist;

  /// No description provided for @settingsSortByAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get settingsSortByAlbum;

  /// No description provided for @settingsSortByDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get settingsSortByDateAdded;

  /// No description provided for @settingsSortByDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get settingsSortByDuration;

  /// No description provided for @settingsSortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending (A-Z)'**
  String get settingsSortAscending;

  /// No description provided for @settingsSortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending (Z-A)'**
  String get settingsSortDescending;

  /// No description provided for @settingsRescanTitle.
  ///
  /// In en, this message translates to:
  /// **'Rescan Library'**
  String get settingsRescanTitle;

  /// No description provided for @settingsRescanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan device for new music'**
  String get settingsRescanSubtitle;

  /// No description provided for @settingsRescanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Rescan Library?'**
  String get settingsRescanConfirm;

  /// No description provided for @settingsRescanMessage.
  ///
  /// In en, this message translates to:
  /// **'This will clear cached song data and rescan your library. This may take a while for large libraries.'**
  String get settingsRescanMessage;

  /// No description provided for @settingsRescanButton.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get settingsRescanButton;

  /// No description provided for @settingsVisualizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get settingsVisualizerTitle;

  /// No description provided for @settingsVisualizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable visual effects'**
  String get settingsVisualizerSubtitle;

  /// No description provided for @settingsVisualizerEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled (uses more battery)'**
  String get settingsVisualizerEnabled;

  /// No description provided for @settingsVisualizerDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled (saves battery)'**
  String get settingsVisualizerDisabled;

  /// No description provided for @settingsVisualizerBatterySaving.
  ///
  /// In en, this message translates to:
  /// **'Disable visualizer to save battery'**
  String get settingsVisualizerBatterySaving;

  /// No description provided for @settingsDynamicColorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Colors'**
  String get settingsDynamicColorsTitle;

  /// No description provided for @settingsDynamicColorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coming soon - colors adapt to album art'**
  String get settingsDynamicColorsSubtitle;

  /// No description provided for @settingsDynamicColorsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsDynamicColorsComingSoon;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeTitle;

  /// No description provided for @settingsThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App appearance'**
  String get settingsThemeSubtitle;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLightComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Light theme support coming in a future update!'**
  String get settingsThemeLightComingSoon;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersion;

  /// No description provided for @settingsAboutBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get settingsAboutBuild;

  /// No description provided for @settingsAboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get settingsAboutLicenses;

  /// No description provided for @settingsAboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsAboutPrivacy;

  /// No description provided for @settingsAboutTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsAboutTerms;

  /// No description provided for @settingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Settings'**
  String get settingsResetTitle;

  /// No description provided for @settingsResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore default values'**
  String get settingsResetSubtitle;

  /// No description provided for @settingsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset Settings?'**
  String get settingsResetConfirm;

  /// No description provided for @settingsResetMessage.
  ///
  /// In en, this message translates to:
  /// **'This will restore all settings to their default values. Your playlists and favorites will not be affected.'**
  String get settingsResetMessage;

  /// No description provided for @settingsResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get settingsResetSuccess;

  /// No description provided for @settingsEqualizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get settingsEqualizer;

  /// No description provided for @settingsPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get settingsPlaybackSpeed;

  /// No description provided for @settingsAudioQuality.
  ///
  /// In en, this message translates to:
  /// **'Audio Quality'**
  String get settingsAudioQuality;

  /// No description provided for @settingsAudioQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High quality (native decoding)'**
  String get settingsAudioQualityHigh;

  /// No description provided for @settingsGaplessPlayback.
  ///
  /// In en, this message translates to:
  /// **'Gapless Playback'**
  String get settingsGaplessPlayback;

  /// No description provided for @settingsGaplessPlaybackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always enabled for seamless transitions'**
  String get settingsGaplessPlaybackSubtitle;

  /// No description provided for @settingsCrossfade.
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get settingsCrossfade;

  /// No description provided for @settingsNormalization.
  ///
  /// In en, this message translates to:
  /// **'Volume Normalization'**
  String get settingsNormalization;

  /// No description provided for @settingsReverb.
  ///
  /// In en, this message translates to:
  /// **'Reverb'**
  String get settingsReverb;

  /// No description provided for @settingsPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch Adjustment'**
  String get settingsPitch;

  /// No description provided for @settingsStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get settingsStatistics;

  /// No description provided for @settingsStatisticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play counts, listening time, smart playlists'**
  String get settingsStatisticsSubtitle;

  /// No description provided for @settingsAiGenre.
  ///
  /// In en, this message translates to:
  /// **'AI Genre Detection'**
  String get settingsAiGenre;

  /// No description provided for @settingsAiGenreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Batch classify songs by genre'**
  String get settingsAiGenreSubtitle;

  /// No description provided for @settingsRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan Library'**
  String get settingsRescan;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Library Cache'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset library data (files not deleted)'**
  String get settingsClearCacheSubtitle;

  /// No description provided for @settingsDefaultSort.
  ///
  /// In en, this message translates to:
  /// **'Default Sort'**
  String get settingsDefaultSort;

  /// No description provided for @settingsSortDirection.
  ///
  /// In en, this message translates to:
  /// **'Sort Direction'**
  String get settingsSortDirection;

  /// No description provided for @settingsStripComments.
  ///
  /// In en, this message translates to:
  /// **'Strip Comments on Import'**
  String get settingsStripComments;

  /// No description provided for @settingsStripCommentsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled - comments removed from new songs'**
  String get settingsStripCommentsEnabled;

  /// No description provided for @settingsStripCommentsLibrary.
  ///
  /// In en, this message translates to:
  /// **'Strip Comments from Library'**
  String get settingsStripCommentsLibrary;

  /// No description provided for @settingsStripCommentsLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all comment metadata from songs'**
  String get settingsStripCommentsLibrarySubtitle;

  /// No description provided for @settingsVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Visualizer Animations'**
  String get settingsVisualizer;

  /// No description provided for @settingsDynamicColors.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Colors'**
  String get settingsDynamicColors;

  /// No description provided for @settingsDynamicColorsDescription.
  ///
  /// In en, this message translates to:
  /// **'This feature will automatically adapt the app\'s colors based on the currently playing album art.'**
  String get settingsDynamicColorsDescription;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get settingsAppVersion;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View third-party licenses'**
  String get settingsLicensesSubtitle;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset Settings'**
  String get settingsReset;

  /// No description provided for @toastGaplessAlwaysEnabled.
  ///
  /// In en, this message translates to:
  /// **'Gapless playback is always enabled'**
  String get toastGaplessAlwaysEnabled;

  /// No description provided for @equalizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizerTitle;

  /// No description provided for @equalizerPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get equalizerPresets;

  /// No description provided for @equalizerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get equalizerCustom;

  /// No description provided for @equalizerFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get equalizerFlat;

  /// No description provided for @equalizerBassBooster.
  ///
  /// In en, this message translates to:
  /// **'Bass Booster'**
  String get equalizerBassBooster;

  /// No description provided for @equalizerBassReducer.
  ///
  /// In en, this message translates to:
  /// **'Bass Reducer'**
  String get equalizerBassReducer;

  /// No description provided for @equalizerTrebleBooster.
  ///
  /// In en, this message translates to:
  /// **'Treble Booster'**
  String get equalizerTrebleBooster;

  /// No description provided for @equalizerTrebleReducer.
  ///
  /// In en, this message translates to:
  /// **'Treble Reducer'**
  String get equalizerTrebleReducer;

  /// No description provided for @equalizerVocalBooster.
  ///
  /// In en, this message translates to:
  /// **'Vocal Booster'**
  String get equalizerVocalBooster;

  /// No description provided for @equalizerRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get equalizerRock;

  /// No description provided for @equalizerPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get equalizerPop;

  /// No description provided for @equalizerJazz.
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get equalizerJazz;

  /// No description provided for @equalizerClassical.
  ///
  /// In en, this message translates to:
  /// **'Classical'**
  String get equalizerClassical;

  /// No description provided for @equalizerHipHop.
  ///
  /// In en, this message translates to:
  /// **'Hip-Hop'**
  String get equalizerHipHop;

  /// No description provided for @equalizerElectronic.
  ///
  /// In en, this message translates to:
  /// **'Electronic'**
  String get equalizerElectronic;

  /// No description provided for @equalizerAcoustic.
  ///
  /// In en, this message translates to:
  /// **'Acoustic'**
  String get equalizerAcoustic;

  /// No description provided for @equalizerRnB.
  ///
  /// In en, this message translates to:
  /// **'R&B'**
  String get equalizerRnB;

  /// No description provided for @equalizerLatin.
  ///
  /// In en, this message translates to:
  /// **'Latin'**
  String get equalizerLatin;

  /// No description provided for @equalizerPiano.
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get equalizerPiano;

  /// No description provided for @equalizerSmallSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Small Speakers'**
  String get equalizerSmallSpeakers;

  /// No description provided for @equalizerLoudness.
  ///
  /// In en, this message translates to:
  /// **'Loudness'**
  String get equalizerLoudness;

  /// No description provided for @equalizerLounge.
  ///
  /// In en, this message translates to:
  /// **'Lounge'**
  String get equalizerLounge;

  /// No description provided for @equalizerSpokenWord.
  ///
  /// In en, this message translates to:
  /// **'Spoken Word'**
  String get equalizerSpokenWord;

  /// No description provided for @equalizerSavePreset.
  ///
  /// In en, this message translates to:
  /// **'Save Preset'**
  String get equalizerSavePreset;

  /// No description provided for @equalizerPresetName.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get equalizerPresetName;

  /// No description provided for @equalizerPresetSaved.
  ///
  /// In en, this message translates to:
  /// **'Preset \"{name}\" saved'**
  String equalizerPresetSaved(String name);

  /// No description provided for @equalizerDeletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete Preset'**
  String get equalizerDeletePreset;

  /// No description provided for @equalizerRenamePreset.
  ///
  /// In en, this message translates to:
  /// **'Rename Preset'**
  String get equalizerRenamePreset;

  /// No description provided for @equalizerPresetDeleted.
  ///
  /// In en, this message translates to:
  /// **'Preset deleted'**
  String get equalizerPresetDeleted;

  /// No description provided for @equalizerBandCount.
  ///
  /// In en, this message translates to:
  /// **'10-band equalizer'**
  String get equalizerBandCount;

  /// No description provided for @equalizerBand60Hz.
  ///
  /// In en, this message translates to:
  /// **'60 Hz'**
  String get equalizerBand60Hz;

  /// No description provided for @equalizerBand230Hz.
  ///
  /// In en, this message translates to:
  /// **'230 Hz'**
  String get equalizerBand230Hz;

  /// No description provided for @equalizerBand910Hz.
  ///
  /// In en, this message translates to:
  /// **'910 Hz'**
  String get equalizerBand910Hz;

  /// No description provided for @equalizerBand3600Hz.
  ///
  /// In en, this message translates to:
  /// **'3.6 kHz'**
  String get equalizerBand3600Hz;

  /// No description provided for @equalizerBand14000Hz.
  ///
  /// In en, this message translates to:
  /// **'14 kHz'**
  String get equalizerBand14000Hz;

  /// No description provided for @equalizerBass.
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get equalizerBass;

  /// No description provided for @equalizerMidrange.
  ///
  /// In en, this message translates to:
  /// **'Midrange'**
  String get equalizerMidrange;

  /// No description provided for @equalizerTreble.
  ///
  /// In en, this message translates to:
  /// **'Treble'**
  String get equalizerTreble;

  /// No description provided for @equalizerEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get equalizerEffects;

  /// No description provided for @equalizerBassBoost.
  ///
  /// In en, this message translates to:
  /// **'Bass Boost'**
  String get equalizerBassBoost;

  /// No description provided for @equalizerVirtualizer.
  ///
  /// In en, this message translates to:
  /// **'Virtualizer'**
  String get equalizerVirtualizer;

  /// No description provided for @equalizerSpatialAudio.
  ///
  /// In en, this message translates to:
  /// **'Spatial Audio'**
  String get equalizerSpatialAudio;

  /// No description provided for @equalizerSpatialDescription.
  ///
  /// In en, this message translates to:
  /// **'Immersive 3D sound experience'**
  String get equalizerSpatialDescription;

  /// No description provided for @equalizerSpatialTip.
  ///
  /// In en, this message translates to:
  /// **'For best results, use headphones or earbuds with spatial audio support.'**
  String get equalizerSpatialTip;

  /// No description provided for @equalizerPerSongTitle.
  ///
  /// In en, this message translates to:
  /// **'Per-Song EQ'**
  String get equalizerPerSongTitle;

  /// No description provided for @equalizerPerSongSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remember EQ per Song'**
  String get equalizerPerSongSubtitle;

  /// No description provided for @equalizerPerSongDescription.
  ///
  /// In en, this message translates to:
  /// **'Auto-load saved EQ for each song'**
  String get equalizerPerSongDescription;

  /// No description provided for @equalizerCurrentSong.
  ///
  /// In en, this message translates to:
  /// **'Current Song'**
  String get equalizerCurrentSong;

  /// No description provided for @equalizerSaveForSong.
  ///
  /// In en, this message translates to:
  /// **'Save EQ for This Song'**
  String get equalizerSaveForSong;

  /// No description provided for @equalizerClearForSong.
  ///
  /// In en, this message translates to:
  /// **'Clear Song EQ'**
  String get equalizerClearForSong;

  /// No description provided for @equalizerSongEqSaved.
  ///
  /// In en, this message translates to:
  /// **'EQ saved for \"{title}\"'**
  String equalizerSongEqSaved(String title);

  /// No description provided for @equalizerSongEqCleared.
  ///
  /// In en, this message translates to:
  /// **'Song EQ cleared'**
  String get equalizerSongEqCleared;

  /// No description provided for @equalizerCustomEqLoaded.
  ///
  /// In en, this message translates to:
  /// **'Custom EQ loaded for this song'**
  String get equalizerCustomEqLoaded;

  /// No description provided for @equalizerResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get equalizerResetToDefault;

  /// No description provided for @reverbTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverb'**
  String get reverbTitle;

  /// No description provided for @reverbOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reverbOff;

  /// No description provided for @reverbSmallRoom.
  ///
  /// In en, this message translates to:
  /// **'Small Room'**
  String get reverbSmallRoom;

  /// No description provided for @reverbMediumRoom.
  ///
  /// In en, this message translates to:
  /// **'Medium Room'**
  String get reverbMediumRoom;

  /// No description provided for @reverbLargeRoom.
  ///
  /// In en, this message translates to:
  /// **'Large Room'**
  String get reverbLargeRoom;

  /// No description provided for @reverbMediumHall.
  ///
  /// In en, this message translates to:
  /// **'Medium Hall'**
  String get reverbMediumHall;

  /// No description provided for @reverbLargeHall.
  ///
  /// In en, this message translates to:
  /// **'Large Hall'**
  String get reverbLargeHall;

  /// No description provided for @reverbPlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get reverbPlate;

  /// No description provided for @visualizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get visualizerTitle;

  /// No description provided for @visualizerOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get visualizerOff;

  /// No description provided for @visualizerResonance.
  ///
  /// In en, this message translates to:
  /// **'Resonance'**
  String get visualizerResonance;

  /// No description provided for @visualizerRipples.
  ///
  /// In en, this message translates to:
  /// **'Ripples'**
  String get visualizerRipples;

  /// No description provided for @visualizerHarmonograph.
  ///
  /// In en, this message translates to:
  /// **'Harmonograph'**
  String get visualizerHarmonograph;

  /// No description provided for @visualizerCelestialHalos.
  ///
  /// In en, this message translates to:
  /// **'Celestial Halos'**
  String get visualizerCelestialHalos;

  /// No description provided for @visualizerAurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get visualizerAurora;

  /// No description provided for @visualizerSpirograph.
  ///
  /// In en, this message translates to:
  /// **'Spirograph'**
  String get visualizerSpirograph;

  /// No description provided for @visualizerVoronoi.
  ///
  /// In en, this message translates to:
  /// **'Voronoi'**
  String get visualizerVoronoi;

  /// No description provided for @visualizerSunflower.
  ///
  /// In en, this message translates to:
  /// **'Sunflower'**
  String get visualizerSunflower;

  /// No description provided for @visualizerAttractors.
  ///
  /// In en, this message translates to:
  /// **'Attractors'**
  String get visualizerAttractors;

  /// No description provided for @visualizerMoire.
  ///
  /// In en, this message translates to:
  /// **'Moiré'**
  String get visualizerMoire;

  /// No description provided for @visualizerPendulum.
  ///
  /// In en, this message translates to:
  /// **'Pendulum'**
  String get visualizerPendulum;

  /// No description provided for @visualizerFlames.
  ///
  /// In en, this message translates to:
  /// **'Flames'**
  String get visualizerFlames;

  /// No description provided for @visualizerFractal.
  ///
  /// In en, this message translates to:
  /// **'Fractal'**
  String get visualizerFractal;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statsOverview;

  /// No description provided for @statsTotalListening.
  ///
  /// In en, this message translates to:
  /// **'Total Listening'**
  String get statsTotalListening;

  /// No description provided for @statsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get statsThisWeek;

  /// No description provided for @statsSongsPlayed.
  ///
  /// In en, this message translates to:
  /// **'Songs Played'**
  String get statsSongsPlayed;

  /// No description provided for @statsUniqueSongs.
  ///
  /// In en, this message translates to:
  /// **'Unique Songs'**
  String get statsUniqueSongs;

  /// No description provided for @statsLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get statsLast7Days;

  /// No description provided for @statsSmartPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Smart Playlists'**
  String get statsSmartPlaylists;

  /// No description provided for @statsNoSongsYet.
  ///
  /// In en, this message translates to:
  /// **'No songs yet'**
  String get statsNoSongsYet;

  /// No description provided for @statsNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No listening data yet'**
  String get statsNoDataYet;

  /// No description provided for @statsDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get statsDayMon;

  /// No description provided for @statsDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get statsDayTue;

  /// No description provided for @statsDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get statsDayWed;

  /// No description provided for @statsDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get statsDayThu;

  /// No description provided for @statsDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get statsDayFri;

  /// No description provided for @statsDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get statsDaySat;

  /// No description provided for @statsDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get statsDaySun;

  /// No description provided for @statsHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hours'**
  String statsHours(int count);

  /// No description provided for @statsMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String statsMinutes(int count);

  /// No description provided for @lyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsTitle;

  /// No description provided for @lyricsNotFound.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found'**
  String get lyricsNotFound;

  /// No description provided for @lyricsInstructions.
  ///
  /// In en, this message translates to:
  /// **'Place a .lrc file with the same name as the audio file to see lyrics'**
  String get lyricsInstructions;

  /// No description provided for @lyricsUnsynchronized.
  ///
  /// In en, this message translates to:
  /// **'Unsynchronized lyrics'**
  String get lyricsUnsynchronized;

  /// No description provided for @lyricsEmbedded.
  ///
  /// In en, this message translates to:
  /// **'Embedded lyrics'**
  String get lyricsEmbedded;

  /// No description provided for @lyricsExternal.
  ///
  /// In en, this message translates to:
  /// **'External .lrc file'**
  String get lyricsExternal;

  /// No description provided for @tagEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Tags'**
  String get tagEditorTitle;

  /// No description provided for @tagEditorFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get tagEditorFieldTitle;

  /// No description provided for @tagEditorFieldArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get tagEditorFieldArtist;

  /// No description provided for @tagEditorFieldAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get tagEditorFieldAlbum;

  /// No description provided for @tagEditorFieldGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get tagEditorFieldGenre;

  /// No description provided for @tagEditorFieldYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get tagEditorFieldYear;

  /// No description provided for @tagEditorFieldTrack.
  ///
  /// In en, this message translates to:
  /// **'Track #'**
  String get tagEditorFieldTrack;

  /// No description provided for @tagEditorFieldComposer.
  ///
  /// In en, this message translates to:
  /// **'Composer'**
  String get tagEditorFieldComposer;

  /// No description provided for @tagEditorFieldBpm.
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get tagEditorFieldBpm;

  /// No description provided for @tagEditorFieldLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get tagEditorFieldLyrics;

  /// No description provided for @tagEditorArtwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get tagEditorArtwork;

  /// No description provided for @tagEditorChangeArtwork.
  ///
  /// In en, this message translates to:
  /// **'Change Artwork'**
  String get tagEditorChangeArtwork;

  /// No description provided for @tagEditorRemoveArtwork.
  ///
  /// In en, this message translates to:
  /// **'Remove Artwork'**
  String get tagEditorRemoveArtwork;

  /// No description provided for @tagEditorSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get tagEditorSaveChanges;

  /// No description provided for @tagEditorDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get tagEditorDiscardChanges;

  /// No description provided for @tagEditorUnsavedMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Do you want to discard them?'**
  String get tagEditorUnsavedMessage;

  /// No description provided for @tagEditorSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tags saved successfully'**
  String get tagEditorSaveSuccess;

  /// No description provided for @tagEditorSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save tags'**
  String get tagEditorSaveError;

  /// No description provided for @tagEditorPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get tagEditorPermissionRequired;

  /// No description provided for @tagEditorPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'To modify music files, VibePlay needs \"All files access\" permission.'**
  String get tagEditorPermissionMessage;

  /// No description provided for @tagEditorPermissionInstruction.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Open Settings\" and enable \"Allow access to manage all files\".'**
  String get tagEditorPermissionInstruction;

  /// No description provided for @tagEditorFindReplace.
  ///
  /// In en, this message translates to:
  /// **'Find & Replace'**
  String get tagEditorFindReplace;

  /// No description provided for @tagEditorFind.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get tagEditorFind;

  /// No description provided for @tagEditorReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get tagEditorReplace;

  /// No description provided for @tagEditorReplaceWith.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get tagEditorReplaceWith;

  /// No description provided for @tagEditorCaseSensitive.
  ///
  /// In en, this message translates to:
  /// **'Case sensitive'**
  String get tagEditorCaseSensitive;

  /// No description provided for @tagEditorWholeWord.
  ///
  /// In en, this message translates to:
  /// **'Whole word'**
  String get tagEditorWholeWord;

  /// No description provided for @tagEditorInTitle.
  ///
  /// In en, this message translates to:
  /// **'In Title'**
  String get tagEditorInTitle;

  /// No description provided for @tagEditorInArtist.
  ///
  /// In en, this message translates to:
  /// **'In Artist'**
  String get tagEditorInArtist;

  /// No description provided for @tagEditorInAlbum.
  ///
  /// In en, this message translates to:
  /// **'In Album'**
  String get tagEditorInAlbum;

  /// No description provided for @tagEditorMatchesFound.
  ///
  /// In en, this message translates to:
  /// **'{count} matches found'**
  String tagEditorMatchesFound(int count);

  /// No description provided for @tagEditorNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get tagEditorNoMatches;

  /// No description provided for @tagEditorReplaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace All'**
  String get tagEditorReplaceAll;

  /// No description provided for @tagEditorReplaceSuccess.
  ///
  /// In en, this message translates to:
  /// **'Replaced {count} occurrences'**
  String tagEditorReplaceSuccess(int count);

  /// No description provided for @tagEditorRemoveUrls.
  ///
  /// In en, this message translates to:
  /// **'Remove URL Tags'**
  String get tagEditorRemoveUrls;

  /// No description provided for @tagEditorRemoveUrlsMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove WOAS, WOAR and other URL tags from the selected song?'**
  String get tagEditorRemoveUrlsMessage;

  /// No description provided for @tagEditorUrlsRemoved.
  ///
  /// In en, this message translates to:
  /// **'URL tags removed'**
  String get tagEditorUrlsRemoved;

  /// No description provided for @genreDetection.
  ///
  /// In en, this message translates to:
  /// **'Genre Detection'**
  String get genreDetection;

  /// No description provided for @genreDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting genre...'**
  String get genreDetecting;

  /// No description provided for @genreDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected: {genre}'**
  String genreDetected(String genre);

  /// No description provided for @genreDetectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not detect genre'**
  String get genreDetectionFailed;

  /// No description provided for @genreApply.
  ///
  /// In en, this message translates to:
  /// **'Apply Genre'**
  String get genreApply;

  /// No description provided for @genreApplied.
  ///
  /// In en, this message translates to:
  /// **'Genre applied: {genre}'**
  String genreApplied(String genre);

  /// No description provided for @youtubeUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload to YouTube'**
  String get youtubeUploadTitle;

  /// No description provided for @youtubeSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get youtubeSignIn;

  /// No description provided for @youtubeSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get youtubeSignOut;

  /// No description provided for @youtubeSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String youtubeSignedInAs(String name);

  /// No description provided for @youtubeGeneratingVideo.
  ///
  /// In en, this message translates to:
  /// **'Generating video...'**
  String get youtubeGeneratingVideo;

  /// No description provided for @youtubeUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading to YouTube...'**
  String get youtubeUploading;

  /// No description provided for @youtubeUploadProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading: {percent}%'**
  String youtubeUploadProgress(int percent);

  /// No description provided for @youtubeUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Upload complete!'**
  String get youtubeUploadComplete;

  /// No description provided for @youtubeUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get youtubeUploadFailed;

  /// No description provided for @youtubeViewVideo.
  ///
  /// In en, this message translates to:
  /// **'View Video'**
  String get youtubeViewVideo;

  /// No description provided for @youtubeShareAudio.
  ///
  /// In en, this message translates to:
  /// **'Or share audio file'**
  String get youtubeShareAudio;

  /// No description provided for @youtubePrivacyPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get youtubePrivacyPublic;

  /// No description provided for @youtubePrivacyUnlisted.
  ///
  /// In en, this message translates to:
  /// **'Unlisted'**
  String get youtubePrivacyUnlisted;

  /// No description provided for @youtubePrivacyPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get youtubePrivacyPrivate;

  /// No description provided for @songInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Song Info'**
  String get songInfoTitle;

  /// No description provided for @songInfoDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get songInfoDuration;

  /// No description provided for @songInfoBitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get songInfoBitrate;

  /// No description provided for @songInfoSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get songInfoSampleRate;

  /// No description provided for @songInfoFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get songInfoFormat;

  /// No description provided for @songInfoSize.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get songInfoSize;

  /// No description provided for @songInfoPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get songInfoPath;

  /// No description provided for @songInfoPlayCount.
  ///
  /// In en, this message translates to:
  /// **'Play Count'**
  String get songInfoPlayCount;

  /// No description provided for @songInfoLastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last Played'**
  String get songInfoLastPlayed;

  /// No description provided for @songInfoDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get songInfoDateAdded;

  /// No description provided for @songInfoCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Path'**
  String get songInfoCopyPath;

  /// No description provided for @songInfoPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard'**
  String get songInfoPathCopied;

  /// No description provided for @dialogDeleteSong.
  ///
  /// In en, this message translates to:
  /// **'Delete Song'**
  String get dialogDeleteSong;

  /// No description provided for @dialogDeleteSongMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this song? This cannot be undone.'**
  String get dialogDeleteSongMessage;

  /// No description provided for @dialogDeletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist?'**
  String get dialogDeletePlaylist;

  /// No description provided for @dialogDeletePlaylistMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String dialogDeletePlaylistMessage(String name);

  /// No description provided for @dialogPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get dialogPermissionRequired;

  /// No description provided for @dialogPermissionStorageMessage.
  ///
  /// In en, this message translates to:
  /// **'VibePlay needs storage permission to access your music library.'**
  String get dialogPermissionStorageMessage;

  /// No description provided for @dialogPermissionMicrophoneMessage.
  ///
  /// In en, this message translates to:
  /// **'VibePlay needs microphone permission for the audio visualizer.'**
  String get dialogPermissionMicrophoneMessage;

  /// No description provided for @dialogResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get dialogResetConfirm;

  /// No description provided for @toastAddedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to Favorites'**
  String get toastAddedToFavorites;

  /// No description provided for @toastRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from Favorites'**
  String get toastRemovedFromFavorites;

  /// No description provided for @toastLibraryScanComplete.
  ///
  /// In en, this message translates to:
  /// **'Library scan complete!'**
  String get toastLibraryScanComplete;

  /// No description provided for @toastLibraryCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Library cache cleared. Rescanning...'**
  String get toastLibraryCacheCleared;

  /// No description provided for @toastNoInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get toastNoInternetConnection;

  /// No description provided for @toastFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This feature is coming soon!'**
  String get toastFeatureComingSoon;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get errorLoadFailed;

  /// No description provided for @errorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get errorSaveFailed;

  /// No description provided for @errorNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get errorNetworkError;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get errorPermissionDenied;

  /// No description provided for @errorFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get errorFileNotFound;

  /// No description provided for @errorPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed'**
  String get errorPlaybackFailed;

  /// No description provided for @errorInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid format'**
  String get errorInvalidFormat;

  /// No description provided for @timeHours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get timeHours;

  /// No description provided for @timeMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get timeMinutes;

  /// No description provided for @timeSeconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get timeSeconds;

  /// No description provided for @timeAgo.
  ///
  /// In en, this message translates to:
  /// **'{time} ago'**
  String timeAgo(String time);

  /// No description provided for @timeNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get timeNever;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get timeToday;

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// No description provided for @menuAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get menuAddToPlaylist;

  /// No description provided for @menuAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get menuAddToQueue;

  /// No description provided for @menuPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get menuPlayNext;

  /// No description provided for @menuGoToArtist.
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get menuGoToArtist;

  /// No description provided for @menuGoToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get menuGoToAlbum;

  /// No description provided for @menuSongInfo.
  ///
  /// In en, this message translates to:
  /// **'Song Info'**
  String get menuSongInfo;

  /// No description provided for @menuEditTags.
  ///
  /// In en, this message translates to:
  /// **'Edit Tags'**
  String get menuEditTags;

  /// No description provided for @menuShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get menuShare;

  /// No description provided for @menuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get menuDelete;

  /// No description provided for @menuUploadToYoutube.
  ///
  /// In en, this message translates to:
  /// **'Upload to YouTube'**
  String get menuUploadToYoutube;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['bn', 'en', 'es', 'fr', 'ja', 'my', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn': return AppLocalizationsBn();
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
    case 'ja': return AppLocalizationsJa();
    case 'my': return AppLocalizationsMy();
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
