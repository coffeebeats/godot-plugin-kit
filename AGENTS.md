# AGENTS.md

Godot 4+ addon of opinionated game infrastructure assembled from `godot-plugin-std`: platform services (storefront, profile, logging), the audio, input, save and settings systems, menus, UI and map templates. Games consume the `dist` branch as `addons/kit`. `README.md` describes every scene a game places and each value it sets on them.

## Commands

```bash
# Format check (settings in `.gdformatrc`)
uv run gdformat --check .

# Lint (settings in `.gdlintrc`)
uv run gdlint .

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit

# Check project files for problems a normal load does not surface (settings in
# `.gdcheckrc`). From the `godot` agent plugin: on Claude's PATH, and elsewhere
# through that plugin's `godot-check` skill.
godot-check

# Regenerate and check the translations after editing `locale/messages.pot` or
# `locale/en_US.po`, the only two catalogue files edited by hand. From the same
# plugin: on Claude's PATH, and elsewhere through its `godot-locale` skill.
LOCALE_DIR=locale godot-locale update
LOCALE_DIR=locale godot-locale validate
```

## Design

- A game uses kit's scenes in place and sets its own values on the instances it places, never by editing kit. Slice scenes so that holds, and list each value a game sets in `README.md`.
- Kit's docs, comments and skills stay generic. Never name a particular game or project template; refer to a game's files as "usually `project/...`".
- `plugins/kit/` is the agent plugin released with the addon, holding the game skills and `godot-bridge`.

## Code Style

Follows the GDScript style guide and `godot-plugin-std`'s conventions:

- Lines are limited to 88 characters.
- A file opens with a `##` block that names its class and says what it does, then uses std's section banners in std's order, omitting empty ones. Overrides go in `ENGINE METHODS (OVERRIDES)` or `PRIVATE METHODS (OVERRIDES)`, and methods are alphabetized within a section.
- Global class names take the `Kit` prefix, private members `_`, and StringName literals `&`.
- Use `##` for public API docs and `# NOTE:` for what a reader must know before touching the code.
- Translation keys take the `kit_` prefix.

### Coroutines

Kit is never the top level of a game, since a game calls into all of it, so kit doesn't `await` outside GUT test methods. An `await` splits a function across frames, which makes its logic hard to follow, and every caller that wants the result has to await it in turn, which lands the `await` in code that never expected to wait. Using it correctly is subtle even where it belongs:

- The engine never awaits a callback such as `_ready`. The node's `ready` signal fires, and the frame moves on, before the rest of the callback runs, so keep `await` out of engine callbacks.
- Code after an `await` runs in a changed world. Its node may have left the tree or been freed while it waited, so check it again before using it.
- A coroutine called without `await` returns at once without waiting. The `missing_await` warning catches only a direct, typed call, never one through a `Callable`.

Report progress with a status getter paired with a signal, as `is_node_ready()` pairs with `ready` and the save system's `are_slots_loaded()` with `slots_loaded`, and let the game check the getter before awaiting the signal, since a signal that already fired won't fire again.

## Testing

Tests use GUT. Test files end in `_test.gd` and live beside the code they test, and test cases are named `test_<subject>_<scenario>_<expectation>`. Annotate each logical atom with its own one-line `# Given:`, `# When:` or `# Then:` comment. Where kit ships a scene, test through that scene rather than a hand-built copy.

## Commits

Use Conventional Commits, for example `feat(input): add gamepad rumble support`. Pull requests squash-merge with the PR title as the commit, and release-please reads that title, so its type picks the version bump.
