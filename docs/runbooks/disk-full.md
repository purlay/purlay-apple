# The disk is full

## On a developer's Mac

1. See what the builds hold: `scripts/dev/clean --dry`.
2. Free it: `make clean` removes the compilation cache (shared by every checkout on this Mac), this checkout's DerivedData,
   SwiftPM's build folders and the rules' scratch. The next build is cold.
3. Simulators: `xcrun simctl delete unavailable`; old runtimes in Xcode → Settings → Components.
4. Other checkouts' DerivedData: Xcode → Settings → Locations → DerivedData → the arrow, and remove the `Purlay-*` folders you
   no longer use.

## On a runner

A hosted runner starts clean, so a full disk is what one job wrote: a cache that grew, or a build that went wrong.

1. Read the failing step's log for the largest folders, and the cache restore step for the cache's size.
2. List the caches: `gh cache list --repo purlay/purlay-apple --sort size_in_bytes --limit 20`. Delete an oversized one:
   `gh cache delete <key>` (or `--all`). Main saves a fresh one on its next run; each week starts a new generation anyway.
3. If a lane's cache keeps growing past a few gigabytes, raise it in an issue with the sizes; do not turn the cache off (it is
   what keeps a pull request under 3 minutes).
