# Project Status

Last updated: 2026-10-01

# What we last did


# Next Steps
These are items that we should work on next.
GitHub issues contain further information on a particular item (https://github.com/Hobadee/PrometheusForge/issues)

1. Advanced templating coverage beyond the current MVP
2. #20 - Conditional section/step execution
3. #2 - Lazy-Load everything by default
4. #21 - Better tag handling


# Open Questions
Found while writing the coverage tests; still need a decision unless marked RESOLVED.
- `AsanaApiClient.InvokeApi` - when Asana returns a non-JSON error body, the inner `catch` shadows `$_`, so `$_.ErrorDetails.Message` is `$null` and the raw response text is dropped; the error falls back to the generic exception message. Looks unintended.
- `AsanaTaskPluginBase.ValidateRichText([string]$html)` - `$null` is coerced to `''` before the method runs, so its `$null -eq $html` early return can never fire (a `$null` fails with "must be wrapped in <body>"). Callers currently guard against `$null` themselves. (AGENTS.md coercion quirk; not auto-corrected.)
- `SourceFactory.Create` / `ImportConfig.Execute` - `$resolvedConfig = if (...) { $loadedConfig.root } else { ... }` unrolls a one-element `root:` list into that single element, so a one-item list is not wrapped in the synthetic "Imported section"; the item's own name/slug are used instead.
- `SourceFactory` is not referenced by any production code any more (only by comments in `StepTree`); `ImportConfig` duplicates its wrapping logic.
- `taskPluginRegistry.GetPlugin()` builds instances with `[Activator]::CreateInstance($pluginName)`, i.e. it treats the plugin *name* as a class name resolved from module scope. It only works when a plugin's name equals its class name and the class lives in the module; it could use the `Type` already stored in `PluginRegistry` instead.
- RESOLVED: an overlay whose target slug is never visited by the tree during a run silently never applies, surfaced only via the end-of-run warning (see Recent Changes) - not a fail-fast case. Decided intentional: e.g. a company/department overlay for setting up application "Foo" should just be skipped, with no error, if a given user's run doesn't touch "Foo" at all. The end-of-run warning is sufficient; no throw needed.
- `ApplyPendingOverlay()`'s `type: step` (leaf-only) path throws against a section target (sections never register a `Step`), so Section->Step overlays need the workaround documented in `README.md` rather than working directly. Undecided whether to relax the guard so a bare `type: step` config can replace a section outright; low priority since the workaround has no real cost.

# Testing Notes
- Test files run in a different order than alphabetical paths (files in a folder before its subfolders), and static state is shared across files. Tests that need a plugin should register it in `BeforeAll` (`RegisterPlugin` is idempotent) rather than assume it exists; tests that replace a registry singleton must restore it in `AfterAll`.
- Do not pipe a `[StepTree]` into `Should` (Pester reads `.Count`, which resolves to the `Count()` method); assert with `($tree -is [StepTree]) | Should -BeTrue` instead.
- String-to-type conversion of module class names (`[type]'CurrentTime'`) fails in test scope; put real type literals (`[CurrentTime]`) in `-ForEach` data.
- `[LogLevel]99` is rejected by PowerShell; use `[System.Enum]::ToObject([LogLevel], 99)` to build an undefined level.
