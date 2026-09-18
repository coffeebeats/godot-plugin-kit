---
name: add-input-action
description: Add a new input action with default bindings, action set registration, and translations. Creates new action sets if needed.
user-invocable: true
argument-hint: "<action_set> <action_name> [type]"
---

Add an input action to the game. The action is registered in an action set, given default key/gamepad bindings in `project.godot`, and translated for display in the controls settings tab. The `type` defaults to `digital` but can be `analog_1d` or `analog_2d`.

## Find the game's wiring

Everything the game owns is reachable from `project.godot`; nothing below assumes a fixed layout.

- **The system scene** — the `[autoload]` entry named `System`, holding the `Input`, `Settings` and `Saves` instances. `project/main/system.tscn` in a repository created from the template.
- **The action-set directory** — the directory holding the `.tres` files that `action_sets` on the `Input` instance points at. Usually `project/input/actions/`.
- **The catalogue** — the directory holding the first entry of `locale/translations` that is not under `addons/`. Usually `project/locale/`.
- **The Steam Input manifest** — the resource `steam_in_game_actions` on the `Input` instance points at. It generates `game_actions_<app_id>.vdf` at the repository root, which is committed.

## Steps

1. **Read reference files** to understand existing actions:
   - the action-set directory — the game's action set `.tres` files
   - `addons/kit/system/input/actions/` — kit's menu action sets, for reference only; the submodule never gains an action
   - `project.godot` — `[input]` section for existing default bindings
   - the catalogue's `messages.pot` — existing `msgctxt "actions_*"` entries
   - the system scene — the `Input` instance's `action_sets`, which kit's controls tab lists for rebinding

2. **Check if the action set exists** in the action-set directory. Action set files are `StdInputActionSet` resources (`.tres`). If the specified action set does not exist, create it (see step 3). If it does exist, skip to step 4.

3. **Create a new action set** (only if it doesn't exist):

   a. Create the action set resource beside the game's existing ones. Copy the `ext_resource` UID for `action_set.gd` from an existing action set file (e.g., `gameplay.tres`) rather than hardcoding it — the UID may change when the `std` submodule is updated:

   ```
   [gd_resource type="Resource" script_class="StdInputActionSet" format=3 uid="uid://..."]

   [ext_resource type="Script" uid="uid://..." path="res://addons/std/input/action_set.gd" id="1_xxxxx"]

   [resource]
   script = ExtResource("1_xxxxx")
   name = &"<SetName>"
   ```

   The `name` should be PascalCase (e.g., `&"Gameplay"`, `&"Combat"`).

   b. Run `godot --import --headless` to generate the UID.

   c. Append the action set to `action_sets` on the `Input` instance in the system scene, so kit's controls tab lists it for rebinding, after the game's existing sets:

   ```
   action_sets = Array[ExtResource("id_for_action_set_gd")]([ExtResource("id_for_gameplay_tres"), ExtResource("id_for_gameplay_options_tres"), ExtResource("id_for_new_action_set_tres")])
   ```

   Add the new set's `ext_resource` entry at the top of the file. Kit's controls tab under `addons/kit/menu/settings/controls/` is read-only.

   d. Add a translation for the action set name using the `add-translation` skill. Action set display names use the set's `name` as the `msgid`, under one shared context:
   - `msgctxt "action_sets"`
   - `msgid "<SetName>"` — e.g., `Gameplay`
   - `msgstr "<Display Name>"` — the English display name shown as the group header

   This is because `Locales.tr_action_set()` looks the name up under the `action_sets` context.

   e. Register the set in the Steam Input manifest, or Steam players cannot bind it. Add an `StdInputActionSet` to the manifest's `action_sets`, and an `StdInputActionSetLayer` to its `action_set_layers` — the two arrays are exclusive, and a layer in the wrong one is written as a base set.

4. **Add the action to the action set** `.tres` file. Actions are `StringName` values in one of three arrays:

   - `actions_digital` — boolean on/off actions (buttons, keys)
   - `actions_analog_1d` — single-axis analog actions (triggers)
   - `actions_analog_2d` — dual-axis analog actions (sticks)

   Add the action's `StringName` (e.g., `&"jump"`) to the correct array. If the array doesn't exist in the `.tres` file yet, add it under the `[resource]` section.

5. **Add default bindings in `project.godot`** under the `[input]` section. Each action needs a block like:

   ```
   <action_name>={
   "deadzone": 0.5,
   "events": [Object(InputEventKey,...), Object(InputEventJoypadButton,...)]
   }
   ```

   Common binding objects:
   - **Keyboard key**: `Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":<KEY_CODE>,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)`
   - **Gamepad button**: `Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":<BUTTON_INDEX>,"pressure":0.0,"pressed":false,"script":null)`
   - **Gamepad axis**: `Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":<AXIS>,"axis_value":<1.0 or -1.0>,"script":null)`

   Common key codes: Space=32, Enter=4194309, Escape=4194305, W=87, A=65, S=83, D=68, E=69, Q=81, Shift=4194325, Ctrl=4194326.
   Common button indices: A/Cross=0, B/Circle=1, X/Square=2, Y/Triangle=3, LB=9, RB=10, LT=trigger axis, RT=trigger axis.

   Ask the user what default bindings they want if not specified.

6. **Add translations** using the `add-translation` skill:
   - Use `msgctxt "actions_<SetName>"` for the action's display name
   - `msgid "<action_name>"` — the key matches the action's StringName
   - `msgstr "<Display Name>"` — the English display name shown in controls settings

7. **Regenerate the Steam Input manifest**, after the translations exist — it embeds a display name per locale, so regenerating first bakes in the raw msgid. Open the manifest resource in the editor and re-assign one of its exported properties; `@tool` setters are what write the file, and nothing watches the action sets it references, so editing a set never rewrites the manifest on its own.

   Then read the `.vdf` diff before committing it. It is generated, so the only change worth keeping is the one this skill asked for.

8. **Run `godot --import --headless`** to validate everything compiles. The action should appear automatically in the controls settings tab under its action set.

## Binding collisions

An origin binds to at most one action, so an action added to a layer takes its key away from whatever held it before (`addons/std/input/godot/device_actions.gd:240`). Nothing reports this: the displaced action simply stops firing on that origin, and only on the screens that load the layer.

Kit's own sets carry one instance to check yours against. `ui_toggle_menu` and `ui_cancel` are both `Escape` in `project.godot`; on any screen loading `menu_options.tres` the key goes to `ui_toggle_menu`, leaving `ui_cancel` on the gamepad only.

After adding a binding, check every action set that layers over the same origin, not just the one you edited.

## Key reference files

- the game's `gameplay.tres` — action set resource pattern
- the game's `gameplay_options.tres` — action set layer pattern (StdInputActionSetLayer)
- the system scene — `Input.action_sets`, the game's sets the controls tab lists
- `addons/kit/menu/settings/controls/controls.gd` — how the controls tab lists them, above kit's menu sets
- `project.godot` — `[input]` section for default bindings
- the catalogue's `messages.pot` — `msgctxt "actions_*"` translation entries
- the catalogue's `en_US.po` — corresponding English translations
- `addons/kit/locale/locales.gd` — `tr_action()` and `tr_action_set()` resolution
- the game's `steam_in_game_actions.tres` — the Steam Input manifest, and the `app_id` naming its `.vdf`
- `addons/std/input/steam/in_game_actions.gd` — how the manifest is generated
- `addons/std/input/action_set.gd` — `StdInputActionSet` class
