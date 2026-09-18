---
name: add-hud-element
description: Add a new kind of HUD element — a status icon strip, a cast bar, a stack counter — alongside the stock KitHudBar, KitHudNumbers and KitHudIndicator. Use when no stock element fits; to place existing elements on an entity, use add-entity-hud instead.
user-invocable: true
argument-hint: "<element_name> [what it shows]"
---

A HUD element is a plain `Control` with its own typed API, its tunables in a style `Resource`, and its colors from a theme type variation. There is **no shared base class**, because nothing is common enough to justify one — so a new kind needs no change to `KitHudLayer`, `KitHudGroup` or any other element, and cannot be blocked by one.

Before starting, check that a stock element with a different style resource does not already do this. Damage and critical numbers are one element with two styles, not two elements.

## Steps

1. **Create the directory** `project/ui/hud/<element>/` holding `<element>.gd`, `<element>.tscn`, `style.gd` and at least one preset `.tres`. Copy the shape from `addons/kit/ui/hud/bar/`, which is the smallest complete example; `addons/kit` itself is a submodule and never gains an element.

2. **Write the element script** as `class_name Hud<Name> extends Control`, using the `Node` script template. Its public API is whatever the *game* would want to say — `set_value(value, max_value)`, `pop(value)` — named for the thing it shows, not for the channel it arrives on.

   Two rules bind every element, both because breaking them fails silently:

   - **Public methods must work before the element's own `_ready`.** An entity placed in a map scene at author time calls them from a `_ready` that runs first, so an element resolving its children with `@onready` must guard on `is_node_ready()` and apply the value when it is ready. `KitHudBar.set_value` is the worked example, and kit's `ui/hud/bar/bar_test.gd:test_value_set_before_ready_is_applied` is the test to copy.
   - **Find the group with `KitHudGroup.of(self)`, never `owner`.** `owner` names the root of the scene the element was *saved* in, which stops being the group the moment the element sits inside a sub-scene reused across several groups. Kit's `ui/hud/group_test.gd:test_of_finds_the_group_from_an_element_it_does_not_own` covers it.

3. **Split appearance from behavior.** This is the dividing line Godot itself draws:

   | Goes in the theme type variation | Goes in the style `Resource` |
   | --- | --- |
   | Colors, fonts, styleboxes, icons | Durations, delays, curves, distances, easing |
   | Anything `Theme` can express | Anything it cannot |

   Add the variation to the game's theme (`gui/theme/custom` in `project.godot`), named `hud_<element>`, following `hud_bar` and `hud_number`. Write `style.gd` as `class_name Hud<Name>Style extends Resource` using the `Resource` script template, with one `@export` per tunable and a doc comment saying what it does in feel terms, not in units. Ship at least one preset `.tres`.

   Use `StdTweenCurve` for any curve export — `KitHudBarStyle.drain` and `KitHudNumberStyle.motion` both do, and it carries the delay as well as the easing.

4. **Render with no art.** Every stock element draws from theme boxes, `ProgressBar`s or `_draw`, so kit ships no textures. Follow that where the element allows, so it stays legible under any theme.

5. **Reach world space through the group, never the layer's `Variant` API.** If the element needs a screen position:

   - `KitHudGroup.make_world_origin()` returns a `Callable` that freezes the entity's world point and re-projects it on every call — what keeps a floating number over the spot it came from while the camera pans.
   - `KitHudGroup.project_target()` returns the entity's live, **unclamped** projection — what an arrow pinned to the viewport edge points along. Reading the element's own rect instead gives where it *is*, not where it should point, which is a bug `KitHudIndicator` shipped once.

   Both keep the dimension-blind `Variant` handling in one place. `KitHudLayer.of(self)` is still the way to reach `get_screen_rect()`, and to parent something that must outlive the group.

6. **Write the test** as `project/ui/hud/<element>/<element>_test.gd`, in the fixture shape of kit's `bar_test.gd` — map double, `SubViewportContainer`, `SubViewport`, a later `UI` sibling holding the layer. Cover the API, the pre-`_ready` call from step 2, and whatever the style resource is supposed to change.

7. **Verify.** `gdformat --check`, `gdlint`, `godot-check`, then GUT (see AGENTS.md Commands). For anything whose point is how it looks or moves, confirm it on a live game with the `run-game` skill; `godot-bridge call hud` reports every element's class, rect and visibility.

8. **List the element** in the stock-element table of the `add-entity-hud` skill, so the next session placing a HUD finds it without reading the directory. `AGENTS.md` names no elements and does not change.

## Key reference files

- `addons/kit/ui/hud/bar/` — the smallest complete element: script, scene, style, preset, test
- `addons/kit/ui/hud/numbers/` — an element that spawns its own nodes and needs world space
- `addons/kit/ui/hud/indicator/` — an element that draws itself and reads group state
- `addons/kit/ui/hud/group.gd` — `of`, `make_world_origin`, `project_target`, `is_target_in_view`
- `addons/kit/ui/hud/layer.gd` — `of`, `get_screen_rect`, and why the layer holds no game vocabulary
- the game's theme — the `hud_*` type variations
- `coffeebeats/godot-plugin-kit` — the elements' tests, which do not ship in `addons/kit`
- `addons/std/tween/curve.gd` — `StdTweenCurve`
- `script_templates/Node/node.gd`, `script_templates/Resource/resource.gd` — the file shapes
