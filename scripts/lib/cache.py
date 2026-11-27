"""Where scripts/enforcement keeps what it can read again (the manifest's reading, each Swift file's parse), and whether that
folder can be trusted: what is read back from it is believed, so a folder another user could write is not used.

  python3 scripts/lib/cache.py [SUBFOLDER]    print the folder, made if new; exit 1 (with a note) when it is not the user's alone
"""
import os
import pathlib
import stat
import sys


def root():
    """The user's own cache folder for the rules: XDG_CACHE_HOME, else ~/.cache."""
    base = os.environ.get("XDG_CACHE_HOME") or pathlib.Path.home() / ".cache"
    return pathlib.Path(os.path.abspath(base)) / "purlay-enforcement"  # absolute, without following a link


def private(folder):
    """Whether the folder, and each folder between it and root(), is the user's alone: no symbolic link, the user's own, and
    no permission for anyone else. A new folder is made so."""
    top = root()
    if folder != top and top not in folder.parents:
        return False
    try:
        top.parent.mkdir(parents=True, exist_ok=True)
        # Each folder from the root down is made by the user, for the user alone (mkdir's parents would take the umask).
        for level in [*reversed([folder, *folder.parents][:len(folder.relative_to(top).parts) + 1])]:
            level.mkdir(mode=0o700, exist_ok=True)
        for current in (folder, *folder.parents):
            status = current.lstat()
            if stat.S_ISLNK(status.st_mode) or status.st_uid != os.getuid() or status.st_mode & 0o077:
                return False
            if current == top:
                return True
    except OSError:
        return False
    return False


if __name__ == "__main__":
    wanted = root().joinpath(*sys.argv[1:])
    if not private(wanted):
        print(f"note: {wanted} is not the user's alone (a link, another owner, or open to others); not used", file=sys.stderr)
        sys.exit(1)
    print(wanted)
