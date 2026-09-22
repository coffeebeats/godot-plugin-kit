# The debug bridge

Inspects and drives a game that is already running. Files, the checker and GUT cover
everything that can be judged without a live process; this covers what is on screen,
what the scene tree looks like right now, and what the game just logged.

```sh
godot-bridge launch                       # start the game, wait until it is usable
godot-bridge status                       # frame, current scene, reporting nodes
godot-bridge tree --path Main             # names, classes, visibility, control rects
godot-bridge eval 'Main.screens().get_depth()'
godot-bridge state                        # what every reporting node says
godot-bridge state --filter Map           # one node, by name at any depth
godot-bridge reporters                    # which nodes report, without asking
godot-bridge screenshot --out shot.png    # or --node <path> to crop to one control
godot-bridge logs                         # what the game printed
godot-bridge wait --for booted            # poll until a node reports ready
godot-bridge stop
```

`--port` (default 9080) selects the instance, so several games can run at once, and it
goes before the subcommand. The standard library is the only requirement beyond the
interpreter, and none of this ever runs in CI.

`bridge/bridge.py` holds the client; `bin/godot-bridge` runs it, supplying an
interpreter.

Node paths for `tree --path` and `screenshot --node` are relative to `/root`, so it is
`--path Main`, not `--path /root/Main`. Prefer the relative form everywhere: a
POSIX-emulating shell on Windows rewrites a leading `/` into one of its own directories
before the tool ever sees the argument.

### Gating

Three independent gates, because the bridge evaluates arbitrary expressions on request:

1. Nothing a game ships depends on the bridge. It lives in
   `addons/kit/system/debug/editor/`, which a game excludes from its export presets
   with `*/editor/*`, and the pack holds neither the script nor its scene. A reporting
   node does ship its `_get_debug_state` method, but the method names nothing in that
   directory, so no shipped file pins a bridge file into the pack.
2. The game mounts it through an `StdConditionLoader` whose expression
   is `editor_run_expression.tres` (`OS.has_feature("editor")`), so only an editor run
   places the node. The same mechanism gates the Steam storefront in
   `addons/kit/platform/storefront/storefront.tscn`. The loader names its scene by uid
   and loads it on demand, which is why excluding the file costs a game nothing.
3. The node listens only when handed a port, either `--bridge-port <N>` after `--` or
   `GODOT_DEBUG_BRIDGE_PORT` for editor runs, where run arguments are a per-machine
   editor setting that cannot be committed. An ordinary F5, a GUT run and a headless CI
   run therefore open no socket.

It binds `127.0.0.1` and nothing else. The first two gates are also why `godot-bridge`
drives a project through the editor binary rather than an exported build: an export has
no bridge to talk to.

### Reporting state

The bridge knows sockets, JSON, `Expression`, the scene tree and the viewport. It knows
nothing about screens, maps or a simulation. A node that wants to be visible to `state`
defines one method:

```gdscript
func _get_debug_state() -> Dictionary:
	return {&"trauma": _trauma, &"offset": _read_offset()}
```

That is the whole contract. There is nothing to register and nothing to import; the
method name is all the two sides share, which is what lets a game exclude the bridge
outright. In a shipped build the method has no caller.

A reporter node in a group would be the other way to do this, and it cannot reach what
is worth reporting. Most of that is private or computed, such as `is_hit_stopped()`, a
hit-stop deadline minus the current time, or a HUD group's anchor path, so a separate
node could only read it by making the parent's internals public. It would also put a
scene reference in every reporting scene, which is the dependency the method avoids.

`state` walks the tree, calls the method on every node defining it, and keys each
answer by that node's path. Two maps in one tree are therefore both reported, where a
registry keyed by name could hold only the last one to arrive. A node that leaves the
tree stops being reported, with nothing to clean up.

`--filter` narrows the walk and may be repeated, keeping the union. A filter is a glob
over the node's whole path, where `*` crosses `/` as it does everywhere else in the
engine; one holding no wildcard and no `/` is taken for a node name at any depth, so
`--filter Map` works without knowing where the map sits.

`KitMap`, `KitFeelLayer` and `KitHudLayer` all report, which every inherited scene
gets for free, and a game typically adds its own `main.gd` (current screen, stack
depth, save slot, and whether the app is settled and booted).

`wait --for [<node glob>:]<field>` polls those reports from the client rather than
evaluating a predicate in the engine, which keeps the bridge simple and lets a failure
in the game's log end the wait early. The node half is optional, and needed only when
two nodes report the same field; a wait that matched several is an error rather than a
silent pick.

### Engine behavior the bridge is shaped around

**`Expression` resolves no autoloads, no global classes and no engine singletons.** It
sees only what `parse(source, names)` was given, so the bridge extracts the identifiers
from the expression and binds the ones it recognises. Without that, `Main.screens()`
fails with `Invalid named index 'Main' for base type Object`. The singleton half is not
obvious, because `ResourceLoader` and `OS` read like built-ins; they are not, and
`ResourceLoader.load(...)` fails the same way until it is bound.

**A pop emits `screen_uncovered`, never `screen_entered`.** Anything tracking whether a
transition is in flight has to clear its flag on both. Clearing on `screen_entered`
alone leaves the app reporting `settled=false` forever after one push and pop, and
`wait` times out on an idle, usable game.

**"Settled" is not "booted".** Each splash screen is a genuine settled state. Sampled
through a real boot, before the menu appears:

```text
settled=False booted=False screen=res://addons/kit/ui/splash/godot_screen.tres
settled=True  booted=False screen=res://addons/kit/ui/splash/godot_screen.tres
settled=True  booted=False screen=res://project/main/splash/studio_screen.tres
settled=True  booted=True  screen=res://project/main/menu/screen.tres
```

A client that waits for "settled" acts on the splash, and reports on a scene that is
ignoring it. `Main._is_booted()` excludes the loading and splash screens, which is why
it lives in `project/` and not in kit.

**An aborted client leaves the game holding the port.** The next `listen` fails with
`Already in use` (`ERR_ALREADY_IN_USE`, error 22) and the new instance runs on with no
bridge. `launch` reaps first with a graceful `quit` over the port, then stops the pid it
recorded for that port once that pid still names a Godot process, since pids are
recycled; that also stops a recorded game that never opened its port. A port held by an
editor-launched game is reported as that rather than killed.

**`StdLogSinkGodot` drops the context dictionary for warnings and errors.** It hands
`push_warning` the message alone, so anything the reader needs has to be in the message
string. `info` and below keep their context.

**The viewport image is read after `await RenderingServer.frame_post_draw`.** This is
kept as cheap insurance rather than a demonstrated requirement: awaiting `process_frame`
instead still produced a complete frame, and toggling `ColorRect.color` across the draw
produced byte-identical images, since that setter's redraw queues for the next frame.

**A coroutine that never resumes takes its reply with it**, leaving the client waiting
on a socket nothing will ever write to. Every awaiting command carries a
`SceneTreeTimer` watchdog for that reason.

### Capturing the game's output

A detached windowed process writes its errors nowhere the caller can see, so `launch`
captures the game's output to a log beside the pid file in the OS temp directory. That
also catches what an in-engine `Logger` tap could not, including an error raised before
the bridge mounts and a crash. `logs` tails it through the same noise filter as the
`godot` agent plugin's edit hook, and `wait` scans it as it polls, so a game that dies
during boot reports

```text
bridge: the game reported an error: SCRIPT ERROR: Invalid access to property or key 'missing' on a base object of type 'Node'.
```

in a couple of seconds rather than timing out sixty seconds later.

Only `SCRIPT ERROR` and `SHADER ERROR` count. The engine labels an error `ERROR`,
`WARNING`, `SCRIPT ERROR` or `SHADER ERROR` and nothing else, and `push_error`, which the
project's logger calls to report one, prints the bare `ERROR:`. That label names the game
and the machine under it alike, and a sandboxed harness guarantees a run's worth of the
machine — an unwritable `user://`, an unreadable certificate store. Counting it failed
every `launch` under one while the game ran fine.

A game that dies is caught by its exit instead, which needs no pattern and catches a crash
that logged nothing at all. `launch` holds the process handle and sees the exit at once;
`wait` has only the port, so it asks the OS every couple of seconds. A game that survives
its own error still has to reach what the wait is for, and every way of giving up prints
the log's tail, so the line explaining a stall is in the message either way.

A wait only counts what the game logged after that wait began. The log outlives the
command that wrote to it, so scanning it whole let one stale line, such as a screenshot
written to an unwritable path an hour earlier, make every later `wait` abandon a healthy
game. `launch` truncates the log, so its own wait reads the whole run.

`wait --equals` decodes its argument as JSON when it can, so `--equals true` matches the
boolean the game reported rather than the string `True`, and `--equals` on a screen
compares against `app.screen`, which is the `StdScreen`'s `res://` path.

`stop` sends the notification a window close sends, and `Lifecycle.shutdown()` answers
it by printing `print_orphan_nodes` in an editor-feature build, so `logs` after a stop
can end on `Stray Node: …`. That is the project's own shutdown diagnostic, not a failure
of the run.
