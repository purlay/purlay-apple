# Repository settings

The settings of `purlay/purlay-apple` that live outside its files, as a checklist the owner applies and re-checks. What can be a
file is one: the rulesets (`rulesets/`), the owners (`CODEOWNERS`), the labels (`labels.yml`), Dependabot (`dependabot.yml`).
Decision: [ADR 0009](../docs/decisions/0009-governance-as-code.md). Nothing here is applied by a workflow.

## Rulesets

- [ ] `main`: Settings → Rules → Rulesets → *New branch ruleset* → *Import a ruleset* → `rulesets/main.json`. Squash only,
      linear history, no force-push, no deletion, conversations resolved, the `verify` check required (from GitHub Actions),
      **no "require branches to be up to date"** (it would restart every open pull request's check after each merge and break
      the 3-minute target), no bypass.
- [ ] `release tags`: *New tag ruleset* → import `rulesets/release-tags.json`. `macos/v*` and `ios/v*` cannot be moved or deleted.

## General

- [ ] Pull requests: allow **squash merging** only (its default message: the pull request's title and description); untick merge
      commits and rebase merging.
- [ ] **Allow auto-merge.**
- [ ] **Automatically delete head branches.**
- [ ] Features: Issues on; Wikis and Projects off.

## Code security

- [ ] **Private vulnerability reporting** on (`SECURITY.md` and the issue form point to it).
- [ ] **Dependency graph** on; **Dependabot alerts** on; **Dependabot security updates** on.
- [ ] **Secret scanning** on, with **push protection** on.
- [ ] Code scanning: nothing to set up; `scorecard.yml` uploads its results.

## Actions

- [ ] Settings → Actions → General → *Workflow permissions*: **Read repository contents and packages permissions** (the default
      token is read-only; each job asks for more in its `permissions:`). Untick *Allow GitHub Actions to create and approve pull
      requests*.
- [ ] *Fork pull request workflows from outside collaborators*: **Require approval for all external contributors**.
- [ ] *Actions permissions*: allow actions created by GitHub and those pinned in the workflows (`ossf/scorecard-action`,
      `dependabot/fetch-metadata`); or allow all actions, since every one is pinned by commit.

## Environments

- [ ] **`release`**: Settings → Environments → New environment → `release`.
  - Required reviewers: the owner (`@doancan`). Prevent self-review off (one maintainer).
  - Deployment branches and tags: *Selected*: the branch `main` and the tag pattern `macos/v*`.
  - Secrets: `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`,
    `APP_STORE_CONNECT_ISSUER_ID`, `SPARKLE_PRIVATE_KEY` ([releasing.md](../docs/development/releasing.md)). No repository-level
    secret holds signing material.
- [ ] **`github-pages`** (made by Pages, [mac-update-feed.md](../docs/runbooks/mac-update-feed.md)): deployment tags `macos/v*`.

## Pages (the Mac's update feed)

- [ ] The domain `updates.purlay.app` verified for the organisation; Source: GitHub Actions; custom domain `updates.purlay.app`;
      Enforce HTTPS ([mac-update-feed.md](../docs/runbooks/mac-update-feed.md#1-the-address-the-owner)).

## The organisation

- [ ] A second owner, and two-factor required for members ([lost-maintainer-access.md](../docs/runbooks/lost-maintainer-access.md)).

## Applying a ruleset from the command line

```sh
gh api -X POST repos/purlay/purlay-apple/rulesets --input .github/rulesets/main.json
gh api -X POST repos/purlay/purlay-apple/rulesets --input .github/rulesets/release-tags.json
gh api repos/purlay/purlay-apple/rulesets --jq '.[] | {id, name, enforcement}'          # check
gh api -X PUT repos/purlay/purlay-apple/rulesets/<id> --input .github/rulesets/main.json  # after a change to the file
```
