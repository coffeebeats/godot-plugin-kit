---
name: run-game
description: Launch this Godot project and drive the running game from the command line — screenshots, scene tree, expression eval, the game's log. Use to confirm a change actually works on screen, or to inspect what a live game is doing; files, the checker and GUT cover everything judgeable without a process.
user-invocable: true
argument-hint: "[what to check]"
---

Drive a live game through `godot-bridge`. Every subcommand talks to kit's debug bridge (`addons/kit/system/debug/editor/bridge.gd`) over loopback TCP.

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
godot-bridge status                      # frame, current screen, reporting nodes
godot-bridge tree --path Main            # names, classes, visibility, control rects
godot-bridge eval 'Main.screens().get_depth()'
godot-bridge state                       # what every reporting node says
godot-bridge state --filter Map          # one node, by name at any depth; repeatable
godot-bridge screenshot --out shot.png   # a real frame; --node crops to one Control
godot-bridge logs                        # what the game printed, errors included
godot-bridge wait --for booted           # poll a field; --equals takes JSON
godot-bridge stop
```

`godot-bridge` is on `PATH` in Claude Code, which puts this plugin's `bin/` there. Where
it is not, run the bridge itself, at a path relative to this skill's directory:

```sh
python3 ../../bridge/bridge.py launch
```

`launch --scene <path>` runs one scene instead of the main scene; `--until` / `--equals` / `--timeout` change what its built-in wait accepts. `--port` (default 9080) goes **before** the subcommand and selects the instance, so several games can run at once.

Always `stop` when finished. A game left running holds the port, and the next `launch` has to reap it.

View the screenshot it writes. It is a real captured frame, so it settles what the window actually shows.

## Traps

Each of these returns a plausible wrong answer rather than an error.

- **Nothing listens without a port.** The node is mounted by an `StdConditionLoader` on `OS.has_feature("editor")`, and the bridge is excluded from every export, so only an editor run has one at all — and it opens no socket until it is handed `--bridge-port <N>` after `--` (or `GODOT_DEBUG_BRIDGE_PORT` for editor runs). `launch` does this for you; an F5, a GUT run and a headless CI run do not. An exported build cannot be driven at all.
- **"Settled" is not "booted".** Each splash screen is a genuine settled state. Wait for `booted`, which excludes splash and loading, or you will assert against a scene that is ignoring you.
- **`Expression` resolves no autoloads, no global classes and no engine singletons.** `eval` binds the identifiers it recognises; a name it does not know fails with `Invalid named index`. `ResourceLoader` and `OS` read like built-ins and are not.
- **Node paths are relative to `/root`** — `--path Main`, never `--path /root/Main`. A POSIX-emulating shell on Windows rewrites the absolute form into a Windows path before the tool sees it.
- **A wait only counts what the game logged after that wait began**, and `launch` truncates the log. `logs` after a `stop` can end on `Stray Node: …`; that is the project's own shutdown diagnostic, not a failure.
- **`Input.action_press` raises no event**, so nothing built on `_input` sees it. Fire actions with `StdInputEvent.trigger_action` — see the Pitfalls section of AGENTS.md.
- **A sandboxed harness cannot write `user://`.** Settings and saves the game writes are dropped, so a run that looks clean persists nothing. Reads still work, so existing saves load and only the writes go missing. Grant the game's user directory, `OS.get_user_data_dir()`, to persist anything; under Codex that is `--add-dir <dir>` or `sandbox_workspace_write.writable_roots` in `.codex/config.toml`.

## Reaching game state

The bridge knows sockets, `Expression`, the tree and the viewport, and nothing about screens, maps or a simulation. A node becomes visible to `state` by defining one method:

```gdscript
func _get_debug_state() -> Dictionary:
	return {&"trauma": _trauma, &"offset": _read_offset()}
```

Nothing is registered and the file names no part of the bridge, which is what lets a game exclude the bridge outright. `state` walks the tree and keys each answer by the reporting node's path, so two maps are both reported rather than one shadowing the other. `godot-bridge reporters` lists which nodes answer, without asking any of them for state.

`--filter` takes a glob over the whole node path and may be repeated, keeping the union. `*` crosses `/`; a filter with no wildcard and no `/` matches that node name at any depth. `wait --for [<node glob>:]<field>` polls one field out of those reports, and naming the node is needed only when two of them report the same field.

`KitMap`, `KitFeelLayer` and `KitHudLayer` all report, so every inherited scene gets those free, and a game typically adds its own `main.gd`. If a check needs state no node reports, add the method to the node that owns the state rather than building an elaborate `eval`.

## The rest

`../../bridge/README.md`, relative to this skill's directory, carries the gating detail and the engine behavior the bridge is shaped around. Read it when something behaves unexpectedly, not before.
