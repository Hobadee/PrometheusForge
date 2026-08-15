# Project Status

Last updated: 2026-08-15

## Recent Changes
- Added explicit public coverage in `Tests/Public/Invoke-Lifecycle.Tests.ps1` for running YAML workflows via both absolute and relative `-FilePath` values.
- Added private registry coverage to assert duplicate registration of the same source plugin type is idempotent (no throw) in sourcePluginRegistry tests, while still preserving conflict checks for different types sharing the same plugin name.
- Refactored variable ingestion into `Variables.SetMany()` and removed `ItemFactory`-local document-specific helper logic.
- Rewired `Invoke-Lifecycle` base and overlay variable application to call `Variables.SetMany()`.
- Simplified variable-shape handling to dictionary/map-only semantics aligned with source plugin contract (`IDictionary`), and added private unit coverage for `SetMany`.
- Taught `ItemFactory` import handling to load top-level `variables` from imported source documents into `Variables` before resolving the imported `root` item.
- Added focused private Pester coverage for imported-variable ingestion in `Tests/Private/Classes/Factories/ItemFactory.tests.ps1`.
- Added an end-to-end public regression proving variables from an imported YAML file are available to later sibling steps in `Tests/Public/Invoke-Lifecycle.Tests.ps1`.
- Wired import item URIs through `TemplateEngine` before source plugin construction so YAML imports can use templated file paths.
- Added a focused regression test for templated YAML imports to confirm the expanded URI reaches the source plugin constructor.
- Expanded comment-based help in `sourcePluginInterface.ValidateConfig()` to explicitly document every enforced rule (non-null config, IDictionary shape, required/parseable `version >= 1.0`, and required `variables` and/or `root`).
- Tightened `sourcePluginInterface.ValidateConfig()` so imported configs must declare `version >= 1.0` and include at least one of `variables` or `root`.
- Updated private Pester coverage for source plugins to exercise version and section validation, and refreshed `yamlSource` fixture data to match the new schema.
- Split `sourcePluginInterface` contract coverage out of `yamlSource.tests.ps1` into a dedicated private test file: `Tests/Private/Classes/Plugins/sourcePluginInterface.tests.ps1`.
- Kept `Tests/Private/Classes/Plugins/Source/yamlSource.tests.ps1` focused on concrete `yamlSource` behavior and aligned assertions with current constructor/metadata behavior.
- Fixed template expansion for sample-style YAML parameter lists by teaching `TemplateEngine.ExpandTopLevelValues()` to traverse `IList` inputs and expand each top-level element in place.
- Added regression coverage for list-shaped parameters in both `TemplateEngine` unit tests and `Invoke-Lifecycle` end-to-end tests.
- Implemented MVP templating runtime with a new `TemplateEngine` class and load-order file `Classes/03-TemplateEngine.ps1`.
- Added a new `sourcePlugin` family with `sourcePluginInterface` and a first `yamlSource` implementation for loading YAML configuration data.
- Wired `ItemStep` constructor to expand top-level string plugin parameters before `SetParameters()` validation.
- Added nested variable path support for templates (e.g., `{{ pin.object.generatedPassword }}`) resolved from `Variables` values.
- Implemented unresolved-template fallback to empty string for MVP.
- Added private unit coverage in `Tests/Private/Classes/TemplateEngine.tests.ps1`.
- Extended `Tests/Private/Classes/Items.tests.ps1` with ItemStep templating integration tests.
- Extended `Tests/Public/Invoke-Lifecycle.Tests.ps1` with an end-to-end templating test validating base+overlay variable resolution.
- Fixed a PowerShell class binder edge case in `ItemSection.ProcessCurrentItem()` and `ProcessAllItems()` by widening the `Process()` family return types to `[object]` and keeping boolean values at runtime.
- Renamed the item execution API from `DoItem()` to `Process()` across `ItemInterface`, `ItemSection`, and `ItemStep`.
- Split `ItemSection` execution semantics so `Process()` executes only the current child item, `ProcessCurrentItem()` exposes that behavior explicitly, and `ProcessAllItems()` preserves full-section traversal.
- Updated `Invoke-Lifecycle` to call `ItemSection.ProcessAllItems()` so top-level workflows still process every child item.
- Updated `Tests/Private/Classes/Items.tests.ps1` to cover both current-item and full-section execution paths using the renamed `Process` API.
- Consolidated collection behavior into `ItemSection` so sections own and manage their child items directly.
- Added `ItemSection.Add()` as the primary list mutation method.
- Added iteration support via `ItemSection.GetEnumerator()`.
- Added current-item execution support via `ItemSection.InvokeCurrentItem()`.
- Added `ItemSection.SetCurrentIndex()`, `ItemSection.GetCurrentItem()`, and `ItemSection.Count()` helpers.
- Migrated coverage to `Tests/Private/Classes/Items.tests.ps1` for the consolidated section behavior.
- Expanded PowerShell comment-based documentation in `Classes/05-itemStep.ps1` for `ItemStep`, including constructor and `DoItem()` behavior, input schema, retry policy, onError semantics, and result persistence notes.
- Expanded PowerShell comment-based documentation in `Classes/05-itemSection.ps1` for `ItemSection`, including constructor behavior, collection APIs, current-item execution, enumeration contract, and full-section execution semantics.
- Implemented `Invoke-Lifecycle` as a real entry point that accepts `-FilePath`, validates the file, supports common PowerShell common parameters, parses YAML, and runs all loaded items.
- Added public tests for `Invoke-Lifecycle` covering successful execution and missing-file errors.
- Implemented Variable Overlay ingestion in `Invoke-Lifecycle` via `-Overlay` (`[string[]]`) so multiple overlays can be passed and processed in provided order.
- Added variable import behavior that loads base config `variables` and then each overlay `variables` map into `Variables`, where later overlays overwrite earlier values.
- Expanded `Invoke-Lifecycle` public tests to validate ordered overlay precedence and missing-overlay error handling.

## TODO

**Suggested Implementation Order**

1. Item replacement overlays
2. Advanced templating coverage beyond the current MVP
3. Item addon overlay insertion semantics and lazy-loading design
4. AI build/load reliability investigation

### Item replacement overlays
Replace items/sections with imported items/sections.

This remains the highest-complexity unimplemented feature. The remaining work is to define and enforce the identity model for overlays, including:
- matching imported content to the correct section or item by stable name/key
- preventing silent collisions when names are duplicated
- deciding how to merge or replace nodes while preserving traversal order
- refactoring the internal naming and storage model only once the final behavior is agreed upon

The core design idea is still valid: split the runtime model into a tree/step lookup layer plus the action objects that are executed, and enforce uniqueness before overlay application.

#### Notes from the designer:
Replace items/sections with imported items/sections

ie: If we had a default "Install Apps" section, but wanted to change how it
worked periodically, we could create an overlay with a new "Install Apps"
section.  This would make the system extremely powerful, as overlays could
change any aspect, but it would also be extremely difficult.  Name keys would
no longer be just a nice-to-have, but become a primary key that overlays would
reference.  Implementation would need to scan for duplicates, and overlaying
would become more difficult, as we would need to search/replace items rather
than simply inserting at current location as we scan.

This will require a slight redesign/refactor, but will be well worth it, and
fairly easy to implement after the redesign/refactor.

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

Additionally, we should refactor some names:
- ItemSection --> StepSection
- ItemStep --> StepAction
- TaskPlugins --> ActionPlugins
- ItemInterface --> Step
Note: I haven't thought 100% about this refactor yet - DO NOT IMPLEMENT until
we have thought about it further and finalized it.

#### Considerations
Do we allow templating inside names??  Names would be nice to list to users,
and if listed to users, templating would be nice, but this would also create a
world of pain to program, as resolving for duplicates would be impossible ahead
of time.  Come to think of it, this wouldn't really be possible.

Lets just add a "Note" field or something - if no "note" field, just print out
the name.  If a "note" field does exist, template and print that instead.


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

### Item addon overlays
The basic YAML-import flow is working, but the remaining design questions are about insertion semantics and long-term behavior rather than the parser itself.

Remaining work:
- define how imported items/sections are inserted into the current `ItemSection` index
- decide how future non-YAML sources should behave in the same pipeline
- make a deliberate decision about relative import resolution before adding it, rather than inferring a hidden rule from current execution location
- implement optional lazy-loading so filename variables set via function return can resolve

Current state:
- YAML imports are supported through `ItemFactory` and the source-plugin flow.
- The remaining issue is not import loading itself; it is the semantics of where and how imported content should be placed in the running item tree.


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

After much deliberation, we will rename to "Prometheus Forge"


## Cleanup Items

### Test Coverage
Ask AI to check test coverage and ensure it's appropriate.  Ensure similar
test types exist for all classes where applicable.

### Invoke-Lifecycle tests
Completed: Added tests in Invoke-Lifecycle to validate both absolute and relative YAML paths.
