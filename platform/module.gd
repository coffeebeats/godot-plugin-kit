##
## KitModule is the base class for a node the game depends on to boot correctly. It
## registers on entering the scene tree and must then report once whether it loaded; a
## failure is logged and enqueued as a critical `KitError`.
##
## NOTE: It registers from `_notification`, which Godot calls on every script in the
## hierarchy, so a subclass overriding `_enter_tree` need not call `super`.
##
## NOTE: A module keeps its status when it leaves the scene tree and re-enters it, and
## is forgotten once freed.
##

class_name KitModule
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## Status enumerates the states of a module. A module starts out loading and settles on
## one of the other two.
enum Status { LOADING, LOADED, FAILED }

# -- INITIALIZATION ------------------------------------------------------------------ #

# NOTE: Private members carry a `_module` prefix, since a subclass may not redeclare a
# parent's variable and silently overrides a parent's method.
static var _module_logger := StdLogger.create(&"platform/module")
static var _module_registry: Dictionary[StringName, KitModule] = {}

var _is_module_registered: bool = false
var _module_status: Status = Status.LOADING

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_loaded returns whether the module with the given ID registered and loaded.
static func is_loaded(id: StringName) -> bool:
	var module: KitModule = _module_registry.get(id)
	return module != null and module._module_status == Status.LOADED


## wait returns once every module in the scene tree has finished loading, with `OK` if
## all of them loaded or `FAILED` if any did not.
static func wait() -> Error:
	var tree := Engine.get_main_loop() as SceneTree

	# NOTE: Polling rather than awaiting each module's outcome means a module that
	# leaves the scene tree mid-wait cannot strand the caller.
	while not _is_every_module_settled():
		await tree.process_frame

	for module in _module_registry.values():
		if module.is_inside_tree() and module._module_status == Status.FAILED:
			return FAILED

	return OK


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_register_module()
		NOTIFICATION_PREDELETE:
			_unregister_module()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_module_id returns the ID which identifies this module. A subclass must override
## it.
func _get_module_id() -> StringName:
	assert(false, "unimplemented")
	return &""


## _get_module_requires returns the IDs of the modules which must load before this one
## reports.
func _get_module_requires() -> Array[StringName]:
	return []


## _report_failed marks this module as failed to load, logs the reason, and enqueues a
## critical `KitError`. A module that already settled is left as it is.
func _report_failed(reason: String) -> void:
	if _module_status != Status.LOADING:
		return

	_module_status = Status.FAILED

	_fail_module(_get_module_id(), reason)


## _report_loaded marks this module as loaded, or as failed if a module it requires has
## not loaded. A module that already settled is left as it is.
func _report_loaded() -> void:
	if _module_status != Status.LOADING:
		return

	var id := _get_module_id()
	if _module_registry.get(id) != self:
		_module_logger.error(
			"Kit module reported without registering.", {&"module": id}
		)
		return

	for requirement in _get_module_requires():
		if not is_loaded(requirement):
			_report_failed("requires '%s', which has not loaded" % requirement)
			return

	_module_status = Status.LOADED

	_module_logger.info("Loaded kit module.", {&"module": id})


static func _fail_module(id: StringName, reason: String) -> void:
	_module_logger.error(
		"Kit module failed to load.", {&"module": id, &"reason": reason}
	)

	var error := (
		KitError
		. new(
			"kit_error_platform_init_title",
			"kit_error_module_failed_message",
			KitError.Severity.CRITICAL,
		)
	)
	KitError.enqueue(error)


static func _is_every_module_settled() -> bool:
	for module in _module_registry.values():
		if module.is_inside_tree() and module._module_status == Status.LOADING:
			return false

	return true


func _register_module() -> void:
	# NOTE: This runs on every entry into the scene tree, and twice per entry when a
	# subclass's `_notification` calls `super`, so only the first call registers.
	if _is_module_registered:
		return

	_is_module_registered = true

	var id := _get_module_id()

	var existing: KitModule = _module_registry.get(id)
	if existing:
		existing._module_status = Status.FAILED
		_module_status = Status.FAILED
		_fail_module(id, "registered twice")
		return

	_module_registry[id] = self


func _unregister_module() -> void:
	var id := _get_module_id()
	if _module_registry.get(id) == self:
		_module_registry.erase(id)
