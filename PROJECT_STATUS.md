# Project Status

Last updated: 2026-09-22

Prometheus Forge is now a YAML-driven workflow engine built around a `StepTree` execution model, a run-scoped `Steps` registry, and plugin-based source/task execution. The project currently supports loading and processing configuration trees from YAML, applying base and overlay variables, resolving templated values, and running steps with tag-based include/exclude filtering and plugin-requested overrides/inserts.

Current capabilities include:
- workflow definition and execution through `Invoke-Forge` with file validation, overlay handling, and import resolution
- `Step`/`StepTree` hierarchy with slug-based identity, run-state tracking, and recursive depth-first execution
- variable storage and map-based ingestion via `Variables.SetMany()`, including `tagsInclude`/`tagsExclude` handling
- template expansion for nested variables and list/object-shaped inputs, with unresolved placeholders falling back to empty strings
- plugin infrastructure for source definitions, task execution, and a minimal plugin-facing API surface for configuration changes
- Asana task/project/section operations and a lightweight terminal logging layer
- test coverage for key public and private behaviors, plus reset logic to prevent cross-run singleton leakage

The project is operating as a working MVP for workflow automation and Asana integration, but broader overlay semantics, advanced templating behaviors, and some plugin/API refinements remain future work.


# Recent Changes
- Confirmed polymorphic overlay support is already in place (Step->Step, Section->Section,
  Step->Section direct; Section->Step via a documented workaround) - no code change, just
  verification. See `README.md` ("Insert vs. Override") for the usage-level explanation.
- Wired CLI overlays (`Invoke-Forge -Overlay`) into the `PendingOverrides`/`ForgeConfigurationApi` override machinery, giving overlay YAML files a YAML-facing syntax for step/section overrides (previously they could only set/overwrite `variables`). An overlay's top-level `root` - the same key/shape the main YAML uses (a single step/section config, or a list of them) - is repurposed for overlays: it is never processed as its own tree, and instead each entry is queued via `[ForgeConfigurationApi]::new().RequestOverride($entry.slug, $entry)`, applied the same way a plugin-requested override would be the next time a `StepTree` node with that `slug` is processed. `Invoke-Forge` collects overlay `root` entries during the existing overlay loop (order matters: a later overlay's override for the same slug wins, same as `variables`; `@(...)` normalizes the single-entry vs. list shapes without unrolling a lone hashtable's own keys), then queues them all right after the root `[StepTree]` is constructed but before `.Process()` is called, so every queued override is pending before the first node is visited. An overlay containing only `root` (no `variables`) is valid on its own - no schema changes needed, since `root` was already an accepted top-level section. See `Public/Invoke-Forge.ps1`.
  - Covered in `Tests/Public/Invoke-Forge.Tests.ps1` (step override, single-config-not-a-list override, section override/subtree replacement, and the existing end-of-run "unmatched override" warning now exercised end-to-end through a real overlay instead of only at the `StepTree`/`PendingOverrides` unit level).
  - Sample overlay updated: `Samples/Sample.Onboard.Overlay.yaml` now documents and shows a commented-out `root:` override example against a real slug (`purchase-zoom-license`) from `Sample.Onboard.yaml`.
- Reworked the override ForgeAPI as the first step of "Robust Overlays" (see Next Steps below). `ForgeConfigurationApi.RequestOverride(key, config)` queues the raw config on a new run-scoped singleton, `[PendingOverrides]` (`Classes/13-PendingOverrides.ps1`, keyed by slug, wired into `Reset-ForgeState.ps1`). `StepTree.Process()` now checks `PendingOverrides` for its **own** slug via `ApplyPendingOverride()` at the start of every call - not just for the requesting step's queue - so an override applies wherever/whenever in the tree a matching slug is next visited. A config with `type -eq 'step'` is a leaf-only swap (only the registered `Step` changes); any other config is a whole-subtree replacement (children/tags too - new capability, previously rejected). Requesting a second override for a slug that hasn't been drained yet overwrites the first and logs a `[Log]::Warning`.
  - Building the replacement `[Step]`/`[StepTree]` is deliberately deferred to `ApplyPendingOverride()`, not done eagerly in `RequestOverride()`: a structural override commonly reuses slugs still held by the subtree it's replacing (e.g. "keep this child, just change its parameters"). `ApplyPendingOverride()` calls the new `StepTree.Remove()` (recursively unregisters a subtree's `Steps` entries) on the node being replaced *first*, so the override's own construction always has clean slugs to register against - no orphaned registry entries either way. See the `'applies a [StepTree]-shaped override that reuses one of the old subtree's own child slugs'` test in `StepTree.tests.ps1` for the regression case this fixes.
  - `Invoke-Forge` now iterates `[PendingOverrides]::GetInstance().GetPendingSlugs()` right after the tree finishes processing, logging a warning for every override that was requested but never had a matching slug to apply to (typo, or a target skipped by conditionals) - mitigates the "silent no-op" behavior change below. This logging lives in `Invoke-Forge`, not on `[PendingOverrides]` itself - raw output doesn't belong in that class, so it only exposes `GetPendingSlugs()` and the caller decides what to do with them.
  - Behavior change (partially mitigated by the `Invoke-Forge` warning above): an override targeting a slug that's never visited by the tree is a no-op rather than an immediate throw, since validation moved from "one central drain point checks the registry" to "each node checks for its own slug." It's now surfaced as an end-of-run warning instead of a hard failure at request time - worth revisiting if fail-fast is wanted back.
  - Removed `ForgeConfigurationApi.GetPendingOverrides()`/`ClearPendingOverrides()` - StepTree now talks to `[PendingOverrides]` directly, so the per-instance passthroughs no longer served a purpose.
  - No `Invoke-Forge`-level (public API) test for this warning's wiring: exercising it end-to-end needs a plugin that calls `RequestOverride()` from within a real run, but `taskPluginRegistry.GetPlugin()` resolves plugins with `[Activator]::CreateInstance($pluginName)` from module scope (see Open Questions), which can't construct a plugin class defined only in a test file. Covered instead at the `StepTree`/`PendingOverrides` unit level.
- Mock task plugins (`MockValidPlugin` etc.) moved out of `Classes/` (they were compiled into the shipped module) and into `Tests/Private/Classes/Plugins/taskPluginRegistry.tests.ps1`; tests register them explicitly with `RegisterPlugin()`. Because `GetPlugin()` resolves by class name from module scope, the retrieval tests use the real `CurrentTime` plugin instead of a mock.
- Full test-suite coverage pass: 306 -> 647 tests, command coverage 74.2% -> 99.82% (1117/1119). New test files for `Step`, `Steps`, `tags`, `processorInterface`, `TaskPluginInterface`, the `Forge*Api` classes, `SourceFactory`, `ImportConfig`, `CurrentTime`, `TextOutput`, `AsanaApiClient`, `AsanaTaskPluginBase` and `AsanaCreateTaskDependency`; gaps filled in the existing StepTree, TemplateEngine, Log/Logs, yamlSource, registry, source/task interface, Asana, PasswordGenerator and Invoke-Forge tests. The registry test files now save/restore their singleton so they no longer leak an empty registry into later files.
  - The 2 uncovered commands are not coverable: `TemplateEngine.ResolvePath`'s `$pathSegments.Count -eq 0` branch is dead code (`-split` never returns 0 elements), and `AsanaTaskPluginBase`'s static `UniversalRichTextTags` initializer is not tracked by Pester.
  - Measure coverage with `Build-Module`, then Pester with `CodeCoverage.Path = build/PrometheusForge/PrometheusForge.psm1` (coverage against the built single-file module; ModuleBuilder `#Region` markers map lines back to source files).
  - Suspected source issues found while testing (tests deliberately do not pin them; see "Open Questions" below).
- Split logging into `[Log]` (static factory/entry point, `Classes/Factories/Log.ps1`), `[Logs]` (run-scoped singleton holding all entries and doing terminal output), and `[LogEntry]` (single searchable entry). `[Log]::Write($message)` defaults to Info. Tests split to match under `Tests/Private/Classes`. PowerShell classes don't support default method parameter values, so `LogEntry` uses explicit constructor overloads.
- MVP is ready to go!
- Added GitHub Actions release automation to build, test, package, and tag a distributable PowerShell module release.


# Next Steps
These are items from TODO.md that we should work on next.
Read TODO.md for further information on a particular item

1. ~~Full test-suite coverage~~ (done - see Recent Changes)
3. ~~Robust Overlays~~ (largely done - polymorphic overlaying and section overlays work; see
   `README.md` for usage and TODO.md's "Step addon overlays" for the remaining insertion-semantics
   and `type: step`-guard decisions)
2. Advanced templating coverage beyond the current MVP
4. Conditional section/step execution


# Open Questions
Found while writing the coverage tests; still need a decision unless marked RESOLVED.
- `AsanaApiClient.InvokeApi` - when Asana returns a non-JSON error body, the inner `catch` shadows `$_`, so `$_.ErrorDetails.Message` is `$null` and the raw response text is dropped; the error falls back to the generic exception message. Looks unintended.
- `AsanaTaskPluginBase.ValidateRichText([string]$html)` - `$null` is coerced to `''` before the method runs, so its `$null -eq $html` early return can never fire (a `$null` fails with "must be wrapped in <body>"). Callers currently guard against `$null` themselves. (AGENTS.md coercion quirk; not auto-corrected.)
- `SourceFactory.Create` / `ImportConfig.Execute` - `$resolvedConfig = if (...) { $loadedConfig.root } else { ... }` unrolls a one-element `root:` list into that single element, so a one-item list is not wrapped in the synthetic "Imported section"; the item's own name/slug are used instead.
- `SourceFactory` is not referenced by any production code any more (only by comments in `StepTree`); `ImportConfig` duplicates its wrapping logic.
- `taskPluginRegistry.GetPlugin()` builds instances with `[Activator]::CreateInstance($pluginName)`, i.e. it treats the plugin *name* as a class name resolved from module scope. It only works when a plugin's name equals its class name and the class lives in the module; it could use the `Type` already stored in `PluginRegistry` instead.
- RESOLVED: an override whose target slug is never visited by the tree during a run silently never applies, surfaced only via the end-of-run warning (see Recent Changes) - not a fail-fast case. Decided intentional: e.g. a company/department overlay for setting up application "Foo" should just be skipped, with no error, if a given user's run doesn't touch "Foo" at all. The end-of-run warning is sufficient; no throw needed.
- `ApplyPendingOverride()`'s `type: step` (leaf-only) path throws against a section target (sections never register a `Step`), so Section->Step overrides need the workaround documented in `README.md` rather than working directly. Undecided whether to relax the guard so a bare `type: step` config can replace a section outright; low priority since the workaround has no real cost.

# Testing Notes
- Test files run in a different order than alphabetical paths (files in a folder before its subfolders), and static state is shared across files. Tests that need a plugin should register it in `BeforeAll` (`RegisterPlugin` is idempotent) rather than assume it exists; tests that replace a registry singleton must restore it in `AfterAll`.
- Do not pipe a `[StepTree]` into `Should` (Pester reads `.Count`, which resolves to the `Count()` method); assert with `($tree -is [StepTree]) | Should -BeTrue` instead.
- String-to-type conversion of module class names (`[type]'CurrentTime'`) fails in test scope; put real type literals (`[CurrentTime]`) in `-ForEach` data.
- `[LogLevel]99` is rejected by PowerShell; use `[System.Enum]::ToObject([LogLevel], 99)` to build an undefined level.
