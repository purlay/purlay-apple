# Decision records

One file per decision, numbered, each stating what is decided today, why, and what was rejected. When a decision changes, its
record is rewritten to say the new decision, in the same pull request as the change; git keeps what it said before. A new
decision gets the next number.

| # | Decision |
|---|---|
| [0001](0001-one-repository-one-package-one-project.md) | One repository, one package and one project for every Apple platform |
| [0002](0002-platform-floors-and-one-availability-seam.md) | iOS 18 and macOS 26 floors, the OS 27 SDKs, and one availability seam in `PurlayDesign` |
| [0003](0003-layers-and-feature-modules.md) | A layer table for the modules, and one feature module per server module |
| [0004](0004-the-contract-is-the-servers.md) | The contract is the server's; the apps generate from its pinned bundle |
| [0005](0005-make-verify-and-a-secret-scan.md) | `make verify` over the lanes of `scripts/verify`, and a secret scan of the history |
| [0006](0006-app-tests-use-their-own-fakes.md) | The iOS app's tests use fakes of their own, not `PurlayTestSupport` |
| [0007](0007-releases-per-platform.md) | Each platform releases on its own, from a tag, trusting main's check |
| [0008](0008-ci-lanes-and-one-required-check.md) | CI: lanes side by side, each only when a change reaches it, and one required check |
| [0009](0009-governance-as-code.md) | The repository's rules are files, reviewed like code |
| [0010](0010-no-third-party-code-beyond-sparkle.md) | No third-party code beyond Sparkle |
| [0011](0011-one-person-per-server.md) | One person per server in the app: a second workspace joins the session in use, and somebody else is refused |

Format: a title that states the decision; `Status: accepted, <date>`; **Context**, **Decision**, **Rejected** (with why) and
**Consequences**.
