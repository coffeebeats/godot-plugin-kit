##
## KitModule is the base class for a node the game depends on to boot correctly. It
## registers with `KitModules` on entering the scene tree, and must then report once
## whether it loaded.
##
## NOTE: It registers from `_notification`, which Godot calls on every script in the
## hierarchy, so a subclass overriding `_enter_tree` need not call `super`.
##

class_name KitModule
extends Node

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		KitModules.register(self, _get_module_id(), _get_module_requires())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_module_id returns the ID which identifies this module to `KitModules`. A
## subclass must override it.
func _get_module_id() -> StringName:
	assert(false, "unimplemented")
	return &""


## _get_module_requires returns the IDs of the modules which must load before this one
## reports.
func _get_module_requires() -> Array[StringName]:
	return []


## _report_failed marks this module as failed to load, logs the reason, and enqueues a
## critical `KitError`.
func _report_failed(reason: String) -> void:
	KitModules.report_failed(_get_module_id(), reason)


## _report_loaded marks this module as loaded, or as failed if a module it requires has
## not loaded.
func _report_loaded() -> void:
	KitModules.report_loaded(_get_module_id())
