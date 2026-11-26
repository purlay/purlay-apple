# 0003. A layer table for the modules, and one feature module per server module

Status: accepted, 2026-11-26

**Context.** Purlay is a core plus modules (chat, issues; tasks, time and others to come). The apps must grow the same way
without later modules reshaping earlier ones, and the engine must stay usable on every Apple platform, the watch included.

**Decision.**
- The modules form layers, held as a table in `scripts/enforcement` and checked against the manifest (`swift package
  dump-package`): `PurlayContract` and `PurlayTokens` depend on nothing; `PurlayKit` on Contract; `PurlayWords` on Kit and
  Contract; `PurlayTestSupport` on Kit and Contract; `PurlayDesign` on Tokens; `PurlayModuleAPI` on nothing; `PurlayMacUI` on Kit,
  Contract, Tokens, Design and Words. A module the table does not name is refused. The engine, its words, the contract and the
  tokens import no UI framework.
- What both apps say about what the engine reports (its phases, server problems, sign-in failures, notices, upload failures) has
  one home, `PurlayWords`, with its own catalogue, translated once. Each app's catalogue holds only that app's own sentences, and
  `scripts/enforcement` refuses a sentence in two catalogues, and a sentence no code that reads its catalogue says (each key
  must be a string literal in that app's code, or in `PurlayWords`' for its own).
- Each server module becomes a `Feature<Module>` target that conforms to `FeatureModule`, may depend on Kit, Contract, Tokens,
  Design, ModuleAPI and Words, and never on, or imports, another feature. The composition root lists the features in a
  `ModuleRegistry`, which shows a feature only where the workspace's membership allows its module and ignores ids it does not
  know.
- Account, settings and the shell belong to the core, not to a feature.

**Rejected.** *One app target with folders:* nothing stops cross-feature imports. *Dynamic plug-ins:* the server has none either
(a permanent non-goal). *A package per module in its own folder:* their settings drift ([0001](0001-one-repository-one-package-one-project.md)).
*The engine's sentences in `PurlayKit`:* the engine would carry a catalogue and words it has no use for, on the watch too. *A copy in
each app:* the copies drifted ("Bağlanılıyor…" on iOS, "Bağlanıyor…" on the Mac) and needed two checkers.

**Consequences.** Adding a module is one target, one line in the table, one line in the registry. Behaviour that crosses modules
(deep links, inbox notices, search results) is declared in `PurlayModuleAPI` first. `--demo` proves each layer rule refuses its
violation.
