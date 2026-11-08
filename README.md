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
| `system/input/input.tscn` | `unknown_glyph` | The glyph a prompt draws for a bound button with no art, defaulting to kit's "??" icon. Left empty, the prompt draws nothing for such a button. |
| `system/setting/settings.tscn` | `menu_tabs` | The game's own settings menu tabs, keyed by their label's message ID. |
| `system/setting/settings.tscn` | `menu_setting_overrides` | Kit's settings menu rows and rebinding groups the game shows or hides, by id, where it differs from kit's default. See [Pick the settings the menu shows](#pick-the-settings-the-menu-shows). |
| `system/setting/interface/font_scaling_observer.tscn` | `theme` | The game's theme, the one `[gui] theme/custom` names, which the text scaling setting resizes. |
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

### Pick the settings the menu shows

Each of kit's settings menu rows has an id, and `MENU_SETTINGS` in `system/setting/settings.gd` says whether the menu shows it by default; every row kit ships does, except the hold row below. The `Settings` node's `menu_setting_overrides` holds only what the game changes, such as `sound_volume_voice: false` in a game with no voice audio, or `true` for a row kit leaves off until a game opts in. A row kit adds in a later version shows up, or stays off, by kit's default until the game overrides it, and an override naming an id kit no longer has logs a warning. A group left with no row is left out, and so is a tab left with none of kit's rows. The game's own tabs from `menu_tabs` always show. Leaving out a row hides only its control, and the observer in `System` keeps applying the stored value, which is the default if the player never set one.

The controls tabs list each of kit's menu action sets as a rebinding group whose rows follow the set's actions, so a game shows or hides the group as a whole. Its id names the tab and the set: `controller_bindings_<set>` or `keyboard_mouse_bindings_<set>`, with `<set>` one of `menu`, `menu_tabbed`, `menu_options` and `menu_binding`. A game's own action sets from `action_sets` show in every controls tab that shows. `controller_steam_configurator` is the row that opens Steam's binding panel while Steam Input drives the controller.

`accessibility_holds_mode`, the Accessibility tab's only row, lets the player choose whether every hold the game lists in an action set's `holds` is held or tapped to toggle. Kit's input scenes give its property to the first player's slot as `hold_mode_property`. The row is off by default, so a game without holds never sees the tab, and a game that has holds turns it on with `accessibility_holds_mode: true`. Until the player picks a mode, each hold runs in its own `mode`. A choice they made while the row showed still applies if the game hides the row later. To give a group of holds a choice of its own, a game adds a property, defaulting to `0` (`INHERIT`) and offering it, and sets it as each hold's `mode_override`, so the group follows the player's general choice until they pick one for it. A player can then keep holding the game's destructive confirms while its other holds toggle.

Every property kit defines under `system/setting/`, with the row that shows it:

| Property | Key | Scope | Type and default | Row id | Read by |
| --- | --- | --- | --- | --- | --- |
| `audio/volume/master_property.tres` | `audio/volume/master` | User | Float, 0 to 10, default 10 | `sound_volume_master` | The volume observer, on the `Master` bus. |
| `audio/volume/sound_effects_property.tres` | `audio/volume/sound_effects` | User | Float, 0 to 10, default 10 | `sound_volume_sound_effects` | The volume observer, on the `sound_effects` and `ui` buses. |
| `audio/volume/music_property.tres` | `audio/volume/music` | User | Float, 0 to 10, default 10 | `sound_volume_music` | The volume observer, on the `music` bus. |
| `audio/volume/voice_property.tres` | `audio/volume/voice` | User | Float, 0 to 10, default 10 | `sound_volume_voice` | The volume observer, on the `voice` bus. |
| `audio/device/output_property.tres` | `audio/device/output` | User | String, default `"Default"` | `sound_audio_device` | The sound device observer. |
| `audio/device/output_options_property.tres` | `audio/device/output_options` | User | Read-only list of the output devices | `sound_audio_device` | The device row, as its choices. |
| `audio/mute/background_property.tres` | `audio/mute/background` | User | Bool, default `true` | `sound_audio_bg_mute` | The mute observer, while the window is unfocused. |
| `audio/mute/global.tres` | `audio/mute/global` | User | Bool, default `false` | None | The mute observer. |
| `interface/language_property.tres` | `interface/language/language_code` | User | String, default the loaded locale closest to the system's | `interface_language_display` | The language observer. |
| `interface/language_options_property.tres` | `interface/language/options` | User | Read-only list of the loaded locales | `interface_language_display` | The language row, as its choices. |
| `interface/font_scaling_property.tres` | `interface/font_scaling` | User | Float, 0.5 to 2, default 1 | `interface_text_scaling` | The font scaling observer. |
| `video/fullscreen.tres` | `display/fullscreen` | User | Bool, default `true` | `display_video_fullscreen` | The window observer. |
| `video/borderless.tres` | `display/window/size/borderless` | Project | Bool, default `false` | `display_video_borderless` | The window observer. |
| `video/window_mode_property.tres` | `display/window/size/mode` | Project | Int, default 3 (fullscreen) | None | The window observer. |
| `video/frame_limit_property.tres` | `application/run/max_fps` | Project | Float, 60 to 240, default 120 | `display_video_fps_limit` | The FPS observer. |
| `video/vsync_property.tres` | `display/window/vsync/vsync_mode` | Project | Bool, default `true` (adaptive) | `display_video_vsync` | The FPS observer. |
| `video/msaa_3d_property.tres` | `display/msaa_3d` | User | Int, default 0 | None | `map/3d/scene.tscn`. |
| `video/render_scale_property.tres` | `display/render_scale` | User | Float, 0.5 to 1, default 1 | None | `map/3d/scene.tscn`. |
| `video/window_size_width.tres` | `display/window/size/window_width_override` | Project | Int, default 0 | None | Nothing in kit. |
| `video/window_size_height.tres` | `display/window/size/window_height_override` | Project | Int, default 0 | None | Nothing in kit. |
| `controls/glyph_type_property.tres` | `controls/glyph/type` | User | Int, default 0 (match the active device) | `controller_button_prompt` | Button prompts and binding rows. |
| `controls/glyph_type_options_property.tres` | `controls/glyph/type_options` | User | List of glyph types | `controller_button_prompt` | The button prompt row, as its choices. |
| `controls/haptics_disable_property.tres` | `controls/haptics/disable` | User | Bool, default `false` | `controller_disable_vibration` | The input system's rumble. |
| `controls/haptics_strength_property.tres` | `controls/haptics/strength` | User | Float, 0 to 100, default 50 | `controller_vibration_strength` | The input system's rumble. |
| `controls/cursor_confined_property.tres` | `controls/cursor/confined` | User | Bool, default `display/fullscreen`'s value until the player sets it | `keyboard_mouse_confine_cursor` | The input system's cursor. |
| `controls/hold_mode_property.tres` | `controls/hold/mode` | User | Int, default 0 (each hold's own mode) | `accessibility_holds_mode` | The first player's input slot, for every hold. |
| `controls/hold_mode_options_property.tres` | `controls/hold/mode_options` | User | Read-only list of the three `StdInputActionHold.Mode` values | `accessibility_holds_mode` | The hold row, as its choices. |

A user setting is saved in the player's profile, and a project setting in Godot's project settings override file, which the engine reads at startup.

### Put UI inside gameplay

A menu screen loads kit's `Menu` set, `system/input/actions/menu.tres`, which clears every other binding and carries the `ui_*` navigation actions, and enables the layers it needs over it. Kit ships only the sets and layers its own scenes load, and each of its layers names `Menu` as its `parent`. A layer over the game's own set belongs to the game, which writes it in its own input directory, usually `project/input/actions/`, under a name of its own, since every set and layer needs a unique name.

1. Kit's pause and settings pushers open on `ui_toggle_menu`, which `menu_options.tres` carries over `Menu`. For gameplay, the game writes an options layer over its set that holds `ui_toggle_menu` and lists it in the map root's `action_set_layers`, so Escape pauses through `menu/pause/pusher.tscn`. It also lists the layer in `Input.menu_options_layers`. Bindings save under a layer's name, so that list is how a rebind in the controls tabs' `MenuOptions` group reaches the game's layer. Nothing ties the game's layer to kit's, so a kit release whose pushers expect another action names it in its release notes.
2. A menu over the world, such as a build or context menu, is a panel. Place `ui/panel/panel.tscn` in the map's `UI`, or `ui/panel/world_panel_2d.tscn` or `world_panel_3d.tscn` to follow a point in the world, put the game's buttons inside it, and open it through its `StdPanel` node or by showing it. For rows of buttons, such as a build menu's items, put `ui/panel/menu_rows.tscn` inside the panel, as [`ui/panel/README.md`](ui/panel/README.md) describes. While open, the panel keeps focus inside itself and loads kit's `Menu` set, so a rebind in the controls tabs' `Menu` group reaches it; the set before it comes back once it closes. Whatever stays live while it's open goes in a layer of the game's own with `Menu` as `parent`, listed in its loader's `action_set_layers` and in `Input.action_sets`. An action that does something only while the panel is open, such as a build menu's item keys, lives only in that layer, so it has one binding. A panel has no scrim; a menu that wants one is a screen.
3. A button that doubles a bindable action, such as a build or a wave start, is an [action button](#add-an-action-button); any other button connects `pressed`. The handler the action reaches validates it, since a key gets there whether or not the button is enabled.
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

### Add an action button

`ui/input/action_button.tscn` is a `KitInputActionButton`, a `Button` that stands for one action. Its icon is the glyph of the key or button bound to the action, its text is the action's translated name, and a click raises the action, held for as long as the button is. The game sets these on its instance:

| Export | Value |
| --- | --- |
| `action_set`, `action` | The action the button stands for. |
| `binding_index`, `player_id` | The binding the glyph draws first and the player whose devices it follows, by default the primary binding and player 1. |
| `cycle_interval` | Seconds each bound origin shows before the glyph moves to the next, so the player sees every binding. `0`, the default, shows the first alone. |
| `raise_action` | On by default. Off, a click raises nothing, and the game connects `pressed` as on any button. |
| `use_action_text` | On by default, so the text follows the player's language. Off, the button keeps the `text` the game sets. |
| `hold_text` | The translation key of the text shown while the action is a hold the player holds, with the action's name as `{action}`. Kit's `kit_hold` reads "Hold to {action}"; empty shows the name alone. |
| `focus_anchor` | Whether focus navigation lands on the button when its screen opens. |

The glyph is one and a half lines of the button's text tall, so it grows with the text size setting, and it follows the Button prompts setting. To resize every action button's glyph, the game's theme sets the integer constant `glyph_scale_percent` (150 in kit's base theme) under the type `KitInputActionButton`, or under a button's own type variation. Assistive tech reads the button as the key's name and then its text, such as "Cross, Sell". For a glyph without a button, place `ui/glyph/glyph.tscn`, a `KitInputGlyph`, which sizes the same way from its `glyph_scale` export, 1.5 by default, rather than the theme.

When an action set lists the action in `holds`, the button follows the mode the hold runs in, which the player's `accessibility_holds_mode` setting can change while the game runs. Held, it shows `hold_text`, and a fill crosses the button as the hold fills. Tapped to toggle, it shows the action's name until the tap. While the hold then fills on its own, it shows `kit_hold_cancel` ("Cancel") beside its own glyph, since a second tap cancels it. The text changes width, so a row of buttons shifts with it. The button reads all of this from a `StdInputActionHoldMonitor`, which `get_hold_monitor()` returns. A game that builds its own prompt places a monitor of its own instead.

The fill is the theme color `hold_fill_color`, translucent white in kit's base theme. It covers the bottom `hold_fill_height_percent` percent of the button, 100 by default, so a small value draws a bar along the bottom edge. Both sit under `KitInputActionButton` as `glyph_scale_percent` does. In a right-to-left layout the fill grows from the right. A game that sets its own text keeps it, and only the fill and glyph change.

### Change the button prompts

A prompt draws an origin from the first set in `Input.glyph_sets` that matches the device and has art for it, moving on to the next matching set when one has none. To change part of a family, put a set with only that art ahead of kit's, such as one Xbox button. Kit's own families layer the same way, with `xbox_one.tres` holding only View ahead of `xbox.tres`, and `playstation_4.tres` only Share ahead of `playstation.tres`. To change all of them, replace the list, keeping those two ahead of their families. Kit's art comes from the CC0 pack named in `system/input/unknown/glyphs/SOURCE.md`, which has matching art for most pads. On Steam builds the sets draw the keyboard and any pad Steam Input isn't driving, and Steam draws its own art for the rest. A bound button with no art in any matching set, or with no image in Steam, draws `Input.unknown_glyph`.

Kit draws every key the same way, from one keycap resource, `system/input/unknown/glyphs/keyboard.tres`:

- Every key gets the same cap. Its height follows the prompt, so a key matches the pad glyph beside it. Its width grows with the label, from a square at `min_width`.
- A printable key shows its label in the player's keyboard layout. A named key shows the abbreviation in `labels`, such as Esc or PgDn, and the arrows show the icons in `icons`.
- Keys are drawn in the set's `font`. Left empty, that is Godot's fallback font, which `gui/theme/custom_font` replaces and a project theme doesn't, so a game whose font lives only in its theme sets `font` here.

For its own look, a game saves a copy of `keyboard.tres`, edits its `cap`, `font`, `font_size`, `color`, `padding` and `min_width`, and lists the copy in place of kit's. `min_width` equals the natural height of a key, which is a line of the label plus twice the vertical padding, so change it along with the font or padding to keep single keys square. Kit's value fits Godot's built-in font at the default `font_size` and `padding`, so a game that sets `gui/theme/custom_font` recomputes it too.

One cap serves the whole game. The settings menu's binding rows show labelled keys as plain text in the theme's font instead, and only their arrows keep the cap.

### Style kit's scenes

Kit's scenes take their look from type variations in the game's theme:

| Variation | Base type | Styles | Kit sets |
| --- | --- | --- | --- |
| `ButtonDialog` | `Button` | An alert's buttons. | Nothing. |
| `ButtonMenu` | `Button` | The pause menu's buttons. | Nothing. |
| `ButtonTabSelected`, `ButtonTabUnselected` | `Button` | The settings menu's tabs, the selected one and the rest. | `normal` on `ButtonTabUnselected`, with no box, so the selected tab stands out. |
| `HudBar`, `HudBarGhost` | `ProgressBar` | A HUD bar's fill, and the ghost behind it that drains after a hit. | `background` and `fill` on both. `HudBar`'s `background` draws nothing, so the ghost shows through. |
| `HudNumber`, `HudNumberCrit` | `Label` | Floating numbers, and the critical hit preset's. | `font_outline_color` and `outline_size` on both, and `font_color` on `HudNumberCrit`. |
| `MenuBody` | `VBoxContainer` | The settings menu's tab contents. | Nothing. |
| `PanelDialog` | `PanelContainer` | The panel behind each menu, alert and gameplay panel. | Nothing. |
| `PanelSettingsHeader`, `PanelSettingsBody` | `PanelContainer` | The settings menu's tab bar and the area below it. | `panel` on both, drawing nothing. |

`System` instances `system/theme/theme.tscn`, which fills the game's theme from kit's `ui/theme/base.tres` as `System` enters the tree. It adds only the items and base types the game's theme lacks, so the game defines just what it restyles, and an item it sets wins over kit's on the same type. Kit's base stays close to Godot's default look and sets no font sizes. The fill changes the game's theme in place rather than layering a copy over it, so the text size setting keeps resizing the theme every control reads. The editor runs no fill, so it previews kit's scenes in the game's theme alone, and the Inspector lists a variation only once the game's theme defines it.

Godot reads a variation's own items before its base type's, so an item kit sets on a variation also wins over the game's item of that name on the base type. A game which styles `ProgressBar`'s `fill` still sees kit's on `HudBar` until it sets `fill` on `HudBar`. Most of the items kit sets tell a scene's parts apart, such as a HUD bar's fill from its ghost, so a game restyles them on the variation itself.

A kit control's own theme items live under a type named after its class, such as the constant `glyph_scale_percent` under `KitInputActionButton`. The control looks for the item on its own type variation first, so a game can set it for one variation, and then on the class's type.

### Configure the project

Kit's scenes also read these project settings:

| Setting | Requirement |
| --- | --- |
| `[input]` | Defines `ui_tab_next`, `ui_tab_prev`, `ui_binding_stop` and `ui_toggle_menu`, which kit's menus name and Godot does not define. |
| `[audio] buses/default_bus_layout` | Defines the buses `Master`, `music`, `sound_effects`, `voice`, `ui` and `game`. |
| `[gui] theme/custom` | The game's theme, which kit fills with what its scenes need. See [Style kit's scenes](#style-kits-scenes). |
| `[internationalization] locale/translations` | Lists every `addons/kit/locale/*.mo`, after the game's own catalogue, so a message the game defines overrides kit's. |

### Drive a running game

`system/debug/editor/bridge.tscn` is a development-only bridge which lets an external process inspect and drive the game — the scene tree, an evaluated expression, a screenshot, the state the running scene's nodes report, or an action press or click sent through `Input`. It is what the `run-game` skill below talks to.

Wire it under the game's `System` scene through an `StdConditionLoader` whose `expressions_allow` holds kit's `system/debug/editor_run_expression.tres`, which allows it only in an editor run. The bridge lives in `system/debug/editor/`, so a game that excludes `*/editor/*` from its export presets ships none of it, and nothing a game ships names any part of it. It then listens only when handed a port, either `--bridge-port <N>` after `--` or `GODOT_DEBUG_BRIDGE_PORT` for editor runs, and binds `127.0.0.1` and nothing else. An ordinary F5, a GUT run and a headless CI run open no socket at all.

Game code becomes visible to it by defining `_get_debug_state() -> Dictionary` on a node; the bridge finds it by walking the tree, so the method needs no registration, and in a shipped build it has no caller.

## **Agent plugin**

This repository is also a plugin marketplace holding one plugin, [`kit`](./plugins/kit). [Claude Code](https://code.claude.com/docs/en/plugin-marketplaces) and Codex both read it, from the same `.claude-plugin/` files. Nothing is published anywhere; a repository references it by GitHub path. The plugin carries the skills that describe this addon:

- `add-setting`, `add-save-field`, `add-input-action`, `add-action-button`, `add-sound` and `add-translation`, which extend a game built on kit. Each reads what the game owns out of its `project.godot` rather than assuming a layout.
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
