import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:id3_codec/id3_codec.dart';
import 'package:path_provider/path_provider.dart';
import 'models/editable_tags.dart';
import '../../../services/log_service.dart';

/// Service for reading and writing audio file tags
/// Supports MP3 files (ID3v1, ID3v2.3, ID3v2.4)
class TagEditorService {
  /// Supported file extensions (MP3 only for now)
  static const supportedExtensions = ['mp3'];

  /// Check if a file format is supported for tag editing
  bool isFormatSupported(String? path) {
    if (path == null) return false;
    final ext = path.split('.').last.toLowerCase();
    return supportedExtensions.contains(ext);
  }

  /// Read all tags from an audio file
  Future<EditableTags?> readTags(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final decoder = ID3Decoder(bytes);
      final metadataList = decoder.decodeSync();

      if (metadataList.isEmpty) {
        return const EditableTags();
      }

      // Merge all metadata from different ID3 versions
      final mergedMap = <String, dynamic>{};
      for (final metadata in metadataList) {
        final tagMap = metadata.toTagMap();
        // Merge, preferring later values (ID3v2 over ID3v1)
        mergedMap.addAll(tagMap);
      }

      // Debug: print available keys and structure
      Log.d('TagEditorService: Top-level keys: ${mergedMap.keys.toList()}');

      // Print structure for debugging
      mergedMap.forEach((key, value) {
        if (key == 'Frames' && value is List) {
          Log.d('TagEditorService: Frames list has ${value.length} items');
          for (int i = 0; i < value.length && i < 5; i++) {
            final frame = value[i];
            if (frame is Map) {
              Log.d('TagEditorService: Frame $i keys: ${frame.keys.toList()}');
            }
          }
        } else if (key != 'Padding') {
          Log.d('TagEditorService: $key = ${value.runtimeType}: ${value.toString().substring(0, value.toString().length > 100 ? 100 : value.toString().length)}');
        }
      });

      // The actual frames are nested inside 'Frames' key
      // Each frame has: {Frame ID: "TIT2", Frame Size: 39, Frame Flags: ..., Content: {...}}
      // We need to map Frame ID -> Content
      Map<String, dynamic> framesMap = {};
      if (mergedMap.containsKey('Frames') && mergedMap['Frames'] is List) {
        final framesList = mergedMap['Frames'] as List;
        for (final frame in framesList) {
          if (frame is Map) {
            final frameId = frame['Frame ID'];
            final content = frame['Content'];
            if (frameId != null && content != null) {
              framesMap[frameId.toString()] = content;
              Log.d('TagEditorService: Parsed frame $frameId -> $content');
            }
          }
        }
      }
      // Also check for direct ID3v1 tags (Title, Artist, Album, etc.)
      mergedMap.forEach((key, value) {
        if (key != 'Header' && key != 'Frames' && key != 'Padding') {
          framesMap[key] = value;
        }
      });

      // Also extract TXXX (user-defined text) frames by their description
      // These are stored as TXXX with {Description: "GENRE", Value: "Classical"}
      // We map them to standard keys for easier lookup
      if (mergedMap.containsKey('Frames') && mergedMap['Frames'] is List) {
        final framesList = mergedMap['Frames'] as List;
        for (final frame in framesList) {
          if (frame is Map && frame['Frame ID'] == 'TXXX') {
            final content = frame['Content'];
            if (content is Map) {
              final desc = content['Description']?.toString();
              final value = content['Value']?.toString();
              if (desc != null && value != null && value.isNotEmpty) {
                // Map common descriptions to their standard frame IDs
                // This handles files where genre/year are stored in TXXX instead of TCON/TYER
                final mappings = {
                  'GENRE': 'TCON',
                  'YEAR': 'TYER',
                  'ALBUMARTIST': 'TPE2',
                  'COMPOSER': 'TCOM',
                  'BPM': 'TBPM',
                  'COMMENT': 'COMM',
                };
                final mappedKey = mappings[desc.toUpperCase()] ?? desc;
                // Only set if not already present from standard frame
                if (!framesMap.containsKey(mappedKey)) {
                  framesMap[mappedKey] = {'Information': value};
                  Log.d('TagEditorService: Mapped TXXX $desc -> $mappedKey = $value');
                }
              }
            }
          }
        }
      }

      Log.d('TagEditorService: Final framesMap keys: ${framesMap.keys.toList()}');
      // Print some actual values
      framesMap.forEach((key, value) {
        final valStr = value.toString();
        if (valStr.length < 200) {
          Log.d('TagEditorService: framesMap[$key] = ${value.runtimeType}: $valStr');
        } else {
          Log.d('TagEditorService: framesMap[$key] = ${value.runtimeType}: ${valStr.substring(0, 200)}...');
        }
      });

      // Helper to get value from tag map (handles nested structures)
      String? getString(String key) {
        var value = framesMap[key];
        if (value == null) {
          Log.d('TagEditorService: getString("$key") = null (key not found)');
          return null;
        }

        Log.d('TagEditorService: getString("$key") raw type=${value.runtimeType}, value=${value.toString().substring(0, value.toString().length > 100 ? 100 : value.toString().length)}');

        // Handle nested map structures (common in id3_codec)
        // Standard frames use: {Information: "text"} or {Information: "text", Encoding: 3}
        // User-defined TXXX frames use: {Description: "key", Value: "text"}
        if (value is Map) {
          // Try common nested keys used by id3_codec
          final candidates = [
            value['Information'],  // Standard ID3v2 text frames (TIT2, TPE1, TALB, etc.)
            value['Value'],        // TXXX user-defined frames
            value['value'],
            value['text'],
            value['content'],
            value['Text'],
            value['Content'],
          ];
          for (final candidate in candidates) {
            if (candidate != null && candidate.toString().trim().isNotEmpty) {
              value = candidate;
              break;
            }
          }
          // If still a Map, try first non-numeric value
          if (value is Map) {
            for (final v in value.values) {
              if (v != null && v is! int && v.toString().trim().isNotEmpty) {
                value = v;
                break;
              }
            }
          }
        }

        // Handle list structures
        if (value is List && value.isNotEmpty) {
          value = value.first;
          if (value is Map) {
            value = value['value'] ?? value['text'] ?? value['content'] ?? value.values.firstOrNull;
          }
        }

        if (value == null) {
          Log.d('TagEditorService: getString("$key") = null (after extraction)');
          return null;
        }
        final str = value.toString().trim();
        Log.d('TagEditorService: getString("$key") extracted = "$str"');
        return str.isEmpty ? null : str;
      }

      // Parse track number (may be in format "1/10" or just a number)
      int? trackNumber;
      int? totalTracks;
      final track = getString('TRCK') ?? getString('Track');
      if (track != null && track.isNotEmpty) {
        if (track.contains('/')) {
          final parts = track.split('/');
          trackNumber = int.tryParse(parts[0]);
          if (parts.length > 1) {
            totalTracks = int.tryParse(parts[1]);
          }
        } else {
          trackNumber = int.tryParse(track);
        }
      }

      // Parse disc number
      int? discNumber;
      int? totalDiscs;
      final disc = getString('TPOS');
      if (disc != null && disc.isNotEmpty) {
        if (disc.contains('/')) {
          final parts = disc.split('/');
          discNumber = int.tryParse(parts[0]);
          if (parts.length > 1) {
            totalDiscs = int.tryParse(parts[1]);
          }
        } else {
          discNumber = int.tryParse(disc);
        }
      }

      // Get artwork from APIC frame
      // id3_codec returns: {MIME: "image/jpeg", PictureType: "...", Description: "...", Base64: "...", PictureData: [...]}
      Uint8List? artwork;
      final apic = framesMap['APIC'];
      if (apic != null) {
        Log.d('TagEditorService: APIC frame found, type=${apic.runtimeType}');
        if (apic is Map) {
          Log.d('TagEditorService: APIC keys: ${apic.keys.toList()}');
          // Try different keys that id3_codec might use
          var imageData = apic['PictureData'] ?? apic['data'] ?? apic['imageData'] ?? apic['bytes'];

          // If Base64, decode it
          if (imageData == null && apic['Base64'] != null) {
            try {
              final base64Str = apic['Base64'].toString();
              if (base64Str.isNotEmpty && !base64Str.startsWith('<')) {
                imageData = base64Decode(base64Str);
                Log.d('TagEditorService: Decoded Base64 artwork, ${imageData.length} bytes');
              }
            } catch (e) {
              Log.d('TagEditorService: Failed to decode Base64 artwork: $e');
            }
          }

          if (imageData != null && imageData is List) {
            artwork = Uint8List.fromList(List<int>.from(imageData));
            Log.d('TagEditorService: Extracted artwork, ${artwork.length} bytes');
          }
        } else if (apic is List<int>) {
          artwork = Uint8List.fromList(apic);
          Log.d('TagEditorService: APIC was raw bytes, ${artwork.length} bytes');
        }
      }

      // Get lyrics from USLT frame
      String? lyrics;
      final uslt = framesMap['USLT'];
      if (uslt != null) {
        if (uslt is Map) {
          lyrics = (uslt['lyrics'] ?? uslt['Lyrics'] ?? uslt['text'] ?? uslt['content'])?.toString();
        } else if (uslt is String) {
          lyrics = uslt;
        }
      }

      final title = getString('TIT2') ?? getString('Title');
      final artist = getString('TPE1') ?? getString('Artist');
      final album = getString('TALB') ?? getString('Album');
      final albumArtist = getString('TPE2');
      final genre = getString('TCON') ?? getString('Genre');
      final yearStr = getString('TYER') ?? getString('TDRC') ?? getString('Year');
      final year = int.tryParse(yearStr ?? '');
      final composer = getString('TCOM');
      final bpmStr = getString('TBPM');
      final bpm = int.tryParse(bpmStr ?? '');
      final comment = getString('COMM');

      Log.d('TagEditorService: ========= PARSED TAGS SUMMARY =========');
      Log.d('TagEditorService: title=$title');
      Log.d('TagEditorService: artist=$artist');
      Log.d('TagEditorService: album=$album');
      Log.d('TagEditorService: albumArtist=$albumArtist');
      Log.d('TagEditorService: genre=$genre');
      Log.d('TagEditorService: year=$year');
      Log.d('TagEditorService: trackNumber=$trackNumber, totalTracks=$totalTracks');
      Log.d('TagEditorService: discNumber=$discNumber, totalDiscs=$totalDiscs');
      Log.d('TagEditorService: composer=$composer');
      Log.d('TagEditorService: bpm=$bpm');
      Log.d('TagEditorService: comment=$comment');
      Log.d('TagEditorService: lyrics=${lyrics != null ? "(${lyrics.length} chars)" : "null"}');
      Log.d('TagEditorService: artwork=${artwork != null ? "(${artwork.length} bytes)" : "null"}');
      Log.d('TagEditorService: ======================================');

      return EditableTags(
        title: title,
        artist: artist,
        album: album,
        albumArtist: albumArtist,
        genre: genre,
        year: year,
        trackNumber: trackNumber,
        totalTracks: totalTracks,
        discNumber: discNumber,
        totalDiscs: totalDiscs,
        composer: composer,
        bpm: bpm,
        comment: comment,
        lyrics: lyrics,
        artwork: artwork,
      );
    } catch (e, stack) {
      Log.d('TagEditorService: Failed to read tags from $filePath: $e');
      Log.d('TagEditorService: Stack trace: $stack');
      return null;
    }
  }

  /// Write tags to an audio file
  /// Note: id3_codec has limited write support - only title, artist, album, and artwork
  /// Other fields will be preserved from existing tags where possible
  Future<TagWriteResult> writeTags(String filePath, EditableTags tags) async {
    if (!isFormatSupported(filePath)) {
      return TagWriteResult(
        success: false,
        error: 'Only MP3 files are supported for tag editing',
        filePath: filePath,
      );
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return TagWriteResult(
          success: false,
          error: 'File not found',
          filePath: filePath,
        );
      }

      Log.d('TagEditorService: Writing tags to $filePath');
      Log.d('TagEditorService: Title=${tags.title}, Artist=${tags.artist}, Album=${tags.album}');
      Log.d('TagEditorService: Genre=${tags.genre}, Year=${tags.year}');

      // Count non-null core fields
      int nonNullFields = 0;
      if (tags.title != null) nonNullFields++;
      if (tags.artist != null) nonNullFields++;
      if (tags.album != null) nonNullFields++;
      if (tags.genre != null) nonNullFields++;
      if (tags.year != null) nonNullFields++;

      if (nonNullFields == 0) {
        Log.d('TagEditorService: WARNING - All core tag fields are null! Nothing meaningful to write.');
        Log.d('TagEditorService: This might indicate a problem with tag reading.');
      }

      final bytes = await file.readAsBytes();
      final originalSize = bytes.length;
      Log.d('TagEditorService: Original file size: $originalSize bytes');

      // Check existing ID3 header
      if (bytes.length >= 10) {
        final hasId3v2 = bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33; // "ID3"
        Log.d('TagEditorService: File has ID3v2 header: $hasId3v2');
        if (hasId3v2) {
          final majorVersion = bytes[3];
          final minorVersion = bytes[4];
          Log.d('TagEditorService: ID3v2.$majorVersion.$minorVersion detected');
        }
      }

      final encoder = ID3Encoder(bytes);

      // Build user defines for additional fields (TXXX frames)
      final userDefines = <String, String>{};
      if (tags.genre != null) userDefines['TCON'] = tags.genre!;  // Use proper frame ID
      if (tags.year != null) userDefines['TYER'] = tags.year.toString();
      if (tags.composer != null) userDefines['TCOM'] = tags.composer!;
      if (tags.comment != null) userDefines['COMM'] = tags.comment!;
      if (tags.albumArtist != null) userDefines['TPE2'] = tags.albumArtist!;
      if (tags.trackNumber != null) {
        if (tags.totalTracks != null) {
          userDefines['TRCK'] = '${tags.trackNumber}/${tags.totalTracks}';
        } else {
          userDefines['TRCK'] = tags.trackNumber.toString();
        }
      }
      if (tags.lyrics != null) userDefines['USLT'] = tags.lyrics!;
      if (tags.bpm != null) userDefines['TBPM'] = tags.bpm.toString();

      Log.d('TagEditorService: userDefines to write: $userDefines');

      // Encode as ID3v2.3
      final resultBytes = encoder.encodeSync(MetadataV2p3Body(
        title: tags.title,
        artist: tags.artist,
        album: tags.album,
        imageBytes: tags.artwork,
        userDefines: userDefines.isNotEmpty ? userDefines : null,
      ));

      final newSize = resultBytes.length;
      Log.d('TagEditorService: New file size: $newSize bytes');

      // Check if bytes actually changed
      bool bytesChanged = false;
      if (originalSize != newSize) {
        bytesChanged = true;
        Log.d('TagEditorService: File size changed from $originalSize to $newSize');
      } else {
        // Compare first 1000 bytes to see if anything changed
        int diffCount = 0;
        final compareLen = originalSize < 1000 ? originalSize : 1000;
        for (int i = 0; i < compareLen; i++) {
          if (bytes[i] != resultBytes[i]) {
            diffCount++;
          }
        }
        bytesChanged = diffCount > 0;
        Log.d('TagEditorService: Byte comparison (first $compareLen bytes): $diffCount differences');
      }

      if (!bytesChanged) {
        Log.d('TagEditorService: WARNING - Encoder did not modify the file bytes!');
        Log.d('TagEditorService: This could mean the id3_codec encoder is not working properly');
        Log.d('TagEditorService: or the tags being written are identical to existing tags');
        // If nothing changed but we have values to write, this might indicate an encoder issue
        if (tags.title != null || tags.artist != null || tags.album != null) {
          Log.d('TagEditorService: We have non-null values but encoder didn\'t modify - possible encoder bug');
        }
      }

      if (resultBytes.isEmpty) {
        Log.d('TagEditorService: ERROR - Encoder returned empty bytes!');
        return TagWriteResult(
          success: false,
          error: 'Encoder returned empty data',
          filePath: filePath,
        );
      }

      // Write back to file using cache directory for temp file (better Android compatibility)
      final cacheDir = await getTemporaryDirectory();
      final fileName = filePath.split('/').last.split('\\').last;
      final tempFile = File('${cacheDir.path}/tag_edit_$fileName');

      try {
        // Write to temp file in cache directory first
        await tempFile.writeAsBytes(resultBytes, flush: true);
        Log.d('TagEditorService: Wrote temp file: ${tempFile.path}');

        // Verify temp file was written correctly
        final tempSize = await tempFile.length();
        if (tempSize != newSize) {
          Log.d('TagEditorService: ERROR - Temp file size mismatch: expected $newSize, got $tempSize');
          await tempFile.delete();
          return TagWriteResult(
            success: false,
            error: 'Failed to write temporary file correctly',
            filePath: filePath,
          );
        }

        // Now copy the temp file content to the original file
        // This approach works better with Android storage permissions
        final tempBytes = await tempFile.readAsBytes();
        await file.writeAsBytes(tempBytes, flush: true);
        Log.d('TagEditorService: Copied temp file to original location');

        // Clean up temp file
        await tempFile.delete();

        // Verify final file
        final verifySize = await file.length();
        Log.d('TagEditorService: Verified file size after write: $verifySize bytes');

        if (verifySize != newSize) {
          Log.d('TagEditorService: WARNING - Final file size mismatch! Expected $newSize, got $verifySize');
          return TagWriteResult(
            success: false,
            error: 'File write verification failed',
            filePath: filePath,
          );
        }

        // Verify the tags were actually written by reading them back
        Log.d('TagEditorService: Verifying written tags...');
        final verifyBytes = await file.readAsBytes();

        // Check new ID3 header
        if (verifyBytes.length >= 10) {
          final hasId3v2 = verifyBytes[0] == 0x49 && verifyBytes[1] == 0x44 && verifyBytes[2] == 0x33;
          Log.d('TagEditorService: After write - has ID3v2: $hasId3v2');
          if (hasId3v2) {
            Log.d('TagEditorService: After write - ID3v2.${verifyBytes[3]}.${verifyBytes[4]}');
          }
        }

        final verifyDecoder = ID3Decoder(verifyBytes);
        final verifyMetadataList = verifyDecoder.decodeSync();
        Log.d('TagEditorService: Verification - found ${verifyMetadataList.length} metadata blocks');

        if (verifyMetadataList.isNotEmpty) {
          for (int i = 0; i < verifyMetadataList.length; i++) {
            final verifyMap = verifyMetadataList[i].toTagMap();
            Log.d('TagEditorService: Verification block $i keys: ${verifyMap.keys.toList()}');

            // Check for Frames and print their content
            if (verifyMap.containsKey('Frames') && verifyMap['Frames'] is List) {
              final frames = verifyMap['Frames'] as List;
              Log.d('TagEditorService: Verification block $i has ${frames.length} frames');
              for (int j = 0; j < frames.length && j < 10; j++) {
                final frame = frames[j];
                if (frame is Map) {
                  Log.d('TagEditorService: Verification frame $j: ${frame.keys.toList()}');
                  frame.forEach((key, value) {
                    final valStr = value.toString();
                    Log.d('TagEditorService:   $key = ${valStr.substring(0, valStr.length > 80 ? 80 : valStr.length)}');
                  });
                }
              }
            }
          }
        }

        Log.d('TagEditorService: Successfully wrote tags to $filePath');
        return TagWriteResult(success: true, filePath: filePath);
      } catch (writeError) {
        Log.d('TagEditorService: Write error: $writeError');
        // Clean up temp file if it exists
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
        rethrow;
      }
    } catch (e, stack) {
      Log.d('TagEditorService: ERROR writing tags: $e');
      Log.d('TagEditorService: Stack trace: $stack');
      return TagWriteResult(
        success: false,
        error: e.toString(),
        filePath: filePath,
      );
    }
  }

  /// Write tags to multiple files (batch operation)
  Stream<BatchWriteProgress> writeBatchTags(
    Map<String, EditableTags> pathsAndTags,
  ) async* {
    final total = pathsAndTags.length;
    var completed = 0;
    final errors = <String>[];

    for (final entry in pathsAndTags.entries) {
      final result = await writeTags(entry.key, entry.value);
      completed++;

      if (!result.success) {
        errors.add('${_getFileName(entry.key)}: ${result.error}');
      }

      yield BatchWriteProgress(
        completed: completed,
        total: total,
        errors: errors,
        currentFile: _getFileName(entry.key),
      );
    }
  }

  /// Remove artwork from a file
  Future<TagWriteResult> removeArtwork(String filePath) async {
    try {
      final existingTags = await readTags(filePath);
      if (existingTags == null) {
        return TagWriteResult(
          success: false,
          error: 'Could not read existing tags',
          filePath: filePath,
        );
      }

      final tagsWithoutArtwork = existingTags.copyWith(clearArtwork: true);
      return writeTags(filePath, tagsWithoutArtwork);
    } catch (e) {
      return TagWriteResult(
        success: false,
        error: e.toString(),
        filePath: filePath,
      );
    }
  }

  /// Clear specific tags from a file
  Future<TagWriteResult> clearTags(
    String filePath,
    Set<String> tagsToClear,
  ) async {
    try {
      final existingTags = await readTags(filePath);
      if (existingTags == null) {
        return TagWriteResult(
          success: false,
          error: 'Could not read existing tags',
          filePath: filePath,
        );
      }

      var cleanedTags = existingTags;
      for (final tagName in tagsToClear) {
        cleanedTags = _clearField(cleanedTags, tagName);
      }

      return writeTags(filePath, cleanedTags);
    } catch (e) {
      return TagWriteResult(
        success: false,
        error: e.toString(),
        filePath: filePath,
      );
    }
  }

  EditableTags _clearField(EditableTags tags, String fieldName) {
    switch (fieldName) {
      case 'title':
        return tags.copyWith(clearTitle: true);
      case 'artist':
        return tags.copyWith(clearArtist: true);
      case 'album':
        return tags.copyWith(clearAlbum: true);
      case 'albumArtist':
        return tags.copyWith(clearAlbumArtist: true);
      case 'genre':
        return tags.copyWith(clearGenre: true);
      case 'year':
        return tags.copyWith(clearYear: true);
      case 'trackNumber':
        return tags.copyWith(clearTrackNumber: true);
      case 'totalTracks':
        return tags.copyWith(clearTotalTracks: true);
      case 'discNumber':
        return tags.copyWith(clearDiscNumber: true);
      case 'totalDiscs':
        return tags.copyWith(clearTotalDiscs: true);
      case 'composer':
        return tags.copyWith(clearComposer: true);
      case 'bpm':
        return tags.copyWith(clearBpm: true);
      case 'comment':
        return tags.copyWith(clearComment: true);
      case 'lyrics':
        return tags.copyWith(clearLyrics: true);
      case 'artwork':
        return tags.copyWith(clearArtwork: true);
      default:
        return tags;
    }
  }

  String _getFileName(String path) {
    return path.split('/').last.split('\\').last;
  }

  /// Remove URL frames (WOAS, WOAR, etc.) from an audio file
  /// This manually strips URL frames from the ID3v2 header
  Future<TagWriteResult> removeUrlFrames(String filePath) async {
    if (!isFormatSupported(filePath)) {
      return TagWriteResult(
        success: false,
        error: 'Only MP3 files are supported',
        filePath: filePath,
      );
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return TagWriteResult(
          success: false,
          error: 'File not found',
          filePath: filePath,
        );
      }

      final bytes = await file.readAsBytes();

      // Check for ID3v2 header
      if (bytes.length < 10 || bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
        return TagWriteResult(
          success: false,
          error: 'No ID3v2 header found',
          filePath: filePath,
        );
      }

      // Parse ID3v2 header
      final majorVersion = bytes[3];
      final flags = bytes[5];
      final hasExtendedHeader = (flags & 0x40) != 0;

      // Calculate ID3v2 tag size (syncsafe integer)
      final tagSize = ((bytes[6] & 0x7F) << 21) |
          ((bytes[7] & 0x7F) << 14) |
          ((bytes[8] & 0x7F) << 7) |
          (bytes[9] & 0x7F);

      Log.d('TagEditorService: Removing URLs - ID3v2.$majorVersion, tag size: $tagSize');

      // Find and remove URL frames (WOAS, WOAR, WCOM, WCOP, WOAF, WORS, WPAY, WPUB, WXXX)
      final urlFrameIds = ['WOAS', 'WOAR', 'WCOM', 'WCOP', 'WOAF', 'WORS', 'WPAY', 'WPUB', 'WXXX'];

      int pos = 10;
      if (hasExtendedHeader && majorVersion >= 3) {
        // Skip extended header
        final extSize = (bytes[10] << 24) | (bytes[11] << 16) | (bytes[12] << 8) | bytes[13];
        pos += 4 + extSize;
      }

      // Build new tag without URL frames
      final newTagBytes = <int>[];
      newTagBytes.addAll(bytes.sublist(0, 10)); // Copy header (will update size later)

      int removedCount = 0;
      while (pos < 10 + tagSize && pos + 10 < bytes.length) {
        // Read frame header
        final frameId = String.fromCharCodes(bytes.sublist(pos, pos + 4));

        // Check for padding (null bytes)
        if (frameId[0] == '\x00') break;

        // Frame size (depends on version)
        int frameSize;
        if (majorVersion >= 4) {
          // v2.4 uses syncsafe integers
          frameSize = ((bytes[pos + 4] & 0x7F) << 21) |
              ((bytes[pos + 5] & 0x7F) << 14) |
              ((bytes[pos + 6] & 0x7F) << 7) |
              (bytes[pos + 7] & 0x7F);
        } else {
          // v2.3 uses regular integers
          frameSize = (bytes[pos + 4] << 24) |
              (bytes[pos + 5] << 16) |
              (bytes[pos + 6] << 8) |
              bytes[pos + 7];
        }

        final totalFrameSize = 10 + frameSize; // header + content

        if (urlFrameIds.contains(frameId)) {
          Log.d('TagEditorService: Removing frame $frameId ($frameSize bytes)');
          removedCount++;
        } else {
          // Keep this frame
          newTagBytes.addAll(bytes.sublist(pos, pos + totalFrameSize));
        }

        pos += totalFrameSize;
      }

      if (removedCount == 0) {
        Log.d('TagEditorService: No URL frames found to remove');
        return TagWriteResult(
          success: true,
          error: 'No URL frames found',
          filePath: filePath,
        );
      }

      // Add padding to maintain alignment
      final audioDataStart = 10 + tagSize;
      final newTagSize = newTagBytes.length - 10;
      final paddingNeeded = tagSize - newTagSize;
      if (paddingNeeded > 0) {
        newTagBytes.addAll(List.filled(paddingNeeded, 0));
      }

      // Update tag size in header (syncsafe)
      final finalTagSize = newTagBytes.length - 10;
      newTagBytes[6] = (finalTagSize >> 21) & 0x7F;
      newTagBytes[7] = (finalTagSize >> 14) & 0x7F;
      newTagBytes[8] = (finalTagSize >> 7) & 0x7F;
      newTagBytes[9] = finalTagSize & 0x7F;

      // Append audio data
      final resultBytes = Uint8List.fromList([
        ...newTagBytes,
        ...bytes.sublist(audioDataStart),
      ]);

      Log.d('TagEditorService: Removed $removedCount URL frames, new size: ${resultBytes.length}');

      // Write back
      await file.writeAsBytes(resultBytes, flush: true);

      return TagWriteResult(
        success: true,
        filePath: filePath,
      );
    } catch (e) {
      Log.d('TagEditorService: Error removing URLs: $e');
      return TagWriteResult(
        success: false,
        error: e.toString(),
        filePath: filePath,
      );
    }
  }

  /// Remove URLs from multiple files
  Future<List<TagWriteResult>> removeUrlsFromFiles(List<String> filePaths) async {
    final results = <TagWriteResult>[];
    for (final path in filePaths) {
      results.add(await removeUrlFrames(path));
    }
    return results;
  }
}

/// Result of a tag write operation
class TagWriteResult {
  final bool success;
  final String? error;
  final String filePath;

  const TagWriteResult({
    required this.success,
    this.error,
    required this.filePath,
  });
}

/// Progress update for batch write operations
class BatchWriteProgress {
  final int completed;
  final int total;
  final List<String> errors;
  final String currentFile;

  const BatchWriteProgress({
    required this.completed,
    required this.total,
    required this.errors,
    required this.currentFile,
  });

  double get progress => total > 0 ? completed / total : 0;
  bool get isComplete => completed >= total;
  bool get hasErrors => errors.isNotEmpty;
}

/// Genre presets for offline use
const genrePresets = [
  'Rock',
  'Pop',
  'Hip-Hop',
  'R&B',
  'Jazz',
  'Classical',
  'Electronic',
  'Dance',
  'Country',
  'Folk',
  'Blues',
  'Metal',
  'Punk',
  'Indie',
  'Alternative',
  'Soul',
  'Reggae',
  'Latin',
  'World',
  'Soundtrack',
  'Ambient',
  'House',
  'Techno',
  'Drum & Bass',
  'Dubstep',
  'Trap',
  'Lo-Fi',
  'K-Pop',
  'J-Pop',
  'Acoustic',
];

// Riverpod provider
final tagEditorServiceProvider = Provider<TagEditorService>((ref) {
  return TagEditorService();
});
