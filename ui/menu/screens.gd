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


## find_manager returns the nearest `StdScreenManager` among the node's ancestors, or
## `null` if the node is not beneath one.
static func find_manager(node: Node) -> StdScreenManager:
	var parent := node.get_parent()
	while parent:
		if parent is StdScreenManager:
			return parent

		parent = parent.get_parent()

	return null
