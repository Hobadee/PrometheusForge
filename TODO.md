# TODO
This document serves as a list of things that we need or want to be completed at some point.  Eventually this will move to GitHub issues or similar
but during heavy dev it's helpful to have a scratchpad on the local machine.

## Lazy Loading
Switch everything to lazy loading.  Possibly split validation into 2 parts - light validation that is done at load-time, and deep validation done at runtime.

Perhaps some way of validating before variables are expanded, since that's the
main reason we can't validate at load right now?

## Variable Checking
Variable names MUST adhere to the same REGEX as slugs, otherwise we won't be able to resolve results.  Add appropriate checks and minimize code duplication.

(Create a static "slug" class that does the check?)


## Asana Task Plugin
Later Asana plugin functions *MAY* need OAuth.  Investigate and implement if needed


## StepTree Metrics
StepTree should store it's metrics, (pass/fail minimum - maybe timing and other?) then pass itself as an object back upstream so we can generate a report at the end.


## Logging Class
Implemented the terminal-only MVP `Log` singleton and `LogLevel` enum. All `TextOutput` output now passes through the logger and is prefixed with its level. The logger can enable or disable terminal output; file and other sinks remain future work.

Reason for being a singleton is that when writing files or other log locations, we want things to remain ordered properly, and only have a single file handle open if required.

The logger should take configuration to be able to output to terminal, file, or other sinks.  (MVP will just be terminal output - we'll handle other outputs later)

Possibly implement sinks as plugins?

Create LogEntry class and store each entry there with timestamp, facility, message, trace, and other metrics, allowing us to replay, filter, or bulk flush logs to a sink later

### Complicating issue:
How do we set a log location?  We can make the plugin a singleton, but how is
the config passed to it initally?  Passing via normal plugin config args has
1 of 2 issues; Either you need to pass an idential config every time (even if
just via templates) or you have the possibility that you add an earlier step
before the config is initialized.

Best bet is to probably store config in a variable, but this seems a little odd
as well.  Think about this some.


## Forge API permission settings
Plugins should declare which `ForgeApi` categories they actually use (e.g. via a new `Apis`/`RequiredApis` key in `PluginInfo()`). Calls to an API category a plugin did not declare should fail (e.g. `ForgeApi` only populates/exposes declared sub-APIs, or each sub-API checks a declared-capabilities set before executing). Not implemented yet — `ForgeApi`/`ForgeVariableApi`/`ForgeConfigurationApi` currently grant full access to every injected plugin.


## Step replacement overlays
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


## Step names
To ensure name uniqueness, we could auto-build names based on
hirearchy, so YAML authors don't need to worry about the entire project but
rather just their section.

This isn't a terrible idea, but would make result resolution extremely difficult
We would likely need to go back to the old model of explicitely registering results
which I want to avoid because a significant number of results need to be registered;
better to auto-register everything and you can grab whenever

This adds significant work for the YAML author to ensure no duplicates, but deal
with it for now.


## Template late-binding
I can't think of any situation where templates would benefit from early binding.
We should convert calls to templatization to late-binding, as that will solve
the near universal binding errors when templates are early-bound.

This may have the follow-on effect of requiring all items to be late-binding
and not allowing any instances of early-binding.  Investigate.

(We do still want early-binding ideally as it allows for sytax checks
before processing begins)


## Advanced Templating system
The project has a working MVP for variable substitution, but the remaining work is the broader runtime surface area that still needs deliberate design and coverage.

Remaining scope:
- `when` expression templating/evaluation
- recursive expansion in nested parameter objects and arrays
- templating for tags, plugin selection, retry settings, and file-loading scenarios
- advanced template functions such as conditionals and loops

Notes:
- Current coverage is focused on direct variable resolution from `Variables`, including nested keys such as `{{ a.b.c }}`.
- The next phase should be driven by concrete runtime use cases rather than broad feature expansion without a clear contract.


## Step addon overlays
The basic YAML-import flow is working, but the remaining design questions are about insertion semantics and long-term behavior rather than the parser itself.

Ideally, we should be able to eventually complete all the following types of overlays:
- Step -> Step
- Section -> Section
- Step -> Section
- Section -> Step

The first 2 should be fairly easy.  Polymorphic overlays will be more difficult.

Remaining work:
- define how imported steps/sections are inserted into the current `StepTree` location
- decide how future non-YAML sources should behave in the same pipeline
- make a deliberate decision about relative import resolution before adding it, rather than inferring a hidden rule from current execution location
- implement optional lazy-loading so filename variables set via function return can resolve

Current state:
- YAML imports are supported through `SourceFactory`, source plugins, and `StepTree` construction.
- Plugin-requested child insertion is supported through `ForgeConfigurationApi.Insert()` and currently adds children beneath the executing tree node.
- The remaining issue is defining a broader insertion contract for future overlay and non-YAML scenarios.


## Issues with AI builds
AI appears to have issues building/loading the module. The remaining work is to investigate the failure mode, reproduce it reliably, and correct the build or module-loading path so automation can run consistently.

This is still a known gap and should be treated as a reliability issue rather than a completed task.

I asked it to fix itself, and it did a few changes to copilot-instructions, but
there may still be issues.  Low priority unless we see this happening more.


## Issues with AI `git`
AI can't find `git` in it's environment.  Figure out what's going on and fix.


## Template Variables
Passing a `Variables` object directly to the template engine feels wrong
somehow.  Leaving it for now so we can get to MVP, but this likely needs to be
refactored and some better, more stable, means of communication between the two
needs to be devised.  Read up on my GOF patterns and see what can be put in
place here.

This is a VERY LOW priority.


## Place Finding
Stretch goal - steps should be able to find where they are in the hirearchy,
drilling down and getting a list of all parents.  This can help for nesting
into their parent objects when doing something, for example, a child grabbing
it's parents return ID and using that to nest itself when it creates itself in
some external system.

This is a VERY LOW priority.


## Section data as Steps
As noted elsewhere, conditionals and tags should move into [Step] objects and be tracked via [Steps].  The logical following is that
each [StepTree] object should also contain a matching entry in [Steps].  We can then easily update conditionals/tags on inserts/overrides.

Additionally we can store return information in the StepTree's [Step] object.  Not sure how we would best access this later, but we could!


## Functions to get step return data
Just like we will be able to pull the logs singleton after a run, we should be able to pull the [Steps] singleton after a run to get result data.

Not sure the best interface for this.


# Cleanup Items

## Test Coverage
Human-verify all test coverage.  It was AI generated; hopefully we aren't validating failures, but we don't know until a human verifies all the tests.

## Consistent throws/errors
Ensure everything errors out or throws consistently.  For example, we shouldn't
null return on invalid input in one place, but throw in another

## Appropriate error handling
Ensure everywhere that can throw, is either caught properly and handled
elsewhere, or SHOULD fall through to a fatal user-facing error.


# Known-Issues

## Retries
Bug in Abort/Retry/Fail code.  Abort doesn't actually abort the entire run.  (It should)
