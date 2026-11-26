# The server has released past the pinned contract

`contract-drift.yml` opens one issue, labelled `contract-drift`, when the server's latest release is newer than the server version
in `Contract/contract.lock`. Run the same check by hand: `scripts/ci/contract-drift`.

A drift is not an error: the pin moves deliberately. Decide:

1. **Does the new contract matter now?** Read the server's changelog between the pinned and the latest version. Move now if the
   apps need something it adds, if it changes something they use, or if the server announces it will stop serving the pinned
   contract (an app the server no longer serves shows "needs a newer Purlay").
2. **To move:** follow [contract.md](../development/contract.md#moving-the-pin) in one pull request, and close the issue from it.
3. **Not now:** comment on the issue with the reason and the version you will move at, and leave it open; the workflow opens no
   second issue while one is open.
