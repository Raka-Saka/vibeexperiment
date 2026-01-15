// ============================================================================
// SECRETS CONFIGURATION TEMPLATE
// ============================================================================
//
// Copy this file to 'secrets.dart' and fill in your values.
// The secrets.dart file is gitignored and will not be committed.
//
// To set up YouTube upload:
// 1. Go to https://console.cloud.google.com/
// 2. Create a new project or select existing
// 3. Enable YouTube Data API v3
// 4. Create OAuth 2.0 credentials (Android app)
// 5. Add your SHA-1 fingerprint and package name
// 6. Copy the client ID below
//
// ============================================================================

class Secrets {
  // YouTube OAuth Client ID
  // Get this from Google Cloud Console > APIs & Services > Credentials
  static const String youtubeClientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';

  // YouTube channel name (optional - used as artist name in uploads)
  static const String youtubeChannelName = 'Your Channel Name';

  // Last.fm API key (future feature)
  static const String? lastFmApiKey = null;
  static const String? lastFmApiSecret = null;
}
