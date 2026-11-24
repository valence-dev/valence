# Changelog

## Unreleased

No code changes. Remote push (FCM) was built and run on Android, end to end, with this package. That covers foreground, background, killed-process sync, notification taps and image notifications. Token rotation has not been observed yet. iOS is experimental and untested. The README now lists the three dependencies to add and links the updated [Remote push](https://getvalence.dev/docs/guides/remote-push/) guide.

## 0.4.0-beta.1 (2026-11-22)

No changes in this package; the version follows the other Valence runtime packages. See the [release notes](https://github.com/valence-dev/valence/releases/tag/v0.4.0-beta.1).

## 0.4.0-beta.0 (2026-11-21)

The first public beta. **Android is supported; iOS is experimental and untested.** See the [release notes](https://github.com/valence-dev/valence/releases/tag/v0.4.0-beta.0)
for a summary and the known limits.

### a push-woken sync says so

No API change. The `sync:` callback a host passes to `ValencePush.handleBackground` should now call
`Valence.backgroundSync(config, kind: ValenceSyncKind.push)`, so a run woken by a data-only message is
distinguishable from the periodic job in the sync lease, in `sync.status` and in the log. The template
does this; a host that omits it reports `background`, which is harmless but less useful.

### First release of this package

Extract Firebase into an opt-in transport package. Schema 12 and push wire shapes stay unchanged. Android delivery needs a Firebase project; iOS is experimental and untested.
