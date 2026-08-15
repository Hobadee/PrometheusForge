# Project Status

Last updated: 2026-08-14

## Recent Changes
- Refactored variable ingestion into `Configuration.SetMany()` and removed `ItemFactory`-local document-specific helper logic.
- Rewired `Invoke-Lifecycle` base and overlay variable application to call `Configuration.SetMany()`.
- Simplified variable-shape handling to dictionary/map-only semantics aligned with source plugin contract (`IDictionary`), and added private unit coverage for `SetMany`.
- Taught `ItemFactory` import handling to load top-level `variables` from imported source documents into `Configuration` before resolving the imported `root` item.
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
- Added nested variable path support for templates (e.g., `{{ pin.object.generatedPassword }}`) resolved from `Configuration` values.
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
- Added variable import behavior that loads base config `variables` and then each overlay `variables` map into `Configuration`, where later overlays overwrite earlier values.
- Expanded `Invoke-Lifecycle` public tests to validate ordered overlay precedence and missing-overlay error handling.

## TODO

**Suggested Implementation Order**

1. [x] Rename `DoItem`
2. [x] Templating system (MVP scope)
3. [x] Item addon overlays
4. Item replacement overlays

Rationale:
- Variable overlays are the smallest, safest next change and unlock immediate value by populating `Configuration` from YAML.
- Templating depends on variables being available first, so it should follow immediately after overlays.
- Item addon overlays are structurally more complex (insertion semantics and config ingestion flow), so they should come after variable plumbing is stable.
- Item replacement overlays have the highest complexity (matching/identity/conflict handling) and remain a stretch goal.

Implementation notes for sequencing:
- Keep templating MVP-focused first (`{{ variable_name }}` and nested keys like `a.b.c`) before adding advanced template functions.
- Treat `when` and step parameters as the first templating targets, then expand to tags/plugin/retry/file-loading scenarios.


### Variable Overlays
Implemented in `Invoke-Lifecycle`:
- Base YAML `variables` are loaded into `Configuration`.
- Multiple `-Overlay` files are accepted and processed in call order (`-Overlay file1,file2,file3`).
- Overlay `variables` are merged by assignment (`Set`), so later overlays win on key collisions.
- Overlay contents are currently treated as variable-focused only (item overlays deferred to later TODOs).


### Source Plugins
Implemented:
- `sourcePluginInterface` provides the shared `Validate()` and `Load()` workflow for configuration sources.
- `yamlSource` is the first concrete source plugin and reads YAML configuration data from a URI or path.
- `ItemFactory` now routes import item URIs through the template engine before source plugin construction.

Deferred:
- Registry/lookup support for source plugins.

### YAML Imports
Working:
- Import item URIs can be templated before plugin resolution.
- `ItemFactory` resolves import items through the configured source plugin and loads the resulting YAML configuration.
- YAML imports are now covered by a focused regression test.


### Templating system
MVP implemented for variable templating in step parameters.

Implemented scope:
- `{{ variable_name }}` and nested paths like `{{ a.b.c }}`
- Expansion in top-level string values inside `ItemStep` plugin parameters
- Expansion for import item URIs before source plugin construction
- Expansion runs before plugin parameter validation (`SetParameters`)
- Missing/unresolved variables resolve to empty string in MVP

Deferred scope:
- `when` expression templating/evaluation
- Recursive expansion in nested parameter objects/arrays
- Templating for tags/plugins/retry/file-loading
- Advanced template functions (`if`, `foreach`, etc.)

Notes:
- Variables continue to come from `Configuration`, including base YAML and ordered overlays.
- End-to-end test coverage now verifies overlay precedence + template expansion together.

Locations we WILL want to use variables:
- ItemStep Parameters
- `when` parameters in sections/steps

Stetch Goal: Locations we would like to use variables:
- Tags (Not sure exactly how this will work yet, but we will definitely want
  to control tag inclusion/exclusion based on variables)
- Plugins (variable chooses which plugin to use)
- Retry (variables set how many retries to do)
- File loading (see the various overlay TODOs)

The easiest way would be to implement templating prior to YAML parsing, but
this means we coulnd't use return values as variables.  (Which is half the
point)

The templating system needs to be able to handle nested values, as plugins
will store return values this way.  For example, we may need to reference:
- pin.object.generatedPassword
- osInstalled.success
- networkConfigured.executionTime

The template system should be able to convert a string to the valid object
reference.

I already did some searching, and there doesn't seem to be a good existing
Powershell templating system, so we will need to roll our own.  For starters
we can just do something basic like:
`{{ variable_name }}`
Stretch goals could eventually include various other template functions such as
`if` statements, `foreach` loops, or other advanced functions included in many
templating systems.  These functions are NOT important howver, especially for
an MVP.


### Item addon overlays
YAML import items can now pull additional configuration into the tree.
The current implementation is handled by `ItemFactory` and source plugins:
``` YAML
type: import
file: path/to/file
```

The remaining design space is around how additional configuration should be
inserted into the current `ItemSection` index and how future non-YAML sources
should behave.

Status note (2026-08-14):
- YAML imports are functioning through `ItemFactory` with template expansion on the URI value.
- We intentionally do not implement relative YAML import resolution in the current
  implementation. Imports are expected to use absolute paths or caller-managed
  execution-location semantics.
- If we revisit relative path imports in the future, we should think carefully
  about the desired semantics before adding them. We should decide whether
  relative paths are anchored to the importing file, the current working
  directory, the entry-point config, or some other explicit base, and whether
  multi-layer imports should support variable expansion, canonicalization, or
  symlink behavior.
- We do not want to bolt relative-path behavior in ad hoc; it needs a deliberate
  design decision and test matrix.

The `file`/URI parameter runs through the template engine so it can be
variable.  (For example: `file: "applications.{{company}}.yaml"`)

We may want to implement lazy-loading as a stretch goal.

Status note (2026-08-08):
- A prior AI implementation attempt for item addon overlays was rejected and
  should not be treated as a valid baseline for follow-up work.
- Revisit this feature with guided implementation and smaller, explicitly
  reviewed steps before making structural changes.
- Keep the next attempt focused on the user-directed design rather than
  inferring broader architecture changes.
- No accepted item addon overlay implementation has landed yet.


### Lazy-Loading
We may want to lazy-load addon overlays at runtime to add support for `when`
directives.  While this isn't strictly required, it could reduce the footprint
of a run, especially given lots of possible includes/options.

We can create a new `ItemImport` that is a placeholder for a lazy-loaded import
item.  We then polymorph it into the appropriate object type right at the start
when we `Process()` it.

Note that we will loose load-time validation with lazy-loading.  Not sure the
best way of handling this right now - that's a future-me problem to think
about.

This is a VERY LOW priority.


### Item replacement overlays
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


### Rename `DoItem`
"DoItem" (in `ItemInterface`) implies a single item.  This doesn't make much
sense for `ItemSection`, which should by default process everything in one go.
With that being said, it makes sense to have an option in the class to do a
single item at a time, even if we don't expect to use it.

We should probably refactor everything from `DoItem` to `Process`, as this
would make more sense in the context of single-item "Steps", or multi-item
"Sections".  We can then have `Process` be the default, and something like
`ProcessStep` be a special function in the `ItemSection` class to simply
process the item that is currently selected by the index.


### Issues with AI builds
AI appears to have issues building/loading the module.  It's frequently
failing, causing issues doing actual tasks in a timely manner.  Investigate and
repair.

I asked it to fix itself, and it did a few changes to copilot-instructions, but
there may still be issues.  Low priority unless we see this happening more.


### Template Configuration
Passing a `Configuration` object directly to the template engine feels wrong
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


### Refactor [Configuration]
Should refactor [Configuration] to be [Variables], as this better explains what
the class does.  (It doesn't actually store any configuration directly)

Low priority.



## Test Status
- `Tests/Private/Classes/Items.tests.ps1` passes after the binder fix.
- Source-level rename completed for `DoItem` → `Process` across the module and tests.
- Verification is no longer blocked for the focused collection test file.
- YAML import items now flow through `ItemFactory` and source plugins with template expansion on the URI.
- The previous rejected WIP approach is no longer the baseline for import handling.
- Source-plugin scaffolding is wired into import ingestion; remaining work is limited to future extension points.

## Notes
- The old standalone `Items` wrapper class has been removed; any future collection helpers can be added directly to `ItemSection`.
