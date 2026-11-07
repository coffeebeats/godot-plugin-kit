# Panel parts

A panel is a menu over the world, such as a build or context menu. A game places `ui/panel/panel.tscn`, or `ui/panel/world_panel_2d.tscn` or `ui/panel/world_panel_3d.tscn` to follow a point in the world, as the root [README](../../README.md#put-ui-inside-gameplay) describes, and puts the parts below inside it. Paths are relative to the addon's root.

## Menu rows

`ui/panel/menu_rows.tscn` is a `VBoxContainer` for a panel's rows of buttons, such as a build menu's items. Put it inside the panel and the rows inside it, each one of kit's buttons or an [action button](../../README.md#add-an-action-button). When the player navigates by key or gamepad, focus starts on the first row that can take it, passing over a hidden or disabled one, however the game adds or orders the rows.

Each row's `FocusHandler` becomes a focus anchor, ranked by the row's place, so the game sets no `use_as_anchor` or `focus_anchor` on a row. In a panel without `menu_rows.tscn`, focus starts on the button whose `FocusHandler` has `use_as_anchor` on, which an action button sets from its own `focus_anchor` export.
