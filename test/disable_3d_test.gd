##
## test/disable_3d_test.gd
##
## Tests that no script kit ships to every game names a 3D class, since an engine built
## with `disable_3d` registers none and fails to parse a script naming one, along with
## every script depending on it. The 3D-only scripts, under `map/3d` or named `*_3d.gd`,
## are left out, and the classes they declare count as 3D classes, as do paths to them
## in `extends` or `preload`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ALLOWED_3D are the classes named with `3D` that an engine built with `disable_3d`
## still registers as of 4.7.2-stable, in the core, the `noise` and `visual_shader`
## modules, or outside the `_3D_DISABLED` blocks of `scene/register_scene_types.cpp`.
const _ALLOWED_3D: Array[StringName] = [
	&"AStar3D",
	&"CompressedTexture3D",
	&"Geometry3D",
	&"ImageTexture3D",
	&"NoiseTexture3D",
	&"PlaceholderTexture3D",
	&"Texture3D",
	&"Texture3DRD",
	&"VisualShaderNodeSample3D",
	&"VisualShaderNodeTexture3D",
	&"VisualShaderNodeTexture3DParameter",
]

## _DIR_3D_ONLY holds the 3D map template, which only a 3D game loads.
const _DIR_3D_ONLY := "res://map/3d"

## _PREFIXES_3D begin the names of classes whose modules `disable_3d` leaves out; `gltf`
## and `fbx` build only without it, and XR, `openxr` included, goes with the
## `disable_xr` it implies (see the engine's `SConstruct` and `modules/*/config.py`).
const _PREFIXES_3D: Array[String] = ["FBX", "GLTF", "OpenXR", "XR"]

## _ROOTS_3D are the classes `disable_3d` leaves out, each along with every class
## inheriting from it, whose families the name match misses in part; see the 4.7.2
## `_3D_DISABLED` blocks of the engine's `scene/register_scene_types.cpp`.
const _ROOTS_3D: Array[StringName] = [
	&"FogMaterial",
	&"ImporterMesh",
	&"LightmapGIData",
	&"Lightmapper",
	&"MeshLibrary",
	&"Node3D",
	&"PanoramaSkyMaterial",
	&"PhysicalSkyMaterial",
	&"PrimitiveMesh",
	&"ProceduralSkyMaterial",
	&"Skin",
	&"SkinReference",
	&"VoxelGIData",
	&"WorldEnvironment",
]

## _SKIPPED_DIRS are the directories holding no script kit ships; `addons` holds
## vendored plugins, and `dist` leaves out `plugins` (see
## `.github/workflows/release-please.yaml`).
const _SKIPPED_DIRS: Array[String] = ["res://addons", "res://plugins"]

## _SUFFIX_3D_ONLY ends the name of each script only a 3D game loads.
const _SUFFIX_3D_ONLY := "_3d.gd"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _classes_3d := {}

# NOTE: A name right after `$`, `%` or `/` names a node in a node path, not a class, so
# it is skipped; gdformat spaces the `%` and `/` operators, so no class name sits there.
# A path spaced as `$ Name` or `$A / Name` is left out, since gdformat never writes it.
var _identifier := RegEx.create_from_string("(?<![$%/\\w])[A-Za-z_][A-Za-z0-9_]*")

# NOTE: Each alternative starts where its literal or comment starts, so the leftmost
# match is always the outermost one, and a `#` inside a string is never a comment.
var _literal_or_comment := RegEx.create_from_string(
	(
		'"""[\\s\\S]*?"""|\'\'\'[\\s\\S]*?\'\'\'|"(?:\\\\.|[^"\\\\\\n])*"'
		+ "|'(?:\\\\.|[^'\\\\\\n])*'|#[^\\n]*"
	)
)

# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	for candidate in ClassDB.get_class_list():
		if _is_3d_class(candidate):
			_classes_3d[StringName(candidate)] = true

	for entry in ProjectSettings.get_global_class_list():
		if _is_3d_class(entry["class"]) or _is_3d_only_script(entry["path"]):
			_classes_3d[StringName(entry["class"])] = true


# -- TEST METHODS -------------------------------------------------------------------- #


func test_class_lists_on_full_build_name_existing_classes() -> void:
	# Given: The classes the lists above name.
	var named: Array[StringName] = []
	named.append_array(_ALLOWED_3D)
	named.append_array(_ROOTS_3D)

	# Then: Each exists in the running engine, so a misspelled entry can't match nothing.
	for entry in named:
		assert_true(ClassDB.class_exists(entry), "missing class: %s" % entry)


func test_classes_3d_on_full_build_cover_3d_classes_and_spare_kept_ones() -> void:
	# Given: The 3D classes `before_all` found in the running engine's class list.

	# Then: Each kind of 3D class is present, and classes 2D builds keep are absent.
	assert_has(_classes_3d, &"Node3D")
	assert_has(_classes_3d, &"Camera3D")
	assert_has(_classes_3d, &"BoxShape3D")
	assert_has(_classes_3d, &"NavigationAgent3D")
	assert_has(_classes_3d, &"PhysicsServer3D")
	assert_has(_classes_3d, &"WorldEnvironment")
	assert_has(_classes_3d, &"GridMap")
	assert_has(_classes_3d, &"XRServer")
	assert_has(_classes_3d, &"GLTFDocument")
	assert_does_not_have(_classes_3d, &"Node2D")
	assert_does_not_have(_classes_3d, &"Texture3D")
	assert_does_not_have(_classes_3d, &"AStar3D")


func test_classes_3d_on_full_build_cover_kit_3d_only_classes() -> void:
	# Given: The 3D classes `before_all` found in the project's global classes.

	# Then: Each class a 3D-only script declares is present, and its 2D twin is absent.
	assert_has(_classes_3d, &"KitMap3D")
	assert_has(_classes_3d, &"KitHudLayer3D")
	assert_has(_classes_3d, &"KitWorldTracker3D")
	assert_does_not_have(_classes_3d, &"KitMap2D")
	assert_does_not_have(_classes_3d, &"KitHudLayer2D")
	assert_does_not_have(_classes_3d, &"KitWorldTracker2D")


func test_find_3d_names_in_source_ignores_comments_and_strings() -> void:
	# Given: A source naming 3D classes only in comments, strings and node paths.
	var lines := [
		"## Node3D in a doc comment.",
		'var a := node.is_class(&"Node3D")  # Node3D in a comment',
		'var b := \'Camera3D\' + "# not a comment" + """',
		"Node3D in a multiline string",
		'"""',
		"var c := $Camera3D",
		"var d := %Camera3D",
		"var e := $A/Camera3D",
		"var f := $/root/Camera3D",
		'var g := $"A"/Camera3D',
		"var h := $A/%Camera3D",
	]
	var source := "\n".join(lines)

	# When: The source is searched for 3D class names.
	var found := _find_3d_names(source)

	# Then: Nothing is found.
	assert_eq(found, PackedStringArray())


func test_find_3d_names_in_source_finds_type_uses() -> void:
	# Given: A source naming 3D classes as types, past a string holding a `#`.
	var lines := [
		'var s := "#"',
		"if child is Node3D:",
		"var camera: Camera3D = null",
		"var layer := KitHudLayer3D.new()",
	]
	var source := "\n".join(lines)

	# When: The source is searched for 3D class names.
	var found := _find_3d_names(source)

	# Then: Each name is found.
	assert_eq(found, PackedStringArray(["Node3D", "Camera3D", "KitHudLayer3D"]))


func test_find_3d_names_in_source_finds_3d_only_script_paths() -> void:
	# Given: A source in `map` naming 3D-only scripts by each form of path.
	var lines := [
		'extends "../ui/hud/layer_3d.gd"',
		'const A := preload("3d/scene.gd")',
		"const B := preload('./3d/viewport_observer.gd')",
		'const C := preload("res://ui/hud/layer_3d.gd")',
		'const D := preload("uid://dld1uw3phkfna")',
		'const E := preload("uid://dllaqka540nal")',
		"const F := preload('''3d/scene.gd''')",
	]
	var source := "\n".join(lines)

	# When: The source is searched for paths to 3D-only scripts.
	var found := _find_3d_names(source, "res://map/scene.gd")

	# Then: Each path is found, resolved to the script it names.
	var expected := [
		"res://ui/hud/layer_3d.gd",
		"res://map/3d/scene.gd",
		"res://map/3d/viewport_observer.gd",
		"res://ui/hud/layer_3d.gd",
		"res://map/3d/scene.gd",
		"res://ui/hud/layer_3d.gd",
		"res://map/3d/scene.gd",
	]
	assert_eq(found, PackedStringArray(expected))


func test_find_3d_names_in_source_ignores_other_paths_and_text() -> void:
	# Given: A source in `map` whose paths and text load no 3D-only script on parse.
	var lines := [
		'# preload("3d/scene.gd")',
		'## See "res://ui/hud/layer_3d.gd".',
		'const A := preload("2d/scene.gd")',
		'const B := preload("uid://dm1yyvkqdxmqe")',
		'const C := preload("uid://aaaaaaaaaaaaa")',
		'const D := preload("res://map/3d/scene.tscn")',
		'const E := load("user://layer_3d.gd")',
		'var s := "Ignored \'%s\'" % "%s: %s"',
		'var t := ^"3d/scene"',
		'var u := load("3d/scene.gd")',
		'const G := "res://ui/hud/layer_3d.gd"',
	]
	var source := "\n".join(lines)

	# When: The source is searched for paths to 3D-only scripts.
	var found := _find_3d_names(source, "res://map/scene.gd")

	# Then: Nothing is found.
	assert_eq(found, PackedStringArray())


func test_list_shipped_scripts_in_kit_leaves_out_3d_only_and_vendored_scripts() -> void:
	# Given: The scripts the sweep reads.
	var paths := _list_shipped_scripts("res://")

	# Then: Shared scripts are listed, and 3D-only, vendored and test scripts are not.
	assert_has(paths, "res://ui/hud/layer.gd")
	assert_has(paths, "res://ui/hud/layer_2d.gd")
	assert_does_not_have(paths, "res://ui/hud/layer_3d.gd")
	assert_does_not_have(paths, "res://map/3d/scene.gd")
	assert_does_not_have(paths, "res://map/3d/viewport_observer.gd")
	assert_does_not_have(paths, "res://ui/tracker/world_tracker_3d_test.gd")
	for path in paths:
		assert_false(path.begins_with("res://addons/"), "vendored script: %s" % path)


func test_shipped_scripts_on_3d_disabled_build_name_no_3d_class() -> void:
	# Given: Every script kit ships to every game.
	var paths := _list_shipped_scripts("res://")
	assert_gt(paths.size(), 0)

	# When: Each is searched for 3D class names and paths to 3D-only scripts.
	var offenders := PackedStringArray()
	for path in paths:
		for found in _find_3d_names(FileAccess.get_file_as_string(path), path):
			offenders.append("%s: %s" % [path, found])

	# Then: None names one.
	assert_eq(offenders, PackedStringArray(), "\n".join(offenders))


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _find_3d_names(source: String, path_script := "res://") -> PackedStringArray:
	var found := PackedStringArray()

	for result in _literal_or_comment.search_all(source):
		var before := source.left(result.get_start()).rstrip(" \t\r\n")
		if not (before.ends_with("preload(") or before.ends_with("extends")):
			continue

		var path := _resolve_path(result.get_string(), path_script)
		if _is_3d_only_script(path):
			found.append(path)

	var code := _literal_or_comment.sub(source, " ", true)
	for result in _identifier.search_all(code):
		var identifier := result.get_string()
		if _classes_3d.has(StringName(identifier)):
			found.append(identifier)

	return found


# NOTE: The match errs broad, since a kept class it matches fails the sweep at once and
# goes in `_ALLOWED_3D`, while a dropped class it misses passes until an export breaks.
func _is_3d_class(candidate: String) -> bool:
	if StringName(candidate) in _ALLOWED_3D:
		return false

	if candidate.contains("3D"):
		return true

	for prefix in _PREFIXES_3D:
		if candidate.begins_with(prefix):
			return true

	for root in _ROOTS_3D:
		if ClassDB.is_parent_class(candidate, root):
			return true

	return false


func _is_3d_only_script(path: String) -> bool:
	if not path.ends_with(".gd"):
		return false

	return path.ends_with(_SUFFIX_3D_ONLY) or path.begins_with(_DIR_3D_ONLY + "/")


# NOTE: Only a literal after `extends` or in `preload` counts, as GDScript loads it on
# parse. A relative one resolves from the script's directory, with or without `./`.
func _resolve_path(literal: String, path_script: String) -> String:
	if literal.begins_with("#"):
		return ""

	var quotes := 3 if literal.begins_with('"""') or literal.begins_with("'''") else 1
	var ref := literal.substr(quotes, literal.length() - 2 * quotes)

	if ref.begins_with("uid://"):
		var id := ResourceUID.text_to_id(ref)
		return ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""

	if ref.is_relative_path():
		return path_script.get_base_dir().path_join(ref).simplify_path()

	return ref.simplify_path() if ref.begins_with("res://") else ""


func _list_shipped_scripts(path_dir: String) -> PackedStringArray:
	var paths := PackedStringArray()

	var dir := DirAccess.open(path_dir)
	assert_not_null(dir)

	for file in dir.get_files():
		var path := path_dir.path_join(file)
		if (
			file.ends_with(".gd")
			and not file.ends_with("_test.gd")
			and not _is_3d_only_script(path)
		):
			paths.append(path)

	for child in dir.get_directories():
		var path := path_dir.path_join(child)
		if child.begins_with(".") or path in _SKIPPED_DIRS or path == _DIR_3D_ONLY:
			continue

		paths.append_array(_list_shipped_scripts(path))

	return paths
