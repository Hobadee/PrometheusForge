# Built-in Task Plugins

Task plugins do the work of a workflow step. A step selects one with `plugin:` and configures it with `parameters:`.

Some task plugins (`ImportConfig`, `OverlayConfig`) load configuration through a **source plugin**; those are documented
separately in [SOURCE_PLUGINS.md](SOURCE_PLUGINS.md). To write your own plugin, see
[Plugin Development](README.md#plugin-development) in the README.

## Using a plugin in a step

```yaml
- type: step
  name: Say Hello
  slug: say-hello
  plugin: TextOutput
  parameters:
    message: "Hello, world"
```

Notes that apply to every task plugin:

- Parameter names are case-insensitive in practice, but this document uses the spelling each plugin documents. Asana
  parameters use Asana's own snake_case names (for example `html_notes`).
- Top-level string values in `parameters` are run through the template engine before the plugin sees them, so
  `{{variableName}}` and `{{step.<slug>.object...}}` references work.
- A plugin's return value is available to later steps as `{{step.<slug>.object}}`, and any error as
  `{{step.<slug>.error}}`.
- A parameter marked **required** causes the step to fail validation if it is missing.

## Summary

| Plugin | Category | Purpose |
| --- | --- | --- |
| [`TextOutput`](#textoutput) | Core | Write a message to the log |
| [`RegisterVariable`](#registervariable) | Core | Set a workflow variable |
| [`CurrentTime`](#currenttime) | Core | Return the current date and time |
| [`PasswordGenerator`](#passwordgenerator) | Core | Generate a random password |
| [`ImportConfig`](#importconfig) | Core | Load a config document and insert it into the workflow |
| [`OverlayConfig`](#overlayconfig) | Core | Load a config document and queue its entries as overlays |
| [`AsanaCreateProject`](#asanacreateproject) | Asana | Create a project |
| [`AsanaCreateSection`](#asanacreatesection) | Asana | Create a section in a project |
| [`AsanaCreateTask`](#asanacreatetask) | Asana | Create a task |
| [`AsanaCreateTaskDependency`](#asanacreatetaskdependency) | Asana | Link tasks as predecessors or successors |
| [`AsanaAddTasksToSection`](#asanaaddtaskstosection) | Asana | Add tasks to a section |

---

## Core task plugins

### TextOutput

Writes a message to the log.

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `message` | Yes (see note) | string | The text to log. |
| `level` | No | string | Any log level name: `Emergency`, `Alert`, `Critical`, `Error`, `Warning`, `Notice`, `Info`, `Debug`, or `Trace`. Defaults to `Info`. |

**Returns:** the plugin instance.

> **Note:** The only enforced check is that `parameters` itself is present, but a missing `message` is not caught
> during validation. Always supply one.
>
> The default terminal log level is `Warning`, so a `TextOutput` at the default `Info` level will not appear on the
> terminal in a default run. Either set `level: Warning` (or higher) on the step, or lower the terminal threshold, for
> example `Invoke-Forge -Variables @{ logTerminalLevel = 'info' }`.

```yaml
- type: step
  name: Announce
  slug: announce
  plugin: TextOutput
  parameters:
    message: "Starting onboarding for {{userName}}"
    level: Warning
```

### RegisterVariable

Stores a value in the workflow variable store so later steps can refer to it as `{{name}}`. This is handy for giving a
short name to a value buried in an earlier step's result.

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `name` | Yes | string | The variable name. Must be a non-empty string. |
| `value` | No | any | The value to store. May be a scalar, list, object, or null. |

**Returns:** `@{ name; value }`.

```yaml
- type: step
  name: Remember Project GID
  slug: remember-project
  plugin: RegisterVariable
  parameters:
    name: AsanaProjectGID
    value: "{{step.create-asana-project.object.data.gid}}"
```

### CurrentTime

Returns the current date and time as a `[datetime]`.

This plugin takes no parameters. Any supplied value is ignored.

**Returns:** the `[datetime]`, available as `{{step.<slug>.object}}`.

```yaml
- type: step
  name: Get Current Time
  slug: current-time
  plugin: CurrentTime
```

### PasswordGenerator

Generates a random password. The password is available as `{{step.<slug>.object.generatedPassword}}`.

| Parameter | Required | Type | Default | Description |
| --- | --- | --- | --- | --- |
| `length` | No | integer | `16` | Password length. Must be at least 1. |
| `includeLowercase` | No | boolean | `true` | Include `a-z`. |
| `includeUppercase` | No | boolean | `true` | Include `A-Z`. |
| `includeNumbers` | No | boolean | `true` | Include `0-9`. |
| `includeSpecial` | No | boolean | `false` | Include `` !@#$%^&*()_+-=[]{}\|;:,.<>? ``. |

At least one character class must be enabled.

**Returns:** the plugin instance. Read the result from its `generatedPassword` property.

> **Security note:** Characters are chosen with `System.Random`, which is not a cryptographically secure generator.
> Consider this before using the output for production credentials.

```yaml
- type: step
  name: Generate Temporary Password
  slug: temp-password
  plugin: PasswordGenerator
  parameters:
    length: 20
    includeSpecial: true
```

### ImportConfig

Loads a configuration document through a source plugin and **inserts** it as a new child at the current step's
location. Because it runs at execution time like any other step, it can be conditional or templated. See
[Insert vs. Overlay](README.md#insert-vs-overlay) in the README.

If the loaded document has a top-level `variables` block, those variables are set first. The document's `root` (or the
whole document, when there is no `root`) is then inserted. A bare list of items, or a single `type: step`, is wrapped
in a synthetic section automatically.

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `URI` | Yes | string | The path or location the source plugin should load. |
| `SourcePluginName` | Yes | string | The source plugin used to load it, for example `yamlSource` (see [SOURCE_PLUGINS.md](SOURCE_PLUGINS.md)). |

**Returns:** `@{ uri; sourcePlugin; insertedName }`.

```yaml
- type: step
  name: Enroll Device
  slug: enroll-device
  plugin: ImportConfig
  parameters:
    uri: "./sections/enroll-device.yaml"
    sourcePluginName: yamlSource
```

### OverlayConfig

Loads a configuration document through a source plugin and queues each entry of its `root` as an **overlay**. An
overlay replaces the step or section that currently has the same `slug`, anywhere in the tree, the next time a node
with that slug is processed. Nothing is inserted as a child of the current step.

As with `ImportConfig`, any top-level `variables` in the loaded document are set first. Every entry in `root` must
carry its own `slug`.

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `URI` | Yes | string | The path or location the source plugin should load. |
| `SourcePluginName` | Yes | string | The source plugin used to load it, for example `yamlSource` (see [SOURCE_PLUGINS.md](SOURCE_PLUGINS.md)). |

**Returns:** `@{ uri; sourcePlugin; queuedSlugs }`.

```yaml
- type: step
  name: Apply Client Overlay
  slug: apply-client-overlay
  plugin: OverlayConfig
  parameters:
    uri: "./overlays/clientA.yaml"
    sourcePluginName: yamlSource
```

---

## Asana task plugins

The Asana plugins only **create** Asana objects. They do not read, update, or delete anything. All of them call the
Asana REST API (`https://app.asana.com/api/1.0` by default) and return the parsed JSON response, so a created object's
ID is available as, for example, `{{step.<slug>.object.data.gid}}`.

### Authentication and connection settings

Credentials are **never** plugin parameters. They are read from workflow variables, which should come from the command
line or an overlay file (such as a git-ignored `.env.yaml`), not from the workflow YAML itself.

| Variable | Required | Description |
| --- | --- | --- |
| `Plugin.Asana.PAT` (or `Plugin_Asana_PAT`) | Yes | Asana Personal Access Token. |
| `Plugin.Asana.BaseUri` (or `Plugin_Asana_BaseUri`) | No | Override the API base URI, for example for testing. |
| `Plugin.Asana.Username` (or `Plugin_Asana_Username`) | No | Reserved for OAuth. OAuth is **not implemented**: setting this variable causes an error. |

Example overlay file:

```yaml
variables:
  Plugin.Asana.PAT: "<your-personal-access-token-here>"
```

If neither a PAT nor an OAuth username is set, the Asana steps fail validation with an authentication error.

### AsanaCreateProject

Creates a project (`POST /projects`).

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `name` | Yes | string | Project title. |
| `workspaceGid` | Yes | string | GID of the workspace to create the project in. |
| `notes` | No | string | Plain-text description. |
| `html_notes` | No | string | Rich-text (HTML) description. |
| `privacy_setting` | No | string | Asana privacy mode for the project. |
| `default_access_level` | No | string | Access level for new members. |
| `color` | No | string | One of `dark-pink`, `dark-green`, `dark-blue`, `dark-red`, `dark-teal`, `dark-brown`, `dark-orange`, `dark-purple`, `dark-warm-gray`, `light-pink`, `light-green`, `light-blue`, `light-red`, `light-teal`, `light-brown`, `light-orange`, `light-purple`, `light-warm-gray`, `none`, `null`. |
| `icon` | No | string | One of `list`, `board`, `timeline`, `calendar`, `rocket`, `people`, `graph`, `star`, `bug`, `light_bulb`, `globe`, `gear`, `notebook`, `computer`, `check`, `target`, `html`, `megaphone`, `chat_bubbles`, `briefcase`, `page_layout`, `mountain_flag`, `puzzle`, `presentation`, `line_and_symbols`, `speed_dial`, `ribbon`, `shoe`, `shopping_basket`, `map`, `ticket`, `coins`. |
| `default_view` | No | string | Default view mode for the project. |

`privacy_setting`, `default_access_level`, and `default_view` are passed to Asana without local validation, so Asana
decides which values are accepted.

```yaml
- type: step
  name: Create Onboarding Project
  slug: create-asana-project
  plugin: AsanaCreateProject
  parameters:
    name: "Onboarding - {{userName}}"
    workspaceGid: "{{Plugin_Asana_WorkspaceGID}}"
    color: light-green
    icon: people
```

### AsanaCreateSection

Creates a section in a project (`POST /projects/{projectGid}/sections`).

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `name` | Yes | string | Section title. |
| `projectGid` | Yes | string | GID of the project that will contain the section. |
| `insert_before` | No | string | GID of an existing section that the new section is placed before. |
| `insert_after` | No | string | GID of an existing section that the new section is placed after. |

`insert_before` and `insert_after` cannot be used together.

```yaml
- type: step
  name: Create Hardware Section
  slug: create-hardware-section
  plugin: AsanaCreateSection
  parameters:
    name: Hardware
    projectGid: "{{AsanaProjectGID}}"
```

### AsanaCreateTask

Creates a task (`POST /tasks`). At least one of `workspace`, `projects`, or `parent` is required.

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `name` | Yes | string | Task title. |
| `workspace` | One of `workspace` / `projects` / `parent` | string | Workspace GID. |
| `projects` | One of `workspace` / `projects` / `parent` | string[] | Project GIDs to add the task to. Must be a non-empty list of non-empty GIDs. |
| `parent` | One of `workspace` / `projects` / `parent` | string | Parent task GID, which makes this a subtask. |
| `assignee` | No | string | Assignee user GID. |
| `notes` | No | string | Plain-text description. |
| `html_notes` | No | string | Rich-text description. See [Rich text](#rich-text). |
| `resource_subtype` | No | string | `default_task`, `milestone`, `approval`, or `custom`. |
| `approval_status` | No | string | `pending`, `approved`, `rejected`, or `changes_requested`. |
| `completed` | No | boolean | Whether the task is complete. Must match `approval_status` when both are set (`pending` means not completed, anything else means completed). |
| `due_at` | No | string | Due timestamp, ISO 8601 UTC (`2026-10-01T17:00:00Z`). |
| `due_on` | No | string | Due date, `YYYY-MM-DD`. |
| `start_at` | No | string | Start timestamp, ISO 8601 UTC. Requires `due_at`. |
| `start_on` | No | string | Start date, `YYYY-MM-DD`. Requires `due_at` or `due_on`. |

Constraints:

- `due_at` and `due_on` are mutually exclusive, as are `start_at` and `start_on`.
- Milestone tasks cannot have `start_at` or `start_on`.
- `assignee`, `parent`, and `workspace` cannot be empty if present.

```yaml
- type: step
  name: Order Laptop
  slug: order-laptop
  plugin: AsanaCreateTask
  parameters:
    name: Order laptop for {{userName}}
    projects:
      - "{{AsanaProjectGID}}"
    due_on: "2026-10-15"
    notes: Standard developer configuration.
```

### AsanaCreateTaskDependency

Links one task to others as predecessors or successors. Wraps `POST /tasks/{taskGid}/addDependencies` and
`POST /tasks/{taskGid}/addDependents`.

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `taskGid` | Yes | string | The anchor task. |
| `relatedTaskGids` | Yes | string[] | Non-empty list of task GIDs to link to the anchor. |
| `relation` | Yes | string | `predecessor`: the related tasks must finish **before** the anchor can start. `successor`: the related tasks happen **after** the anchor is completed. |

```yaml
- type: step
  name: Configure After Order
  slug: link-tasks
  plugin: AsanaCreateTaskDependency
  parameters:
    taskGid: "{{ConfigureTaskGID}}"
    relatedTaskGids:
      - "{{OrderTaskGID}}"
    relation: predecessor
```

### AsanaAddTasksToSection

Adds tasks to a section (`POST /sections/{sectionGid}/addTask`). Asana accepts one task per request, so the plugin sends
one request per GID. Because Asana places each newly added task at the top of a section, the plugin reverses the list
before sending so the final order matches the order you gave.

| Parameter | Required | Type | Description |
| --- | --- | --- | --- |
| `sectionGid` | Yes | string | The section that receives the tasks. |
| `taskGids` | Yes | string[] | Non-empty list of task GIDs to add. |

**Returns:** an array with one API response per task.

```yaml
- type: step
  name: File Tasks Under Hardware
  slug: file-hardware-tasks
  plugin: AsanaAddTasksToSection
  parameters:
    sectionGid: "{{HardwareSectionGID}}"
    taskGids:
      - "{{OrderTaskGID}}"
      - "{{ConfigureTaskGID}}"
```

### Rich text

`html_notes` is validated against Asana's [rich text](https://developers.asana.com/docs/rich-text) subset before
anything is sent. The value must be wrapped in `<body>...</body>` and may only use these tags:

`body`, `strong`, `em`, `u`, `s`, `code`, `ol`, `ul`, `li`, `a`, `blockquote`, `pre`

For `AsanaCreateTask`, `h1`, `h2`, `hr`, and `img` are also allowed. `AsanaCreateProject` passes `html_notes` through
without this check.
