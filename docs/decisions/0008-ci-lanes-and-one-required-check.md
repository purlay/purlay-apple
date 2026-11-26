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
- The simulator lane runs on main, weekly and when the iOS app or its test plans change, on one named simulator.
- Xcode's content-addressed compilation cache is restored by every macOS job; only main saves it, so a pull request cannot leave
  anything behind for another. Each week starts a new cache.
- One job, `verify`, always runs, judges every lane (passed, or skipped because `changes` said so), writes each lane's time
  against the target, and is the only required check.
- Every workflow: top-level permissions `{}` and each job its own; actions pinned by commit; timeouts on every job; no
  `pull_request_target` that checks out a pull request's code; a single retry only for a machine's failure, never a test's.

**Rejected.** *One job running `make verify`:* serial, about 6 to 9 minutes. *A simulator on every pull request:* no check that
starts one fits 3 minutes. *Caching DerivedData:* timestamps make it unreliable; the compilation cache is keyed by content.
*Requiring branches to be up to date:* each merge would restart every open pull request's check, and the 3 minutes with it.

**Consequences.** A documents-only pull request is green in seconds; a code change takes as long as its slowest lane plus the wait
for a runner. With several pull requests open, macOS jobs queue for the plan's 5 runners.
