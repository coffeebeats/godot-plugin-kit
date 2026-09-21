##
## KitModules tracks whether each of the game's modules loaded. A module is a node the
## game depends on to boot; it registers on entering the scene tree and reports once
## whether it loaded, and a failure is logged and enqueued as a critical `KitError`.
##
## NOTE: A module reports only on its own code. A storefront whose client is not running
## raises its own error; a storefront with no implementation fails to load.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It
## is a "static" library that can be imported at compile-time using 'preload'.
##

class_name KitModules
extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

## Status enumerates the states of a registered module. A module starts out loading and
## settles on one of the other two.
enum Status { LOADING, LOADED, FAILED }


## Module is the record kept for each registered module.
class Module:
	extends RefCounted

	## requires lists the IDs of the modules which must load before this one reports.
	var requires: Array[StringName] = []

	## status is the module's current `Status`.
	var status: Status = Status.LOADING


# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"system/modules")
static var _modules: Dictionary[StringName, Module] = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_loaded returns whether the module with the given ID registered and loaded.
static func is_loaded(id: StringName) -> bool:
	var module: Module = _modules.get(id)
	return module != null and module.status == Status.LOADED


## is_settled returns whether every registered module has finished loading, whether or
## not it succeeded.
static func is_settled() -> bool:
	for module in _modules.values():
		if module.status == Status.LOADING:
			return false

	return true


## register declares a module, which must then report whether it loaded, and forgets
## it once `node` exits the scene tree. Each ID in `requires` names a module which must
## have loaded by the time this one reports.
##
## NOTE: `KitModule` calls this on entering the scene tree; only a node that must extend
## another class calls it itself, from its `_enter_tree`.
static func register(
	node: Node, id: StringName, requires: Array[StringName] = []
) -> void:
	if id in _modules:
		_modules[id].status = Status.FAILED
		_fail(id, "registered twice")
		return

	var module := Module.new()
	module.requires = requires
	_modules[id] = module

	node.tree_exiting.connect(_unregister.bind(id), CONNECT_ONE_SHOT)


## report_failed marks the module as failed to load, logs the reason, and enqueues a
## critical `KitError`. A module that already settled is left as it is.
static func report_failed(id: StringName, reason: String) -> void:
	var module: Module = _modules.get(id)
	if module:
		if module.status != Status.LOADING:
			return

		module.status = Status.FAILED

	_fail(id, reason)


## report_loaded marks the module as loaded. A module whose requirements have not all
## loaded fails instead, naming the first one missing. A module that already settled is
## left as it is.
static func report_loaded(id: StringName) -> void:
	var module: Module = _modules.get(id)
	if not module:
		_logger.error("Kit module reported without registering.", {&"module": id})
		return

	if module.status != Status.LOADING:
		return

	for requirement in module.requires:
		if not is_loaded(requirement):
			report_failed(id, "requires '%s', which has not loaded" % requirement)
			return

	module.status = Status.LOADED

	_logger.info("Loaded kit module.", {&"module": id})


## wait returns once every registered module has finished loading, with `OK` if all of
## them loaded or `FAILED` if any did not.
static func wait() -> Error:
	var tree := Engine.get_main_loop() as SceneTree

	# NOTE: Polling rather than awaiting each module's outcome means a module that
	# leaves the scene tree mid-wait cannot strand the caller.
	while not is_settled():
		await tree.process_frame

	for module in _modules.values():
		if module.status == Status.FAILED:
			return FAILED

	return OK


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _fail(id: StringName, reason: String) -> void:
	_logger.error("Kit module failed to load.", {&"module": id, &"reason": reason})

	var error := (
		KitError
		. new(
			"kit_error_platform_init_title",
			"kit_error_module_failed_message",
			KitError.Severity.CRITICAL,
		)
	)
	KitError.enqueue(error)


static func _unregister(id: StringName) -> void:
	_modules.erase(id)
