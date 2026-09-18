---
name: add-entity-hud
description: Give a world entity a HUD — a health bar, name plate, floating combat numbers or an off-screen indicator that follow it on screen. Use when an entity in a map's SubViewport needs anything drawn above it.
user-invocable: true
argument-hint: "<entity_scene> [elements: bar|numbers|indicator]"
---

Author a HUD group scene for one kind of entity, then point a `KitHudAnchor` on the entity at it. The layer mounts the group, a `KitWorldTracker` keeps it over the entity, and the entity calls typed methods on the elements themselves.

Four words: **layer** (the plane, one per map, already in every template), **anchor** (the node you add to the entity), **group** (the scene of elements that entity gets), **elements**. You author the group and the anchor; the layer and the tracker are already built.

## Steps

1. **Author the group scene.** `New Inherited Scene` from `addons/kit/ui/hud/group_2d.tscn` (or `group_3d.tscn`), saved beside the entity as `<entity>_hud.tscn`. It arrives with a `KitHudGroup` root and a `KitWorldTracker2D`/`3D` child already wired.

   Lay elements out inside it with **ordinary anchors and containers** — a `VBoxContainer` of a `Label` and a `KitHudBar`, say. Placement inside the group is normal `Control` layout, not per-element screen offsets. Instance the stock element scenes:

   | Element | Scene | API |
   | --- | --- | --- |
   | `KitHudBar` | `addons/kit/ui/hud/bar/bar.tscn` | `set_value(value, max_value)` |
   | `KitHudNumbers` | `addons/kit/ui/hud/numbers/numbers.tscn` | `pop(value)` |
   | `KitHudIndicator` | `addons/kit/ui/hud/indicator/indicator.tscn` | none; it aims itself |

   A name plate is a plain `Label` — there is no `HudLabel`, because a `Label` is already the whole feature. Damage and a critical hit are **two `KitHudNumbers` instances with different styles** (`style_damage.tres`, `style_crit.tres`), not one element with a flag.

2. **Attach a script to the group root**, extending `KitHudGroup`, that names the elements:

   ```gdscript
   class_name EnemyHud
   extends KitHudGroup

   var damage: KitHudNumbers = null
   var health: KitHudBar = null
   var name_plate: Label = null

   func _bind_elements() -> void:
       damage = $Damage
       health = $Rows/Health
       name_plate = $Rows/Name
   ```

   **Use `_bind_elements`, never `@onready`.** Godot readies the UI subtree after the game world, so an entity placed in a map scene at author time reaches its own `_ready` while the group's `@onready` members are still null. `_bind_elements` runs when the group is instantiated, before it is mounted, so it holds whichever way the entity arrived. `KitHudGroup.was_bound_in_tree` and `layer_test.gd` guard this; it is the fault that shipped once already.

3. **Add the anchor to the entity.** A `KitHudAnchor2D` (or `3D`) child of the entity, with `group_scene` set to the scene from step 1. That is the entire contract — the anchor finds the layer itself through `KitMap.for_node`, and outside a map it warns once and goes inert so the entity stays runnable in a headless test.

   Set `target` only to follow something other than the parent, such as a `Marker2D` above the entity. In 3D that is also the fix for a group that should hold a fixed height above a receding model, since `KitWorldTracker.offset` is screen-space.

4. **Call the elements from the entity.**

   ```gdscript
   @onready var _hud: EnemyHud = $HudAnchor2D.group

   func _on_damaged(amount: float, is_crit: bool) -> void:
       _hud.health.set_value(health, max_health)
       (_hud.crit if is_crit else _hud.damage).pop(amount)
   ```

   Every call is a typed method on the element that implements it. The HUD layer carries no vocabulary for game facts — no `set_value`, no `trigger`, no keys, no signal routing — so a new element kind needs no change to any shared class.

5. **Choose the off-screen behavior**, which lives on the group and its tracker, never on the anchor:

   - A **name plate** that should vanish: `hide_offscreen = true` on the group (the default), `clamped = false` on the tracker.
   - An **off-screen indicator**: the mirror — `hide_offscreen = false`, `clamped = true`, `viewport_margin` to inset the edge. `KitHudIndicator` reads the group's `is_target_in_view` to hide itself while the entity can be seen.
   - An entity that wants **both** carries two anchors pointing at two group scenes. That is explicit and rare.

   `offset`, `clamped` and `viewport_margin` all belong to the group's `KitWorldTracker`, beside the layout they affect.

6. **Verify.** Run the checker and GUT (see AGENTS.md Commands). If the entity is placed in a map scene at author time rather than spawned, that is the ordering path from step 2 — confirm it on a live game with the `run-game` skill, where `godot-bridge call hud` reports every mounted group, its screen position, and each element's rect.

## Gotchas

- **A clamped group must size its root to its content.** The tracker insets the viewport edge by the host's half-extent, so a zero-sized root pins to the wrong place.
- **Numbers are parented to the layer, not the group**, so they stay where they were spawned instead of riding the entity. That is deliberate; do not reparent them.
- **Re-parenting an entity frees and rebuilds its group**, losing element state. Move the entity within one map rather than across.
- Colors, fonts and box art are **theme type variations** — `hud_bar`, `hud_bar_ghost`, `hud_number` and `hud_number_crit`, in the game's theme at `gui/theme/custom`. Timing, curves and motion are the element's **style `Resource`**. That line is where Godot itself draws it: the theme system expresses the first and cannot express the second.

## Key reference files

- `addons/kit/ui/hud/group.gd` — `KitHudGroup`, `_bind_elements`, `of`, `make_world_origin`, `project_target`
- `addons/kit/ui/hud/anchor.gd`, `anchor_2d.gd`, `anchor_3d.gd` — the anchor and its typed `target`
- `addons/kit/ui/hud/layer.gd` — what the layer is, and is not
- `addons/kit/ui/hud/group_2d.tscn`, `group_3d.tscn` — the scenes to inherit
- `addons/kit/ui/hud/bar/`, `numbers/`, `indicator/` — the stock elements and their style resources
- `ui/hud/layer_test.gd`, `group_test.gd` in `coffeebeats/godot-plugin-kit` — the wiring, built by hand, as executable reference; tests do not ship in `addons/kit`
- `addons/kit/ui/tracker/world_tracker.gd` — the tracker's own exports and signals
- To add a new **kind** of element rather than use a stock one, use the `add-hud-element` skill.
