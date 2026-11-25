# Migrating a 0.4 host to 0.5

0.5 moves the `valence` package to `flutter_local_notifications` 23. That plugin raises the Android build
floor for every host, including hosts that never enable notifications, because the plugin ships inside
the runtime. Your data, your update state and your bridge schema carry over untouched.

Android is supported. iOS is experimental and untested.

## What changes

| | 0.4 example app | 0.5 minimum |
|---|---|---|
| Flutter | 3.44 | **3.47** |
| `flutter_local_notifications` (inside `valence`) | 22.3.2 | **23.0.4** |
| Android `compileSdk` | `flutter.compileSdkVersion` (36) | **37** |
| Android Gradle plugin (AGP) | 9.0.1 | **9.1.1** |
| Gradle wrapper | 9.1.0 | **9.3.1** |
| `desugar_jdk_libs` | 2.1.4 | 2.1.4 (unchanged) |

With `compileSdk` 36 the build stops at `:app:checkDebugAarMetadata` with "Dependency
':flutter_local_notifications' requires libraries and applications that depend on it to compile against
version 37 or later of the Android APIs."

Start from a clean commit, so `git diff` shows exactly what each step did.

## 1. Flutter 3.47 or later

```sh
flutter --version
```

Upgrade if it reports anything below 3.47.

## 2. Update the tooling

```sh
npx create-valence@latest update
```

That replaces `valence/valence.mjs` and the `/valence` skill. Start a new Claude Code session afterwards,
or the old skill stays loaded.

## 3. Host `pubspec.yaml`

In your Flutter host's `pubspec.yaml`, set the Flutter floor and the package versions:

```yaml
environment:
  flutter: ">=3.47.0"

dependencies:
  valence: ^0.5.0-beta.0
  # Only if you use remote push:
  valence_push: ^0.5.0-beta.0
```

If your app also lists `flutter_local_notifications` itself (for its own reminder code), change that line
to:

```yaml
  flutter_local_notifications: ^23.0.4
```

The plugin's Dart API did not change between 22 and 23, so app-owned notification code compiles as it is.

Your app's own UI library is your choice. Flutter 3.47 deprecates `package:flutter/material.dart` in favour
of the `material_ui` package; moving your own `MaterialApp` is optional and separate from this upgrade.
Valence's own screens (loading, error, update required) now use plain Flutter widgets, so they work under
a legacy `MaterialApp`, a `material_ui` app or a Cupertino app alike, and follow the phone's dark mode.

Then run:

```sh
flutter pub get
```

## 4. Android build files

All three files are under your host's `android/` directory.

**`android/app/build.gradle.kts`** — compile against SDK 37:

```kotlin
android {
    compileSdk = 37
```

If the line still reads `compileSdk = flutter.compileSdkVersion` (the `flutter create` default, which is
36), step 5 rewrites it for you. Any other value is left alone, so set it by hand. In a Groovy
`build.gradle`, the line is `compileSdk 37`.

**`android/settings.gradle.kts`** — Android Gradle plugin 9.1.1 or later:

```kotlin
plugins {
    id("com.android.application") version "9.1.1" apply false
```

In a Groovy `settings.gradle`: `id 'com.android.application' version '9.1.1' apply false`. An older host
that sets it in `android/build.gradle` instead uses
`classpath 'com.android.tools.build:gradle:9.1.1'`.

**`android/gradle/wrapper/gradle-wrapper.properties`** — Gradle 9.3.1 or later:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-9.3.1-all.zip
```

If the file has a `distributionSha256Sum` line, update or remove it to match the new version.

Newer versions are fine for all three. Flutter 3.50 warns below AGP 9.3.1 and Gradle 9.5.0 but still
builds.

**Coming from AGP 8.x?** AGP 9 turns on its new DSL and built-in Kotlin by default, and a host made by an
older `flutter create` (one that still applies `org.jetbrains.kotlin.android`) fails to configure after
the version bump. Either add these two lines to `android/gradle.properties`, which is what Flutter's
current template does:

```properties
android.newDsl=false
android.builtInKotlin=false
```

or regenerate `android/` with `flutter create .` on Flutter 3.47 or later and re-apply your own edits
(`applicationId`, signing, permissions, the notification receivers).

Keep the core library desugaring lines you added for 0.4. They have not changed.

## 5. Regenerate

From the project root:

```sh
node valence/valence.mjs codegen
```

This rewrites `compileSdk = flutter.compileSdkVersion` to `compileSdk = 37`, adds the desugaring lines if
they are missing, and warns if AGP or Gradle is still below the floor. It never edits AGP or the Gradle
wrapper itself.

## 6. Check with doctor

```sh
node valence/valence.mjs doctor
```

Two rows cover this upgrade:

- `Android desugaring` — `PASS` once the two desugaring lines are present.
- `Android build` — `PASS` reads `compileSdk 37, AGP 9.1.1, Gradle 9.3.1` (or your newer values). It is
  a `FAIL` that names each value below the floor, and a `WARN` when it cannot read one (for example, a
  `compileSdk` taken from a version catalog). Check a `WARN` by hand.

## 7. Build and try it on a device

```sh
flutter build apk --debug
```

Then, on an Android device or emulator, check what the tests cannot:

- a scheduled reminder arrives, and `notify.schedule` reports `exact` or `inexact` honestly;
- tapping a notification while the app is open fires `notify.tapped`;
- tapping one while the app is closed opens it, and `notify.initial` returns the tap once;
- each action button opens the app and fires `notify.action`;
- reminders survive a reboot.

Plugin 23 changes how Android 14 and later treat the intents behind a tap, so the tap checks are worth
running once after the upgrade.

Ship a store build after this. The new floor is a native change, which an over-the-air bundle cannot
deliver.
