# Continuous integration

What CI checks, how it stays inside its targets, and what to do when it does not. The decision is
[ADR 0008](../decisions/0008-ci-lanes-and-one-required-check.md); the releases are in [releasing.md](releasing.md).

## The targets

- **A pull request is mergeable within 3 minutes** of its last push: `verify`, the only required check, is green. That is the target,
  not a guarantee: the lanes themselves fit it only just (the slowest takes 111–172 s warm), and the wait for a runner does not;
  the organisation's other repositories decide that wait ([below](#where-a-pull-requests-time-goes)). `verify` does not wait for
  the simulator lane, and on a pull request the simulator starts only after `verify` has passed, so it never runs beside its own
  run's required lanes. Once started it holds a macOS runner for 6–10 minutes, which another pull request's lanes, or main's run
  after a merge, may wait for; merging or closing the pull request cancels it.
- **A documents-only pull request is green in under 30 seconds** (expected from its jobs' times; no such run measured yet).
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
| `ci-cancel.yml` | a pull request closed or merged | cancels that pull request's `ci.yml` run in flight (below) |
| `release-macos.yml` | a `macos/v*` tag; by hand, `publish` off, for a rehearsal | [the Mac release](../runbooks/release-macos.md) |
| `release-ios.yml` | an `ios/v*` tag; by hand | an unsigned Release archive, kept 14 days |
| `contract-drift.yml` | Mondays 04:41 UTC, by hand | one issue when the server has released past the pin ([runbook](../runbooks/contract-drift.md)) |
| `scorecard.yml` | every push to main, Mondays, by hand | the OpenSSF Scorecard, under Security → Code scanning |
| `labels.yml` | a change to `.github/labels.yml`; every pull request | syncs the labels; labels a pull request by its paths |
| `dependency-review.yml` | every pull request to main | GitHub's dependency review: refuses a pull request that adds a dependency with a known vulnerability of high severity or worse. Not required |
| `dependabot-auto-merge.yml` | a Dependabot pull request | turns on auto-merge (squash) for a patch update; `verify` still decides |

## `ci.yml`, job by job

| Job | Runner | Runs when | What | Expected time, warm |
|---|---|---|---|---|
| `changes` | Linux | always | each app's version has its changelog section (`scripts/ci/changelog-versions`); the branch name (`scripts/check-branch`); the pull request's title as a conventional commit, because it becomes the squash commit (`scripts/ci/check-pr-title`, judged again when the title is edited); which lanes the change needs (`scripts/ci/changes`) | 5–10 s |
| `security` | Linux | always, a documents-only pull request included | gitleaks over the whole history (`scripts/verify security`) | 5–8 s |
| `rules` | Linux | any code change | `scripts/verify rules`: the architecture rules and their demonstration, actionlint and shellcheck at the versions `scripts/install-lint-tools` pins (digests checked), the strings, and the tests of CI's own scripts: the lanes (`changes-test`), the demonstration's verdicts (`enforcement-demo-verdicts-test`), the SDK's sentence calls checked on CI whatever Xcode is selected (`sentence-calls-ci-test`), a test run's summary (`test-summary-test`, `test-summary-injection-test`), the cache folder's trust (`cache-trust-folders-test`), the title (`check-pr-title-test`), the release gate (`release-gate-test`) and every job's condition (`job-conditions-test`) | 19–22 s, plus the tools' download |
| `packages` | `xcode-27` | any code change but the scripts and `Design/` alone | the layer rule (with the SDK's sentence calls checked against this Xcode, and the manifest cache trusted only in the user's own folder: `enforcement-cache-trust-test`), format, and every package test on macOS (`TestPlans/macOS.xctestplan`, targets side by side), the Mac screens drawn | 111–179 s |
| `ios` | `xcode-27` | the package, `Config/`, the project or `Apps/iOS` change | the package and the iOS app built for the simulator | 75–143 s |
| `macos` | `xcode-27` | the package, `Config/`, the project or `Apps/macOS` change | the Mac app built (Debug; Debug and Release on main), its ATS and entitlements checked | 68–122 s (main: more, unmeasured) |
| `generated` | `xcode-27` | `Contract/`, `Tools/`, `Sources/*/Generated` or their scripts change | the pinned bundle, `scripts/generate --check`, the generator's tests | 57–100 s |
| `simulator` | `xcode-27` | every push to main, nightly, by hand: beside the other lanes | the tests that need iOS (`TestPlans/iOS.xctestplan`: `PurlayTests`, `PurlayUITests`, `PurlayDesignTests`), built for testing, then the simulator booted, then tested without building. A release requires it on main | 369–594 s: over the target (below) |
| `simulator (pull request)` (`simulator-pr`) | `xcode-27` | a pull request that changes `Apps/iOS`, `Sources/PurlayDesign`, `Tests/PurlayDesignTests`, `TestPlans/iOS.xctestplan` or the simulator's scripts, **once `verify` has passed** | the same steps as `simulator` (one YAML anchor, `simulator-steps`; `scripts/ci/job-conditions-test` holds the two jobs' runner, timeout and permissions equal). **Not required**; cancelled when the pull request is merged or closed | as `simulator`, after `verify` (run 45935368669: `verify` green 03:47:58, this job 03:48:54–03:56:31, 55 tests, 0 failed; every lane ran in that run, so the case its status function exists for, an iOS-only change with lanes skipped before `verify`, is held by `job-conditions-test` and not yet seen on a run: the first such pull request shows it) |
| `simulator-red-on-main` | Linux | the simulator failed on main | opens the one issue labelled `ci-red-main`, or brings the open one up to date (`scripts/ci/red-main-issue`) | 5–10 s |
| `verify` | Linux | always, after every lane but the simulator | the timing summary; every lane passed or was not needed (`scripts/ci/verify-needs`) | 5–10 s |

The exact mapping from paths to lanes is `scripts/ci/changes`, which a person can run: `git diff --name-only main | scripts/ci/changes
pull_request`. A path it does not know runs every lane; a workflow, the `Makefile`, `scripts/verify` or `scripts/ci` runs every lane;
any event but a pull request runs every lane, so main always checks and caches everything. A workflow, the `Makefile`,
`scripts/verify` or `scripts/ci` alone runs every lane but the simulator; `scripts/ci/changes-test`, run by `rules`, holds the
mapping to the cases that matter.

**A pull request's time** is its slowest needed lane plus the wait for a runner, plus about 10 s for `changes` and 8 s for
`verify`; the lane times above cover both measurement sets ([below](#where-a-pull-requests-time-goes) and
[PR #2's](#what-the-times-rest-on)); the variance is the shared runners'. **A documents-only pull
request** runs `changes` and `security` side by side and then `verify`: about 25 seconds. A pull request that changes the iOS
app or the design system also runs the simulator, which takes 6 to 10 minutes; it starts when `verify` has passed, so its result
arrives some 6 to 10 minutes after the merge button turns green.

**The trade-off.** The simulator gives a pull request a signal without holding its merge to 6–10 minutes, and never beside its
own run's required lanes, which already take four of the five macOS runners. Once it starts it holds a runner that another pull
request, or main's run after a merge, may wait for; a merge or a close cancels it. `ci-cancel.yml` runs on a pull request's
`closed` event, joins `ci.yml`'s concurrency group of that pull request (`ci-<number>`) with cancel-in-progress, and does
nothing else: `permissions: {}`, nothing checked out, one job whose name is no required check. It is not a `closed` trigger in
`ci.yml`, because that run would post every job's check onto the pull request's head, skipped, `verify`'s included; a skipped
check counts as passed, so a reopened pull request (or Dependabot's auto-merge after a reopen) would read as green until its new
run's `verify` existed. Cancelling on a merge is not yet seen on a run. A fork's pull request is the exception: its `ci-cancel.yml` run, like every workflow a fork starts, waits for an approval (*Require approval for all external contributors*, [settings.md](../../.github/settings.md)) that nobody gives to a closed pull request, so a fork's simulator run keeps its runner to the end, 6–10 minutes. That is accepted: `pull_request_target` would cancel it, at the price of running with the repository's token on a fork's event. A person who wants its result before merging waits for it; nothing makes them. A change can
therefore merge with the iOS tests red; main's run catches it on the push, `simulator-red-on-main` opens (or updates) one
`ci-red-main` issue, and no release ships from a commit whose main run, simulator included, did not pass
([releasing.md](releasing.md#what-every-release-workflow-does-first-the-gate)). Whoever reads that issue fixes main first.

## Where a pull request's time goes

Measured on the hosted `xcode-27` runner, warm (main's compilation cache of the day restored), every lane but the simulator
needed. A job's time is its set-up, its `scripts/verify` phases and its clean-up; the run's time adds the wait for runners.

| Run (PR) | Wait before the macOS lanes started | `packages` (set-up and clean-up · format · resolve · build · test) | `ios` | `macos` | push → `verify` green |
|---|---:|---|---:|---:|---:|
| 45898569052 (#2) | 14 s | 172 s (29 · 7 · 34 · 36 · 65) | 92 s | 68 s | 193 s |
| 45895104429 (#2) | 13 s | 165 s | 102 s | 109 s | 186 s |
| 45921783768 (#5) | 346 s | 114 s (18 · 4 · 21 · 27 · 44) | 87 s | 122 s | 654 s |
| 45923140177 (#5, the warm-up below) | 570 s | 172 s | 127 s | 117 s | 1209 s |
| 45926185244 (#5) | 577 s | 111 s (15 · 4 · 19 · 27 · 46) | 125 s | 93 s | 1117 s |
| 45928126332 (#5) | 556 s | 148 s (21 · 7 · 28 · 37 · 54) | 75 s | 120 s | 1623 s (`verify` itself waited 847 s for a Linux runner) |

- **The lanes nearly fit the target; the wait for a runner does not.** With runners free, the run is `changes` (about 10 s), the
  slowest lane (usually `packages`) and `verify` (about 8 s): 186 s and 193 s in PR #2's runs, when `packages` took 165–172 s;
  about 150 s when it takes 111–114 s, as in PR #5's runs. The runner's speed varies that much from one job to the next. The
  runs over 3 minutes waited: for macOS runners (5 for the organisation) and, in PR #5's, for any runner at all (`changes`, a
  Linux job, waited 105–280 s, and `verify` up to 847 s), because the organisation's 20 concurrent jobs were taken by other repositories' runs: the
  server's (174 runs between 01:10 and 02:24 UTC on 2026-11-27, 24 of them queued at a time) and the per-platform repositories whose code this one now
  holds, whose CI still runs on macOS (`purlay-ios`: 11 runs in that hour). **Once work happens here alone, turning off the CI
  of `purlay-ios`, `purlay-macos` and `purlay-swift`** (archive them, or disable their workflows) is the change that matters
  most for the wait, and it is outside this repository.
- **`packages`**: its test phase is the largest part (44–65 s for about 1000 tests on three cores; `PurlayMacUITests` alone 37 s,
  every other target together 35 s, in run 45921784210), then the build (27–44 s with every compilation a cache hit: linking and
  copying seven test bundles), then the job's first `xcodebuild` (21–40 s, shown as `resolve`).
- **The first `xcodebuild` of a job** costs 21–40 s whatever it does; the next one 3–4 s, even with a fresh derived data folder
  and a fresh packages folder (run 45921784210). It is the runner, not the network: Sparkle's 99 MB resolve in 4 s once
  `xcodebuild` has run once.

**Measured, and not adopted** (run 45921784210, unless said):

- *Caching the resolved packages* (`SourcePackages`): resolving with an empty packages folder takes 4 s after the first
  `xcodebuild`; restoring 99 MB would cost as much. The 21–40 s `resolve` is the first `xcodebuild`, not the download.
- *Starting the first `xcodebuild` in the background while the caches restore* (run 45923140177): the warm-up took 32–37 s
  beside the restore instead of 21–40 s alone, the lane then waited 14–15 s for it, and `packages` lost the overlap it already
  has (its layer rule and format run beside `resolve`): `packages` 172 s, `ios` 127 s. Slower; removed.
- *One `xcodebuild test` for `packages`* instead of resolve, build-for-testing and test-without-building: 112 s against 92 s for
  the three phases in the same night's run. The phases stay, and say where the time went.
- *`ios` for arm64 only, one derived data folder for both builds:* 75 s + 49 s against today's 37 s + 10 s + 30 s with the same
  change to the engine: a different `ARCHS` misses main's cache, and the shared folder did not spare the second build its 146
  compilations.
- *`PurlayMacUITests` in a job of its own:* `packages` would save some 17 s of tests, for a fifth required macOS job and its own
  set-up (25 s) and first `xcodebuild` (21–40 s); in the `macos` lane it would make `macos` the slowest. Not worth a runner of
  five. The tests themselves are the lever: `PurlayMacUITests` (37 s, screens drawn one after another) and
  `PurlayContractTests`' one test that reads every schema's examples (13 s of its 26 s).

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
| `simulator` | 1091 s, **failed** / 926 s | 369 s / 509 s / 594 s (45893442148) |
| **The pull request, wall** | 18 min 38 s / 17 min 21 s | 6 min 27 s to 10 min 13 s with the simulator; **without it: 2 min 25 s to 3 min 11 s** to the last lane |

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
device: its boot (65–85 s) and its first minutes, during which the first test launch takes 165–394 s on three cores. A hosted
runner is clean every time, so every run pays it. The paths to a faster simulator, cheapest first:

1. **Move logic out of the app target into packages**, where it is tested on macOS in seconds; the app's own tests then shrink to
   wiring, and the simulator lane to what only a device shows. This shortens what runs, not the device's first minutes.
2. **A larger hosted runner** (more cores; a paid plan): the device's settling competes with fewer things.
3. **A self-hosted Mac** that keeps a booted, settled device between runs: no boot, no first-minutes cost; it needs a machine
   kept up to date and isolated from pull requests' code (fork pull requests never run on it).

Until one of these is taken, the lane runs on main, nightly and by hand, and as a non-required check for the iOS app and the
design system.

**On a developer's Apple silicon Mac:** [getting-started.md](getting-started.md) has the times.
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
named device by its identifier (`scripts/ci/simulator-destination`). The project's one package, Sparkle, is pinned by revision
in the committed `Apps/Purlay.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, so every build and every
release resolves the same code; Dependabot proposes its updates. The runner label is `xcode-27` (GitHub's image with Xcode
27.0, 27.1 and 27.2; 27.1 is its default, which cannot read the project). When the image changes:
[runbook](../runbooks/xcode-update.md).

## Hardening

- Top-level `permissions: {}`; each job asks for what it uses (`contents: read` for most; `pull-requests: read` for `changes`;
  `actions: read` for the summary; `issues: write` for `simulator-red-on-main` alone). No job of `ci.yml` can write to the code.
- Every action is pinned by its full commit, with the version in a comment; Dependabot proposes updates weekly.
- `persist-credentials: false` on every checkout: no later step holds the token in `.git/config`.
- Inputs a person controls (branch names, pull request fields) reach a script through `env:`, never by `${{ }}` inside `run:`.
- No `pull_request_target` checks out or runs a pull request's code; `labels.yml` uses it only for the labeler, which reads the
  list of changed paths.
- A pull request from a fork needs approval before its workflows run (`.github/settings.md`).
- `scripts/ci/retry-infra` runs a step once more only when the log shows the machine failed (a simulator that would not boot, a
  download that did not arrive), never when a test failed, and says so as a warning on the run.
- A job that needs `verify` (or any job whose `if` is `always()`) states its own status function: otherwise GitHub judges its
  implicit `success()` over every ancestor, and a lane `changes` skipped would skip it (actions/runner#2205). No workflow that
  runs on a pull request's `closed` event has a job named like a required check; `ci-cancel.yml` listens to `closed` alone, in
  `ci.yml`'s group, and can do nothing. `scripts/ci/job-conditions-test`, in `rules`, reads every workflow as YAML (the system
  Ruby's Psych) and holds all of it, each rule shown first to refuse its violation.
- Dependabot's branches are recognised by the pull request's author (`dependabot[bot]`), which a branch name cannot fake.
- No bot comments on pull requests: results are the checks and the run's summary page.

## When it is slow or down

- **A pull request over 3 minutes:** read the run's summary. Waiting for a runner is the plan's limit (20 jobs and 5 macOS jobs
  for the whole organisation, every repository's runs included): avoid opening pull requests on top of each other, and see what
  else the organisation is running (*Actions* of each repository). A cold lane: was main's nightly run green? Re-run the scheduled
  run by hand (*Actions → CI → Run workflow* on main) to warm the week.
- **CI down, or out of macOS minutes:** [runbook](../runbooks/ci-outage.md).
- **A change that makes the check slower** says why in its description, with the run's times.
- **A new lane** is a job that `verify` needs and `scripts/ci/changes` maps, or it is not checked. The simulator is the one
  exception: main and the release gate check it, `verify` does not wait for it, and on a pull request it waits for `verify`.
- **A `ci-red-main` issue:** main's simulator is red. Fix main before anything else; until it is green no release can ship.
