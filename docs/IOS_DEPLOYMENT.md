# iOS Deployment Guide

This guide provides step-by-step instructions for deploying the Exam Management App to iOS devices and the App Store.

## 📋 Prerequisites

### Required Accounts and Software

1. **Apple Developer Account**
   - Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)
   - Required for App Store distribution
   - Free account allows development and TestFlight testing only

2. **macOS Computer**
   - macOS 12.0 or later
   - Required for building iOS apps (Flutter iOS builds require macOS)

3. **Xcode**
   - Xcode 14.0 or later (recommended: latest version)
   - Install from Mac App Store or [Apple Developer Downloads](https://developer.apple.com/download/)
   - Includes iOS SDK, simulators, and development tools

4. **Flutter SDK**
   - Flutter 3.2.3 or higher
   - Verify installation: `flutter doctor`

5. **CocoaPods** (for iOS dependencies)
   - Install: `sudo gem install cocoapods`
   - Verify: `pod --version`

### Verify Prerequisites

```bash
# Check Flutter installation
flutter doctor

# Check Xcode installation
xcodebuild -version

# Check CocoaPods
pod --version

# Check Apple Developer account
# (Sign in to developer.apple.com to verify)
```

**Expected `flutter doctor` output should show:**
```
[✓] Flutter (Channel stable, 3.2.3, ...)
[✓] Xcode - develop for iOS and macOS (Xcode 14.x)
[✓] CocoaPods version 1.x.x
[✓] Connected device (iOS simulator or physical device)
```

## 🔧 Pre-Deployment Configuration

### Step 1: Configure Bundle Identifier

The bundle identifier must be unique and match your Apple Developer account.

**File:** `ios/Runner.xcodeproj/project.pbxproj`

Current bundle identifier: `com.pea.examManagementApp`

**To change it:**
1. Open `ios/Runner.xcodeproj` in Xcode
2. Select "Runner" in the project navigator
3. Select "Runner" target
4. Go to "Signing & Capabilities" tab
5. Update "Bundle Identifier" to your unique identifier (e.g., `com.yourcompany.examManagementApp`)

**Or edit directly in Xcode project settings:**
- Product → Scheme → Edit Scheme
- Or modify `PRODUCT_BUNDLE_IDENTIFIER` in build settings

### Step 2: Configure App Display Name

**File:** `ios/Runner/Info.plist`

The display name is already set to "Exam Management App". To change it:

```xml
<key>CFBundleDisplayName</key>
<string>Your App Name</string>
```

### Step 3: Configure Version and Build Number

**File:** `pubspec.yaml`

```yaml
version: 1.0.0+1
# Format: version_name+build_number
# version_name: 1.0.0 (shown to users)
# build_number: 1 (incremented for each App Store submission)
```

**Important:**
- Increment `build_number` (+1) for each App Store submission
- Update `version_name` for major/minor releases (e.g., 1.0.0 → 1.1.0)

### Step 4: Configure App Icons and Launch Screen

**App Icon:**
1. Prepare app icon in required sizes (1024x1024 for App Store)
2. Place icon files in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
3. Or use Xcode's App Icon generator

**Launch Screen:**
- Current launch screen: `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- Customize if needed for branding

### Step 5: Configure API Endpoints

**File:** `lib/services/api_discovery_service.dart`

Ensure production API URLs are configured:

```dart
static final List<String> _defaultApiUrls = [
  'https://exam-app-api.duckdns.org',  // Production HTTPS
  'http://exam-app-api.duckdns.org',    // Fallback HTTP
];

static final List<String> _defaultChatUrls = [
  'https://backend-chat.duckdns.org',   // Production HTTPS
  'http://backend-chat.duckdns.org',    // Fallback HTTP
];
```

### Step 6: Configure App Transport Security (ATS)

iOS requires HTTPS for network requests. Configure ATS in `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>exam-app-api.duckdns.org</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
        <key>backend-chat.duckdns.org</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Note:** If using HTTPS (recommended), you can remove ATS exceptions. The above configuration enforces HTTPS.

### Step 7: Install iOS Dependencies

```bash
cd ios
pod install
cd ..
```

**Expected output:**
```
Analyzing dependencies
Downloading dependencies
Installing [dependencies]
Generating Pods project
```

## 🏗️ Building for iOS

### Step 1: Clean Previous Builds

```bash
# Clean Flutter build
flutter clean

# Clean iOS build (optional)
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

### Step 2: Get Dependencies

```bash
flutter pub get
```

### Step 3: Build iOS App

#### Option A: Build for Device Testing

```bash
# Build for connected iOS device
flutter build ios --release

# Or build for specific device
flutter build ios --release --device-id=<device-id>
```

#### Option B: Build for App Store Distribution

```bash
# Build iOS app for App Store
flutter build ios --release --no-codesign
```

**Note:** `--no-codesign` builds the app without code signing. You'll sign it in Xcode.

### Step 4: Open in Xcode

```bash
open ios/Runner.xcworkspace
```

**Important:** Always open `.xcworkspace`, not `.xcodeproj` (CocoaPods requirement)

## 🔐 Code Signing and Certificates

### Step 1: Create App ID in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to "Certificates, Identifiers & Profiles"
3. Click "Identifiers" → "+" → "App IDs"
4. Select "App"
5. Enter:
   - **Description**: Exam Management App
   - **Bundle ID**: `com.pea.examManagementApp` (or your custom ID)
6. Enable required capabilities (Push Notifications, if needed)
7. Click "Continue" → "Register"

### Step 2: Create Distribution Certificate

1. In Apple Developer Portal → "Certificates"
2. Click "+" to create new certificate
3. Select "Apple Distribution" (for App Store)
4. Follow instructions to create Certificate Signing Request (CSR):
   - Open Keychain Access on Mac
   - Keychain Access → Certificate Assistant → Request a Certificate
   - Enter email and name
   - Save to disk
5. Upload CSR to Apple Developer Portal
6. Download certificate and double-click to install in Keychain

### Step 3: Create Provisioning Profile

1. In Apple Developer Portal → "Profiles"
2. Click "+" → "App Store" distribution
3. Select your App ID
4. Select your Distribution Certificate
5. Enter profile name: "Exam Management App Distribution"
6. Download and double-click to install

### Step 4: Configure Signing in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Runner" project in navigator
3. Select "Runner" target
4. Go to "Signing & Capabilities" tab
5. **For Development:**
   - Check "Automatically manage signing"
   - Select your Team (Apple Developer account)
   - Xcode will automatically create certificates and profiles

6. **For App Store Distribution:**
   - Uncheck "Automatically manage signing" (optional)
   - Select "Manual" signing
   - Choose your Distribution Provisioning Profile
   - Select your Distribution Certificate

## 📦 Creating Archive for App Store

### Step 1: Configure Build Settings

1. In Xcode, select "Runner" scheme
2. Product → Scheme → Edit Scheme
3. Select "Archive" in left sidebar
4. Set "Build Configuration" to "Release"

### Step 2: Select Generic iOS Device

1. In Xcode toolbar, select destination
2. Choose "Any iOS Device (arm64)" or "Generic iOS Device"
3. **Important:** Don't select a simulator (can't archive for simulator)

### Step 3: Archive the App

1. Product → Archive
2. Wait for build to complete (may take several minutes)
3. Organizer window will open automatically

**If Archive is disabled:**
- Ensure you selected "Generic iOS Device" or "Any iOS Device"
- Check that "Release" configuration is selected
- Verify code signing is configured correctly

### Step 4: Validate Archive

1. In Organizer, select your archive
2. Click "Validate App"
3. Sign in with your Apple ID
4. Select distribution method: "App Store Connect"
5. Select your team
6. Review app information
7. Click "Validate"

**Fix any validation errors before distributing.**

### Step 5: Distribute to App Store

1. In Organizer, select your validated archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Choose distribution options:
   - **Upload**: Upload to App Store Connect (recommended)
   - **Export**: Export .ipa file (for manual upload)
5. Select distribution method: "Upload"
6. Review app information
7. Select signing options:
   - **Automatically manage signing** (recommended)
   - Or select your distribution certificate manually
8. Click "Upload"
9. Wait for upload to complete

## 📱 App Store Connect Setup

### Step 1: Create App Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to "My Apps"
3. Click "+" → "New App"
4. Fill in app information:
   - **Platform**: iOS
   - **Name**: Exam Management App
   - **Primary Language**: English (or your language)
   - **Bundle ID**: Select your App ID
   - **SKU**: Unique identifier (e.g., `exam-management-app-001`)
   - **User Access**: Full Access (or Limited Access)
5. Click "Create"

### Step 2: Configure App Information

#### App Information Tab

- **Name**: Exam Management App
- **Subtitle**: (Optional) Brief description
- **Category**: Education
- **Content Rights**: Select appropriate options
- **Age Rating**: Complete questionnaire

#### Pricing and Availability

- Set price (Free or Paid)
- Select countries/regions
- Set availability date

#### App Privacy

- Complete privacy questionnaire
- Add privacy policy URL (required)
- Describe data collection practices

### Step 3: Prepare App Store Listing

#### App Store Screenshots

Required sizes:
- **6.7" Display (iPhone 14 Pro Max)**: 1290 x 2796 pixels
- **6.5" Display (iPhone 11 Pro Max)**: 1242 x 2688 pixels
- **5.5" Display (iPhone 8 Plus)**: 1242 x 2208 pixels

**Screenshot Requirements:**
- At least 1 screenshot per device size
- Maximum 10 screenshots per device size
- PNG or JPEG format
- No transparency

#### App Preview Video (Optional)

- 15-30 seconds
- Show app functionality
- MP4, MOV, or M4V format

#### Description

- **Name**: Exam Management App (30 characters max)
- **Subtitle**: (Optional, 30 characters max)
- **Description**: Detailed app description (up to 4000 characters)
- **Keywords**: Comma-separated keywords (100 characters max)
- **Support URL**: Your support website
- **Marketing URL**: (Optional) Marketing website
- **Promotional Text**: (Optional, 170 characters) Can be updated without new submission

#### Version Information

- **Version**: 1.0.0 (matches pubspec.yaml)
- **Copyright**: Your copyright notice
- **What's New**: Release notes for this version

### Step 4: Submit for Review

1. After uploading build, go to "App Store" tab
2. Select build version in "iOS App" section
3. Complete all required information (marked with *)
4. Answer export compliance questions
5. Click "Submit for Review"
6. Wait for Apple's review (typically 24-48 hours)

## 🧪 Testing Before Submission

### TestFlight (Beta Testing)

1. **Upload Build to TestFlight**
   - Archive and upload as described above
   - Build will appear in TestFlight after processing (10-30 minutes)

2. **Add Internal Testers**
   - Go to App Store Connect → TestFlight
   - Add internal testers (up to 100, must be in your team)
   - They can test immediately after build processing

3. **Add External Testers**
   - Create external testing group
   - Add testers (up to 10,000)
   - Requires Beta App Review (24-48 hours)
   - Testers receive email invitation

4. **Test on Physical Devices**
   - Install TestFlight app on iOS device
   - Accept invitation
   - Install and test the app

### Local Device Testing

```bash
# Connect iOS device via USB
# Enable Developer Mode on device (Settings → Privacy & Security → Developer Mode)

# Build and run on device
flutter run --release

# Or build and install
flutter build ios --release
# Then install via Xcode or Apple Configurator
```

## 🔍 Pre-Submission Checklist

### Code and Configuration

- [ ] Bundle identifier is unique and registered
- [ ] Version and build number are correct
- [ ] App icons are provided in all required sizes
- [ ] Launch screen is configured
- [ ] API endpoints are production URLs (HTTPS)
- [ ] App Transport Security is configured
- [ ] All dependencies are up to date
- [ ] Code is clean (no debug code, test data, etc.)

### App Store Connect

- [ ] App record is created
- [ ] All required app information is filled
- [ ] Screenshots are provided for all required device sizes
- [ ] App description is complete and accurate
- [ ] Privacy policy URL is provided
- [ ] Age rating questionnaire is completed
- [ ] Export compliance questions are answered

### Testing

- [ ] App tested on physical iOS device
- [ ] All features work correctly
- [ ] API connections work with production endpoints
- [ ] Chat functionality works
- [ ] No crashes or critical bugs
- [ ] TestFlight testing completed (if using)

### Legal and Compliance

- [ ] Privacy policy is accessible
- [ ] Terms of service (if applicable)
- [ ] Export compliance requirements met
- [ ] Content rights are accurate
- [ ] Age rating is appropriate

## 🐛 Troubleshooting

### Issue: "No devices found" or "No iOS devices connected"

**Solution:**
```bash
# Check connected devices
flutter devices

# Enable Developer Mode on iOS device
# Settings → Privacy & Security → Developer Mode → Enable

# Trust computer on device
# When prompted, tap "Trust" on device
```

### Issue: Code Signing Errors

**Error:**
```
Code signing is required for product type 'Application'
```

**Solution:**
1. Open Xcode → Runner project
2. Select Runner target → Signing & Capabilities
3. Check "Automatically manage signing"
4. Select your Team
5. If errors persist, clean build folder:
   ```bash
   cd ios
   rm -rf build Pods Podfile.lock
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```

### Issue: "Archive" is Disabled in Xcode

**Solution:**
- Select "Generic iOS Device" or "Any iOS Device" as destination
- Don't select a simulator
- Ensure "Release" configuration is selected
- Check that code signing is configured

### Issue: CocoaPods Installation Errors

**Error:**
```
[!] CocoaPods could not find compatible versions
```

**Solution:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod cache clean --all
pod install --repo-update
cd ..
```

### Issue: Build Fails with "Undefined symbol"

**Solution:**
```bash
# Clean and rebuild
flutter clean
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter pub get
flutter build ios --release
```

### Issue: App Rejected by App Store Review

**Common Reasons:**
- Missing privacy policy
- Incomplete app information
- App crashes during review
- Violates App Store guidelines
- Missing required permissions descriptions

**Solution:**
- Review rejection reason in App Store Connect
- Address all issues mentioned
- Resubmit with updated build or information

### Issue: TestFlight Build Not Appearing

**Solution:**
- Wait 10-30 minutes for processing
- Check build status in App Store Connect → TestFlight
- Verify build was uploaded successfully
- Check for processing errors in App Store Connect

## 📊 Build Configuration Options

### Build for Development

```bash
# Debug build (for development)
flutter build ios --debug

# Profile build (for performance testing)
flutter build ios --profile
```

### Build for Distribution

```bash
# Release build (for App Store)
flutter build ios --release

# Release build without code signing (sign in Xcode)
flutter build ios --release --no-codesign
```

### Build with Specific Configuration

```bash
# Build with custom build name and number
flutter build ios --release \
  --build-name=1.0.0 \
  --build-number=1

# Build with environment variables
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

## 🔄 Updating the App

### Step 1: Update Version

**File:** `pubspec.yaml`

```yaml
version: 1.0.1+2  # Increment version and build number
```

### Step 2: Build and Archive

Follow the same build and archive process as initial submission.

### Step 3: Upload New Build

1. Upload new build to App Store Connect
2. Select new build in App Store tab
3. Update "What's New" section with release notes
4. Submit for review

## 📱 Distribution Methods

### 1. App Store (Public Distribution)

- Available to all users
- Requires App Store review
- Best for production releases

### 2. TestFlight (Beta Testing)

- Internal testing: Up to 100 testers (immediate)
- External testing: Up to 10,000 testers (requires review)
- Good for beta testing before public release

### 3. Ad Hoc Distribution

- Limited to 100 devices
- Requires device UDIDs
- Good for internal testing without TestFlight

### 4. Enterprise Distribution

- Requires Apple Enterprise Program ($299/year)
- Unlimited internal distribution
- For organizations with 100+ employees

## 🔒 Security Considerations

### API Security

- Use HTTPS for all API calls
- Validate SSL certificates
- Don't hardcode API keys or secrets
- Use secure storage for sensitive data

### Code Obfuscation (Optional)

```bash
# Build with code obfuscation
flutter build ios --release --obfuscate --split-debug-info=./debug-info
```

### App Transport Security

- Enforce HTTPS connections
- Configure ATS exceptions only if necessary
- Document any HTTP exceptions

## 📈 Monitoring and Analytics

### App Store Connect Analytics

- Track downloads, sales, and usage
- Monitor crash reports
- View user reviews and ratings
- Analyze user engagement

### Crash Reporting

Consider integrating:
- Firebase Crashlytics
- Sentry
- Apple's built-in crash reporting

## ⚠️ Important Notes

1. **Build Time**: iOS builds can take 5-15 minutes depending on project size
2. **Review Time**: App Store review typically takes 24-48 hours
3. **Version Requirements**: Each App Store submission requires a new build number
4. **Certificate Expiration**: Distribution certificates expire after 1 year, renew before expiration
5. **Device Requirements**: Test on multiple iOS versions and device sizes
6. **Network Security**: Ensure all network requests use HTTPS in production
7. **Privacy**: Complete privacy questionnaire accurately
8. **Content Guidelines**: Ensure app complies with App Store Review Guidelines

## 📚 Additional Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)

## 🆘 Getting Help

If you encounter issues:

1. Check Flutter documentation: `flutter doctor -v`
2. Review Xcode build logs
3. Check App Store Connect for processing errors
4. Review Apple Developer Forums
5. Contact Apple Developer Support (if enrolled in program)

---

**Last Updated:** 2025
**Maintained By:** NguyenCaoAnh

