# godot-plugin-kit

Opinionated Godot game infrastructure, assembled from 'std'.

## Usage

### Add as a dependency

Add this repository's `dist` branch as a submodule of a Godot project, typically under the `addons` directory:

```sh
git submodule add -b dist https://github.com/coffeebeats/godot-plugin-kit addons/kit
```

Each release is a commit on `dist`, tagged `dist/vX.Y.Z`. Versions follow semantic versioning independently of Godot; raising the minimum Godot version is a major release.

[`godot-project-template`](https://github.com/coffeebeats/godot-project-template) is a game built this way, and every step below is wired up there.

### Register the autoloads

Kit ships no autoloads. Register these three in `project.godot`:

- `Platform`, a scene instancing the `platform/` scenes.
- `System`, a scene instancing the `system/` scenes. The game's own values are set on its instances.
- `Lifecycle`, the script `addons/kit/system/lifecycle.gd`. Kit's pause menu reaches it by this name, and a game saves its progress on `Lifecycle.shutdown_requested`.

Register `Platform` before `System`: the modules in `System` require the profile, and fail to load if it has not loaded first.

### Copy the assemblies

`premade/platform.tscn` and `premade/system.tscn` are ready-made `Platform` and `System` scenes, each instancing every scene under its tree. Copy both into the game, give each copy a new `uid` in its header, and register the copies as the autoloads above. The game owns the copies from then on, while the scenes they instance keep arriving with the submodule. `platform.tscn` needs no changes. `system.tscn` leaves every export in the table below unset, so set the ones the game needs and delete the nodes it does not; `Saves` fails to load until it has a `schema`. Instancing the scenes into autoloads of your own works just as well.

### Set the game's values

Each value the game owns is an export on a scene instanced in `System`:

| Scene | Export | Value |
| --- | --- | --- |
| `system/input/input.tscn` | `action_sets` | The game's action sets, which the settings menu lists for rebinding. |
| `system/setting/settings.tscn` | `menu_tabs` | The game's own settings menu tabs, keyed by their label's message ID. |
| `system/setting/interface/font_scaling_observer.tscn` | `theme` | The font theme which the text scaling setting resizes. |
| `system/save/saves.tscn` | `schema` | The game's save data, required. |
| `system/save/saves.tscn` | `slot_count` | The number of save slots, each shown in the save menu. |

Two values are set from code instead, since no export in `System` can reach or hold them:

- `KitSystems.audio().screens`, the game's `StdScreenManager`, which ducks the mix under covering screens.
- `KitPauseMenu.return_to_main_menu`, the game's way back to its main menu. The pause menu offers returning only once it is set.

A build tagged `storefront:steam` loads the Steam storefront, profile and input, and every other build loads the default ones. An export preset sets the tag in `custom_features`, and an editor run in *Debug > Customize Run Instances*.

### Check that the modules loaded

The scenes the game depends on to boot are modules: `storefront` and `profile` in `Platform`, and `input`, `settings`, `audio` and `saves` in `System`. Each extends `KitModule` and reports once whether it loaded, logging `Loaded kit module. module=<id>` at `INFO` when it does — one line per module, which a boot check can require.

A module fails when it finds no implementation or more than one, when its configuration is missing, when a module it requires has not loaded by the time its `_ready` runs, or when its `_ready` returns without reporting, as one cut short by a script error does. It logs `Kit module failed to load.` and nothing more, because only the game knows which modules it can run without. A module reports only on its own code, so a storefront whose client is not running raises its own error and still loads.

Check the modules from the main scene's `_ready`, once the autoloads are ready. `KitModule.get_module_ids()` lists every module that registered, and `KitModule.get_status(id)` says whether one is loading, loaded or failed. A game that needs every module can enqueue a critical `KitError` with its own title and message for the first failure, and let its boot drain show it. Code that uses a single module checks it with `KitModule.is_loaded(id)`.

`saves` loads its slots on a worker thread and reports once they finish, so it is usually still loading when the main scene checks. Before showing anything that reads the save slots, check `are_slots_loaded()` and otherwise wait for `slots_loaded`.

The game's own nodes become modules the same way: extend `KitModule`, override `_get_module_id` and, if the module requires others, `_get_module_requires`, then call `_report_loaded()` or `_report_failed(reason)` once by the end of `_ready`. A module that finishes loading later, as `saves` does, overrides `_is_module_async` to return `true` and reports when it is done. A node that must extend another class can own a child of that class instead, as the audio system owns its `StdSoundEventPlayer`. When a module's implementation varies by build, give the implementations a base script that joins a group, and have the node that registered look the implementation up there before it reports. A scene whose script failed to load is still added to the tree, but it never joins the group.

### Use the menus

Each menu is a finished screen, used in place:

- **Settings:** push `menu/settings/screen.tres`, or list `menu/settings/pusher.tscn` in a screen's `attachment_scenes` to open it on `ui_toggle_menu`.
- **Save slots:** push `menu/save/screen.tres` and await its `popped` signal, which carries the chosen slot's index.
- **Pause:** list `menu/pause/pusher.tscn` in a gameplay screen's `attachment_scenes`.
- **Splash:** push `ui/splash/godot_screen.tres`, whose scene emits `advanced` once it is done. `ui/splash/splash.gd` makes a splash of any scene.

For a different layout, assemble a menu from the scenes it is made of: the settings tabs and their `group` and `setting` rows, the controls tab's `action_set` groups, the save menu's `slot_button`, and the dialogs in `ui/menu/`.

### Configure the project

Kit's scenes also read these project settings:

| Setting | Requirement |
| --- | --- |
| `[input]` | Defines `ui_tab_next`, `ui_tab_prev`, `ui_binding_stop` and `ui_toggle_menu`, which kit's menus name and Godot does not define. |
| `[audio] buses/default_bus_layout` | Defines the buses `Master`, `music`, `sound_effects`, `voice`, `ui` and `game`. |
| `[gui] theme/custom` | Defines the type variations kit's scenes name: `button_dialog`, `button_menu`, `button_tab_selected`, `button_tab_unselected`, `hud_bar`, `hud_bar_ghost`, `hud_number`, `hud_number_crit`, `menu_body` and `panel_dialog`. |
| `[internationalization] locale/translations` | Lists every `addons/kit/locale/*.mo`, after the game's own catalogue, so a message the game defines overrides kit's. |

### Drive a running game

`system/debug/editor/bridge.tscn` is a development-only bridge which lets an external process inspect and drive the game — the scene tree, an evaluated expression, a screenshot, or the state the running scene's nodes report. It is what the `run-game` skill below talks to.

Wire it under the game's `System` scene through an `StdConditionLoader` whose `expressions_allow` holds kit's `system/debug/editor_run_expression.tres`, which allows it only in an editor run. The bridge lives in `system/debug/editor/`, so a game that excludes `*/editor/*` from its export presets ships none of it, and nothing a game ships names any part of it. It then listens only when handed a port, either `--bridge-port <N>` after `--` or `GODOT_DEBUG_BRIDGE_PORT` for editor runs, and binds `127.0.0.1` and nothing else. An ordinary F5, a GUT run and a headless CI run open no socket at all.

Game code becomes visible to it by defining `_get_debug_state() -> Dictionary` on a node; the bridge finds it by walking the tree, so the method needs no registration, and in a shipped build it has no caller.

## **Agent plugin**

This repository is also a plugin marketplace holding one plugin, [`kit`](./plugins/kit). [Claude Code](https://code.claude.com/docs/en/plugin-marketplaces) and Codex both read it, from the same `.claude-plugin/` files. Nothing is published anywhere; a repository references it by GitHub path. The plugin carries the skills that describe this addon:

- `add-setting`, `add-save-field`, `add-input-action`, `add-sound` and `add-translation`, which extend a game built on kit. Each reads what the game owns out of its `project.godot` rather than assuming a layout.
- `add-entity-hud` and `add-hud-element`, for the HUD.
- `run-game`, and the `godot-bridge` it drives a live game with, through the debug bridge above.

A repository enables the plugin in its `.claude/settings.json`, beside `godot-infra`'s:

```json
{
  "extraKnownMarketplaces": {
    "godot-plugin-kit": {
      "source": { "source": "github", "repo": "coffeebeats/godot-plugin-kit", "ref": "v1" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "kit@godot-plugin-kit": true }
}
```

Each machine installs it once, after trusting the repository folder:

```sh
claude plugin install kit@godot-plugin-kit --scope project
```

The plugin declares no `version`, so each commit is its version, and it follows the floating major tag: a release moves `v1`, and Claude Code picks the update up in the background. The skills and the gitlink therefore agree at the major, which is the level a skill's claims hold at.

The marketplace ref and the install are per machine and per repository path. The "Agent plugin" section of [godot-infra's README](https://github.com/coffeebeats/godot-infra#agent-plugin) says what to do when the hook or `godot-bridge` goes missing. A major release of this plugin moves the ref, so every machine re-adds the marketplace at the ref in the repository's `.claude/settings.json`.

The marketplace is served from `main`, never from `dist`. `dist` carries the addon subtree for the engine to consume, and `package-addon` copies with a bare glob, so `.claude-plugin/` cannot reach it and `plugins/` is excluded by name.

### Codex

A repository declares the same marketplace in its `.codex/config.toml`, which Codex reads once the project folder is trusted:

```toml
[marketplaces.godot-plugin-kit]
source_type = "git"
source = "https://github.com/coffeebeats/godot-plugin-kit.git"
ref = "v1"

[plugins."kit@godot-plugin-kit"]
enabled = true
```

A machine without that file gets the same result from `codex plugin marketplace add coffeebeats/godot-plugin-kit --ref v1` and `codex plugin add kit@godot-plugin-kit`.

Codex puts nothing from the plugin on `PATH`, so `godot-bridge` is run there through `python3`, at a path built from the skill directory the harness names; the `run-game` skill carries that form. The skills that call `godot-check` and `godot-locale` name the `godot` plugin's skills of those names for the same reason.

## **Development**

### Setup

The following instructions outline how to get the project set up for local development:

1. Clone this repository using the `--recurse-submodules` flag, ensuring all submodules are initialized. Alternatively, run `git submodule sync` to update all submodules to latest.
2. [Follow the instructions](https://github.com/coffeebeats/gdenv/blob/main/docs/installation.md) to install `gdenv`. Then, install the [pinned version of Godot](./.godot-version) with `gdenv i`.
3. [Install `uv`](https://docs.astral.sh/uv/getting-started/installation/), then run `uv sync`. That installs the Python tooling from [`uv.lock`](./uv.lock), and downloads the interpreter named by [`.python-version`](./.python-version) if the machine has none. Invoke each tool as `uv run <tool>`.
4. The edit checks and `godot-check` come from the `godot` agent plugin, declared in [`.claude/settings.json`](./.claude/settings.json) for Claude Code and [`.codex/config.toml`](./.codex/config.toml) for Codex. Claude Code installs it once per machine with `claude plugin install godot@godot-infra --scope project`. Codex installs it itself once the folder is trusted, then asks you to trust the edit hook in `/hooks`, and asks again whenever that hook changes. If the hook or `godot-check` goes missing, see the "Agent plugin" section of [godot-infra's README](https://github.com/coffeebeats/godot-infra#agent-plugin).

### Code submission

When submitting code for review, ensure the following requirements are met:

1. The project adheres as closely as possible to the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

2. The project is correctly formatted using [gdformat](https://github.com/Scony/godot-gdscript-toolkit/wiki/4.-Formatter):

    ```sh
    uv run gdformat --check .
    ```

3. All [gdlint](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) linter warnings are addressed:

    ```sh
    uv run gdlint .
    ```

4. All [Gut](https://github.com/bitwes/Gut) unit tests pass:

    ```sh
    godot \
        --headless \
        -s addons/gut/gut_cmdln.gd \
        -gdir="res://" \
        -ginclude_subdirs \
        -gprefix="" \
        -gsuffix="_test.gd" \
        -gexit
    ```

## **Releasing**

[Semantic Versioning](http://semver.org/) is used for versioning and [Conventional Commits](https://www.conventionalcommits.org/) is used for commit messages. A [release-please](https://github.com/googleapis/release-please) integration via [GitHub Actions](https://github.com/googleapis/release-please-action) automates releases.

### Secrets

The default GitHub actions and workflows read the following repository secrets:

- `GHA_TOKEN` - If desired, create a PAT for GitHub actions to use when checking a project; allows fix-formatting commits to trigger actions.
- `RELEASE_PLEASE_TOKEN` - Enables release pull requests to run CI/CD workflows.

## **Version history**

See [CHANGELOG.md](https://github.com/coffeebeats/godot-plugin-kit/blob/main/CHANGELOG.md).

## **License**

[MIT License](https://github.com/coffeebeats/godot-plugin-kit/blob/main/LICENSE)
