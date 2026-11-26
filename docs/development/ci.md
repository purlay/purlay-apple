# Continuous integration

What CI checks, how it stays inside its targets, and what to do when it does not. The decision is
[ADR 0008](../decisions/0008-ci-lanes-and-one-required-check.md); the releases are in [releasing.md](releasing.md).

## The targets

- **A pull request is mergeable within 3 minutes** of its last push: `verify`, the only required check, is green.
- **A documents-only pull request is green in under 30 seconds.**
- **A release ships within 10 minutes** of its tag (not counting the owner's approval of the `release` environment).

Every run of `ci.yml` writes a table of its jobs' times, and the wait for a runner, against the 3-minute target to the run's
summary page, and warns on the run when it is over; the release workflows do the same against 10 minutes
(`scripts/ci/summary`).

## The workflows

| Workflow | When | What |
|---|---|---|
| `ci.yml` | every pull request to main, every push to main, Mondays 03:17 UTC, by hand | the lanes, and `verify` |
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
| `packages` | `xcode-27` | any code change but the scripts and `Design/` alone | format, and every package test on macOS (`TestPlans/macOS.xctestplan`), the Mac screens drawn | 100–140 s |
| `ios` | `xcode-27` | the package, `Config/`, the project or `Apps/iOS` change | the package and the iOS app built for the simulator | 50–100 s |
| `macos` | `xcode-27` | the package, `Config/`, the project or `Apps/macOS` change | the Mac app built (Debug; Debug and Release on main), its ATS and entitlements checked | 60–110 s (main: 120–200 s) |
| `generated` | `xcode-27` | `Contract/`, `Tools/`, `Sources/*/Generated` or their scripts change | the pinned bundle, `scripts/generate --check`, the generator's tests | 70–110 s |
| `simulator` | `xcode-27` | main, the schedule, by hand, and a pull request that changes `Apps/iOS` or the iOS test plans | the iOS tests on the simulator `.github/toolchain.env` names | 4–8 min (not a pull request's usual path) |
| `verify` | Linux | always, after the others | the timing summary; every lane passed or was not needed (`scripts/ci/verify-needs`) | 5–10 s |

The exact mapping from paths to lanes is `scripts/ci/changes`, which a person can run: `git diff --name-only main | scripts/ci/changes
pull_request`. A path it does not know runs every lane; a workflow, the `Makefile`, `scripts/verify` or `scripts/ci` runs every lane;
any event but a pull request runs every lane, so main always checks and caches everything.

**A pull request's time** is its slowest needed lane plus the wait for a runner: about 2 to 2½ minutes for a change to the engine,
which needs `packages`, `ios`, `macos` and `rules`. **A documents-only pull request** runs `changes` and `security` side by side
and then `verify`: about 25 seconds. A pull request that changes the iOS app also runs the simulator, which does not fit 3 minutes;
that is accepted for the app's own changes, and it is why the simulator runs nowhere else on pull requests.

## What the times rest on

Measured, not yet on this workflow's runners (TD-021):

- **Each lane on a developer's Apple silicon Mac, warm, 2026-11-26:** `rules` 50–85 s, `generated` 12 s, `packages` 90 s, `ios`
  91 s, `macos Release` 120 s, `simulator` 62 s; an unsigned iOS Release archive 99 s.
- **The quality audit's run of the pull request's lanes in sequence, warm:** about 2 min 18 s in all. **Cold:** `packages` 113 s
  and the Mac's Debug and Release builds 192 s. **Restoring the compilation cache is what makes 3 minutes possible**: a lane that
  starts cold can take longer than the target on its own.
- **The hosted runner** (Apple M1, virtual, 3 cores, 7 GB): the first `xcodebuild` of a job costs about 45 s more than the next one
  whatever the cache holds, so a macOS lane's floor is about 80–90 s (some 20 s of job set-up and cache restore, plus that first
  build). The same lane has taken 77 s in one run and 141 s in another, because the machines are shared. A pull request that
  ran equivalent lanes measured 89–97 s for the iOS lanes, 106–126 s for the engine's, and 100–156 s for the Mac's; a
  documents-only one 15 s. Starting a simulator took about three and a half minutes of an eleven-minute job.

## The caches

- **Compilation:** Xcode's content-addressed cache (`COMPILATION_CACHE_ENABLE_CACHING`, path `PURLAY_CACHE_DIR`). A build in a
  fresh checkout reuses what any earlier build with the same inputs compiled, whatever the files' dates. One cache per lane, per
  Xcode build and per day: `cas-<lane>-<Xcode build>-<ISO week>-<date>` (`scripts/ci/cache-keys`).
  - **Only main saves.** A pull request restores and never writes, so a branch cannot plant anything for main or another branch.
  - **Main restores only the current week's caches**, so each week starts from nothing and a cache cannot grow without end; the
    Monday run warms the week. A pull request also falls back to last week's, so Monday's first pull request is not cold.
  - A different Xcode never sees another's cache: its build is part of every name.
  - GitHub keeps 10 GB of caches per repository and evicts the least recently used. If eviction empties a lane's cache during the
    week, its next main run saves it again.
- **The contract bundle:** cached by the digest of `Contract/contract.lock`, saved by main; on a miss
  `scripts/prepare-contract` downloads it from the server's release and checks it against the lock.

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
  organisation): avoid opening pull requests on top of each other. A cold lane: was main's Monday run green? Re-run the scheduled
  run by hand (*Actions → CI → Run workflow* on main) to warm the week.
- **CI down, or out of macOS minutes:** [runbook](../runbooks/ci-outage.md).
- **A change that makes the check slower** says why in its description, with the run's times.
- **A new lane** is a job that `verify` needs and `scripts/ci/changes` maps, or it is not checked.
