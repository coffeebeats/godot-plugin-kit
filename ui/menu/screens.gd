##
## Screens is a shared library for reaching the `StdScreenManager` which mounted a
## scene. A screen's scene sits beneath its manager, so a menu finds the manager by
## walking its ancestors, as `StdScreenPusher` does, rather than through a game-owned
## global.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It
## is a "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_manager returns the nearest `StdScreenManager` among the node's ancestors. The
## node must be mounted beneath one, as every screen's scene is.
static func find_manager(node: Node) -> StdScreenManager:
	var parent := node.get_parent()
	while parent:
		if parent is StdScreenManager:
			return parent

		parent = parent.get_parent()

	assert(false, "invalid state; missing screen manager")

	return null


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
