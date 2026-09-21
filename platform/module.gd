##
## KitModule is the base class for a node the game depends on to boot correctly. It
## registers on entering the scene tree and must report whether it loaded by the end of
## `_ready`. A failure is only logged, since the game decides which modules it needs.
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

# NOTE: Private members carry a `_module` prefix. GDScript rejects a subclass variable
# that redeclares a parent's, and a subclass method silently replaces a parent's.
static var _module_logger := StdLogger.create(&"platform/module")
static var _module_registry: Dictionary[StringName, KitModule] = {}

var _is_module_registered: bool = false
var _module_status: Status = Status.LOADING

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_module_ids returns the IDs of every registered module, in the order they
## registered.
static func get_module_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_module_registry.keys())
	return ids


## get_status returns the status of the module with the given ID. An ID no module has
## registered under reads as failed.
static func get_status(id: StringName) -> Status:
	var module: KitModule = _module_registry.get(id)
	return module._module_status if module else Status.FAILED


## is_loaded returns whether the module with the given ID registered and loaded.
static func is_loaded(id: StringName) -> bool:
	return get_status(id) == Status.LOADED


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_register_module()
		NOTIFICATION_POST_ENTER_TREE:
			if _module_status == Status.LOADING:
				_check_module_requires()
		NOTIFICATION_READY:
			# NOTE: Godot sends this after the subclass's `_ready` returns, including one
			# which a script error cut short.
			if _module_status == Status.LOADING and not _is_module_async():
				_report_failed("did not report by the end of _ready")
		NOTIFICATION_PREDELETE:
			_unregister_module()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_module_id returns the ID which identifies this module. A subclass must override
## it.
func _get_module_id() -> StringName:
	assert(false, "unimplemented")
	return &""


## _get_module_requires returns the IDs of the modules which must have loaded before
## this one's `_ready` runs. The module fails if any has not.
func _get_module_requires() -> Array[StringName]:
	return []


## _is_module_async returns whether this module reports after its `_ready` returns, as
## one which loads in the background does. Any other module which has not reported by
## then fails.
func _is_module_async() -> bool:
	return false


## _report_failed marks this module as failed to load and logs the reason. A module that
## already settled is left as it is.
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

	if not _check_module_requires():
		return

	_module_status = Status.LOADED

	_module_logger.info("Loaded kit module.", {&"module": id})


func _check_module_requires() -> bool:
	# NOTE: This also runs just before `_ready`, so a module which starts work there and
	# reports once it finishes cannot pass on a requirement which loaded in between.
	for requirement in _get_module_requires():
		if not is_loaded(requirement):
			_report_failed("requires '%s', which has not loaded" % requirement)
			return false

	return true


static func _fail_module(id: StringName, reason: String) -> void:
	_module_logger.error(
		"Kit module failed to load.", {&"module": id, &"reason": reason}
	)


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
