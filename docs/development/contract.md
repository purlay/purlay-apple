# The contract pipeline

The server repository owns the contract ([ADR 0004](../decisions/0004-the-contract-is-the-servers.md)). This repository holds a
pin, `Contract/contract.lock` (server version, contract version, bundle format, the manifest's digest), and the generator that
turns the pinned bundle into Swift.

```sh
scripts/prepare-contract       # the bundle the lock names, from the server's release (make setup runs it); nothing when it is there
scripts/contract use DIR       # take a bundle from `bun run contract:bundle --out DIR` in a server checkout
scripts/contract fetch TAG     # or from a server release, after checking its digest file
scripts/contract verify        # Contract/bundle is exactly what the lock names
scripts/generate               # write Sources/PurlayContract/Generated, Sources/PurlayKit/Generated, Sources/PurlayTokens/Generated
scripts/generate --check       # fail unless what is on disk is what would be written (the generated lane)
scripts/contract-test          # the real client against a real server of the pinned version (needs a server checkout)
scripts/ci/contract-drift      # whether the server has released past the pin
```

`Contract/bundle/` is fetched and ignored. `scripts/prepare-contract` compares the lock before and after and fails on any
difference, so the pin never moves by accident.

## Moving the pin

1. `scripts/contract fetch vX.Y.Z` (the server's release tag) rewrites the lock and the bundle; or `use` a bundle built from a
   server checkout.
2. `scripts/generate`, then fix what the compiler and the tests show. A change to how code is generated is a change to
   `Tools/PurlayGen`, with its tests.
3. With a server checkout at that version: `PURLAY_SERVER_CHECKOUT=~/Projects/purlay scripts/contract-test` (TD-017).
4. Update the server version the documents name (`docs/product/mac-behaviour.md` "Server features", the NFR-VER row), and the
   changelogs if a person would notice.
5. One pull request, `feat(contract): speak server X.Y.Z` (or `fix`), closing the `drift` issue if one is open.

The oldest server a build reads is `CompatibleContracts.minimumServer` in `Sources/PurlayKit/Handshake/Handshake.swift` (0.5.0).
