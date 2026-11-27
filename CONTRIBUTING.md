# Contributing to Valence

Thanks for helping. Bug reports, docs fixes and code are all welcome.

## Before you start

- **Security problems:** do not open an issue. Follow [SECURITY.md](SECURITY.md).
- **Bugs:** open an issue with the bug template. Say which device or emulator and Android version you
  ran on.
- **Larger changes:** open an issue first so we can agree on the shape before you write the code.
- **Docs site:** the site's source is not public yet. Report docs problems as issues here.

## Setup

You need Node 22.18 or later, Flutter 3.47 or later with Dart 3.13 or later, and Git.

```sh
git clone https://github.com/valence-dev/valence.git
cd valence
npm test                                   # CLI, wizard, generated Dart and TS
cd packages/bridge && npm ci && npm run typecheck && npm test
cd ../valence && flutter test && flutter analyze --fatal-infos
```

The Dart test in `npm test` skips if `dart` is not on your PATH. A skip is not a pass.

## Repo layout

| Path | What it is |
|---|---|
| `bin/valence.mjs` | The `npm create valence` wizard |
| `.claude/skills/valence/references/contracts.md` | **The spec.** Bundle format, update state machine, bridge, sync, store policy, test matrix |
| `.claude/skills/valence/scripts/valence.mjs` | The zero-dependency CLI: keygen, codegen, bundle, verify, pointer, seed |
| `packages/valence` | The Flutter host runtime (pub.dev) |
| `packages/valence_push` | Optional Firebase push transport (pub.dev) |
| `packages/bridge` | The TypeScript web client, `@getvalence/bridge` (npm) |
| `examples/` | Reference integrations |

[AGENTS.md](AGENTS.md) has the full rules; the ones that matter most are below.

## Rules

1. **The spec comes first.** A behaviour change updates `contracts.md`, the code and the tests in the
   same pull request. If code and spec disagree, that is a bug.
2. **The bridge IDL and the manifest `format` are additive only.** Never change a field's meaning; add a
   new field or a new `format` number.
3. **Security paths are never simplified:** the signature check order, the bridge nonce, the navigation
   lock, strict decoding and atomic state writes. Every security fix comes with a regression test.
4. **The CLI stays zero-dependency** (Node standard library only).
5. **Generated code must stay clean:** Dart passes `dart analyze --fatal-infos`, TypeScript type-checks
   under `--strict --verbatimModuleSyntax`.
6. **Small and boring wins.** The smallest correct change, no speculative abstractions.

## Pull requests

- Branch from `main` and open the pull request against `main`.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
  `fix(updater): keep the trial marker after a renderer reload`.
- Add a line to the relevant `CHANGELOG.md` under the next version.
- CI must be green. Say in the description what you ran by hand, especially anything on a device.

By contributing you agree that your work is released under the [MIT License](LICENSE), and that you
follow the [Code of Conduct](CODE_OF_CONDUCT.md).
