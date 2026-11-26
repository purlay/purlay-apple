# Purlay for Apple platforms: documentation

The entry point: where things stand, what holds the code in shape, and which document to read when. The repository's own
[README](../README.md) is the short version for a visitor.

## Where things stand (2026-11-26)

- **Mac:** released. 0.3.0 (2026-11-24) is the latest; fixes wait under *Unreleased* in
  [`Apps/macOS/CHANGELOG.md`](../Apps/macOS/CHANGELOG.md). FR-101 to FR-124 work; followed threads (FR-125) wait for the contract.
  The first release from this repository waits for the stable update feed (TD-019, [runbook](runbooks/mac-update-feed.md)).
- **iPhone and iPad:** the walking skeleton works against a real server (launch, handshake, sign-in through the system browser,
  resuming a session), in English and Turkish. Slice 1 of the [entry design](design/entry-shell-account.md) is in progress: the
  launch screen, connecting and Welcome are built. Nothing is distributed: Q-001 blocks it.
- **The engine:** shared by both apps; speaks the contract of server 0.8.0 and reads servers from 0.5.0. The server has
  released 0.9.0 ([contract drift](runbooks/contract-drift.md)).
- **CI and releases:** the lanes run side by side behind one required check; releases run from tags
  ([ci.md](development/ci.md), [releasing.md](development/releasing.md)). Their times on hosted runners are estimates until the
  first week of runs (TD-021).
- **Known debts:** [tech-debt.md](architecture/tech-debt.md). The ones that block a release: TD-005 (iOS signing) and TD-019 (the
  Mac's feed).

## What holds the code in shape

- One repository, one package, one project; the apps release separately — [ADR 0001](decisions/0001-one-repository-one-package-one-project.md), [0007](decisions/0007-releases-per-platform.md)
- iOS 18 and macOS 26 floors; OS-version checks only in `PurlayDesign` — [ADR 0002](decisions/0002-platform-floors-and-one-availability-seam.md)
- The layer table; features never import features — [ADR 0003](decisions/0003-layers-and-feature-modules.md), [modules-and-layers.md](architecture/modules-and-layers.md)
- The contract is generated from the server's pinned bundle, never written by hand — [ADR 0004](decisions/0004-the-contract-is-the-servers.md)
- No third-party code beyond Sparkle; no unchecked concurrency; no code that can trap — [ADR 0010](decisions/0010-no-third-party-code-beyond-sparkle.md), [conventions](architecture/conventions.md)
- Each of these is checked by `scripts/enforcement`, and `--demo` proves each check refuses its violation.

## Next

1. iOS slice 1: the Problem screen's design, the two-step and no-workspace screens, the notice banners (FR-009).
2. The stable update feed and the bridge release, then the Mac's first release from here (TD-019).
3. iOS slice 2: the shell and the Account sheet (FR-020, FR-023), with account deletion and the wipe on sign-out (P-1, P-6).

## Quick start

```sh
make setup     # the pinned contract bundle, gitleaks, the git hooks
make verify    # what a pull request needs
```

Then open `Apps/Purlay.xcodeproj` (Xcode 27.2 or later). Everything else: [getting-started.md](development/getting-started.md).

## The map

| Document | Read it when |
|---|---|
| [product/vision.md](product/vision.md) | asking what the apps are for, and what they must not become |
| [product/requirements.md](product/requirements.md) | changing what an app does: the FRs, NFRs, assumptions and open questions |
| [product/mac-behaviour.md](product/mac-behaviour.md) | a Mac behaviour that is not obvious from the screen |
| [design/entry-shell-account.md](design/entry-shell-account.md) | building the iOS entry screens, the shell or the Account sheet; the owner's proposals P-1 to P-11 |
| [architecture/overview.md](architecture/overview.md) | how the apps, the engine and the server fit together |
| [architecture/modules-and-layers.md](architecture/modules-and-layers.md) | adding or moving a module; what `scripts/enforcement` checks |
| [architecture/conventions.md](architecture/conventions.md) | before any code change |
| [architecture/tech-debt.md](architecture/tech-debt.md) | before a release; when a shortcut tempts you |
| [decisions/](decisions/README.md) | asking why something is the way it is; before changing the architecture |
| [development/getting-started.md](development/getting-started.md) | setting up, running the apps, local servers, strings |
| [development/testing.md](development/testing.md) | where a test goes, which lane runs it, what no test reaches |
| [development/ci.md](development/ci.md) | changing a workflow or a lane; a slow check |
| [development/contract.md](development/contract.md) | moving the contract pin, or touching the generator |
| [development/releasing.md](development/releasing.md) | versions, changelogs, tags, the `release` environment |
| [development/hardening.md](development/hardening.md) | what can go wrong, what prevents it, what to do |
| [runbooks/](runbooks/README.md) | doing one of those things, step by step |
| [../.github/settings.md](../.github/settings.md) | the repository settings that are not files |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | branches, commits, pull requests |

## The working rule

Every change: read the documents it touches, make the change, update those documents in the same pull request (every path,
command and number in them must stay true), record a decision if one was made, run `make verify`.
