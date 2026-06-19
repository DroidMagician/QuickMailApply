# QuickMail Apply

One-tap job applications from LinkedIn — share or paste a recruiter email, pick a profile, and open a pre-filled email with the right resume attached.

## Features

- **Profiles** — Flutter Developer, Android Developer, Team Lead (customizable)
- **Share from LinkedIn** — Share text/email directly into the app (Android; iOS after Share Extension setup)
- **LinkedIn Post Parser** — Auto-extracts email, job title, company, and skills from shared posts
- **AI Email Generator** — Gemini-powered (or smart templates) tailored emails by profile & job title
- **Resume Score** — Grade your resume PDF against profile keywords and best practices
- **Follow-up reminders** — Track when to follow up on applications (History tab)
- **Application history** — Recent recruiter emails with profile and timestamp
- **Android** — Opens Gmail compose with recipient, subject, body, and resume
- **iOS** — Opens native Mail compose with attachment

## Quick start

```bash
flutter pub get
flutter run
```

## Workflow

1. Copy or **Share** recruiter email from LinkedIn
2. Open QuickMail Apply (email auto-fills if shared)
3. Select profile → **Apply**
4. Review and send in Gmail / Mail

## Release builds

See [docs/RELEASE.md](docs/RELEASE.md) for Play Store and App Store instructions.

```bash
./scripts/build_playstore.sh   # Android .aab
./scripts/build_ios_release.sh # iOS archive prep
```

## Privacy

All data is stored locally on your device. See [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md).
