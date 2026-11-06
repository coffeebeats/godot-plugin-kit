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
| `system/input/input.tscn` | `action_sets` | The game's action sets and its own layers, which the settings menu's Controller and Keyboard & Mouse tabs list for rebinding, leaving out those in `menu_options_layers`. On Steam builds, Steam Input also reads a controller's binding against them, so list every set and layer the game's manifest has, here or in `menu_options_layers`. |
| `system/input/input.tscn` | `menu_options_layers` | The game's layers over its own sets that carry the actions of kit's `MenuOptions` layer, such as `ui_toggle_menu`. The controls tabs show those actions in the `MenuOptions` group, one row per action, and a rebind there writes to each layer that declares the action. The group shows no other action, so put any action of the game's own in a set or layer listed in `action_sets`. List each layer here and not in `action_sets`, where the tabs would give it a group whose rebinds reach only that layer. Steam Input reads them as it does `action_sets`. |
| `system/input/input.tscn` | `glyph_sets` | The glyph sets button prompts draw from, defaulting to kit's. See [Change the button prompts](#change-the-button-prompts). |
| `system/input/input.tscn` | `unknown_glyph` | The glyph a prompt draws for a bound button with no art, defaulting to kit's "??" icon. A prompt that shows button names, as keyboard prompts do by default, shows the name instead where the button has one. Left empty, the prompt shows its label instead. |
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
- **Alerts over gameplay:** a map opens `ui/menu/alert_gameplay.tscn` for a match's result, a game over or a disconnect, as [`ui/menu/README.md`](ui/menu/README.md) describes.
- **Splash:** push `ui/splash/godot_screen.tres`, whose scene emits `advanced` once it is done. `ui/splash/splash.gd` makes a splash of any scene.

For a different layout, assemble a menu from the scenes it is made of: the settings tabs and their `group` and `setting` rows, the `controls` tab, placed once per `device_category`, with its `action_set` groups, the save menu's `slot_button`, and the dialogs in `ui/menu/`, whose [README](ui/menu/README.md) lists their values and what each one is for.

### Put UI inside gameplay

A menu screen loads kit's `Menu` set, `system/input/actions/menu.tres`, which clears every other binding and carries the `ui_*` navigation actions, and enables the layers it needs over it. Kit ships only the sets and layers its own scenes load, and each of its layers names `Menu` as its `parent`. A layer over the game's own set belongs to the game, which writes it in its own input directory, usually `project/input/actions/`, under a name of its own, since every set and layer needs a unique name.

1. Kit's pause and settings pushers open on `ui_toggle_menu`, which `menu_options.tres` carries over `Menu`. For gameplay, the game writes an options layer over its set that holds `ui_toggle_menu` and lists it in the map root's `action_set_layers`, so Escape pauses through `menu/pause/pusher.tscn`. It also lists the layer in `Input.menu_options_layers`. Bindings save under a layer's name, so that list is how a rebind in the controls tabs' `MenuOptions` group reaches the game's layer. Nothing ties the game's layer to kit's, so a kit release whose pushers expect another action names it in its release notes.
2. A menu over the world, such as a build or context menu, is a panel. Place `ui/panel/panel.tscn` in the map's `UI`, or `ui/panel/world_panel_2d.tscn` or `world_panel_3d.tscn` to follow a point in the world, put the game's buttons inside it, and open it through its `StdPanel` node or by showing it. While open, the panel keeps focus inside itself and loads kit's `Menu` set, so a rebind in the controls tabs' `Menu` group reaches it; the set before it comes back once it closes. Whatever stays live while it's open goes in a layer of the game's own with `Menu` as `parent`, listed in its loader's `action_set_layers` and in `Input.action_sets`. An action that does something only while the panel is open, such as a build menu's item keys, lives only in that layer, so it has one binding. A panel has no scrim; a menu that wants one is a screen.
3. A button that doubles a bindable action, such as a build or a wave start, takes a `FocusHandler` and a `StdInputActionTrigger`; any other button connects `pressed`. The handler the action reaches validates it, since a key gets there whether or not the button is enabled.
4. A screen with a text field lists the `ui_text_*` actions in a layer of its own.

A panel's values are exports on its child nodes, which *Editable Children* on its instance shows:

| Node | Export | Value |
| --- | --- | --- |
| `StdPanel` | `transition` | How the panel opens and closes, or `transition_open` and `transition_close` for each. Without one it opens and closes instantly. |
| `StdPanel` | `close_actions` | The actions that close it, `ui_cancel` by default. |
| `StdPanel` | `click_outside_to_close` | The mouse buttons whose press outside it closes it, the left one by default. The press still reaches what it lands on, so a HUD button beside the panel closes it and is pressed. |
| `StdPanel` | `close_on_hide`, `open_on_show`, `close_when_covered` | Hiding the panel closes it and showing it opens it, both on by default. A screen covering the map closes it only with `close_when_covered`. |
| `StdPanel` | `sound_open`, `sound_close` | The sounds it plays as it opens and closes, none by default. |
| `StdInputActionSetLoader` | `action_set_layers` | The game's layers over `Menu` holding what stays live. |
| `WorldTracker2D`, `WorldTracker3D` | `map`, `target` | The map, and the node in its world the panel follows. Until `target` is set, the panel stays where it is. An open panel follows its target off-screen and stays open; to close it instead, connect the tracker's `target_exited_view` to `StdPanel`'s `close`. |
| `WorldTracker2D`, `WorldTracker3D` | `offset`, `flip_at_edges`, `viewport_margin` | Where the panel sits from its target. With `flip_at_edges` on, the default, it moves to the target's far side rather than cross the screen's edge, staying `viewport_margin` inside it. |

### Change the button prompts

A prompt draws an origin from the first set in `Input.glyph_sets` that matches the device and has art for it, moving on to the next matching set when one has none. To change part of a family, put a set with only that art ahead of kit's, such as one Xbox button. Kit's own families layer the same way, with `xbox_one.tres` holding only View ahead of `xbox.tres`, and `playstation_4.tres` only Share ahead of `playstation.tres`. To change all of them, replace the list, keeping those two ahead of their families. Kit's art comes from the CC0 pack named in `system/input/unknown/glyphs/SOURCE.md`, which has matching art for most pads. On Steam builds the sets draw the keyboard and any pad Steam Input isn't driving, and Steam draws its own art for the rest. A bound button with no art in any matching set, or with no image in Steam, draws `Input.unknown_glyph`, unless the prompt shows button names and the button has one.

Kit draws every key the same way, from one keycap resource, `system/input/unknown/glyphs/keyboard.tres`:

- Every key gets the same cap. Its height follows the prompt, so a key matches the pad glyph beside it. Its width grows with the label, from a square at `min_width`.
- A printable key shows its label in the player's keyboard layout. A named key shows the abbreviation in `labels`, such as Esc or PgDn, and the arrows show the icons in `icons`.
- Keys are drawn in the set's `font`. Left empty, that is Godot's fallback font, which `gui/theme/custom_font` replaces and a project theme doesn't, so a game whose font lives only in its theme sets `font` here.

For its own look, a game saves a copy of `keyboard.tres`, edits its `cap`, `font`, `font_size`, `color`, `padding` and `min_width`, and lists the copy in place of kit's. `min_width` equals the natural height of a key, which is a line of the label plus twice the vertical padding, so change it along with the font or padding to keep single keys square. Kit's value fits Godot's built-in font at the default `font_size` and `padding`, so a game that sets `gui/theme/custom_font` recomputes it too.

One cap serves the whole game. The settings menu's binding rows show labelled keys as plain text in the theme's font instead, and only their arrows keep the cap.

### Configure the project

Kit's scenes also read these project settings:

| Setting | Requirement |
| --- | --- |
| `[input]` | Defines `ui_tab_next`, `ui_tab_prev`, `ui_binding_stop` and `ui_toggle_menu`, which kit's menus name and Godot does not define. |
| `[audio] buses/default_bus_layout` | Defines the buses `Master`, `music`, `sound_effects`, `voice`, `ui` and `game`. |
| `[gui] theme/custom` | Defines the type variations kit's scenes name: `button_dialog`, `button_menu`, `button_tab_selected`, `button_tab_unselected`, `hud_bar`, `hud_bar_ghost`, `hud_number`, `hud_number_crit`, `menu_body` and `panel_dialog`. |
| `[internationalization] locale/translations` | Lists every `addons/kit/locale/*.mo`, after the game's own catalogue, so a message the game defines overrides kit's. |

### Drive a running game

`system/debug/editor/bridge.tscn` is a development-only bridge which lets an external process inspect and drive the game — the scene tree, an evaluated expression, a screenshot, the state the running scene's nodes report, or an action press or click sent through `Input`. It is what the `run-game` skill below talks to.

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
      "source": { "source": "github", "repo": "coffeebeats/godot-plugin-kit", "ref": "v3" },
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

The plugin declares no `version`, so each commit is its version, and it follows the floating major tag: a release moves `v3`, and Claude Code picks the update up in the background. The skills and the gitlink therefore agree at the major, which is the level a skill's claims hold at.

The marketplace ref and the install are per machine and per repository path. The "Agent plugin" section of [godot-infra's README](https://github.com/coffeebeats/godot-infra#agent-plugin) says what to do when the hook or `godot-bridge` goes missing. A major release of this plugin moves the ref, so every machine re-adds the marketplace at the ref in the repository's `.claude/settings.json`.

The marketplace is served from `main`, never from `dist`. `dist` carries the addon subtree for the engine to consume, and `package-addon` copies with a bare glob, so `.claude-plugin/` cannot reach it and `plugins/` is excluded by name.

### Codex

A repository declares the same marketplace in its `.codex/config.toml`, which Codex reads once the project folder is trusted:

```toml
[marketplaces.godot-plugin-kit]
source_type = "git"
source = "https://github.com/coffeebeats/godot-plugin-kit.git"
ref = "v3"

[plugins."kit@godot-plugin-kit"]
enabled = true
```

A machine without that file gets the same result from `codex plugin marketplace add coffeebeats/godot-plugin-kit --ref v3` and `codex plugin add kit@godot-plugin-kit`.

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
