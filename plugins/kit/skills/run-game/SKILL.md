---
name: run-game
description: Launch this Godot project and drive the running game from the command line — screenshots, scene tree, expression eval, the game's log. Use to confirm a change actually works on screen, or to inspect what a live game is doing; files, the checker and GUT cover everything judgeable without a process.
user-invocable: true
argument-hint: "[what to check]"
---

Drive a live game through `godot-bridge`. Every subcommand talks to kit's debug bridge (`addons/kit/system/debug/debug.gd`) over loopback TCP.

`launch` runs the scene named by `run/main_scene` in `project.godot` unless `--scene` says otherwise.

## When to use something else

The checker and GUT are faster and need no window, so reach for the bridge only when the question is about a live process:

| Question | Use |
| --- | --- |
| Does this file parse, is a `uid` missing, does a `NodePath` export resolve | `godot-check` |
| Does this logic hold | GUT — see the test command in AGENTS.md |
| Does the app boot at all | `godot --headless --quit-after 30` |
| What is on screen, what is in the tree right now, what did it just log | this skill |

## The loop

```sh
godot-bridge launch                      # start, and wait until past splash and loading
godot-bridge status                      # frame, current screen, registered handlers
godot-bridge tree --path Main            # names, classes, visibility, control rects
godot-bridge eval 'Main.screens().get_depth()'
godot-bridge call app                    # a handler the running scene registered
godot-bridge screenshot --out shot.png   # a real frame; --node crops to one Control
godot-bridge logs                        # what the game printed, errors included
godot-bridge wait --for app.booted       # poll a handler; --equals takes JSON
godot-bridge stop
```

`launch --scene <path>` runs one scene instead of the main scene; `--until` / `--equals` / `--timeout` change what its built-in wait accepts. `--port` (default 9080) goes **before** the subcommand and selects the instance, so several games can run at once.

Always `stop` when finished. A game left running holds the port, and the next `launch` has to reap it.

Read a screenshot back with the Read tool. It is a real captured frame, so it settles what the window actually shows.

## Traps

Each of these returns a plausible wrong answer rather than an error.

- **Nothing listens without a port.** The node is mounted by an `StdConditionLoader` on `OS.has_feature("debug")`, so a release export carries no bridge at all, and even a debug build opens no socket until it is handed `--bridge-port <N>` after `--` (or `GODOT_DEBUG_BRIDGE_PORT` for editor runs). `launch` does this for you; an F5, a GUT run and a headless CI run do not.
- **"Settled" is not "booted".** Each splash screen is a genuine settled state. Wait for `app.booted`, which excludes splash and loading, or you will assert against a scene that is ignoring you.
- **`Expression` resolves no autoloads, no global classes and no engine singletons.** `eval` binds the identifiers it recognises; a name it does not know fails with `Invalid named index`. `ResourceLoader` and `OS` read like built-ins and are not.
- **Node paths are relative to `/root`** — `--path Main`, never `--path /root/Main`. An MSYS shell rewrites the absolute form into a Windows path before the tool sees it.
- **A wait only counts what the game logged after that wait began**, and `launch` truncates the log. `logs` after a `stop` can end on `Stray Node: …`; that is the project's own shutdown diagnostic, not a failure.
- **`Input.action_press` raises no event**, so nothing built on `_input` sees it. Fire actions with `StdInputEvent.trigger_action` — see the Pitfalls section of AGENTS.md.

## Reaching game state

The bridge knows sockets, `Expression`, the tree and the viewport, and nothing about screens, maps or a simulation. Those register handlers:

```gdscript
const Debug := preload("res://addons/kit/system/debug/debug.gd")

Debug.register(&"map", _get_debug_state)      # in _ready
Debug.unregister(&"map", _get_debug_state)    # in _exit_tree, with the same handler
```

Both are safe with no bridge present. A game built from the template registers `app` from its own `main.gd`, and `map` comes from `KitMap`, so every inherited map gets it free. `godot-bridge commands` lists what the running game has.

If a check needs state no handler exposes, add a handler rather than building an elaborate `eval`.

## The rest

The plugin's `bridge/README.md` carries the gating detail, the engine behavior the bridge is shaped around, and the Windows-shell trap (MSYS rewrites an argument that looks like an absolute Unix path, so node paths are relative to `/root`). Read it when something behaves unexpectedly, not before.
