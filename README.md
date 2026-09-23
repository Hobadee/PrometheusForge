<p align="center">
  <img src="Assets/prometheus-forge-logo.svg" alt="Prometheus Forge logo" width="240">
</p>

<h1 align="center">Prometheus Forge</h1>

<p align="center">
  A PowerShell workflow engine for YAML-defined onboarding, offboarding, and operational automation.
</p>

Prometheus Forge lets teams define repeatable workflows as reusable YAML configurations. Base configurations can be
adapted for different clients, departments, or roles using variable overlays, imported sections, templating, and
extensible task plugins.

The original goal was to template Asana projects for onboarding and offboarding users across multiple clients. The
plugin system now allows Prometheus Forge to support a wider range of operational tasks and integrations.

The project is written in PowerShell 7.4+ and is designed to be cross-platform, easy to extend, and straightforward
to maintain.


## Features

- YAML-defined workflows with reusable step and section structure
- Variable overlays for client, department, or run-specific customization
- Imported configuration sections and templated file paths
- Extensible task plugin architecture
- Plugin-requested step insertion and same-name step replacement
- Serial workflow execution with configurable task behavior

## Requirements

- PowerShell 7.4 or later
- `powershell-yaml` 0.4.12 or later

Install the YAML dependency with:

```powershell
Install-Module -Name powershell-yaml -MinimumVersion 0.4.12 -Scope CurrentUser
```

## Quick Start

```powershell
Install-Module PrometheusForge
Invoke-Forge -FilePath .\Samples\Sample.Onboard.yaml
```

To view all options and examples for the public command:

```powershell
Get-Help Invoke-Forge -Full
```

### Example
This is what a real command might look like:
- `onboard.yaml` would hold the bulk of an onboarding configuration and pull in several other sub-configurations
- Variables to change the run behavior can be passed directly on the command line.  Here we are enabling debug logging.
  Command-line variables take precedence over any overlays, but can still be overwritten during the actual run
- Multiple overlays can be passed, and will overwrite each other with the last taking the highest precedence
  - `.env.yaml` is a good place to store API keys - make sure you `.gitignore` it!
  - `clientA.yaml` can be various variables related to a specific client, department, or other modification you may need to make
    Future versions will allow overwriting steps or even entire sections with overlay versions instead.
  - `newUserDetails` would contain user-specific details in this onboarding situation

```powershell
Invoke-Forge -FilePath onboard.yaml -Variables @{ logTerminalLevel = 'debug'} -Overlay .env.yaml, clientA.yaml, newUserDetails.yaml
```

## Configuration Model

Prometheus Forge applies configuration serially.  Later values take precedence over earlier values where supported. Individual steps can be replaced to account for implementation
differences between clients or environments.

Current execution behavior:

- Workflows run serially in dependency order.
- The default run mode is non-interactive and aborts on error.
- The current built-in example plugin is `TextOutputPlugin`.


## Insert vs. Overlay

Prometheus Forge has two distinct mechanisms for composing a workflow out of smaller pieces of
YAML. The terminology below isn't fully locked down yet, so treat the names as descriptive rather
than final.

### Insert

An **insert** loads a separate YAML document and adds it as a new child at the current location in
the tree, alongside whatever is already there. Nothing existing is removed or replaced.

Inserts are useful for splitting a large workflow into smaller, reusable files and collecting them
back together into a single master configuration - for example, keeping "create user", "enroll
device", and "install software" as their own files and composing them from a top-level
`onboard.yaml`.

Inserts are handled by the `ImportConfig` task plugin, which loads a document via a source plugin
(e.g. `yamlSource`) and queues it for insertion with `Api.Configuration.Insert()`:

```yaml
- type: step
  name: Enroll Device
  slug: enroll-device
  plugin: ImportConfig
  parameters:
    uri: "./sections/enroll-device.yaml"
    sourcePluginName: yamlSource
```

### Overlay

An **overlay** replaces a step or section already in the tree, targeted by slug, with a different
step or section. Unlike an insert, this removes what's currently there instead of adding alongside
it.

This is useful when a specific client or department needs a substantially different version of a
step or section than the base configuration provides - for example, a client with its own custom
user-onboarding step - without having to duplicate and maintain the rest of the workflow.

An overlay can be requested two ways:

- **From YAML**, via the `-Overlay` parameter on `Invoke-Forge` (see Quick Start above): an overlay
  file's top-level `root` - the same shape as the main YAML's `root` - queues one overlay per entry,
  targeting its own `slug`, alongside whatever `variables` and tag include/exclude filters that same
  overlay file sets.
- **From a plugin**, via `Api.Configuration.RequestOverlay(slug, config)`.

Either way, the request is queued and applied the next time a tree node with that slug is processed
(`StepTree.ApplyPendingOverlay()`), so the overlay can target any node in the tree, not only
children of the requesting step (or, for a YAML overlay file, not only nodes under a particular
location - it can target anywhere in the whole tree). A `type: step` overlay swaps only the step's
implementation; the node's position, tags, and children are left untouched. Any other `type` (e.g.
`section`) replaces the whole subtree - position, tags, and children included.

An overlay's `type` doesn't need to match what it's replacing:

- Replacing a step with a `type: section` config (with its own `items`) works directly - the old
  step's registration is cleared before the section is built, so a step-shaped and a section-shaped
  target look the same to the underlying machinery.
- Replacing a *section* with a bare `type: step` config does **not** work directly - it throws,
  because a section never registers a `Step` for the leaf-only overlay path to find. Get the same
  effect by wrapping the replacement in a `type: section` config whose `items` contains a single
  `type: step` entry; that goes through the structural path instead, which doesn't care what the
  original target was.

This kind of overlay is the "Robust Overlays" work described in `TODO.md`.

## Plugin Development

Task plugins implement the `taskPluginInterface` contract. Existing plugin examples are available in
`Classes/Plugins/Task/`, and the interface is defined in `Classes/Plugins/00-taskPluginInterface.ps1`.

Plugins can use the injected `ForgeApi` surface to access workflow variables and request supported configuration
changes during execution.

## Development and Testing

`Build-Module` is provided by PoshCode's [ModuleBuilder](https://github.com/PoshCode/ModuleBuilder) module. Install it
for your current user with:

```powershell
Install-Module -Name ModuleBuilder -Scope CurrentUser
```

After installing ModuleBuilder and Pester, build the module and run the test suite from the repository root:

```powershell
Build-Module
Import-Module .\build\PrometheusForge\PrometheusForge.psd1 -Force
Invoke-Pester
```

The generated files in `build/` should not be edited directly.

### *NIX
A `makefile` is provided for *NIX users to ease build and test workflows from a non-PowerShell environment.  (`pwsh` must be in your `$path`)  Standard `make` targets exist:
- `make`
- `make test`
- `make clean`

There are also some special additional `make` targets:
- `make shell`
    will put you in a PowerShell instance with the module loaded
- `make production`
    Installs the production dependancies (YAML PS module)
- `make dev`
    Installs development dependancies (PoshCode Module Builder)

## AI-Assisted Development

AI tools were used to assist with implementation, documentation, and testing. Prometheus Forge's architecture,
workflow model, design decisions, and code review remain human-led and thoughtfully designed.  Areas that were
completely AI generated without any human thought or review have generally be labelled as such, although this
isn't a 100% guarantee.

## Roadmap

- Expand test coverage across the full workflow surface
- Add advanced templating, including conditional expressions and recursive nested expansion
- Improve step addon overlay insertion semantics and lazy loading
