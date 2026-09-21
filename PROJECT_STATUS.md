# Project Status

Last updated: 2026-09-20

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
3. Robust Overlays - allow polymorphic overlaying and section overlays
2. Advanced templating coverage beyond the current MVP
4. Conditional section/step execution


# Open Questions
Found while writing the coverage tests. None were changed; they need a decision.
- `AsanaApiClient.InvokeApi` - when Asana returns a non-JSON error body, the inner `catch` shadows `$_`, so `$_.ErrorDetails.Message` is `$null` and the raw response text is dropped; the error falls back to the generic exception message. Looks unintended.
- `AsanaTaskPluginBase.ValidateRichText([string]$html)` - `$null` is coerced to `''` before the method runs, so its `$null -eq $html` early return can never fire (a `$null` fails with "must be wrapped in <body>"). Callers currently guard against `$null` themselves. (AGENTS.md coercion quirk; not auto-corrected.)
- `SourceFactory.Create` / `ImportConfig.Execute` - `$resolvedConfig = if (...) { $loadedConfig.root } else { ... }` unrolls a one-element `root:` list into that single element, so a one-item list is not wrapped in the synthetic "Imported section"; the item's own name/slug are used instead.
- `SourceFactory` is not referenced by any production code any more (only by comments in `StepTree`); `ImportConfig` duplicates its wrapping logic.
- `taskPluginRegistry.GetPlugin()` builds instances with `[Activator]::CreateInstance($pluginName)`, i.e. it treats the plugin *name* as a class name resolved from module scope. It only works when a plugin's name equals its class name and the class lives in the module; it could use the `Type` already stored in `PluginRegistry` instead.

# Testing Notes
- Test files run in a different order than alphabetical paths (files in a folder before its subfolders), and static state is shared across files. Tests that need a plugin should register it in `BeforeAll` (`RegisterPlugin` is idempotent) rather than assume it exists; tests that replace a registry singleton must restore it in `AfterAll`.
- Do not pipe a `[StepTree]` into `Should` (Pester reads `.Count`, which resolves to the `Count()` method); assert with `($tree -is [StepTree]) | Should -BeTrue` instead.
- String-to-type conversion of module class names (`[type]'CurrentTime'`) fails in test scope; put real type literals (`[CurrentTime]`) in `-ForEach` data.
- `[LogLevel]99` is rejected by PowerShell; use `[System.Enum]::ToObject([LogLevel], 99)` to build an undefined level.
