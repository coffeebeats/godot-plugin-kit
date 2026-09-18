---
name: add-save-field
description: Add a new field to the save data system. Handles both adding fields to existing StdConfigItem classes and creating entirely new config items with full scaffolding.
user-invocable: true
argument-hint: "<config_item> <field_name> <type>"
---

Add a field to the save data system. The field can be added to an existing `StdConfigItem` or a new one can be created. The `type` must be one supported by the `Config` class: `bool`, `float`, `int`, `String`, `Vector2`, `PackedInt64Array`, `PackedStringArray`, `PackedVector2Array`.

## Find the game's schema

The `[autoload]` entry named `System` in `project.godot` names the system scene — `project/main/system.tscn` in a repository created from the template, which also fixes the game's source root as `project/`. The `schema` property on its `Saves` instance points at the game's save schema resource, and **that resource's directory holds every config item below**: `project/save/` in the template, whose schema class is `ProjectSaveData`.

## Steps

1. **Read the current schema** to understand existing structure:
   - the schema's `data.gd` — the save data class with `@export` vars for each config item
   - the schema's `data.tres` — resource wiring (ext_resource + property assignments)
   - All `.gd` files beside it — existing `StdConfigItem` subclasses

2. **Determine target config item.** Check if the provided config item name exists.

3. **If adding to an existing `StdConfigItem`**, add an `@export var` to the class:

   ```gdscript
   ## description is a brief explanation of the field.
   @export var field_name: Type = default_value
   ```

   Place it in the `CONFIGURATION` section, following existing field ordering.

4. **If creating a new `StdConfigItem`**, scaffold all required files:

   a. Create the `.gd` script at `project/save/<item_name>.gd` following the pattern in `project/save/example.gd`:

   ```gdscript
   ##
   ## project/save/<item_name>.gd
   ##
   ## <ClassName> is a collection of <description> properties.
   ##

   class_name <ClassName>
   extends StdConfigItem

   # -- CONFIGURATION ------------------------------------------------------------------- #

   ## field_name is a brief explanation of the field.
   @export var field_name: Type = default_value

   # -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


   func _get_category() -> StringName:
   	return "<item_name>"
   ```

   Match the prefix the game's existing config items use, giving `<Prefix><PascalCaseName>Data` (e.g., `ProjectPlayerData` where the schema class is `ProjectSaveData`).

   b. Run `godot --import --headless` to generate the UID for the new script.

   c. Create the `.tres` resource at `project/save/<item_name>.tres` following the pattern in `project/save/example.tres`. Look up the generated UID from `.godot/uid_cache.bin` or by running import and checking the generated `.uid` file:

   ```
   [gd_resource type="Resource" script_class="<ClassName>" format=3 uid="uid://..."]

   [ext_resource type="Script" uid="uid://..." path="res://project/save/<item_name>.gd" id="1_xxxxx"]

   [resource]
   script = ExtResource("1_xxxxx")
   ```

   d. Add an `@export` var to `project/save/data.gd`:

   ```gdscript
   ## item_name contains <description> data.
   @export var item_name := <ClassName>.new()
   ```

   e. Wire the new resource into `project/save/data.tres` by adding an `ext_resource` entry for the `.tres` file and assigning the property in the `[resource]` section.

5. **Run `godot --import --headless`** to validate the changes compile.

6. **Handle schema versioning** (only if the current version in `data.tres` is > 0):

   a. Bump the `version` field in `data.tres`.

   b. Create a `StdConfigSchemaMigration` script at `project/save/migration_v<N>.gd` that extends `StdConfigSchemaMigration` and overrides `_migrate()`. For new fields, the migration is typically a no-op (old saves just get the default value), but it documents the schema change.

   c. Create a `.tres` for the migration with `version_from` set to the old version number.

   d. Add the migration resource to the `migrations` array in `data.tres`.

   e. Regenerate golden files: `TEST_GENERATE_GOLDENS=1 godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit`

   If the version is `0`, skip this step — version 0 indicates rapid iteration mode where no migrations are needed.

## Supported types

| GDScript type        | Config getter      | Config setter      |
| -------------------- | ------------------ | ------------------ |
| `bool`               | `get_bool`         | `set_bool`         |
| `float`              | `get_float`        | `set_float`        |
| `int`                | `get_int`          | `set_int`          |
| `String`             | `get_string`       | `set_string`       |
| `Vector2`            | `get_vector2`      | `set_vector2`      |
| `PackedInt64Array`   | `get_int_list`     | `set_int_list`     |
| `PackedStringArray`  | `get_string_list`  | `set_string_list`  |
| `PackedVector2Array` | `get_vector2_list` | `set_vector2_list` |

## Key reference files

- the schema's `example.gd` — canonical `StdConfigItem` pattern
- the schema's `example.tres` — resource wiring pattern
- the schema's `data.gd` — the save data class
- the schema's `data.tres` — schema resource with ext_resource entries, version, migrations
- `addons/std/config/config.gd` — `Config` class with supported type accessors
- `addons/std/config/schema/migration.gd` — `StdConfigSchemaMigration` base class
- `script_templates/Resource/resource.gd` — section header template
