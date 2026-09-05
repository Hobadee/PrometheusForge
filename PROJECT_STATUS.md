# Project Status

Last updated: 2026-09-05

## Recent Changes
- Scaffolded an optional plugin-facing API surface: `Classes/Api/ForgeApi.ps1` (top-level facade), `Classes/Api/ForgeVariableApi.ps1` (wraps `Variables`), and `Classes/Api/ForgeConfigurationApi.ps1` (MVP stub that only records requested overrides; no override-merging consumer yet). `TaskPluginInterface` now exposes `$this.Api` (settable via `SetApi()`), and `taskPluginRegistry.GetPlugin()` injects a fresh `ForgeApi` into every plugin instance it creates. This is opt-in: existing plugins are unaffected since `Api` defaults to `$null` and nothing requires calling it.
- Began the `Item*` to `Step*` architecture migration. `Item` terminology and the legacy item model are deprecated; new work should use `StepTree` for execution order and `Steps` for executable actions.
- Refactored `Steps` storage to match registry design: dictionary is now instance-scoped (`$this.Steps`) under the singleton instance instead of static class storage.
- Superseded prior `Steps` static-storage null-access workaround with an instance-scoped dictionary refactor.
- Renamed the project and PowerShell module to Prometheus Forge, including the public `Invoke-Forge` entry point, module manifest, build output, tests, and documentation.
- Added explicit public coverage in `Tests/Public/Invoke-Forge.Tests.ps1` for running YAML workflows via both absolute and relative `-FilePath` values.
- Added private registry coverage to assert duplicate registration of the same source plugin type is idempotent (no throw) in sourcePluginRegistry tests, while still preserving conflict checks for different types sharing the same plugin name.
- Refactored variable ingestion into `Variables.SetMany()` and removed `ItemFactory`-local document-specific helper logic.
- Rewired `Invoke-Forge` base and overlay variable application to call `Variables.SetMany()`.
- Simplified variable-shape handling to dictionary/map-only semantics aligned with source plugin contract (`IDictionary`), and added private unit coverage for `SetMany`.
- Taught `ItemFactory` import handling to load top-level `variables` from imported source documents into `Variables` before resolving the imported `root` item.
- Added focused private Pester coverage for imported-variable ingestion in `Tests/Private/Classes/Factories/ItemFactory.tests.ps1`.
- Added an end-to-end public regression proving variables from an imported YAML file are available to later sibling steps in `Tests/Public/Invoke-Forge.Tests.ps1`.
- Wired import item URIs through `TemplateEngine` before source plugin construction so YAML imports can use templated file paths.
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
- Wired `ItemStep` constructor to expand top-level string plugin parameters before `SetParameters()` validation.
- Added nested variable path support for templates (e.g., `{{ pin.object.generatedPassword }}`) resolved from `Variables` values.
- Implemented unresolved-template fallback to empty string for MVP.
- Added private unit coverage in `Tests/Private/Classes/TemplateEngine.tests.ps1`.
- Extended `Tests/Private/Classes/Items.tests.ps1` with ItemStep templating integration tests.
- Extended `Tests/Public/Invoke-Forge.Tests.ps1` with an end-to-end templating test validating base+overlay variable resolution.
- Fixed a PowerShell class binder edge case in `ItemSection.ProcessCurrentItem()` and `ProcessAllItems()` by widening the `Process()` family return types to `[object]` and keeping boolean values at runtime.
- Renamed the item execution API from `DoItem()` to `Process()` across `ItemInterface`, `ItemSection`, and `ItemStep`.
- Split `ItemSection` execution semantics so `Process()` executes only the current child item, `ProcessCurrentItem()` exposes that behavior explicitly, and `ProcessAllItems()` preserves full-section traversal.
- Updated `Invoke-Forge` to call `ItemSection.ProcessAllItems()` so top-level workflows still process every child item.
- Updated `Tests/Private/Classes/Items.tests.ps1` to cover both current-item and full-section execution paths using the renamed `Process` API.
- Consolidated collection behavior into `ItemSection` so sections own and manage their child items directly.
- Added `ItemSection.Add()` as the primary list mutation method.
- Added iteration support via `ItemSection.GetEnumerator()`.
- Added current-item execution support via `ItemSection.InvokeCurrentItem()`.
- Added `ItemSection.SetCurrentIndex()`, `ItemSection.GetCurrentItem()`, and `ItemSection.Count()` helpers.
- Migrated coverage to `Tests/Private/Classes/Items.tests.ps1` for the consolidated section behavior.
- Expanded PowerShell comment-based documentation in `Classes/05-itemStep.ps1` for `ItemStep`, including constructor and `DoItem()` behavior, input schema, retry policy, onError semantics, and result persistence notes.
- Expanded PowerShell comment-based documentation in `Classes/05-itemSection.ps1` for `ItemSection`, including constructor behavior, collection APIs, current-item execution, enumeration contract, and full-section execution semantics.
- Implemented `Invoke-Forge` as a real entry point that accepts `-FilePath`, validates the file, supports common PowerShell common parameters, parses YAML, and runs all loaded items.
- Added public tests for `Invoke-Forge` covering successful execution and missing-file errors.
- Implemented Variable Overlay ingestion in `Invoke-Forge` via `-Overlay` (`[string[]]`) so multiple overlays can be passed and processed in provided order.
- Added variable import behavior that loads base config `variables` and then each overlay `variables` map into `Variables`, where later overlays overwrite earlier values.
- Expanded `Invoke-Forge` public tests to validate ordered overlay precedence and missing-overlay error handling.

## TODO

**Suggested Implementation Order**

1. Step replacement overlays
2. Advanced templating coverage beyond the current MVP
3. Step addon overlay insertion semantics and lazy-loading design
4. AI build/load reliability investigation

**Stretch goal: permission plugin API access**
Plugins should declare which `ForgeApi` categories they actually use (e.g. via a new `Apis`/`RequiredApis` key in `PluginInfo()`). Calls to an API category a plugin did not declare should fail (e.g. `ForgeApi` only populates/exposes declared sub-APIs, or each sub-API checks a declared-capabilities set before executing). Not implemented yet — `ForgeApi`/`ForgeVariableApi`/`ForgeConfigurationApi` currently grant full access to every injected plugin.

### Active architecture: Steps replace Items
`Item` terminology and the legacy item model are deprecated. The migration separates the workflow into two independently managed concerns:

- `StepTree` stores hierarchy and execution order, with nodes referring to actions by name.
- `Steps` stores the executable action objects, keyed by their unique step names.

This separation makes it possible to alter execution order or lazily load tree content at runtime without changing the action objects themselves. It is the current major work item and is intended to solve both immediate MVP overlay/import needs and future runtime extensibility.

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

Here is the process we will go about migration (see subsections for details)
1. Refactor some names
2. Create "Steps" class
3. Wire StepTreeInterface into Steps class

#### Refactor
We should refactor some names to keep things clear
- ItemInterface --> StepTreeInterface
- ItemSection --> StepTreeSection
- ItemStep --> StepTreeAction
- taskPluginInterface --> ActionPluginInterface
- Task plugins --> Action plugins

#### Steps Class Specification:
Main data is an associative array of `[string]$name = [StepTreeInterface]$object`
Each step will store it's plugin object in the `Steps` class instead of the
StepTree itself.  `StepTreeAction` items will lookup and run the plugin from
the `Steps` class at runtime.

The `Steps` class should have the following methods:
- add() - Add a step - error if step already exists
- delete() - remove a step by name
- update() - Replace an existing step by name
- addOrUpdate() - Adds a step, update if step already exists
- get() - get a step by name
- exists() - checks if a step exists by name

#### Wiring StepTreeInterface into Steps class
While I don't *EXPECT* the need for `StepTreeSection` to need to connect to the
`Steps` class, I don't want to preclude the possibility.  I expect all my
concrete implementations in `Steps` to be `StepTreeAction`s, but I still want
everything done at the `StepTreeInterface` level.

#### Notes from the designer:
Replace items/sections with imported items/sections

When data is imported, it will be split into 2 similar but separate sections.
Viewing things as a "database", we will have the following "tables":
- StepTree
- Steps

Both will have "Primary Keys" of the step name.  On load, we will load the
hirearchy into the `StepTree`.  This will consist simply of `Step.Name`.
(This would also be the logical place to store/test conditions in future
versions, although this won't be present in MVP)  When we run, we will simply
traverse the `StepTree`, and for each item we search the `Steps` list for the
matching `Action` object and run it.

The biggest thing here is that we should check and enforce name uniqueness, or
the user will foot-gun themselves.  (Possibly auto-build names based on
hirearchy so YAML authors don't need to worry about the entire project but
rather just their section?)


#### Considerations
Do we allow templating inside names??  Names would be nice to list to users,
and if listed to users, templating would be nice, but this would also create a
world of pain to program, as resolving for duplicates would be impossible ahead
of time.  Come to think of it, this wouldn't really be possible.

Lets just add a "Note" field or something - if no "note" field, just print out
the name.  If a "note" field does exist, template and print that instead.


#### Move imports to be a special plugin class?
Since I have already implemented lazy-loading for plugins, I think it could be
a good idea to use that existing code for "imports" - refactor imports as a
special plugin that mostly just uses the regular `taskPlugin` infrastructure,
but has a few special hooks in the StepTree to pull the `$res` object the
plugin generates and insert it during `Process()`


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
- YAML imports are currently supported through the legacy `ItemFactory` and the source-plugin flow.
- The remaining issue is not import loading itself; it is the semantics of where and how imported content should be placed in the running `StepTree`.


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


### Rename Project
The name "Lifecycle" doesn't actually fit this project well.  While I will use
it for user-lifecycle tasks, it is capable of so much more.  We need to figure
out a better name for it and rename everything.  (Without breaking it all!)

Completed: Renamed the project and PowerShell module to "Prometheus Forge". The technical module name is `PrometheusForge`, and the main command is `Invoke-Forge`.


## Cleanup Items

### Test Coverage
Ask AI to check test coverage and ensure it's appropriate.  Ensure similar
test types exist for all classes where applicable.

### Invoke-Forge tests
Completed: Added tests in Invoke-Forge to validate both absolute and relative YAML paths.

### Consistent throws/errors
Ensure everything errors out or throws consistently.  For example, we shouldn't
null return on invalid input in one place, but throw in another

### Appropriate error handling
Ensure everywhere that can throw, is either caught properly and handled
elsewhere, or SHOULD fall through to a fatal user-facing error.
