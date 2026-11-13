# Changelog

## 4.1.3 (2026-11-13)

## What's Changed
* fix(save): report a save that fails on a full disk, and keep the slot as it was by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/151


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v4.1.2...v4.1.3

## 4.1.2 (2026-11-12)

## What's Changed
* fix(lifecycle): make `Lifecycle` a subclass of std v10.1's `StdLifecycle` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/148
* fix(menu): free the pause and save menus' dialogs on a shutdown, not on a close request a game may cancel by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/150


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v4.1.1...v4.1.2

## 4.1.1 (2026-11-12)

## What's Changed
* fix(menu): stop the controller tab erroring at quit by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/146


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v4.1.0...v4.1.1

## 4.1.0 (2026-11-12)

## What's Changed
* fix(menu): stop the settings menu hanging the screen loader at boot by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/140
* fix: replace kit's scene and resource preloads with exports set in its own scenes, so a threaded load can't deadlock by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/141
* chore: document the preload rule in AGENTS.md and exclude GUT tests from the `preload` checker rule by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/145
* feat(menu): keep the settings menu in the tree and load through `StdLoader`, for std v10 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/143


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v4.0.0...v4.1.0

## 4.0.0 (2026-11-11)

## What's Changed
* chore(addons)!: bump `std` to v8.0.0 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/113
* feat(input)!: add `menu_options_layers` and validate kit's and the game's action sets by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/115
* feat(input)!: add `glyph_sets` and draw keys from one keycap resource by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/116
* feat(ui): add panel scenes and `KitWorldTracker.flip_at_edges` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/117
* feat(input)!: add `unknown_glyph` and draw "??" for buttons with no art by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/118
* feat(input)!: add Back art, layered glyph sets and positional PlayStation prompts by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/119
* feat(ui): add `alert_gameplay.tscn`, an alert to open over gameplay by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/120
* feat(ui)!: add `KitInputActionButton` and rebuild `KitInputGlyph` over std's glyph texture by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/121
* feat(ui)!: fill the game's theme from kit's base theme and rename its variations to PascalCase by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/122
* feat(menu): add `menu_setting_overrides`, so a game shows or hides kit's settings menu rows by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/124
* chore(addons): bump `std` to v8.1.0 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/125
* feat(ui): add `menu_rows.tscn`, a panel's rows whose first usable one takes focus by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/123
* feat(menu): add an Accessibility tab where the player picks how holds are performed by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/126
* chore(addons)!: bump `std` to v9.0.0 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/130
* refactor(locale): name the rebinder's placeholders, as the action button's are by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/132
* feat(input): show a hold's state on `KitInputActionButton` and draw action glyphs larger by default by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/131
* feat(input): add `origin_names`, naming each button and key a prompt shows for screen readers by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/133
* chore(locale): clear two fuzzy German guesses for origin names by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/134
* feat(input): draw and name each Joy-Con's own buttons, and add Home, Capture and Steam button art by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/137
* feat(setting)!: default the language to the one Steam has for the game, and always save a pick by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/138
* chore(storefront): correct why one Steam language gives no choice by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/139


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v3.0.1...v4.0.0

## 3.0.1 (2026-11-01)

## What's Changed
* docs(readme): point the marketplace ref at v3 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/108
* chore(deps-dev): bump ruff from 0.17.2 to 0.17.3 in the python group by @dependabot[bot] in https://github.com/coffeebeats/godot-plugin-kit/pull/107
* chore(deps): bump astral-sh/setup-uv from 10.3.2 to 10.3.3 in the github-actions group by @dependabot[bot] in https://github.com/coffeebeats/godot-plugin-kit/pull/106
* fix(input): label the `Splash` and `MenuOptions` actions by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/111
* chore(addons): bump `std` to v7.2.0 and `GodotSteam` to latest by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/112


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v3.0.0...v3.0.1

## 3.0.0 (2026-10-27)

## What's Changed
* feat(input)!: give each device its own controls tab and drop the menu navigation layer by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/82


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v2.0.2...v3.0.0

## 2.0.2 (2026-10-27)

## What's Changed
* chore(ci): update Python tooling with Dependabot by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/69
* chore(ci): group Dependabot updates by ecosystem by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/73
* chore(addons): bump `std` to v7.1.1 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/79
* chore(deps-dev): bump ruff from 0.16.7 to 0.17.2 by @dependabot[bot] in https://github.com/coffeebeats/godot-plugin-kit/pull/72
* chore(deps): bump astral-sh/setup-uv from 10.2.0 to 10.3.2 by @dependabot[bot] in https://github.com/coffeebeats/godot-plugin-kit/pull/71
* chore(addons): bump `std` to v7.1.2 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/81


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v2.0.1...v2.0.2

## 2.0.1 (2026-10-25)

## What's Changed
* fix(map): name no 3D class in the base map so a 2D-only export parses by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/67


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v2.0.0...v2.0.1

## 2.0.0 (2026-10-24)

## What's Changed
* fix(input): size a keyboard glyph to its label's padded box by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/61
* feat(debug): accept `&"…"` and `^"…"` literals in the bridge's `eval` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/63
* feat(debug): add the bridge's `press` and `click` commands by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/64
* chore(addons)!: bump `std` to v7.1.0 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/65
* chore(menu): cover the rebinder's bind, cancel and device-switch paths by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/66


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.5.0...v2.0.0

## 1.5.0 (2026-10-16)

## What's Changed
* chore(deps): bump astral-sh/setup-uv from 10.0.1 to 10.2.0 by @dependabot[bot] in https://github.com/coffeebeats/godot-plugin-kit/pull/56
* chore(deps): bump addons/std from `c873bb1` to `e4edf19` by @dependabot[bot] in https://github.com/coffeebeats/godot-plugin-kit/pull/55
* feat(input): ship the menu's navigation actions as a layer any set may enable by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/58

## New Contributors
* @dependabot[bot] made their first contribution in https://github.com/coffeebeats/godot-plugin-kit/pull/56

**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.4.1...v1.5.0

## 1.4.1 (2026-09-22)

## What's Changed
* fix(bridge): judge a launch by the game's exit, not every ERROR it logs by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/53


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.4.0...v1.4.1

## 1.4.0 (2026-09-22)

## What's Changed
* feat(skills): support Codex in the kit plugin by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/51


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.3.4...v1.4.0

## 1.3.4 (2026-09-22)

## What's Changed
* fix(storefront): pick each module's implementation from the build's storefront by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/48
* fix(input): default `get_active_device` and `get_input_slot` to the first player by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/49


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.3.3...v1.3.4

## 1.3.3 (2026-09-22)

## What's Changed
* fix(storefront): start Steam under the game's app ID instead of app 1 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/46


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.3.2...v1.3.3

## 1.3.2 (2026-09-22)

## What's Changed
* chore(claude): add an AGENTS.md with kit's conventions by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/44


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.3.1...v1.3.2

## 1.3.1 (2026-09-21)

## What's Changed
* chore(addons): bump `std` to v6.1.2 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/42


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.3.0...v1.3.1

## 1.3.0 (2026-09-21)

## What's Changed
* feat(modules): report whether each module loaded through a `KitModule` base class by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/40


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.2.2...v1.3.0

## 1.2.2 (2026-09-21)

## What's Changed
* fix: log through `StdLogger` rather than the engine's output functions by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/38


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.2.1...v1.2.2

## 1.2.1 (2026-09-20)

## What's Changed
* chore(test): separate each given/when/then block with a blank line by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/36


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.2.0...v1.2.1

## 1.2.0 (2026-09-20)

## What's Changed
* feat(debug): report state by walking the tree instead of registering handlers by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/33


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.1.1...v1.2.0

## 1.1.1 (2026-09-19)

## What's Changed
* docs(readme): point plugin setup trouble at godot-infra's caveats by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/31


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.1.0...v1.1.1

## 1.1.0 (2026-09-19)

## What's Changed
* feat(input): drop the Steam Input manifest from the input system by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/29


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.0.1...v1.1.0

## 1.0.1 (2026-09-19)

## What's Changed
* chore(release): drop the 1.0.0 override by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/27


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v1.0.0...v1.0.1

## 1.0.0 (2026-09-19)

## What's Changed
* feat(premade): ship the platform and system assemblies by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/25


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.8...v1.0.0

## 0.1.8 (2026-09-19)

## What's Changed
* fix(locale): fall back to the project's fallback locale for untranslated actions by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/23


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.7...v0.1.8

## 0.1.7 (2026-09-18)

## What's Changed
* docs(debug): point the bridge test's header at 'godot-bridge' by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/21


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.6...v0.1.7

## 0.1.6 (2026-09-18)

## What's Changed
* feat(claude): ship the game skills and the bridge as an agent plugin by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/19


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.5...v0.1.6

## 0.1.5 (2026-09-17)

## What's Changed
* fix(menu): require a screen manager and guard the screens library by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/15
* fix(save): let the save system's own default set the slot count by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/17


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.4...v0.1.5

## 0.1.4 (2026-09-17)

## What's Changed
* feat: move the Godot splash screen into kit by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/11
* feat: ship ready-to-use settings, save and pause menus by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/12


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.3...v0.1.4

## 0.1.3 (2026-09-17)

## What's Changed
* feat: move 'Locales', 'Lifecycle' and the menu action sets into kit by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/7
* feat: move the UI layer and the base map scenes into kit by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/8


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.2...v0.1.3

## 0.1.2 (2026-09-17)

## What's Changed
* fix(ci): stop publishing the project icon to 'dist' by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/5


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.1...v0.1.2

## 0.1.1 (2026-09-17)

## What's Changed
* chore: replace the template's scaffolding with kit's dependencies by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/1
* feat: move the platform and system layers into kit by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/3
* fix: make kit configurable from the consumer's own scenes by @coffeebeats in https://github.com/coffeebeats/godot-plugin-kit/pull/4

## New Contributors
* @coffeebeats made their first contribution in https://github.com/coffeebeats/godot-plugin-kit/pull/1

**Full Changelog**: https://github.com/coffeebeats/godot-plugin-kit/compare/v0.1.0...v0.1.1

## Changelog
