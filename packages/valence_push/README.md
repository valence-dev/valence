# valence_push

Opt-in Firebase Messaging transport for `valence`. Remote push (FCM) was built and
run on Android, end to end. That covers foreground, background, killed-process sync,
notification taps and image notifications. Token rotation has not been observed yet.
iOS is experimental and untested. See [Remote push](https://getvalence.dev/docs/guides/remote-push/)
for native setup, token registration, sign-out, sending from your server, images and
acceptance checks.

Add these three dependencies only in hosts that use remote push:

```yaml
dependencies:
  valence_push: ^0.4.0-beta.2
  firebase_core: ^4.14.0
  firebase_messaging: ^16.7.0
```

Initialize Firebase, register the top-level background callback,
then pass `createFirebasePush()` (import `package:valence_push/valence_push.dart`)
to `Valence.open`. Replace the old no-argument `ValencePush()` constructor.
`ValencePush.handleBackground` stays in core and accepts the existing data map.
Custom transports now exchange `ValencePushMessage` instead of `RemoteMessage`.
Preserve notification envelope presence through `hasNotification`, even for empty
notifications, so notification messages never trigger data-only sync hints.

Core-only hosts keep `valence` without this package. They need no Firebase setup;
local notifications and badges remain core dependencies. Installing this package
includes the native Firebase SDKs even when no Dart code invokes them. Review
native auto-init and consent settings; a false Dart flag cannot remove those SDKs.
No SDK-version bump, wire/schema change, signing change or delivery guarantee is added.

In this monorepo, `pubspec_overrides.yaml` resolves the sibling core checkout for contributors.
Pub consumers use the versioned dependency; the override is not part of the upload.
Run `flutter pub get`, `flutter test`, `dart analyze --fatal-infos .` here. The publish
dry run uses the local override and reports a dependency-override hint; the upload
excludes that file. Before publishing the adapter, publish core and repeat the
checks against its published version.

```dart
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:valence/valence.dart';
import 'package:valence_push/valence_push.dart';

import 'push_background.dart';
import 'valence/config.g.dart';

Future<Valence> openPushHost() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(pushBackgroundMessage);
  return Valence.open(valenceConfig, push: createFirebasePush());
}
```
