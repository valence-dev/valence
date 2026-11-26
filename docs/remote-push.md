# Remote push

Contracts section 6.4. New methods/events use `since: 12`; regenerate the schema and ship
a store build. Remote push is an opt-in **native dependency**: install `valence_push`
only in push hosts. `valence` alone has no Firebase dependencies; local notifications
and badges remain in core. Removing the package and rebuilding the host removes
its Firebase SDKs, unless another app dependency supplies them. A Dart flag or
omitting `push.*` cannot remove installed native SDKs. Review the resolved package
graph and final binary before completing store disclosures.

Remote push (FCM) was built and run on Android, end to end. That covers foreground, background,
killed-process sync, notification taps and image notifications. Token rotation has not been observed
yet. iOS/APNs and its rich-image extension are experimental and untested.

`valence_push` is an **add-on**, not a plugin: `push.*` is a core namespace, so the
package supplies a `ValencePushTransport` rather than a schema fragment, and it needs
no `plugins` entry, no namespace and no `since` stamp of its own. The
[plugin directory](https://getvalence.dev/docs/guides/plugin-directory/) explains the difference between the
two shapes and lists both.

The reserved `since: 12` identifies this addition in Valence's template. An app
maintains its own additive schema history; gate calls and events with `has()`
from its regenerated bridge rather than comparing `app.info().bridge` to 12.
Update the generated bridge and `@getvalence/bridge` together: current generated
code supplies both method and event availability tables.

## Configure the native host

Add these three dependencies to the host's `pubspec.yaml`, next to `valence`:

```yaml
dependencies:
  valence_push: ^0.5.0-beta.0
  firebase_core: ^4.14.0
  firebase_messaging: ^16.7.0
```

The `main.dart` lines below and `push_background.dart` import both Firebase packages, so they are
always direct dependencies. These versions preserve the registration-token API used here;
Messaging 17 moves to registration/Firebase Installation IDs. Adapt the API and
your send backend together before upgrading that major version.

Use your Firebase project to register your exact Android application id, add
`google-services.json` to `android/app/`, and apply the Google services Gradle
plugin in your push host. The core example deliberately omits that plugin, so
there is no copy of this wiring left in the repo to crib from — it takes two
lines in two files. In `android/settings.gradle.kts`, declare it in the `plugins` block:

```kotlin
plugins {
    // …keep the plugins already there, and add:
    id("com.google.gms.google-services") version "4.4.4" apply false
}
```

and in `android/app/build.gradle.kts`, add one line to the `plugins` block, after the Flutter plugin.
Leave the lines already there as they are:

```kotlin
plugins {
    // …keep the plugins already there, and add:
    id("com.google.gms.google-services")
}
```

Miss either half and `Firebase.initializeApp()` throws on missing default
options at launch, so the failure is loud rather than silent.
Declare `android.permission.POST_NOTIFICATIONS` in the main Android manifest.
Android needs compatible Google Play services. Never put a service
account key in the app, web output, or repository.

Without more setup, FCM posts background notifications with the launcher icon on its own fallback
channel. To match your local notifications, name the icon and a channel in the `<application>` element
of the main manifest:

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_stat_valence" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="valence_reminders" />
```

Reuse the white status drawable from [local notifications](https://getvalence.dev/docs/guides/local-notifications/), and
name a channel your app creates with `notify.channels.set`. FCM uses its fallback channel until that
channel exists.

Copy [push_background.dart](https://github.com/valence-dev/valence/blob/main/.claude/skills/valence/templates/push_background.dart) to the host's
`lib/push_background.dart`. Before `Valence.open`:

```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp();
FirebaseMessaging.onBackgroundMessage(pushBackgroundMessage);
final push = createFirebasePush();
final valence = await Valence.open(valenceConfig, hostBuild: 2, push: push);
```

Import `package:valence_push/valence_push.dart` alongside `firebase_core`,
`firebase_messaging`, `valence.dart`, the generated config and your background callback.
`hostBuild` is your store build number; raise it in the build that adds push (see
[below](#a-host-without-push)). The core repository example deliberately includes no push
dependency or initialization; its push methods return `E_UNSUPPORTED`. To enable push, add the
package and native setup above and wire this initialization into your host. Setting
`VALENCE_PUSH=true` on the core example no longer enables Firebase.

Existing unreleased push hosts replace `ValencePush()` with `createFirebasePush()`.
Custom `ValencePushTransport` implementations now exchange `ValencePushMessage`
instead of Firebase `RemoteMessage`; preserve `hasNotification` even for empty
notification envelopes. That native-only flag is excluded from the bridge JSON.

`hasNotification` is **required** and has no default, so a transport cannot leave it out. `false` is the
permissive answer: it is the half of the data-only check that lets a payload trigger a sync, and core used
to work it out itself from the provider envelope. Now that the transport is yours, a default would mean a
transport that never thought about the field turned every notification carrying `{"valence":"sync"}` into
a background sync. Pass `message.notification != null` (or your provider's equivalent); the compiler will
not let you forget.
`ValencePushMessage.fromRemote` moves into the adapter's conversion; construct
provider-neutral records directly in custom transports. The background callback's
`ValencePush.handleBackground` API and every bridge signature stay unchanged.

`start` captures notification taps without fetching a token or prompting. Keep
the push object for the lifetime of the host; `await push.dispose()` stops its
listeners when permanently discarding the host. It does not unregister the device.

Firebase native auto-init is separate from the bridge. Supplying a project config
can enable SDK registration before Dart runs, independently of Android notification
permission. For consent-sensitive apps, follow Firebase auto-init controls in the
native setup guide; a passive permission check is not a global SDK privacy switch.

## Use the typed web bridge

```ts
import { call, connect, has, on } from '#lib/valence/bridge.g';

await connect();
if (has('push.initial')) {
  const stop = on('push.tapped', ({ message }) => showMessage(message));
  try {
    const initial = await call('push.initial');
    if (initial) showMessage(initial);
  } catch (e) {
    // A host built without valence_push answers E_UNSUPPORTED.
    if ((e as { code?: string }).code !== 'E_UNSUPPORTED') throw e;
  }
  // Call stop() when this root subscription is discarded.
}
```

`showMessage` is your app's display handler, not a native command. Render title,
body and data as text. Never evaluate scripts, insert raw HTML or blindly navigate
to a URL in a push. Nothing in a payload grants access to the bridge or selects a
sync server. Use your router only after validating the app's own route identifier.

| Call | Behavior |
|---|---|
| `push.permission()` | Checks without prompting. Returns `notDetermined`, `denied`, `authorized`, or `provisional`. |
| `push.permission({request: true})` | Requests alert/badge/sound permission. Call from an explicit user action. |
| `push.token()` | Returns an FCM installation registration token, or null without authorization/provisional permission, or before iOS has an APNs token. Does not request permission. |
| `push.initial()` | Consumes the latest pre-subscription tap, then enables live `push.tapped`. A second call returns null. |

`push.received` and `push.tapped` carry `{message}`. The message is
`{id, data, title, body, image}`; all fields except `data` can be null.
`push.tokenChanged` carries `{token}`. Foreground received events and live token
events are best effort. The token is an installation address, not a login credential.
Do not log it.

An Android permission denial may need the user to visit system settings; repeated
requests cannot override the OS. Permission status is separate from network
availability and does not promise delivery.

### A host without push

`has()` follows your schema, and a host built without `valence_push` has the same schema, so
`has('push.initial')` is still true there and every `push.*` call throws `E_UNSUPPORTED`. Catch it, as
above, so an over-the-air bundle that reaches an older store build does not fail at boot.

To tell the two builds apart before calling, raise `hostBuild` in the store build that adds push and
read it back as `app.info().host`. `bundle --min-host N` holds a bundle back from hosts whose bridge
version is below `N`. It measures your schema version, not `hostBuild`, so it only separates push hosts
when the store build that added push also raised the schema version.

### Register the token with your backend

Ask for permission only from an explicit user action. After that, register on every start, on resume
and on `push.tokenChanged`. Send the token with `http.request`: the host attaches the signed-in user's
bearer token, so your backend knows whose installation it is. Remember the token you registered, so you
can unlink it at sign-out.

```ts
const API = 'https://api.example.com';

// Never prompts. Call it after sign-in, on start, on resume and on rotation.
async function registerPush(rotated?: string) {
  if (!has('push.token')) return;
  try {
    const permission = await call('push.permission', {});
    if (permission !== 'authorized' && permission !== 'provisional') return;
    const token = rotated ?? (await call('push.token'));
    if (!token) return;
    const response = await call('http.request', {
      url: `${API}/push/register`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token }),
    });
    if (response.status === 200) await call('prefs.set', { key: 'app.pushToken', value: token });
  } catch (e) {
    if ((e as { code?: string }).code !== 'E_UNSUPPORTED') throw e;
  }
}

on('push.tokenChanged', ({ token }) => void registerPush(token));
on('app.lifecycle', ({ state }) => { if (state === 'foreground') void registerPush(); });
```

Registering again with the same token should be a no-op on your server. One token belongs to one
installation; when a different user signs in on that phone, move the token to them.

### Unlink it before you sign out

Unlink the token **before** `auth.setToken({token: null})`. Afterwards `http.request` sends no bearer,
and your backend cannot tell who is asking. If sign-out is then refused, typically with `E_PENDING`
because the outbox is not empty, the user is still signed in, so link the token again:

```ts
async function signOut() {
  const token = await call('prefs.get', { key: 'app.pushToken' });
  if (token) {
    // Best effort: your server also drops tokens FCM reports as unregistered.
    await call('http.request', {
      url: `${API}/push/unregister`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token }),
    }).catch(() => {});
    await call('prefs.set', { key: 'app.pushToken', value: null });
  }
  try {
    await call('auth.setToken', { token: null });
  } catch (e) {
    void registerPush(); // E_PENDING: still signed in, so stay reachable
    throw e;
  }
}
```

[Signing users in and out](https://getvalence.dev/docs/guides/accounts/#signing-out) covers `E_PENDING` itself.

## Display an image

Send an FCM HTTP v1 notification from your trusted server with
`android.notification.image` set to an HTTPS image URL. The Android FCM SDK
displays it in the background notification tray; expanding the notification may
be needed to see the image. On the foreground path Valence delivers metadata to
the page for an in-app presentation; it does not create a second system alert.
Image loading and delivery can fail independently. HTTPS `image` metadata crosses
the bridge, not image bytes. The signed page's CSP still governs web image loads.

Push hosts installing `valence_push` need an iOS deployment target of **15.0 or later**
for Firebase. Raise Runner and extension target settings in those hosts. Core-only
hosts no longer inherit that Firebase requirement; other plugins still set their own minima.

On iOS, upload the APNs key to Firebase, add the Firebase project plist to Runner,
enable Push Notifications plus Remote notifications/Background fetch, and keep
Firebase method swizzling enabled. Add a Notification Service Extension target,
link Firebase Messaging into that target, and use the supplied
[NotificationService.swift](https://github.com/valence-dev/valence/blob/main/.claude/skills/valence/templates/NotificationService.swift). Set the extension's principal class to
`$(PRODUCT_MODULE_NAME).NotificationService` and extension point to
`com.apple.usernotifications.service`. Send `aps.mutable-content: 1` and
`apns.fcm_options.image` with a URL including a supported file extension. A
minimal extension plist is supplied next to the Swift template. Provision both
targets in Xcode. iOS is experimental and untested.

## Wake sync without loading the UI

Send a **data-only** FCM HTTP v1 message:

```json
{
  "message": {
    "token": "installation-registration-token",
    "data": {"valence": "sync"},
    "android": {"priority": "high"},
    "apns": {
      "headers": {"apns-push-type": "background", "apns-priority": "5"},
      "payload": {"aps": {"content-available": 1}}
    }
  }
}
```

Only that exact one-field data map and no notification object triggers sync.
Other messages and extra configuration fields are ignored as commands. The
top-level entry-point callback uses `Valence.backgroundSync(valenceConfig)` with
the host's compiled config and stored bearer token. It does not call
`Valence.open`, start a WebView/server, activate an update, close SQLite, or commit
a trial. The existing sync lease and normal cursor/outbox rules still apply.

Delivery is best effort. The OS may delay or drop the hint, especially after
force-stop, under battery restrictions, or after high-priority abuse. Background
work must finish within the provider's execution window (roughly 30 seconds).
Normal resume/periodic sync remains the correctness path. A busy lease means no
sync was attempted; never display it as “up to date.”

## Sending from your server

FCM HTTP v1 takes an OAuth access token, not a static server key. Your server signs a JWT with the
Firebase service account's private key, with the scope
`https://www.googleapis.com/auth/firebase.messaging`, and exchanges it at
`https://oauth2.googleapis.com/token` for an access token that lasts an hour. Each message is then a
`POST https://fcm.googleapis.com/v1/projects/<project-id>/messages:send` with that token as its bearer
and `{"message": …}` as its body.

**"Something changed" is two messages, not one.** The sync hint must stay data-only: add a
`notification` object to it and it is a notification, and it no longer runs a sync. To show the user
something as well, send a second, separate notification message.

Drop the token when FCM answers `UNREGISTERED`, 404, or `INVALID_ARGUMENT` (400) about the
registration token. Retry 429 and 5xx answers later, with backoff.

A sender needs no SDK. This one uses `node:crypto` only:

```js
import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';

// Server only. The service account never goes in the app, the web bundle or the repository.
const account = JSON.parse(readFileSync(process.env.FCM_SERVICE_ACCOUNT, 'utf8'));
const b64 = value => Buffer.from(JSON.stringify(value)).toString('base64url');
let cached;

async function accessToken() {
  if (cached && cached.expires - 60_000 > Date.now()) return cached.token;
  const iat = Math.floor(Date.now() / 1000);
  const claims = {
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 3600,
  };
  const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64(claims)}`;
  const signature = createSign('RSA-SHA256').update(unsigned).sign(account.private_key, 'base64url');
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`oauth ${response.status} ${body.error ?? ''}`);
  cached = { token: body.access_token, expires: Date.now() + body.expires_in * 1000 };
  return cached.token;
}

// Returns 'sent', 'drop' (forget this token) or 'failed'.
export async function send(message) {
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${await accessToken()}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message }),
  });
  if (response.ok) return 'sent';
  const { error } = await response.json().catch(() => ({}));
  const code = error?.details?.find(d => d.errorCode)?.errorCode ?? error?.status;
  const badToken = response.status === 404 || code === 'UNREGISTERED'
    || (code === 'INVALID_ARGUMENT' && /registration token/i.test(error?.message ?? ''));
  return badToken ? 'drop' : 'failed';
}

// After a change, for each token of each affected user:
await send({
  token,
  data: { valence: 'sync' },
  android: { priority: 'high' },
  apns: { headers: { 'apns-push-type': 'background', 'apns-priority': '5' }, payload: { aps: { 'content-available': 1 } } },
});
await send({ token, notification: { title: 'New item', body: 'Your list changed' }, data: { route: 'list' } });
```

The `data` of the notification message is your app's own metadata; it reaches the page in
`push.received` and `push.tapped`, and never runs a sync.

## Check it in your own app

Run these with your own Firebase project before you ship: deny then grant permission; register;
send a foreground notification; background the app and send an image notification;
tap it both warm and after process death; send a data-only sync hint and verify a
known server row/outbox acknowledgement without any bundle-state transition;
check token persistence/rotation and normal offline launch. Do not use force-stop
as a test of guaranteed silent delivery. Token rotation has not been observed yet,
so keep re-registering on resume as well as on `push.tokenChanged`.

Primary references checked 2026-10-22:
[Flutter message handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[native setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[Messaging 16.7](https://pub.dev/packages/firebase_messaging/versions/16.7.0),
[image payloads](https://firebase.google.com/docs/cloud-messaging/android/send-image).

Host-to-page push events are capped at 256 KiB including script escaping. Successful and error replies count Unicode separator escapes before enforcing their JSON byte cap. An oversized error returns E_TOO_LARGE with a finite numeric correlation id, or null for an invalid/oversized id.
