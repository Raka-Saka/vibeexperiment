# YouTube Upload Setup Guide

The YouTube upload feature requires Google Cloud configuration to work. Follow these steps:

## 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your project ID

## 2. Enable YouTube Data API v3

1. Go to **APIs & Services** > **Library**
2. Search for "YouTube Data API v3"
3. Click **Enable**

## 3. Configure OAuth Consent Screen

1. Go to **APIs & Services** > **OAuth consent screen**
2. Choose **External** user type
3. Fill in the required fields:
   - App name: `VibePlay`
   - User support email: your email
   - Developer contact: your email
4. Add scopes:
   - `https://www.googleapis.com/auth/youtube.upload`
5. Add test users (your Google account email)
6. Save

## 4. Create OAuth 2.0 Credentials

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. Choose **Android** application type
4. Fill in:
   - Name: `VibePlay Android`
   - Package name: `com.vibeplay.vibeplay`
   - SHA-1 certificate fingerprint (see below)

### Getting SHA-1 Fingerprint

For debug builds, run:
```bash
cd android
./gradlew signingReport
```

Or use keytool:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

## 5. Download Configuration (Optional)

For some Google Sign-In features, you may need `google-services.json`:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a project (or link to your Google Cloud project)
3. Add an Android app with package name `com.vibeplay.vibeplay`
4. Download `google-services.json`
5. Place it in `android/app/`

## 6. Update Client ID (if needed)

If you created a new OAuth client, update the client ID in:
`lib/services/youtube_upload_service.dart`

```dart
class YouTubeConfig {
  static const clientId = 'YOUR_CLIENT_ID.apps.googleusercontent.com';
  // ...
}
```

## Testing

1. Build and run the app
2. Play a song
3. Tap the menu (⋮) on a song tile or in Now Playing screen
4. Select "Upload to YouTube"
5. Sign in with a Google account that's added as a test user
6. The app will generate a waveform video and upload it

## Troubleshooting

### "Sign in failed"
- Ensure Google Play Services is installed on the device
- Check that SHA-1 fingerprint is correctly registered
- Verify the package name matches exactly

### "API quota exceeded"
- YouTube API has daily quotas
- Wait 24 hours or request quota increase in Google Cloud Console

### "Video generation failed"
- Check that the audio file exists and is readable
- Ensure sufficient storage space for temp video file
- Check logcat for detailed error messages

## Security Note

The `client_secret_*.json` file in the project root should NOT be committed to version control. It's only needed for server-side OAuth flows, not for mobile apps.

Add to `.gitignore`:
```
client_secret_*.json
google-services.json
```
