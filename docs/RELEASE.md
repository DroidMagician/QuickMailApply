# QuickMail Apply — Release Guide

## Play Store (Android)

### 1. Create a signing keystore (one time)

```bash
keytool -genkey -v \
  -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### 2. Configure signing

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties` with your passwords and keystore path.

### 3. Build the App Bundle

```bash
chmod +x scripts/build_playstore.sh
./scripts/build_playstore.sh
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 4. Play Console checklist

- App name: **QuickMail Apply**
- Package: `com.quickmail.apply.quickmailapply`
- Category: Productivity or Business
- Privacy policy URL (host `docs/PRIVACY_POLICY.md` on GitHub Pages or your site)
- Data safety: stores profiles and history **locally only** — no server collection
- Screenshots: Apply screen, Profiles, History
- Content rating questionnaire

---

## App Store (iOS)

### 1. One-time Share Extension setup in Xcode

The Share Extension source files are in `ios/Share Extension/`. Add the target once:

1. Open `ios/Runner.xcworkspace` in Xcode
2. **File → New → Target → Share Extension**
3. Name it **Share Extension** (exact name — matches Podfile)
4. Delete the auto-generated `ShareViewController.swift` and use the one in `ios/Share Extension/`
5. Replace generated `Info.plist` with `ios/Share Extension/Info.plist`
6. Set entitlements to `ios/Share Extension/Share Extension.entitlements`
7. **Signing & Capabilities** on **Runner** and **Share Extension**:
   - Add **App Groups** → `group.com.quickmail.apply`
8. **Build Settings → User-Defined** on both targets:
   - `CUSTOM_GROUP_ID` = `group.com.quickmail.apply`
9. **Runner → Build Phases**: move **Embed Foundation Extensions** above **Thin Binary**
10. Set **Runner → Signing → Runner.entitlements** to `Runner/Runner.entitlements`

### 2. Build for App Store

```bash
chmod +x scripts/build_ios_release.sh
./scripts/build_ios_release.sh
```

Then in Xcode: **Product → Archive → Distribute App**.

### 3. App Store checklist

- Display name: **QuickMail Apply**
- Bundle ID: `com.quickmail.apply.quickmailapply`
- Privacy policy URL
- App Privacy: data not collected (local storage only)
- Screenshots for 6.7" and 5.5" iPhone

---

## Share from LinkedIn

### Android
Long-press recruiter email → **Share** → **QuickMail Apply**

### iOS (after Share Extension setup)
Select email text → **Share** → **QuickMail Apply**

The app extracts the email, switches to the Apply tab, and pre-fills the field.

---

## Version bumps

Edit `pubspec.yaml`:

```yaml
version: 1.1.0+2   # 1.1.0 = user-facing, 2 = build number
```

Android `versionCode` and iOS `CFBundleVersion` use the build number (`+2`).
