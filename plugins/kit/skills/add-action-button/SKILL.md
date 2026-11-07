---
name: add-action-button
description: Add a button that stands for an input action, showing the bound key or controller button and the action's name, and raising the action when clicked. Adds the action first if the game lacks it.
user-invocable: true
argument-hint: "<scene> <action_set> <action_name>"
---

Add a `KitInputActionButton` to one of the game's scenes. The button's icon is the glyph of the origin bound to the action, its text is the action's translated name, and a click raises the action. A key press and a click therefore reach the same handler.

## Find the game's wiring

- **The scene**: the scene the user named, which places the button. A button inside gameplay usually sits in a map's `UI` or in a panel under it.
- **The action-set directory**: the directory holding the `.tres` files that `action_sets` on the `Input` instance in the `System` autoload's scene points at. Usually `project/input/actions/`.

## Steps

1. **Make sure the action exists.** Look for it in the named set in the action-set directory, with default bindings under `[input]` in `project.godot` and a `msgctxt "actions_<SetName>"` translation in the game's catalogue. If any is missing, run the `add-input-action` skill for it first. The button's text comes from that translation through `Locales.tr_action`, so an untranslated action shows its raw name.

2. **Check that the action is live where the button is.** The action must be in the set or an enabled layer while the button shows, or a click raises an action that nothing binds, and `StdInputActionTrigger` asserts in debug builds. A button in a panel reaches only kit's `Menu` set and the layers in the panel's loader, so the action goes in one of the game's layers with `Menu` as `parent`, listed there. See "Put UI inside gameplay" in kit's README.

3. **Instance `res://addons/kit/ui/input/action_button.tscn`** in the scene, not a bare `Button` with the script, since the scene carries the focus handler. Set on the instance:
   - `action_set`: the set's `.tres`, as an `ext_resource`
   - `action`: the action's `StringName`, such as `&"combat_build"`
   - `focus_anchor = true` on the one button focus navigation lands on when the screen opens, except on a row of `ui/panel/menu_rows.tscn`, since that scene focuses its first usable row itself
   - `use_action_text = false` and a `text` of the game's own only where the button's label isn't the action's name
   - `raise_action = false` only where a click should run the game's own code instead of raising the action, which the game connects to `pressed`

   Leave `icon` alone, since the button draws the glyph there itself.

4. **Make the action's handler validate it.** Whatever handles the action checks that it can run, such as whether the player can afford the build, because a key reaches the handler whether or not the button is enabled. Disabling the button only greys out the click. Don't connect the button's `pressed` to the same logic, since the raised action already runs it, and a second connection would run it twice.

5. **If the action is a hold, let the button show it.** When the set lists the action in `holds`, the button follows the mode the player picks in kit's Accessibility tab: "Hold to <name>" and a fill while held, "Cancel" and the hold's `cancel_action` glyph after a toggle's tap, the name alone for a press. Set `hold_text` to another translation key formatted with `{action}`, or to empty for the name alone. The handler acts on the slot's `action_hold_triggered` for the action, not its raw press. Turn on `accessibility_holds_mode` in the `Settings` node's `menu_setting_overrides` if the game hasn't, so the player can pick the mode.

6. **Size the glyph and fill through the theme, if needed.** The glyph is as tall as a line of the button's text. To make every action button's glyph taller, set the integer constant `glyph_scale_percent` under the type `KitInputActionButton` in the game's theme, such as `150`. The hold's fill is the color `hold_fill_color` over the button's lower `hold_fill_height_percent` percent, so a small value draws a bar along the bottom edge. A button with a `theme_type_variation` reads each item from that variation first.

7. **Run `godot --import --headless`** to check that the scene loads. Then run the game with the `run-game` skill and press the bound key to confirm it reaches the handler.

## Key reference files

- `addons/kit/ui/input/action_button.gd`: the button's exports and theme items
- `addons/std/input/action_hold.gd`: a hold's modes, `duration` and `cancel_action`
- `addons/kit/ui/glyph/glyph.tscn`: a `KitInputGlyph`, for a glyph shown without a button
- `addons/std/input/action_trigger.gd`: how a click raises and holds the action
- `addons/kit/locale/locales.gd`: `tr_action()`, which names the action
