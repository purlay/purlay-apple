# 0008. CI: lanes side by side, each only when a change reaches it, and one required check

Status: accepted, 2026-11-26

**Context.** A pull request must be mergeable within 3 minutes. The organisation is on GitHub's free plan: 5 concurrent macOS
jobs across every repository. A hosted macOS runner is clean every time; compiling the engine from nothing took minutes, and
starting a simulator took about three and a half minutes whatever was tested.

**Decision.**
- `ci.yml` runs the lanes of `scripts/verify` as separate jobs, side by side. Linux runs `changes`, `security` and `rules`;
  macOS runs `packages`, `ios`, `macos`, and `generated` only when the contract, the generator or the generated code change.
- `changes` maps the changed paths to the lanes that read them (`scripts/ci/changes`). A document needs no lane; an unknown path
  runs every lane; any event but a pull request runs every lane.
- The simulator lane runs on every push to main, nightly and by hand, on one named simulator, and only what needs iOS (the app's
  tests and `PurlayDesignTests`); every other package test runs once, on macOS. On a pull request that changes the iOS app or
  the design system it runs too, as a check that is **not required**, and only after `verify` has passed, so that it never runs
  beside its own run's required lanes; a merge or close of the pull request cancels it (`ci-cancel.yml`, a workflow of its own so that no `closed` run posts `verify`) (amended 2026-11-27). A release requires main's
  run of the tagged commit to have passed, its simulator job included; a red simulator on main opens or updates one
  `broken` issue. (Amended 2026-11-26, after measuring it at 369–594 s warm on the hosted runner, most of it the fresh
  device's boot and first launch: it ran every package test that builds for iOS, weekly, and `verify` waited for it.)
- Xcode's content-addressed compilation cache is restored by every macOS job. Main saves it; a pull request saves only when it
  found nothing at all to restore, into a scope GitHub keeps to that pull request, so it cannot leave anything behind for
  another. Each week starts a new cache.
- One job, `verify`, always runs, judges every lane (passed, or skipped because `changes` said so), writes each lane's time
  against the target, and is the only required check.
- Every workflow: top-level permissions `{}` and each job its own; actions pinned by commit; timeouts on every job; no
  `pull_request_target` that checks out a pull request's code; a single retry only for a machine's failure, never a test's.

**Rejected.** *One job running `make verify`:* serial, about 6 to 9 minutes. *A simulator on every pull request, or a required one on
some:* no check that starts one fits 3 minutes on a hosted runner. *Booting the simulator beside the build:* measured slower
(the build starved: 364 s instead of 78 s). The way to a required simulator check is a larger or self-hosted runner, or less
logic in the app target ([ci.md](../development/ci.md#what-the-times-rest-on)). *Caching DerivedData:* timestamps make it unreliable; the compilation cache is keyed by content.
*Requiring branches to be up to date:* each merge would restart every open pull request's check, and the 3 minutes with it.

**Consequences.** A pull request can merge with the iOS tests red; main's run and its issue catch it, and the release gate
holds the release until they are green. A documents-only pull request is green in seconds; a code change takes as long as its slowest lane plus the wait
for a runner. With several pull requests open, macOS jobs queue for the plan's 5 runners.
