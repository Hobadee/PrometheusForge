# Project Status

Last updated: 2026-09-05

## Recent Changes
- Added an `AI-Assisted Development` section to `README.md` that transparently acknowledges AI assistance while clarifying that architecture, workflow design, decisions, and review are human-led.
- Reworked `README.md` for user and collaborator onboarding: corrected the sample workflow path and PowerShell requirement, added feature and configuration summaries, documented installation, plugin development, testing, and roadmap guidance, and corrected introductory terminology.
- Implemented plugin-requested step replacement through `ForgeConfigurationApi.RequestOverride()`. `StepTree.Process()` consumes queued overrides before traversing children and replaces the matching `Steps` entry with a newly constructed step. The MVP accepts only same-named `type: step` replacement configs; section replacement and cross-type replacement remain unsupported. Added focused `StepTree` coverage for replacement execution and registry update behavior.
- Updated `Invoke-Forge.Tests.ps1` to replace deprecated `type: import` StepTree syntax with the `type: step` + `plugin: ImportConfig` pattern (including `defer_binding: true` when sibling steps rely on variables imported at runtime).
- Updated sample YAML files (`Sample.Onboard.yaml`, `Sample.Onboard.ImportedSection.yaml`) to use plugin-based `ImportConfig` steps instead of legacy import directives.
- Fixed cross-run singleton leakage: `Variables` and `Steps` are run-scoped singletons but were previously never cleared, so calling `Invoke-Forge`/`Test-Item`/`Test-Steps` more than once in the same session reused state from the prior run. Added `[Variables]::Reset()` (new) and used the existing `[Steps]::Reset()` to null out each singleton's `Instance`. Added `Private/Reset-ForgeState.ps1` as the single call site that resets both, and wired it into the top of `Invoke-Forge`, `Test-Item`, and `Test-Steps`. Plugin registries (`sourcePluginRegistry`, `taskPluginRegistry`) are intentionally NOT reset since their registrations happen once at module load and must persist across runs. Any new run-scoped singleton should add its own `Reset()` and be wired into `Reset-ForgeState`.
- Scaffolded an optional plugin-facing API surface: `Classes/Api/ForgeApi.ps1` (top-level facade), `Classes/Api/ForgeVariableApi.ps1` (wraps `Variables`), and `Classes/Api/ForgeConfigurationApi.ps1` (MVP stub that only records requested overrides; no override-merging consumer yet). `TaskPluginInterface` now exposes `$this.Api` (settable via `SetApi()`), and `taskPluginRegistry.GetPlugin()` injects a fresh `ForgeApi` into every plugin instance it creates. This is opt-in: existing plugins are unaffected since `Api` defaults to `$null` and nothing requires calling it.
- Completed the `Item*` to `Step*` architecture migration. `StepTree` now owns hierarchy and execution order, while the run-scoped `Steps` registry owns executable `Step` objects keyed by name. `Invoke-Forge` and the test entry points construct and process `StepTree` instances; the deprecated `Item` model and `ItemFactory` path are no longer used for normal workflow execution.
- Refactored `Steps` storage to match registry design: dictionary is now instance-scoped (`$this.Steps`) under the singleton instance instead of static class storage.
- Superseded prior `Steps` static-storage null-access workaround with an instance-scoped dictionary refactor.
- Renamed the project and PowerShell module to Prometheus Forge, including the public `Invoke-Forge` entry point, module manifest, build output, tests, and documentation.
- Added explicit public coverage in `Tests/Public/Invoke-Forge.Tests.ps1` for running YAML workflows via both absolute and relative `-FilePath` values.
- Added private registry coverage to assert duplicate registration of the same source plugin type is idempotent (no throw) in sourcePluginRegistry tests, while still preserving conflict checks for different types sharing the same plugin name.
- Refactored variable ingestion into `Variables.SetMany()` and removed the old item-factory-specific document helper logic.
- Rewired `Invoke-Forge` base and overlay variable application to call `Variables.SetMany()`.
- Simplified variable-shape handling to dictionary/map-only semantics aligned with source plugin contract (`IDictionary`), and added private unit coverage for `SetMany`.
- Imported YAML handling now loads top-level `variables` before resolving the imported root and normalizes imported content into `StepTree` nodes.
- Added an end-to-end public regression proving variables from an imported YAML file are available to later sibling steps in `Tests/Public/Invoke-Forge.Tests.ps1`.
- Wired import URIs through `TemplateEngine` before source plugin construction so YAML imports can use templated file paths.
- Added a focused regression test for templated YAML imports to confirm the expanded URI reaches the source plugin constructor.
- Expanded comment-based help in `sourcePluginInterface.ValidateConfig()` to explicitly document every enforced rule (non-null config, IDictionary shape, required/parseable `version >= 1.0`, and required `variables` and/or `root`).
- Tightened `sourcePluginInterface.ValidateConfig()` so imported configs must declare `version >= 1.0` and include at least one of `variables` or `root`.
- Updated private Pester coverage for source plugins to exercise version and section validation, and refreshed `yamlSource` fixture data to match the new schema.
- Split `sourcePluginInterface` contract coverage out of `yamlSource.tests.ps1` into a dedicated private test file: `Tests/Private/Classes/Plugins/sourcePluginInterface.tests.ps1`.
- Kept `Tests/Private/Classes/Plugins/Source/yamlSource.tests.ps1` focused on concrete `yamlSource` behavior and aligned assertions with current constructor/metadata behavior.
- Fixed template expansion for sample-style YAML parameter lists by teaching `TemplateEngine.ExpandTopLevelValues()` to traverse `IList` inputs and expand each top-level element in place.
- Added regression coverage for list-shaped parameters in both `TemplateEngine` unit tests and `Invoke-Forge` end-to-end tests.
- Implemented MVP templating runtime with a new `TemplateEngine` class and load-order file `Classes/03-TemplateEngine.ps1`.
- Added a new `sourcePlugin` family with `sourcePluginInterface` and a first `yamlSource` implementation for loading YAML configuration data.
- `Step` construction expands top-level string plugin parameters before `SetParameters()` validation.
- Added nested variable path support for templates (e.g., `{{ pin.object.generatedPassword }}`) resolved from `Variables` values.
- Implemented unresolved-template fallback to empty string for MVP.
- Added private unit coverage in `Tests/Private/Classes/TemplateEngine.tests.ps1`.
- Added Step/StepTree templating integration coverage.
- Extended `Tests/Public/Invoke-Forge.Tests.ps1` with an end-to-end templating test validating base+overlay variable resolution.
- Completed the StepTree execution model, including recursive depth-first processing, tree collection helpers, dynamic child insertion through `ForgeConfigurationApi.Insert()`, and the PowerShell class-binder return-type workaround.
- Implemented `Invoke-Forge` as a real entry point that accepts `-FilePath`, validates the file, supports common PowerShell common parameters, parses YAML, and runs all loaded items.
- Added public tests for `Invoke-Forge` covering successful execution and missing-file errors.
- Implemented Variable Overlay ingestion in `Invoke-Forge` via `-Overlay` (`[string[]]`) so multiple overlays can be passed and processed in provided order.
- Added variable import behavior that loads base config `variables` and then each overlay `variables` map into `Variables`, where later overlays overwrite earlier values.
- Expanded `Invoke-Forge` public tests to validate ordered overlay precedence and missing-overlay error handling.

## TODO

**Suggested Implementation Order**

1. Include/Skip based on tags - VERY IMPORTANT FOR MVP!
2. Full test-suite coverage
3. Advanced templating coverage beyond the current MVP
4. Step addon overlay insertion semantics and lazy-loading design


### API permission settings
Plugins should declare which `ForgeApi` categories they actually use (e.g. via a new `Apis`/`RequiredApis` key in `PluginInfo()`). Calls to an API category a plugin did not declare should fail (e.g. `ForgeApi` only populates/exposes declared sub-APIs, or each sub-API checks a declared-capabilities set before executing). Not implemented yet — `ForgeApi`/`ForgeVariableApi`/`ForgeConfigurationApi` currently grant full access to every injected plugin.


### Completed architecture: StepTree and Steps
The deprecated `Item` terminology and legacy item model have been removed from normal workflow execution. The current architecture separates the workflow into two independently managed concerns:

- `StepTree` stores hierarchy and execution order, with nodes referring to actions by name.
- `Steps` stores the executable action objects, keyed by their unique step names.

This separation allows execution order and tree content to evolve without changing executable action objects. YAML imports, plugin-requested child insertion, and plugin-requested step replacement are supported through this model. File-based overlay replacement semantics remain future work.


### Step replacement overlays
Replace steps/actions with imported steps/actions.

The idea behind this, is that if we have for example a "Install" step that
works completely different for Client A and Client B, we can easily replace the
entire action without having to rebuild everything. With this feature, overlays
can do more than simply inject new items and variables; they can replace
existing steps.

Replacement of sections will remain out-of-scope for now.  Section-level
modifications can be done via exluding the section and importing a new section.

Implementation will be done by splitting out the data into 2 sections;
- tree/step layer containing original ordering/hirearchy with a name reference
- Action objects, keyed by name

#### Import model
Imported data is split into two related structures:
Viewing things as a "database", we will have the following "tables":
- StepTree
- Steps

Both will have "Primary Keys" of the step name.  On load, we will load the
hierarchy into the `StepTree`. This consists of `Step.Name` references.
(This would also be the logical place to store/test conditions in future
versions, although this won't be present in MVP)  When we run, we will simply
traverse the `StepTree`, find the matching `Step` object in `Steps`, and run it.

The biggest thing here is that we should check and enforce name uniqueness, or
the user will foot-gun themselves.  (Possibly auto-build names based on
hirearchy so YAML authors don't need to worry about the entire project but
rather just their section?)

#### Overlay Targets
Ideally, we should be able to eventually complete all the following types of overlays:
- Step -> Step
- Section -> Section
- Step -> Section
- Section -> Step

The first 2 should be fairly easy.  Polymorphic overlays will be more difficult.


### Templating system
The project has a working MVP for variable substitution, but the remaining work is the broader runtime surface area that still needs deliberate design and coverage.

Remaining scope:
- `when` expression templating/evaluation
- recursive expansion in nested parameter objects and arrays
- templating for tags, plugin selection, retry settings, and file-loading scenarios
- advanced template functions such as conditionals and loops

Notes:
- Current coverage is focused on direct variable resolution from `Variables`, including nested keys such as `{{ a.b.c }}`.
- The next phase should be driven by concrete runtime use cases rather than broad feature expansion without a clear contract.


### Step addon overlays
The basic YAML-import flow is working, but the remaining design questions are about insertion semantics and long-term behavior rather than the parser itself.

Remaining work:
- define how imported steps/sections are inserted into the current `StepTree` location
- decide how future non-YAML sources should behave in the same pipeline
- make a deliberate decision about relative import resolution before adding it, rather than inferring a hidden rule from current execution location
- implement optional lazy-loading so filename variables set via function return can resolve

Current state:
- YAML imports are supported through `SourceFactory`, source plugins, and `StepTree` construction.
- Plugin-requested child insertion is supported through `ForgeConfigurationApi.Insert()` and currently adds children beneath the executing tree node.
- The remaining issue is defining a broader insertion contract for future overlay and non-YAML scenarios.


### Issues with AI builds
AI appears to have issues building/loading the module. The remaining work is to investigate the failure mode, reproduce it reliably, and correct the build or module-loading path so automation can run consistently.

This is still a known gap and should be treated as a reliability issue rather than a completed task.

I asked it to fix itself, and it did a few changes to copilot-instructions, but
there may still be issues.  Low priority unless we see this happening more.


### Issues with AI `git`
AI can't find `git` in it's environment.  Figure out what's going on and fix.


### Template Variables
Passing a `Variables` object directly to the template engine feels wrong
somehow.  Leaving it for now so we can get to MVP, but this likely needs to be
refactored and some better, more stable, means of communication between the two
needs to be devised.  Read up on my GOF patterns and see what can be put in
place here.

This is a VERY LOW priority.


### Place Finding
Stretch goal - steps should be able to find where they are in the hirearchy,
drilling down and getting a list of all parents.  This can help for nesting
into their parent objects when doing something, for example, a child grabbing
it's parents return ID and using that to nest itself when it creates itself in
some external system.

This is a VERY LOW priority.


### Log Plugin
Plugin similar to TextOutput, but called "Log" instead.

MVP will just have different log levels that just prefix the output with the
level name.  Colored output based on type would be nice as well.  Log levels
passed as either name or number.

Later versions should log to a location based on URI.  Try to support as many
URI locations as possible.  Basic is just a file, but if we could log to a real
logserver as well, that would be awesome.

#### Complicating issue:
How do we set a log location?  We can make the plugin a singleton, but how is
the config passed to it initally?  Passing via normal plugin config args has
1 of 2 issues; Either you need to pass an idential config every time (even if
just via templates) or you have the possibility that you add an earlier step
before the config is initialized.

Best bet is to probably store config in a variable, but this seems a little odd
as well.  Think about this some.


## Cleanup Items

### Test Coverage
Ask AI to check test coverage and ensure it's appropriate.  Ensure similar
test types exist for all classes where applicable.

### Consistent throws/errors
Ensure everything errors out or throws consistently.  For example, we shouldn't
null return on invalid input in one place, but throw in another

### Appropriate error handling
Ensure everywhere that can throw, is either caught properly and handled
elsewhere, or SHOULD fall through to a fatal user-facing error.
