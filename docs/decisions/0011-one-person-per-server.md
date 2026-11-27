# 0011. One person per server in the app

Status: accepted, 2026-11-27

**Context.** The Mac opens one workspace session per window tab, each with its own model, preferences, files and caches, but
the Keychain keeps one credential per server (`KeychainSessionStore`, keyed by service and server). A second person signing in
through another workspace of the same server overwrote the first person's credential: at the next launch every workspace
restored the second person, and the first person's workspace removed her drafts, outbox and Quick Look copies as another
person's (M-1 of §10), while her server session stayed alive with nothing on the device holding it. Since signing out and
erasing now remove what the app keeps of a person, two people on one server became a way to lose one person's data.

**Decision.** One person is signed in per server in the app.
- A workspace that signs in while another workspace of the same server is signed in joins that session: it adopts the
  session in use, with no browser, and reads its workspace with it (`AppModel.signIn()`, `SharedServer.sessionInUse`). The
  server lists the person's workspaces from `/api/me` with that session, so no browser round trip is needed. Only a
  confirmed session is joined or compared against: one whose person has been read and that is kept, never one a browser
  has just brought back.
- On the Mac, a browser sign-in's session is kept apart until `/api/me` says whose it is: in memory, and in the Keychain
  under a pending entry of its own for each workspace session (`AppEnvironment.pendingSessions`, one Keychain service per
  workspace), so a quit does not lose it and one workspace's never replaces another's; at launch it is read again (kept or
  refused), or ended and forgotten when a session is already kept for the server or it was made for another address. It becomes the
  server's credential only then, and only when it is the person the server's other sessions hold; when that person already
  holds a confirmed session here, that session is used and the browser's is ended, so the server has one session. A first read that fails keeps it in
  memory, and Try Again reads again with it; a model that lets it go unkept ends it on the server (`/auth/logout`), so none
  is left alive with nothing holding it.
- A browser sign-in that brings back somebody else (another workspace signed in while the browser was open) is refused: that
  session is ended at once (`/auth/logout`), nothing is written to the Keychain and nothing of anybody's is removed, and the
  person is told `SignInError.anotherPersonSignedIn(server:)`: "Sign out of <server> first to use another account."
- What belongs to the server's one credential and person is kept where every workspace sees it (`AppEnvironment
  .sharedPreferences`): an unconfirmed erasure, so whichever workspace hears the session end applies it.
- Signing in again (`reauthenticate()`) moves every workspace that holds the old session to the new one before the old one
  is ended; it is refused while another workspace of the server is signing out or erasing.
- Signing out of, or erasing the account from, one workspace ends every workspace of the server, and removes what each kept
  only where it is the same person's.

**Rejected.** *A credential per person per server (several accounts at once):* real multi-account support, which the product
does not ask for (P-9 lists it as later); it changes the Keychain's layout, the sign-in screen and every place that assumes
one session per server. *Letting the second person in and keeping both:* the credential cannot hold both, which is what lost
data. *Refusing a second workspace's sign-in instead of joining:* the person is already signed in; asking them to sign in
again to open another of their own workspaces is friction with no gain.

**Consequences.** The Mac cannot show two people of one server side by side; switching people means signing out of the
server first, which the refusal says. iOS has one session and nobody to refuse, so it is unchanged: its browser sign-in is
kept in the Keychain at once, as before. Several accounts at once remains P-9, and would revisit this record.
