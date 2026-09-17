##
## Unit tests for the debug bridge: the command registry game code touches, and the
## pure functions behind every reply - identifier extraction, node lookup, the scene
## tree description and JSON rendering.
##
## The socket itself is exercised by driving a real game through `tools/bridge.sh`; see
## `tools/README.md`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Debug := preload("debug.gd")
const DebugScene := preload("debug.tscn")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _bridge: Node = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_debug_register_adds_a_command() -> void:
	# Given: A handler that is not registered.
	assert_false("test" in _bridge.list_commands())
	# When: It is registered.
	Debug.register(&"test", _handler)
	# Then: The command is listed.
	assert_true("test" in _bridge.list_commands())


func test_debug_register_twice_keeps_one_command() -> void:
	# Given: A registered handler.
	Debug.register(&"test", _handler)
	# When: A second handler takes the same name.
	Debug.register(&"test", func() -> int: return 1)
	# Then: The command is listed once.
	assert_eq(Array(_bridge.list_commands()).count("test"), 1)


func test_debug_unregister_removes_the_command() -> void:
	# Given: A registered handler.
	Debug.register(&"test", _handler)
	# When: It is unregistered by name.
	Debug.unregister(&"test")
	# Then: The command is gone.
	assert_false("test" in _bridge.list_commands())


func test_debug_unregister_with_a_replaced_handler_keeps_the_command() -> void:
	# Given: A handler which was replaced by another one.
	Debug.register(&"test", _handler)
	Debug.register(&"test", func() -> int: return 1)
	# When: The replaced handler unregisters itself, as a departing scene does.
	Debug.unregister(&"test", _handler)
	# Then: The replacement is left in place.
	assert_true("test" in _bridge.list_commands())


func test_debug_register_without_a_bridge_does_nothing() -> void:
	# Given: No bridge in the scene, as in a release build.
	StdGroup.with_id(Debug.GROUP_DEBUG_SHIM).remove_member(_bridge)
	# When: A caller registers a handler anyway.
	Debug.register(&"test", _handler)
	# Then: Nothing is found, and the call above raised no error.
	assert_null(Debug.instance())


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
	assert_true(_bridge._resolve("Platform") is Node)
	assert_not_null(_bridge._resolve("ResourceLoader"))
	assert_true(_bridge._resolve("KitSystems") is Script)


func test_debug_resolve_with_an_unknown_name_returns_null() -> void:
	# Then: A name nothing in the project defines resolves to nothing.
	assert_null(_bridge._resolve("NotAnythingThisProjectDefines"))


func test_debug_node_accepts_every_form_of_the_same_path() -> void:
	# Given: An autoload the caller may name three ways.
	var expected := _bridge.get_tree().root.get_node_or_null(^"Platform")
	# Then: The absolute, root-prefixed and bare forms all find it.
	assert_eq(_bridge._node("/root/Platform"), expected)
	assert_eq(_bridge._node("root/Platform"), expected)
	assert_eq(_bridge._node("Platform"), expected)


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
	var resource := DebugScene
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
	_bridge = add_child_autofree(DebugScene.instantiate())
	assert_not_null(Debug.instance(), "invalid state; the bridge did not register")


func after_each() -> void:
	if not _bridge.is_in_group(Debug.GROUP_DEBUG_SHIM):
		StdGroup.with_id(Debug.GROUP_DEBUG_SHIM).add_member(_bridge)

	Debug.unregister(&"test")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _handler() -> int:
	return 0
