##
## Unit tests for the debug bridge. They cover how it finds the nodes reporting
## state and the pure functions behind every reply, including identifier
## extraction, node lookup, the tree description and JSON rendering.
##
## The socket itself is exercised by driving a real game through `godot-bridge`, which
## kit's agent plugin ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const BridgeScene := preload("bridge.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #


## Reporter is a node defining the method the bridge looks for, and nothing more.
class Reporter:
	extends Node

	var value: int = 0

	func _get_debug_state() -> Dictionary:
		return {&"value": value}


## Mistaken is a node defining the method with the wrong return type, which is the
## one way to carry the method's name without honoring its contract.
class Mistaken:
	extends Node

	func _get_debug_state() -> int:
		return 1


# -- INITIALIZATION ------------------------------------------------------------------ #

var _bridge: Node = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_debug_find_reporters_finds_only_a_node_defining_the_method() -> void:
	# Given: A node reporting state, and a plain node.
	var reporter := _add_reporter("Probe")
	var plain: Node = add_child_autofree(Node.new())

	# When: The bridge looks for reporters.
	var found: Array = _bridge.find_reporters()

	# Then: Only the reporter is found.
	assert_true(reporter in found)
	assert_false(plain in found)


func test_debug_collect_state_keys_each_reporter_by_its_path() -> void:
	# Given: Two nodes reporting state.
	var first := _add_reporter("First")
	var second := _add_reporter("Second")
	second.value = 2

	# When: State is collected.
	var state: Dictionary = _bridge.collect_state()

	# Then: Each answer is under the node's own path, as is each listed reporter.
	assert_eq(state.get(String(first.get_path())), {&"value": 0})
	assert_eq(state.get(String(second.get_path())), {&"value": 2})
	var listed: PackedStringArray = _bridge.list_reporters()
	assert_eq(state.keys(), Array(listed))


func test_debug_collect_state_reports_two_nodes_sharing_a_name() -> void:
	# Given: Two reporters of the same name, as two maps in one tree are.
	var first := _add_reporter("Map")
	var second := _add_reporter("Map")
	second.value = 2

	# When: State is collected.
	var state: Dictionary = _bridge.collect_state()

	# Then: Both are present, since a path tells them apart where a name cannot.
	assert_eq(state.size(), 2)
	assert_eq(state.get(String(first.get_path())), {&"value": 0})
	assert_eq(state.get(String(second.get_path())), {&"value": 2})


func test_debug_collect_state_with_a_bare_name_matches_at_any_depth() -> void:
	# Given: Two reporters, only one of them wanted.
	var wanted := _add_reporter("Wanted")
	_add_reporter("Other")

	# When: State is collected under the wanted node's name alone.
	var state: Dictionary = _bridge.collect_state(PackedStringArray(["Wanted"]))

	# Then: Only that node answered.
	assert_eq(state.keys(), [String(wanted.get_path())])


func test_debug_collect_state_with_a_glob_keeps_every_match() -> void:
	# Given: Two reporters sharing a prefix, and one which does not.
	var first := _add_reporter("HudTop")
	var second := _add_reporter("HudBottom")
	_add_reporter("Map")

	# When: State is collected under a glob over the prefix.
	var state: Dictionary = _bridge.collect_state(PackedStringArray(["*/Hud*"]))

	# Then: Both matches answered, and nothing else did.
	assert_eq(state.size(), 2)
	assert_true(String(first.get_path()) in state)
	assert_true(String(second.get_path()) in state)


func test_debug_collect_state_with_several_filters_keeps_their_union() -> void:
	# Given: Three reporters.
	var first := _add_reporter("First")
	var second := _add_reporter("Second")
	_add_reporter("Third")

	# When: State is collected under two filters.
	var state: Dictionary = _bridge.collect_state(
		PackedStringArray(["First", "Second"])
	)

	# Then: Both named nodes answered.
	assert_eq(state.size(), 2)
	assert_true(String(first.get_path()) in state)
	assert_true(String(second.get_path()) in state)


func test_debug_collect_state_with_an_unmatched_filter_is_empty() -> void:
	# Given: A reporter.
	_add_reporter("Probe")

	# When: State is collected under a filter naming something else.
	var state: Dictionary = _bridge.collect_state(PackedStringArray(["Absent"]))

	# Then: Nothing answered.
	assert_true(state.is_empty())


func test_debug_collect_state_skips_a_node_answering_with_no_dictionary() -> void:
	# Given: A reporter, and a node whose method returns the wrong type.
	_add_reporter("Probe")
	var mistaken := Mistaken.new()
	mistaken.name = "Mistaken"
	add_child_autofree(mistaken)

	# When: State is collected.
	var state: Dictionary = _bridge.collect_state()

	# Then: The good reporter answered and the mistaken one was left out.
	assert_eq(state.size(), 1)
	assert_true(String(state.keys()[0]).ends_with("Probe"))


func test_debug_filters_accepts_one_glob_or_an_array_of_them() -> void:
	# Then: Each form a JSON client can send is read as the globs it stands for.
	assert_eq(_bridge._filters("Map"), PackedStringArray(["Map"]))
	assert_eq(_bridge._filters(["Map", "Hud"]), PackedStringArray(["Map", "Hud"]))
	assert_eq(_bridge._filters(""), PackedStringArray())
	assert_eq(_bridge._filters([]), PackedStringArray())
	assert_eq(_bridge._filters(null), PackedStringArray())


func test_debug_identifiers_collects_each_name_once() -> void:
	# Given: An expression naming the same identifier twice.
	var source := "KitSystems.saves().get_depth() + KitSystems.get_depth()"

	# When: Its identifiers are collected.
	var out: PackedStringArray = _bridge._identifiers(source)

	# Then: Each name appears once, and the punctuation does not appear at all.
	assert_eq(Array(out).count("KitSystems"), 1)
	assert_true("get_depth" in out)
	assert_eq(Array(out), ["KitSystems", "saves", "get_depth"])


func test_debug_resolve_finds_what_expression_cannot() -> void:
	# Then: An autoload, an engine singleton and a global class each resolve.
	assert_true(_bridge._resolve("Lifecycle") is Node)
	assert_not_null(_bridge._resolve("ResourceLoader"))
	assert_true(_bridge._resolve("KitSystems") is Script)


func test_debug_resolve_with_an_unknown_name_returns_null() -> void:
	# Then: A name nothing in the project defines resolves to nothing.
	assert_null(_bridge._resolve("NotAnythingThisProjectDefines"))


func test_debug_node_accepts_every_form_of_the_same_path() -> void:
	# Given: An autoload the caller may name three ways.
	var expected := _bridge.get_tree().root.get_node_or_null(^"Lifecycle")

	# Then: The absolute, root-prefixed and bare forms all find it.
	assert_eq(_bridge._node("/root/Lifecycle"), expected)
	assert_eq(_bridge._node("root/Lifecycle"), expected)
	assert_eq(_bridge._node("Lifecycle"), expected)


func test_debug_node_with_no_path_returns_the_root() -> void:
	# Given: The window root.
	var root := _bridge.get_tree().root

	# Then: Both an empty path and a bare `root` reach it.
	assert_eq(_bridge._node(""), root)
	assert_eq(_bridge._node("root"), root)

	# Then: A name no node carries reaches nothing.
	assert_null(_bridge._node("NoSuchNodeExists"))


func test_debug_describe_reports_a_node_and_its_children() -> void:
	# Given: A node with one `Control` child.
	var root: Node = autofree(Node.new())
	root.name = &"Root"
	var child := Control.new()
	child.name = &"Child"
	root.add_child(child)

	# When: It is described with room for the child.
	var out := _bridge._describe(root, 1) as Dictionary

	# Then: The node and its one child are described.
	assert_eq(out[&"name"], "Root")
	assert_eq(out[&"class"], "Node")
	assert_eq((out[&"children"] as Array).size(), 1)
	assert_eq((out[&"children"][0] as Dictionary)[&"name"], "Child")

	# Then: The child carries the rect only a `Control` has.
	assert_true((out[&"children"][0] as Dictionary).has(&"rect"))


func test_debug_describe_at_the_depth_limit_counts_the_children() -> void:
	# Given: A node with one child.
	var root: Node = autofree(Node.new())
	root.add_child(Node.new())

	# When: It is described with no room left for the child.
	var out := _bridge._describe(root, 0) as Dictionary

	# Then: The child is reported as a count rather than dropped silently.
	assert_false(out.has(&"children"))
	assert_eq(out[&"children_omitted"], 1)


func test_debug_to_json_encodes_types_json_cannot() -> void:
	# Given: A dictionary of values `JSON.stringify` drops or mangles on its own.
	var value := {&"at": Vector2(1, 2), &"box": Rect2(0, 0, 3, 4), &"names": [&"a"]}

	# When: It is rendered for the wire.
	var out := _bridge._to_json(value) as Dictionary

	# Then: Every value survives, under string keys.
	assert_eq(out["at"], [1.0, 2.0])
	assert_eq(out["box"], [0.0, 0.0, 3.0, 4.0])
	assert_eq(out["names"], ["a"])

	# Then: The result round-trips through `JSON`.
	assert_eq(JSON.parse_string(JSON.stringify(out)), out)


func test_debug_to_json_renders_a_resource_as_its_path() -> void:
	# Given: A resource which is on disk.
	var resource := BridgeScene

	# Then: Its path stands in for it.
	assert_eq(_bridge._to_json(resource), resource.resource_path)


func test_debug_to_json_renders_a_bare_object_as_text() -> void:
	# Given: An object with no resource path.
	var node: Node = autofree(Node.new())

	# When: It is rendered.
	var out: Variant = _bridge._to_json(node)

	# Then: It degrades to a string rather than failing the whole command.
	assert_typeof(out, TYPE_STRING)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	# NOTE: A game composes this node into its own tree. The test stands it up alone,
	# so the bridge is covered without the rest of the system.
	_bridge = add_child_autofree(BridgeScene.instantiate())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_reporter stands a reporting node up in the tree under `node_name`, freed
## with the test.
func _add_reporter(node_name: StringName) -> Reporter:
	var reporter := Reporter.new()
	reporter.name = node_name
	add_child_autofree(reporter)

	return reporter
