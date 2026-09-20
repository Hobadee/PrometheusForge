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

Prometheus Forge applies configuration serially.  Later values override earlier values where supported. Individual steps can be replaced to account for implementation
differences between clients or environments.

Current execution behavior:

- Workflows run serially in dependency order.
- The default run mode is non-interactive and aborts on error.
- The current built-in example plugin is `TextOutputPlugin`.


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
