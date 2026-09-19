---
name: add-translation
description: Add a new translatable string to the project. Use when adding UI elements, buttons, labels, or any user-facing text that needs localization.
user-invocable: true
argument-hint: "<msgid_key> <English text>"
---

Add a translatable string to the game. Only edit two files: `messages.pot` and `en_US.po` in the game's catalogue. Other locale files are updated automatically by a propagation command, and editing one by hand corrupts it: every other `.po` keys off the **English text** as its `msgid`, not the key-based one these two use, and `poswap` performs that swap during propagation. Binary `.mo` files are compiled by CI — do not edit them.

## Find the catalogue

`locale/translations` in `project.godot` lists every `.mo` the game loads. The game's catalogue is the directory holding the **first entry that is not under `addons/`**, usually `project/locale/`.

## Kit's strings

Strings kit's own scenes emit take a `kit_` prefix and live in `addons/kit/locale/`, a submodule: never edit it. To reword a kit string, or to translate it into a language kit does not ship, add the same key and `msgctxt` to the game's catalogue. `locale/translations` lists the game's `.mo` files before kit's, so the game's entry wins.

When a kit update adds a language, append its `addons/kit/locale/<lang>.mo` to `locale/translations`, after every game entry. A `translations_test.gd` asserting the listing is complete fails until it is there.

## Prerequisites

Steps 4–5 run `godot-locale`, which the `godot` plugin from `godot-infra` puts on `PATH`. It needs `msgfmt` and `msgmerge` from `gettext`, and `uv`, which fetches `poswap` for it. If any is missing, stop and point the user at the README's setup section rather than guessing at an install command.

## Translation file format

Both files use **key-based `msgid`** values (e.g., `main_play`, `options_gameplay`). Keys follow a hierarchical `snake_case` convention matching the UI location (e.g., `main_` for main menu, `options_` for the game's settings tabs, `error_` for error dialogs).

Each entry has a `#.` translator comment explaining what the string is and where it appears. If the string needs disambiguation, add a `msgctxt` line (see existing `button_prompt` and `actions_*` entries for examples).

## Steps

1. **Read both files** to find the correct insertion point. Place the new entry near related entries (group by UI area). Match the surrounding whitespace in each file — `messages.pot` uses extra blank lines between section groups while `en_US.po` uses single blank lines throughout.

2. **Edit `messages.pot`** — add the entry with an empty `msgstr`:

   ```po
   #. Description of the string for translators, including where it appears.
   msgid "my_new_key"
   msgstr ""
   ```

3. **Edit `en_US.po`** — add the same entry with the English text as `msgstr`:

   ```po
   #. Description of the string for translators, including where it appears.
   msgid "my_new_key"
   msgstr "My English Text"
   ```

4. **Propagate to other locales** by running:

   ```sh
   godot-locale update
   ```

5. **Validate** all translation files:

   ```sh
   godot-locale validate
   ```

   `validate` also checks that each translation keeps the placeholders its English text declares, so a `%s` dropped from a translated string fails here.

Set `LOCALE_DIR` for both commands where the catalogue is not `project/locale`.

## Reference the key

Use the **key-based `msgid`** (not the English text) when referencing the string:

- In `.tscn` scene files: set `text = "my_new_key"`
- In GDScript: `tr("my_new_key")`
