# Menu parts

Kit's menus are built from the dialogs and pieces in this folder. A game places a dialog and sets the values below on its instance, or assembles a dialog of its own from the same parts. Paths are relative to the addon's root.

## Alert dialog

`ui/menu/alert.tscn` is `KitAlertDialog`, a modal with a title, a message and up to two buttons, which pushes itself onto a screen stack. The game calls `open` with the `StdScreenManager` to push onto and connects `closed`, which carries `PRIMARY` or `SECONDARY` for the button pressed, or `DISMISS` when the player cancelled or the dialog left the stack any other way. Its screen caches the instance, so the dialog survives closing and can open again; whatever made it frees it.

| Export | Value |
| --- | --- |
| `title`, `message` | Locale keys for the title and message, each hidden while empty. |
| `primary_label`, `secondary_label` | Locale keys for the two buttons, Okay and Cancel by default. They are translated in the `alert` context, so the game's catalogue lists its own under `msgctxt "alert"`. The secondary button is hidden while its label is empty. |
| `dismissable` | Whether `ui_cancel` closes the dialog with `DISMISS`, on by default. |
| `screen` | The `StdScreen` it pushes, one per instance, holding its transition, attachments and input settings. |

## Alert over gameplay

`ui/menu/alert_gameplay.tscn` is the alert to open from gameplay, for a match's result, a game over or a disconnect. A map instantiates it, sets its values, connects `closed` and calls `open` with the `StdScreenManager` that pushed the map. Until the game sets them, its primary button reads Continue and its secondary is hidden. `closed` carries `DISMISS` when the dialog leaves the stack without a button, such as when the player returns to the main menu from the pause menu over it, so the game acts only on `PRIMARY` and `SECONDARY`.

It changes these values from `alert.tscn`, and a dialog for gameplay built from other parts needs each of them:

| Value | Why |
| --- | --- |
| `screen.transition`, a 0.25 s fade | The transition blocks input until it ends, so a key the player pressed as the match ended doesn't press a button. |
| `screen.attachment_scenes`, holding `menu/pause/pusher.tscn` | The pause key opens the pause menu over the dialog, so quitting and returning to the main menu still work. |
| The loader's `action_set_layers`, holding `system/input/actions/menu_options.tres` | The dialog loads kit's `Menu` set, which lacks `ui_toggle_menu`, so without this layer the pause key never reaches the pusher. |
| `dismissable`, off | A gamepad's back button would otherwise close the dialog before the player chooses. |
| `screen.cache_instance`, off | The dialog frees itself once it closes, so a map makes a new one each time. |
| The secondary button's `FocusHandler`, not an anchor | Focus starts on the primary button. |
