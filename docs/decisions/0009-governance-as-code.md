# 0009. The repository's rules are files, reviewed like code

Status: accepted, 2026-11-26

**Context.** Branch protection, labels, owners and update policy decide what can reach main. Set by hand in a settings page, they
drift, cannot be reviewed, and are lost with access.

**Decision.**
- `.github/rulesets/main.json`: main takes squash merges only, keeps a linear history, refuses force-pushes and deletion, needs
  every review conversation resolved, and requires the `verify` check, without requiring a branch to be up to date.
  `.github/rulesets/release-tags.json`: release tags cannot be moved or deleted. Nobody bypasses either.
- `.github/CODEOWNERS` names an owner per area; `.github/labels.yml` is every label, synced by a workflow, and pull requests are
  labelled by path (`.github/labeler.yml`).
- `.github/dependabot.yml` groups updates weekly; a patch update merges by itself once `verify` passes.
- The settings that have no file (secret scanning, Dependabot alerts, private vulnerability reporting, the Actions token, forks,
  the `release` environment) are a checklist in `.github/settings.md`.
- Local hooks (`.githooks`, installed by `make setup`) check format, secrets and the commit message before anything is pushed.

**Rejected.** *Settings by hand only:* invisible to review. *Requiring an approving review:* one maintainer cannot approve their
own pull request; owners are asked, not required, until a second person can review. *A merge queue:* not needed at this volume.

**Consequences.** A change to the rules is a pull request; applying a ruleset file is done through the API by the owner
(`.github/settings.md`). The files and the live settings can drift until someone reapplies them; the Scorecard reports some of it.
