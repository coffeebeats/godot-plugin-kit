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

- `Platform`, a scene composing the `platform/` bricks. Kit's scripts reach it by this name.
- `System`, a scene composing the `system/` bricks. The game's own values are set on its instances.
- `Lifecycle`, the script `addons/kit/system/lifecycle.gd`. Kit's pause menu reaches it by this name, and a game saves its progress on `Lifecycle.shutdown_requested`.

### Set the game's values

Each value the game owns is an export on a brick placed in `System`:

| Brick | Export | Value |
| --- | --- | --- |
| `system/input/input.tscn` | `action_sets` | The game's action sets, which the settings menu lists for rebinding. |
| `system/input/input.tscn` | `steam_in_game_actions` | The game's Steam Input manifest, required on Steam. |
| `system/input/input.tscn` | `focused_sound_group` | The sound played as focus moves between controls. |
| `system/setting/settings.tscn` | `menu_tabs` | The game's own settings menu tabs, keyed by their label's message ID. |
| `system/setting/interface/font_scaling_observer.tscn` | `theme` | The font theme which the text scaling setting resizes. |
| `system/save/saves.tscn` | `schema` | The game's save data, required. |
| `system/save/saves.tscn` | `slot_count` | The number of save slots, each shown in the save menu. |

Two values are set from code instead, since no export in `System` can reach or hold them:

- `KitSystems.audio().screens`, the game's `StdScreenManager`, which ducks the mix under covering screens.
- `KitPauseMenu.return_to_main_menu`, the game's way back to its main menu. The pause menu offers returning only once it is set.

### Use the menus

Each menu is a finished screen, used in place:

- **Settings:** push `menu/settings/screen.tres`, or list `menu/settings/pusher.tscn` in a screen's `attachment_scenes` to open it on `ui_toggle_menu`.
- **Save slots:** push `menu/save/screen.tres` and await its `popped` signal, which carries the chosen slot's index.
- **Pause:** list `menu/pause/pusher.tscn` in a gameplay screen's `attachment_scenes`.
- **Splash:** push `ui/splash/godot_screen.tres`, whose scene emits `advanced` once it is done. `ui/splash/splash.gd` makes a splash of any scene.

For a different layout, assemble a menu from the bricks it is made of: the settings tabs and their `group` and `setting` rows, the controls tab's `action_set` groups, the save menu's `slot_button`, and the dialogs in `ui/menu/`.

### Configure the project

Kit's bricks also read these project settings:

| Setting | Requirement |
| --- | --- |
| `[input]` | Defines `ui_tab_next`, `ui_tab_prev`, `ui_binding_stop` and `ui_toggle_menu`, which kit's menus name and Godot does not define. |
| `[audio] buses/default_bus_layout` | Defines the buses `Master`, `music`, `sound_effects`, `voice`, `ui` and `game`. |
| `[gui] theme/custom` | Defines the type variations kit's scenes name: `button_dialog`, `button_menu`, `button_tab_selected`, `button_tab_unselected`, `hud_bar`, `hud_bar_ghost`, `hud_number`, `hud_number_crit`, `menu_body` and `panel_dialog`. |
| `[internationalization] locale/translations` | Lists every `addons/kit/locale/*.mo`, after the game's own catalogue, so a message the game defines overrides kit's. |

## **Development**

### Setup

The following instructions outline how to get the project set up for local development:

1. Clone this repository using the `--recurse-submodules` flag, ensuring all submodules are initialized. Alternatively, run `git submodule sync` to update all submodules to latest.
2. [Follow the instructions](https://github.com/coffeebeats/gdenv/blob/main/docs/installation.md) to install `gdenv`. Then, install the [pinned version of Godot](./.godot-version) with `gdenv i`.
3. [Install `uv`](https://docs.astral.sh/uv/getting-started/installation/), then run `uv sync`. That installs the Python tooling from [`uv.lock`](./uv.lock), and downloads the interpreter named by [`.python-version`](./.python-version) if the machine has none. Invoke each tool as `uv run <tool>`.

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
