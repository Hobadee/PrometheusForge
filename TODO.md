# TODO
This document serves as a list of things that we need or want to be completed at some point.
This has largely moved to GitHub issues, but some less well-defined items will live here for now.
Additionally, this will still serve as a scratchpad on the local machine during heavier development.


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

Polymorphic overlay replacement (Step->Step, Section->Section, Step->Section) is DONE.
Section->Step needs a workaround, not a direct path - see `README.md` ("Insert vs. Overlay") for
what's supported and why. Open decision: whether to relax the `type: step` guard so it can replace
a section directly instead of needing that workaround (see `PROJECT_STATUS.md` Open Questions) - low priority.

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


## Fix Conditional Tags
IncludeTags should run IF AND ONLY IF the tag is included - skip run if tag is NOT included!
If both include and exclude, still take priority variable


## Section data as Steps
As noted elsewhere, conditionals and tags should move into [Step] objects and be tracked via [Steps].  The logical following is that
each [StepTree] object should also contain a matching entry in [Steps].  We can then easily update conditionals/tags on inserts/overlays.

Additionally we can store return information in the StepTree's [Step] object.  Not sure how we would best access this later, but we could!
