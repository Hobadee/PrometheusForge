# Built-in Source Plugins

Source plugins load configuration documents from an external location and hand them to the engine as a parsed
configuration object. They are not workflow steps, so you never write `plugin: yamlSource` in a step. You name a source
plugin from a **task plugin** that needs to load a document, such as `ImportConfig` or `OverlayConfig`:

```yaml
- type: step
  name: Enroll Device
  slug: enroll-device
  plugin: ImportConfig
  parameters:
    uri: "./sections/enroll-device.yaml"
    sourcePluginName: yamlSource
```

For the task plugins themselves, see [TASK_PLUGINS.md](TASK_PLUGINS.md). To write your own source plugin, see
[Plugin Development](README.md#plugin-development) in the README.

## Summary

| Plugin | Purpose |
| --- | --- |
| [`yamlSource`](#yamlsource) | Load configuration from a local YAML file |

## Rules that apply to every source plugin

Every source plugin inherits the same load-and-validate workflow, so any document it returns must satisfy these rules
regardless of where it came from:

- The loaded document must be a dictionary (a YAML mapping at the top level).
- It must have a `version` key that parses as version `1.0` or later. A bare `1` is treated as `1.0`.
- It must contain a `variables` section, a `root` section, or both.

A document that breaks any of these rules fails to load with an error naming the source.

A minimal valid document:

```yaml
version: 1.0
variables:
  greeting: Hello
root:
  - type: step
    name: Say Hello
    slug: say-hello
    plugin: TextOutput
    parameters:
      message: "{{greeting}}"
```

## yamlSource

Loads configuration data from a YAML file.

**Registered name:** `yamlSource`

| Input | Required | Description |
| --- | --- | --- |
| `URI` | Yes | Path to the YAML file. Relative paths resolve from the **current working directory**, not from the module or the workflow file that referenced them. A `file://` URI is also accepted. |

In practice, `URI` is supplied through the `uri` parameter of the task plugin that uses the source plugin.

Behavior:

- Only local files are supported. Any other URI scheme (for example `https://`) is rejected.
- Errors raised while loading:

  | Condition | Exception |
  | --- | --- |
  | Empty or missing URI | `ArgumentNullException` |
  | File not found | `FileNotFoundException` |
  | File cannot be read | `UnauthorizedAccessException` |
  | Document parses to nothing (for example an empty file) | `InvalidOperationException` |
  | Document breaks one of the [rules above](#rules-that-apply-to-every-source-plugin) | `InvalidOperationException` or `ArgumentException` |

- Parsing uses `ConvertFrom-Yaml`, so the `powershell-yaml` module is required.

## Using a source plugin from PowerShell

Source plugins can also be used directly, which is handy for testing a document before wiring it into a workflow:

```powershell
$plugin = [sourcePluginFactory]::GetPlugin('yamlSource', './sections/enroll-device.yaml')
$config = $plugin.Load()
```

`GetPlugin` throws if the name isn't registered. `Load()` only reads and validates the document once; later calls return
the same loaded object. Note that these classes are internal, so import the module with `Using Module` (as the tests do)
to reach them.
