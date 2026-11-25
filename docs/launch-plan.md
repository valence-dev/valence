# Launch plan: prove it in public

Goal: a stranger can see Valence working on their own phone within a minute, and can try it in their own project within an afternoon. Hype and sponsors come after that, not before.

Success measure: **apps in production on Valence** and weekly npm downloads, not stars.

Status on 2026-10-16:

| Item | State |
|---|---|
| Code repo `Bishal-Pahari/valence` | Private. Clean `main`, but old commits are still reachable by hash until the repo is deleted and recreated. |
| Site and docs repo `valence-site` | Local only, two commits, not on GitHub. Domain not chosen, `SITE_URL` is a placeholder. |
| npm package `create-valence` | **Never published.** `npm create valence@latest`, the first command on the site, fails for everyone. npm is not logged in on this machine. |
| Reference app | Exists only as the simulated phone on the website. |
| Flutter and Dart | Installed locally (Dart 3.12.2). |

## Phase 0: ready to be seen (about 1 week)

Everything here happens before the repo goes public.

| # | Task | Done when | Needs you |
|---|---|---|---|
| 0.1 | Harden the three review findings: no `shell: true` in the wizard (C1), no writes through links in `update` (C2), confine `web.out`, `web.lib`, `web.routes` and `host.dir` to the project (C3) | Each has a regression test in `valence.test.mjs`; `npm test` passes | |
| 0.2 | Add `SECURITY.md` (private reporting via GitHub security advisories), `CONTRIBUTING.md`, issue and PR templates | Files exist; GitHub shows "Report a vulnerability" | |
| 0.3 | Delete and recreate the GitHub repo, push the clean history | Old commit hashes return 404 | Approve the `delete_repo` permission (`gh auth refresh -h github.com -s delete_repo`) |
| 0.4 | Real npx flow from a packed tarball (AGENTS.md rule 2), then publish `create-valence@0.3.x` | `npm create valence@latest` works in a scratch project on Windows, macOS and Linux | npm account login; 2FA |
| 0.5 | Choose the domain, deploy `valence-site`, set `SITE_URL`, submit the sitemap in Search Console | Site live over HTTPS; check-seo passes with the real domain | Domain, host account, Search Console access |
| 0.6 | Make both repos public | Repos public; docs links stop returning 404 | Your go-ahead |

## Phase 1: the reference app (about 2 to 3 weeks)

The conference schedule app from the website, built for real. This is also roadmap item 1, and the source the pub package will be extracted from in the next bet.

**Where:** `examples/schedule/` in the code repo, with `web/` (SvelteKit, static adapter) and `mobile/` (Flutter host). Keeping it in the repo means CI proves every change against a real app.

| # | Task | Done when |
|---|---|---|
| 1.1 | Build the web app: day view, "Up next" card, sessions from the `schedule` bucket, plus `shim.ts` so it also runs as a website | The same build works at a public URL and inside the host |
| 1.2 | Run `npm create valence@latest` then `/valence init` exactly as a new user would, and keep a **friction log** of every stumble | Host builds on Android and iOS; every stumble is filed as an issue or fixed. The friction log is the most valuable research we will get. |
| 1.3 | Native value (Apple 4.2): offline cold start, a local notification 10 minutes before a starred session, and a home-screen widget showing "Up next" | Three §6 items work; `/valence doctor` passes |
| 1.4 | An in-app **"Shell" screen** showing the current, previous, trial and bad bundles and the floor: the device's own update state | A viewer can watch a trial, commit or rollback happen without any server telemetry. This is what makes the live demo visible. |
| 1.5 | Data: seed from the schedule JSON; sync as static chunks on the same CDN, no backend | First launch in airplane mode shows the full schedule; a correction row appears after sync |
| 1.6 | OTA hosting on a static host with the cache headers from the spec | Files, then manifests, then the pointer; pointer cached for 60 s |
| 1.7 | CI release pipeline: build web, `valence bundle`, `verify`, upload, `pointer --rollout 10`; ramping is a manual workflow run. The signing key lives in the `VALENCE_SIGNING_KEY` secret. | A tagged commit produces a staged release with no laptop involved |
| 1.8 | A **public release log** page on the site, built from the published pointer and manifests: each release's seq, date, rollout and notes | Visitors can see the real release history of a real app |

## Phase 2: through the stores (1 to 3 weeks, mostly waiting)

| # | Task | Done when | Needs you |
|---|---|---|---|
| 2.1 | Write review notes for both stores: what is downloaded (JavaScript and assets only), why that fits DPLA §3.3.1(B) and Play's interpreter exemption, the native features, and that the app works offline | Notes reviewed against the store policy guide | |
| 2.2 | TestFlight and Play internal testing | Builds installed on real devices; a full OTA release and an automatic rollback tested on each platform | Apple Developer account ($99/yr), Play Console account ($25 once), test devices |
| 2.3 | Production submission | Approved in both stores | Store listings, screenshots, privacy labels |
| 2.4 | If review pushes back: record the exact wording, adjust, and turn it into a section of the store policy guide | Every rejection reason becomes documentation | |

**Biggest risk:** App Review. Testing through TestFlight and the internal track first is the cheapest way to find out.

## Phase 3: the moment (1 week)

| # | Task |
|---|---|
| 3.1 | Record the 60-second "phones heal themselves" video: install, push a deliberately broken release, watch the Shell screen go trial, fail, fail, bad, back on the good bundle, then push the fix |
| 3.2 | Publish the essay "The hermit-crab architecture: keep the core, swap the shell" on the site |
| 3.3 | Launch on Show HN, r/FlutterDev, Flutter Community and X, all on the same day, every post linking the video, the store apps and the quick start |
| 3.4 | Turn on GitHub Sponsors with a clear "what your money funds" list: the pub package, the security audit, the rollout dashboard |

## After launch (the next bets)

- **Package it:** extract the runtime from `examples/schedule/mobile` into a `valence` pub package, and `client.ts` into `@valence/bridge`.
- **Migration guides** for teams leaving Capacitor Appflow (access ends 2027-12-31) and App Center CodePush.
- **Sponsors:** integration guides with the services in the release path (Cloudflare R2 or another CDN, Supabase or Turso for sync, Sentry for crash and ready signals); apply to OSTIF for an audit of the update path, and to NLnet for a grant.

## Set aside for now

A hosted SaaS, CRDTs, third-party mini-app stores, and new features that are not on this list.

## The open question

Who is the first team other than us that will run Valence in production? Phase 1's friction log and the launch should be aimed at finding them.
