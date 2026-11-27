"""Where scripts/enforcement keeps what it can read again (the manifest's reading, each Swift file's parse), and whether that
folder can be trusted: what is read back from it is believed, so a folder another user could write, or swap for their own, is
not used.

  python3 scripts/lib/cache.py [SUBFOLDER]    print the folder, made if new; exit 1 (with a note) when it cannot be trusted
"""
import os
import pathlib
import stat
import sys

OTHERS_WRITE = stat.S_IWGRP | stat.S_IWOTH


def root():
    """The user's own cache folder for the rules: XDG_CACHE_HOME, else ~/.cache."""
    base = os.environ.get("XDG_CACHE_HOME") or pathlib.Path.home() / ".cache"
    return pathlib.Path(os.path.abspath(base)) / "purlay-enforcement"  # absolute, without following a link


def problem(folder):
    """Why the folder cannot be trusted, or None. From the cache root down each folder is the user's own, no link, and written
    by no one else: one that others may only read (0755, as an earlier version made it) is made the user's alone. Above it,
    no folder may be written by others without the sticky bit, or they could rename the cache and put their own in its place
    after this check."""
    top = root()
    if folder != top and top not in folder.parents:
        return f"{folder} is not under {top}"
    try:
        top.parent.mkdir(parents=True, exist_ok=True)
        for above in (top.parent, *top.parent.parents):
            status = above.stat()
            if status.st_mode & OTHERS_WRITE and not status.st_mode & stat.S_ISVTX:
                return f"{above}, above the cache, can be written by others"
        # Each folder from the root down is made by the user, for the user alone (mkdir's parents would take the umask).
        levels = [folder, *folder.parents][:len(folder.relative_to(top).parts) + 1]
        for level in reversed(levels):
            level.mkdir(mode=0o700, exist_ok=True)
            status = level.lstat()
            if stat.S_ISLNK(status.st_mode) or status.st_uid != os.getuid():
                return f"{level} is a link or another user's"
            if status.st_mode & OTHERS_WRITE:
                return f"{level} can be written by others"
            if status.st_mode & 0o077:
                level.chmod(0o700)
    except OSError as error:
        return f"{folder}: {error}"
    return None


def private(folder):
    """Whether the folder can be trusted; when it cannot, says why once, on stderr."""
    reason = problem(folder)
    if reason:
        print(f"note: the rules' cache is not used ({reason}), so they run without it", file=sys.stderr)
    return reason is None


if __name__ == "__main__":
    wanted = root().joinpath(*sys.argv[1:])
    if not private(wanted):
        sys.exit(1)
    print(wanted)
