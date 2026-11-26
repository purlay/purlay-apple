# CI is down, or out of macOS runners

1. **Which is it?** githubstatus.com (Actions); `gh run list --status queued --limit 20` (runs waiting for a runner);
   organisation Settings → Billing → Actions (minutes, if the repository is private).
2. **Queued behind other runs.** The free plan runs 5 macOS jobs at once for the whole organisation. Cancel runs nobody needs:
   superseded pushes are cancelled by CI's concurrency, but other repositories' and old manual runs are not
   (`gh run cancel <run-id>`). Avoid pushing to several pull requests at once.
3. **Actions is down.** Wait; nothing merges without `verify`, by design. Meanwhile check locally: `make verify-all` (every lane)
   and keep the output for the pull request.
4. **It must merge before CI is back** (a fix for a broken release): the owner adds the repository admin role to the `main`
   ruleset's bypass list, merges with the local `make verify-all` output in the description, and removes the bypass at once.
   The next main run must be green; if it is not, revert.
5. **Out of minutes** (only a private repository consumes them; macOS minutes count ten times): raise the spending limit, or wait
   for the month; do not move lanes off macOS to save minutes.
