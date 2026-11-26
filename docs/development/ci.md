# Continuous integration

What CI checks, how it stays inside its targets, and what to do when it does not. The decision is
[ADR 0008](../decisions/0008-ci-lanes-and-one-required-check.md); the releases are in [releasing.md](releasing.md).

## The targets

- **A pull request is mergeable within 3 minutes** of its last push: `verify`, the only required check, is green.
- **A documents-only pull request is green in under 30 seconds.**
- **A release ships within 10 minutes** of its tag (not counting the owner's approval of the `release` environment).

Every run shows the target and where the time went, on the run's summary page and in the log:

- `verify` (and each release workflow's `summary` job) writes every job's time and its wait for a runner against the target,
  every step of 5 s or more, and a warning when the run is over (`scripts/ci/summary`).
- Each lane of `scripts/verify` times its phases (`resolve`, `build`, `boot`, `test`, `check`, `format`): the log stamps each
  phase's start and end with the time of day, and the lane writes a table of them to its job's summary, against
  `PURLAY_TARGET_SECONDS` (180 in `ci.yml`, 600 in the release workflows). Every test action also prints how many tests ran,
  passed, failed and were skipped.

## The workflows

| Workflow | When | What |
|---|---|---|
| `ci.yml` | every pull request to main, every push to main, nightly at 03:17 UTC, by hand | the lanes, and `verify` |
| `release-macos.yml` | a `macos/v*` tag; by hand, `publish` off, for a rehearsal | [the Mac release](../runbooks/release-macos.md) |
| `release-ios.yml` | an `ios/v*` tag; by hand | an unsigned Release archive, kept 14 days |
| `contract-drift.yml` | Mondays 04:41 UTC, by hand | one issue when the server has released past the pin ([runbook](../runbooks/contract-drift.md)) |
| `scorecard.yml` | every push to main, Mondays, by hand | the OpenSSF Scorecard, under Security → Code scanning |
| `labels.yml` | a change to `.github/labels.yml`; every pull request | syncs the labels; labels a pull request by its paths |
| `dependabot-auto-merge.yml` | a Dependabot pull request | turns on auto-merge (squash) for a patch update; `verify` still decides |

## `ci.yml`, job by job

| Job | Runner | Runs when | What | Expected time, warm |
|---|---|---|---|---|
| `changes` | Linux | always | each app's version has its changelog section (`scripts/ci/changelog-versions`); the branch name (`scripts/check-branch`); which lanes the change needs (`scripts/ci/changes`) | 5–10 s |
| `security` | Linux | always, a documents-only pull request included | gitleaks over the whole history (`scripts/verify security`) | 10–20 s |
| `rules` | Linux | any code change | `scripts/verify rules`: the architecture rules and their demonstration, the strings | 60–120 s (unmeasured on Linux; 50–85 s on a developer Mac) |
| `packages` | `xcode-27` | any code change but the scripts and `Design/` alone | the layer rule, format, and every package test on macOS (`TestPlans/macOS.xctestplan`, targets side by side), the Mac screens drawn | 130–180 s |
| `ios` | `xcode-27` | the package, `Config/`, the project or `Apps/iOS` change | the package and the iOS app built for the simulator | 100–115 s |
| `macos` | `xcode-27` | the package, `Config/`, the project or `Apps/macOS` change | the Mac app built (Debug; Debug and Release on main), its ATS and entitlements checked | 90–135 s (main: more, unmeasured) |
| `generated` | `xcode-27` | `Contract/`, `Tools/`, `Sources/*/Generated` or their scripts change | the pinned bundle, `scripts/generate --check`, the generator's tests | 60–90 s |
| `simulator` | `xcode-27` | main, nightly, by hand, and a pull request that changes `Apps/iOS`, `Sources/PurlayDesign`, `Tests/PurlayDesignTests`, `TestPlans/iOS.xctestplan` or the simulator's scripts | the tests that need iOS (`TestPlans/iOS.xctestplan`: `PurlayTests`, `PurlayUITests`, `PurlayDesignTests`), built for testing, then the simulator booted, then tested without building | 6–8½ min: over the target (below) |
| `verify` | Linux | always, after the others | the timing summary; every lane passed or was not needed (`scripts/ci/verify-needs`) | 5–10 s |

The exact mapping from paths to lanes is `scripts/ci/changes`, which a person can run: `git diff --name-only main | scripts/ci/changes
pull_request`. A path it does not know runs every lane; a workflow, the `Makefile`, `scripts/verify` or `scripts/ci` runs every lane;
any event but a pull request runs every lane, so main always checks and caches everything. A workflow, the `Makefile`,
`scripts/verify` or `scripts/ci` alone runs every lane but the simulator; `scripts/ci/changes-test`, run by `rules`, holds the
mapping to the cases that matter.

**A pull request's time** is its slowest needed lane plus the wait for a runner: about 2 to 2½ minutes for a change to the engine,
which needs `packages`, `ios`, `macos` and `rules`: measured 3 min 11 s and 2 min 25 s warm to the last lane, plus about 10 s for `verify` (runs 45890766300, 45892203168, the
slowest lane `packages` at 134–179 s). **A documents-only pull request** runs `changes` and `security` side by side and then
`verify`: about 25 seconds. A pull request that changes the iOS app or the design system also runs the simulator, which does not
fit 3 minutes on the hosted runner (below); that is why it runs for nothing else.

## What the times rest on

Measured on PR #2 (every lane, the whole tree changed), 2026-11-26, on the hosted `xcode-27` runner (Apple M1, virtual, 3 cores,
7 GB). Job times include the job's set-up; "cold" is no compilation cache, "warm" is the pull request's own cache from its
previous push.

| Lane | Cold (run 45870656651, before; 45875297933, after) | Warm (45890766300 / 45892203168) |
|---|---|---|
| `packages` | 342 s / 372 s (build 201 s, tests 84 s one target after another) | 179 s / 134 s (layer rule 29 s → beside the fetch; build 31–41 s; tests 44–55 s side by side) |
| `ios` | 228 s / 247 s | 99 s / 106 s (builds 37 + 27 s) |
| `macos` | 161 s / 117 s | 90 s / 90 s |
| `generated` | 109 s / 87 s | 59 s / 57 s |
| `rules`, `security`, `changes` | 20 s, 5 s, 8 s | 21 s, 5 s, 5 s |
| `simulator` | 1091 s, **failed** / 926 s | 369 s / 509 s |
| **The pull request, wall** | 18 min 38 s / 17 min 21 s | 6 min 27 s / 8 min 46 s; **without the simulator: 3 min 11 s / 2 min 25 s** to the last lane |

**The simulator lane, before and after.**

- *Before* (run 45870656651): every package test that builds for iOS ran again on the simulator, and failed for want of the
  contract bundle; the device booted beside a cold build. One 1044 s step: about 890 s of build and 152 s of testing, as
  far as the quiet log told.
- *Only what needs iOS* (40 tests instead of every package's). Logic runs once, on macOS.
- *Boot beside the build* (runs 45875297933 cold, 45878129726 warm): the device itself booted in about 85 s, but while it
  booted and settled the machine starved: 89 MB of cache took 4 minutes to restore, resolving the packages 96–358 s, and the
  *warm* build 364 s against 78 s for the same build in `ios`. The job took 926 s either way.
- *Boot after the build* (45890766300): restore 3 s, resolve 22 s, build 21 s, boot 119 s (of which the device's own 65 s,
  mostly data migration), tests 165 s. Job 369 s. A second warm run (45892203168, each target apart) took 509 s:
  `PurlayTests` 221 s for 33 tests that run in a second, `PurlayDesignTests` 12 s, the two skipped UI tests 36 s.

**Why the simulator does not fit 3 minutes, and what would.** Build and fetch are under a minute warm; the rest is the fresh
device: its boot (65–85 s) and its first minutes, during which the first app launch takes over three minutes on three cores.
A hosted runner is clean every time, so every run pays it. What would fit: a larger runner (more cores; a paid plan), or a
self-hosted Mac that keeps a booted, settled device between runs. Until then the lane runs only for the iOS app and the design
system, and nightly on main.

**On a developer's Apple silicon Mac** (10 cores, warm): `packages` 75 s, `simulator` 54 s (boot 6 s), `rules` about 40 s.
The hosted runner's first `xcodebuild` of a job costs some 25–45 s whatever the cache holds (it shows in each lane's `resolve`).

## The caches

- **Compilation:** Xcode's content-addressed cache (`COMPILATION_CACHE_ENABLE_CACHING`, path `PURLAY_CACHE_DIR`). A build in a
  fresh checkout reuses what any earlier build with the same inputs compiled, whatever the files' dates. One cache per lane, per
  Xcode build and per day: `cas-<lane>-<Xcode build>-<ISO week>-<date>` (`scripts/ci/cache-keys`).
  - **Main saves**, once per lane and day (the nightly run, or the first push of the day).
  - **A pull request saves only when it found nothing at all** (main not warm yet, or a new Xcode), so that its next push is
    warm. GitHub keeps a pull request's cache to that pull request: no other branch, main included, can read it. A pull request
    that restored main's cache, even an older one, never saves.
  - **Main restores only the current week's caches**, so each week starts from nothing and a cache cannot grow without end; the
    nightly run warms each day. A pull request also falls back to last week's, so Monday's first pull request is not cold.
  - Sizes measured: `ios` 199 MB, `simulator` 89 MB.
  - A different Xcode never sees another's cache: its build is part of every name.
  - GitHub keeps 10 GB of caches per repository and evicts the least recently used. If eviction empties a lane's cache during the
    week, its next main run saves it again.
- **The contract bundle:** cached by the digest of `Contract/contract.lock`, saved by main; on a miss
  `scripts/prepare-contract` downloads it from the server's release and checks it against the lock. `packages` and `generated`
  share these steps through `.github/actions/contract-bundle`; the simulator lane does not need the bundle.

## The toolchain

`.github/toolchain.env` states the Xcode (27.2) and the simulator (iPhone 17, iOS 27.2). Every macOS job selects that Xcode
with `scripts/ci/select-xcode` and fails at once if the runner image lacks it or another answers; the simulator lane picks the
named device by its identifier (`scripts/ci/simulator-destination`). The runner label is `xcode-27` (GitHub's image with Xcode
27.0, 27.1 and 27.2; 27.1 is its default, which cannot read the project). When the image changes:
[runbook](../runbooks/xcode-update.md).

## Hardening

- Top-level `permissions: {}`; each job asks for what it uses (`contents: read` for most; `pull-requests: read` for `changes`;
  `actions: read` for the summary). No job of `ci.yml` can write to the repository.
- Every action is pinned by its full commit, with the version in a comment; Dependabot proposes updates weekly.
- `persist-credentials: false` on every checkout: no later step holds the token in `.git/config`.
- Inputs a person controls (branch names, pull request fields) reach a script through `env:`, never by `${{ }}` inside `run:`.
- No `pull_request_target` checks out or runs a pull request's code; `labels.yml` uses it only for the labeler, which reads the
  list of changed paths.
- A pull request from a fork needs approval before its workflows run (`.github/settings.md`).
- `scripts/ci/retry-infra` runs a step once more only when the log shows the machine failed (a simulator that would not boot, a
  download that did not arrive), never when a test failed, and says so as a warning on the run.
- Dependabot's branches are recognised by the pull request's author (`dependabot[bot]`), which a branch name cannot fake.
- No bot comments on pull requests: results are the checks and the run's summary page.

## When it is slow or down

- **A pull request over 3 minutes:** read the run's summary. Waiting for a runner is the plan's limit (5 macOS jobs for the whole
  organisation): avoid opening pull requests on top of each other. A cold lane: was main's nightly run green? Re-run the scheduled
  run by hand (*Actions → CI → Run workflow* on main) to warm the week.
- **CI down, or out of macOS minutes:** [runbook](../runbooks/ci-outage.md).
- **A change that makes the check slower** says why in its description, with the run's times.
- **A new lane** is a job that `verify` needs and `scripts/ci/changes` maps, or it is not checked.
