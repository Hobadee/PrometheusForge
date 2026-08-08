# Project Status

Last updated: 2026-08-08

## Recent Changes
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
2. Templating system (MVP scope)
3. Item addon overlays
4. Item replacement overlays (stretch)

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


### Templating system
We need to be able to use variables.  This will require a templating system.
Variables may be set via ingested YAML, or may be set later via return values.
Variables are stored in our `Configuration` class, and should be simple to
retrieve from there already - the hard part is parsing fields and inserting
the requested variable.

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
We should be able to import YAML files into the tree that contain additional
sections/steps.  This will likely simply be handled by:
``` YAML
type: import
file: path/to/file
```

Will need to create a handler in ItemFactory for this.  Additionally, since our
code *shouldn't* be directly tied to YAML, we should probably create an
additional handler to ingest configuration data (YAML to start, but extensible)
and use that.  Once the data is ingested, we need to insert the additional
configuration into the current `ItemSection` index.  (Ingested items should
follow the root item config, and will thus *ALWAYS* have a `root` item we
can ingest as a section at the current ItemSection index.)


### Item replacement overlays
Stretch goal - replace items/sections with imported items sections

ie: If we had a default "Install Apps" section, but wanted to change how it
worked periodically, we could create an overlay with a new "Install Apps"
section.  This would make the system extremely powerful, as overlays could
change any aspect, but it would also be extremely difficult.  Name keys would
no longer be just a nice-to-have, but become a primary key that overlays would
reference.  Implementation would need to scan for duplicates, and overlaying
would become more difficult, as we would need to search/replace items rather
than simply inserting at current location as we scan.

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

## Test Status
- `Tests/Private/Classes/Items.tests.ps1` passes after the binder fix.
- Source-level rename completed for `DoItem` → `Process` across the module and tests.
- Verification is no longer blocked for the focused collection test file.

## Notes
- The old standalone `Items` wrapper class has been removed; any future collection helpers can be added directly to `ItemSection`.
