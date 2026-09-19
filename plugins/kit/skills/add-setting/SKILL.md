---
name: add-setting
description: Add a new user-configurable setting with property, observer, UI, and translations. Covers audio, video, interface, and controls categories.
user-invocable: true
argument-hint: "<category> <setting_name> <type>"
---

Add a user-configurable setting to the project. This involves creating a settings property resource, an observer to react to changes, UI in the settings menu, and translations. The `type` determines which property class and UI control to use.

## Setting types

| Type | Property class | UI control | Controller script |
|---|---|---|---|
| `bool` | `StdSettingsPropertyBool` | `checkbox.tscn` | `controller_toggle_button.gd` |
| `float_range` | `StdSettingsPropertyFloatRange` | `slider.tscn` | `controller_range.gd` |
| `option_string` | `StdSettingsPropertyString` | `option_button.tscn` | `controller_option_button_string.gd` |
| `option_int` | `StdSettingsPropertyInt` | `option_button.tscn` | `controller_option_button_int.gd` |

## Find the game's wiring

- **The system scene** — the `[autoload]` entry named `System` in `project.godot`, holding the `Settings` instance and the game's observers. Usually `project/main/system.tscn`, which also fixes the game's source root as `project/`.
- **The game's settings tabs** — the scenes `menu_tabs` on that `Settings` instance points at, keyed by each tab label's msgid.

## Steps

Kit's settings under `addons/kit/system/setting/` are the reference to copy from, never a place to add to: `addons/kit` is a submodule. A game's setting lives under `project/setting/`, and its observer is placed in the game's own system scene.

1. **Read reference files** to understand the existing patterns:
   - `addons/kit/system/setting/audio/volume/master_property.tres` — property resource pattern
   - `addons/kit/system/setting/audio/volume/observer.gd` — observer pattern
   - the system scene — where the game's observers are placed
   - `addons/kit/menu/settings/sound/sound.tscn` — one of kit's settings tabs, the UI pattern to copy
   - a scene from `menu_tabs` — the game's own settings tab

2. **Create the property resource** at `project/setting/<category>/<name>_property.tres`:

   ```
   [gd_resource type="Resource" script_class="<PropertyClass>" format=3 uid="uid://..."]

   [ext_resource type="Resource" uid="uid://..." path="res://addons/kit/system/setting/<scope>.tres" id="1_xxxxx"]
   [ext_resource type="Script" uid="uid://..." path="res://addons/std/setting/<property_script>.gd" id="2_xxxxx"]

   [resource]
   script = ExtResource("2_xxxxx")
   category = &"<category>"
   name = &"<setting_path>"
   default = <default_value>
   scope = ExtResource("1_xxxxx")
   ```

   For `float_range`, also include `minimum`, `maximum`, and `step` fields.

   Choose the correct scope resource:
   - `addons/kit/system/setting/user_settings_scope.tres` — per-user settings (most common: audio, controls, interface)
   - `addons/kit/system/setting/project_settings_scope.tres` — project-wide settings

3. **Create the observer** at `project/setting/<category>/<subcategory>/observer.gd`. Observers are grouped by subcategory (e.g., kit's `audio/volume/observer.gd` handles all volume settings). If the game already has an observer for the subcategory, add the new property to it instead of creating a new file:

   ```gdscript
   ##
   ## project/setting/<category>/<name>/observer.gd
   ##
   ## <ObserverName> is a `StdSettingsObserver` that applies <description>.
   ##

   extends StdSettingsObserver

   # -- CONFIGURATION ------------------------------------------------------------------- #

   ## property is the settings property to observe.
   @export var property: <PropertyClass> = null

   # -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


   func _get_settings_properties() -> Array[StdSettingsProperty]:
   	return [property]


   func _handle_value_change(
   	_property: StdSettingsProperty, value: <ValueType>
   ) -> void:
   	# Apply the setting change here.
   	pass
   ```

4. **Place the observer in the system scene**:

   Add a node for the observer as a child of the `System` root, after `Settings`. Reference the observer script and the property resource via `ext_resource`. An observer binds through its property's scope rather than its parent, so it works outside kit's `Settings` node.

5. **Add UI to the game's own settings tab.** Kit's tabs under `addons/kit/menu/settings/` are read-only, so the control goes in a tab the game owns — one of the scenes already in `menu_tabs`, or a new `project/menu/settings/<tab>/<tab>.tscn`. A new tab is registered in `menu_tabs` on the `Settings` instance in the system scene, keyed by its label's msgid (`options_<tab>`); the settings menu shows it after kit's own tabs.

   The UI structure follows this hierarchy:
   ```
   GroupNode (instance of addons/kit/menu/settings/group.tscn)       — label = "options_<category>_<group>"
     └─ SettingNode (instance of addons/kit/menu/settings/setting.tscn) — label = "options_<category>_<setting>"
          ├─ InputControl (slider/checkbox/option_button .tscn)
          └─ ControllerNode (StdSettingsController*)
                property = <property .tres>
                target = NodePath("../InputControl")  # for sliders
   ```

   Follow the exact pattern in the reference `.tscn` files. Each node needs a `unique_id`, `layout_mode = 2`, and proper resource references.

   For sliders (`controller_range.gd`), the controller needs:
   - `property` — the settings property resource
   - `target` — `NodePath("../HSlider")`

   For checkboxes (`controller_toggle_button.gd`), the controller needs:
   - `property` — the settings property resource

   For option buttons (`controller_option_button_string.gd`), the controller needs:
   - `property` — the settings property resource
   - `options_property` — a separate options list property resource

6. **Add translations** using the `add-translation` skill:
   - Group label: `options_<category>_<group>` (if creating a new group)
   - Setting label: `options_<category>_<setting_name>`
   - Tab label: `options_<tab>` (if creating a new tab)

7. **Run `godot --import --headless`** and verify the setting appears correctly in the settings menu.

## Key reference files

- `addons/kit/system/setting/audio/volume/master_property.tres` — property resource (FloatRange)
- `addons/kit/system/setting/audio/mute/background_property.tres` — property resource (Bool)
- `addons/kit/system/setting/audio/volume/observer.gd` — observer pattern
- `addons/kit/system/setting/audio/device/observer.gd` — observer with multiple properties
- the system scene — the game's observers, beside kit's `FontScalingObserver`
- `addons/kit/system/setting/user_settings_scope.tres` — per-user scope
- `addons/kit/system/setting/project_settings_scope.tres` — project-wide scope
- `addons/kit/menu/settings/sound/sound.tscn` — full settings tab UI (slider, option button, checkbox examples)
- `addons/kit/menu/settings/controls/controls.tscn` — controls tab UI
- `addons/kit/menu/settings/setting.tscn` — setting container scene
- `addons/kit/menu/settings/group.tscn` — group container scene
- a scene from `Settings.menu_tabs` — the game's own settings tab
- `addons/kit/ui/input/slider.tscn` — slider input control
- `addons/kit/ui/input/checkbox.tscn` — checkbox input control
- `addons/kit/ui/input/option_button.tscn` — option button input control
- `addons/std/setting/controller_range.gd` — range controller
- `addons/std/setting/controller_toggle_button.gd` — toggle controller
- `addons/std/setting/controller_option_button_string.gd` — string option controller
- `addons/std/setting/controller_option_button_int.gd` — int option controller