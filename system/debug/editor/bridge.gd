##
## SystemDebugBridge is a development-only bridge which lets an external process
## inspect and drive a running game. It reads line-delimited JSON from a loopback
## socket and answers with the scene tree, expressions, screenshots and node state.
##
## NOTE: This file is in `editor/`, which an export excludes, and nothing a game ships
## names anything in here. The bridge listens only when given a port.
##

extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## ADDRESS is the only interface the bridge binds to. A debug build evaluates arbitrary
## expressions on request, so the socket must never leave the machine.
const ADDRESS := "127.0.0.1"

## ARGUMENT_PORT is the user command-line argument naming the port to listen on. It is
## read from the arguments *after* `--`, which the engine leaves alone.
const ARGUMENT_PORT := "--bridge-port"

## ENV_PORT is an environment variable naming the port to listen on. It exists for runs
## started from the editor, where command-line arguments are a per-machine editor
## setting that cannot be committed.
const ENV_PORT := "GODOT_DEBUG_BRIDGE_PORT"

## METHOD_DEBUG_STATE is the method a node defines to report its state. It takes no
## arguments and returns a `Dictionary`, and the bridge calls it by name, so a
## reporting node needs no reference to this file.
const METHOD_DEBUG_STATE := &"_get_debug_state"

## TREE_DEPTH is how many levels of children a `tree` command returns by default.
const TREE_DEPTH: int = 3

## TIMEOUT_COMMAND is how long a command which awaits the engine may run before the
## bridge answers with an error instead.
##
## NOTE: An awaited signal may never arrive, since `frame_post_draw` does not fire while
## the window is minimized, and a coroutine that never resumes takes its reply with it.
const TIMEOUT_COMMAND: float = 5.0

# -- INITIALIZATION ------------------------------------------------------------------ #

## _mounted is the bridge currently in the tree, which catches a second one. A static
## variable rather than a group, since a group would be a name a game could use to
## reach the bridge.
static var _mounted: Node = null

var _buffer: String = ""
var _busy: bool = false
var _classes: Dictionary = {}
var _logger := StdLogger.create(&"system/debug")
var _peer: StreamPeerTCP = null
var _pending: Array[Dictionary] = []
var _port: int = 0
var _server: TCPServer = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## collect_state returns the state of every node reporting one, keyed by the node's
## path and ordered by the tree. A node matching none of `filters` is left out; an
## empty `filters` keeps every one.
##
## NOTE: A node answering with anything but a `Dictionary` is logged and skipped, so
## one mistaken reporter cannot empty the whole reply.
func collect_state(filters: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out := {}

	for node in find_reporters():
		var path := String(node.get_path())
		if not _matches(path, filters):
			continue

		var state: Variant = node.call(METHOD_DEBUG_STATE)
		if not state is Dictionary:
			var returned := {&"node": path, &"type": type_string(typeof(state))}
			_logger.warn("Ignoring node reporting no dictionary.", returned)
			continue

		out[path] = state

	return out


## find_reporters returns every node in the tree defining `METHOD_DEBUG_STATE`, in tree
## order. Nothing registers; a node is found because it answers to the method.
func find_reporters() -> Array[Node]:
	var out: Array[Node] = []
	_collect_reporters(get_tree().root, out)

	return out


## list_reporters returns the paths of the nodes reporting state, in tree order. It is
## the cheap half of `collect_state`, since no node is asked for its state.
func list_reporters() -> PackedStringArray:
	var out := PackedStringArray()
	for node in find_reporters():
		out.append(String(node.get_path()))

	return out


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(not _mounted, "invalid state; duplicate node found")
	_mounted = self


func _exit_tree() -> void:
	if _mounted == self:
		_mounted = null

	_peer = null

	if _server:
		_server.stop()
		_server = null


func _process(_delta: float) -> void:
	if not _server:
		return

	if not _peer or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if not _server.is_connection_available():
			return

		_peer = _server.take_connection()
		_buffer = ""

	_peer.poll()

	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_peer = null
		return

	_read()
	_drain()


func _ready() -> void:
	_port = _read_port()

	if _port <= 0:
		set_process(false)
		_logger.debug("Debug bridge is inert; no port was provided.")
		return

	_server = TCPServer.new()

	var err := _server.listen(_port, ADDRESS)
	if err != OK:
		_server = null
		set_process(false)

		# NOTE: `StdLogSinkGodot` hands a warning to `push_warning` without its context
		# fields, so anything the reader needs has to be in the message itself.
		var reason := "port %d: %s" % [_port, error_string(err)]
		_logger.warn("Failed to open the debug bridge (%s)." % reason)

		return

	_logger.info("Opened the debug bridge.", {&"port": _port})


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _collect_reporters appends `node` and its descendants which report state to `out`,
## in tree order.
func _collect_reporters(node: Node, out: Array[Node]) -> void:
	if node.has_method(METHOD_DEBUG_STATE):
		out.append(node)

	for child in node.get_children():
		_collect_reporters(child, out)


## _describe renders a node as a dictionary, recursing until `depth` is exhausted.
func _describe(node: Node, depth: int) -> Dictionary:
	var out := {&"name": String(node.name), &"class": node.get_class()}

	var script: Variant = node.get_script()
	if script is Script:
		out[&"script"] = (script as Script).resource_path

	if node is Control:
		out[&"visible"] = (node as Control).visible
		out[&"rect"] = (node as Control).get_global_rect()
	elif node is CanvasItem:
		out[&"visible"] = (node as CanvasItem).visible
	elif node.get(&"global_position") != null:
		# NOTE: This reaches the 3D case by property rather than by type, which also
		# covers whatever else a game hangs a global position on.
		out[&"position"] = node.get(&"global_position")

	var count := node.get_child_count()
	if count < 1:
		return out

	if depth < 1:
		out[&"children_omitted"] = count
		return out

	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(_describe(child, depth - 1))

	out[&"children"] = children

	return out


## _drain handles the next pending request, if the bridge is not already busy with one.
##
## TODO: `_busy` has two owners, the watchdog at a timeout and the awaited command on a
## late resume, so a command that comes back late can release the bridge while a newer
## one runs. Replace the flag with a generation counter, or serialize per connection.
func _drain() -> void:
	if _busy or _pending.is_empty():
		return

	_busy = true
	await _handle(_pending.pop_front())
	_busy = false


## _fail answers a request with an error message.
func _fail(message: String) -> void:
	_send({&"ok": false, &"error": message})


## _filters reads the `filter` argument, which a client may send as one glob or as an
## array of them. Anything else, an absent argument included, filters nothing.
func _filters(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()

	if value is String or value is StringName:
		if String(value) != "":
			out.append(String(value))

		return out

	if value is Array:
		for entry: Variant in value:
			if (entry is String or entry is StringName) and String(entry) != "":
				out.append(String(entry))

	return out


## _global_classes returns a map from global class name to script path, built once.
func _global_classes() -> Dictionary:
	if _classes.is_empty():
		for entry in ProjectSettings.get_global_class_list():
			_classes[entry["class"]] = entry["path"]

	return _classes


## _handle dispatches one request and answers it.
func _handle(request: Dictionary) -> void:
	var args: Dictionary = request.get("args", {})

	match StringName(request.get("cmd", "")):
		&"status":
			_reply(_status())
		&"reporters":
			_reply(list_reporters())
		&"tree":
			_on_tree(args)
		&"eval":
			_on_eval(args)
		&"state":
			_on_state(args)
		&"screenshot":
			await _on_screenshot(args)
		&"quit":
			_reply(true)
			_quit.call_deferred()
		var cmd:
			_fail("unknown command: %s" % cmd)


## _identifiers returns the identifier-shaped words in an expression.
func _identifiers(source: String) -> PackedStringArray:
	var out := PackedStringArray()

	var pattern := RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")
	for match_result in pattern.search_all(source):
		var identifier := match_result.get_string()
		if identifier not in out:
			out.append(identifier)

	return out


## _matches reports whether a node's path satisfies any of `filters`. An empty
## `filters` is satisfied by everything.
##
## NOTE: A filter is a glob over the whole path where `*` crosses `/`; one with no
## wildcard and no `/` matches that node name at any depth.
func _matches(path: String, filters: PackedStringArray) -> bool:
	if filters.is_empty():
		return true

	for filter in filters:
		var pattern := filter
		if not ("*" in pattern or "?" in pattern or "/" in pattern):
			pattern = "*/" + pattern

		if path.match(pattern):
			return true

	return false


## _node returns the node a client-supplied path names, or `null` when there is none.
##
## NOTE: A path is relative to `/root` unless it begins with `/`. The relative form is
## documented, because an MSYS shell rewrites one that looks like an absolute Unix path.
func _node(path: String) -> Node:
	if path.begins_with("/"):
		return get_node_or_null(NodePath(path))

	# NOTE: `root` and `root/...` are accepted too, since that is what the absolute form
	# looks like once a shell has eaten its leading slash.
	var relative := path
	if relative == "root":
		relative = ""
	elif relative.begins_with("root/"):
		relative = relative.trim_prefix("root/")

	var root := get_tree().root
	if relative == "":
		return root

	return root.get_node_or_null(NodePath(relative))


## _on_eval evaluates an expression against the running game.
func _on_eval(args: Dictionary) -> void:
	var source: String = args.get("expr", "")
	if source == "":
		_fail("missing argument: expr")
		return

	# NOTE: `Expression` sees only the names it is given, so without this the bridge
	# reaches no project API at all.
	var names := PackedStringArray()
	var values: Array = []

	for identifier in _identifiers(source):
		var value: Variant = _resolve(identifier)
		if value == null:
			continue

		names.append(identifier)
		values.append(value)

	var expression := Expression.new()

	var err := expression.parse(source, names)
	if err != OK:
		_fail(expression.get_error_text())
		return

	var result: Variant = expression.execute(values, self, false)
	if expression.has_execute_failed():
		_fail(expression.get_error_text())
		return

	_reply(result)


## _on_screenshot captures the window and writes it to a PNG file.
func _on_screenshot(args: Dictionary) -> void:
	var path: String = args.get("path", "")
	if path == "":
		_fail("missing argument: path")
		return

	var node_path: String = args.get("node", "")
	var control: Control = null

	if node_path != "":
		control = _node(node_path) as Control
		if not control:
			_fail("no such control: %s" % node_path)
			return

	var state := {&"done": false}
	_watchdog(state)

	# NOTE: The viewport texture only holds a complete frame after the draw, so reading
	# it any earlier yields a blank or half-drawn image rather than an error.
	await RenderingServer.frame_post_draw

	if state[&"done"]:
		return

	state[&"done"] = true

	var image := get_viewport().get_texture().get_image()

	if control:
		# NOTE: With a `canvas_items` stretch mode a control's rect is in the stretch
		# space, not in viewport pixels, so it has to go through the screen transform.
		var xform := control.get_viewport().get_screen_transform()
		var region := Rect2i(
			(xform * control.get_global_rect()).intersection(
				Rect2(Vector2.ZERO, image.get_size())
			)
		)

		if region.size.x < 1 or region.size.y < 1:
			_fail("control is not on screen: %s" % node_path)
			return

		image = image.get_region(region)

	var err := image.save_png(path)
	if err != OK:
		_fail("failed to write %s: %s" % [path, error_string(err)])
		return

	_reply({&"path": path, &"size": image.get_size()})


## _on_state answers with the state of every node reporting one, narrowed by `filter`.
func _on_state(args: Dictionary) -> void:
	var filters := _filters(args.get("filter", []))

	var state := collect_state(filters)
	if state.is_empty() and not filters.is_empty():
		_fail("no node matched: %s (reporting: %s)" % [filters, list_reporters()])
		return

	_reply(state)


## _on_tree answers with a description of part of the scene tree.
func _on_tree(args: Dictionary) -> void:
	var path: String = args.get("path", "")

	var node := _node(path)
	if not node:
		_fail("no such node: %s" % path)
		return

	_reply(_describe(node, int(args.get("depth", TREE_DEPTH))))


## _quit shuts the game down as though the window manager had asked it to.
func _quit() -> void:
	# NOTE: This is the notification a window close sends, so the project's own graceful
	# shutdown runs and the bridge need not know what it is. `Lifecycle` answers it by
	# quitting, which leaves the deferred call below reaching only a scene without it.
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit.call_deferred()


## _read consumes whatever the peer has sent and queues the complete requests.
func _read() -> void:
	var available := _peer.get_available_bytes()
	if available < 1:
		return

	var data: Array = _peer.get_data(available)
	if data[0] != OK:
		return

	_buffer += (data[1] as PackedByteArray).get_string_from_utf8()

	while true:
		var index := _buffer.find("\n")
		if index < 0:
			break

		var line := _buffer.substr(0, index)
		_buffer = _buffer.substr(index + 1)

		var request: Variant = JSON.parse_string(line)
		if request is Dictionary:
			_pending.append(request)
			continue

		_fail("malformed request: %s" % line)


## _read_port returns the port named on the command line or in the environment.
func _read_port() -> int:
	var args := OS.get_cmdline_user_args()

	for i in args.size():
		var argument := args[i]

		if argument.begins_with(ARGUMENT_PORT + "="):
			return argument.trim_prefix(ARGUMENT_PORT + "=").to_int()

		if argument == ARGUMENT_PORT and i + 1 < args.size():
			return args[i + 1].to_int()

	return OS.get_environment(ENV_PORT).to_int()


## _reply answers a request with a result value.
func _reply(result: Variant) -> void:
	_send({&"ok": true, &"result": _to_json(result)})


## _resolve returns the value an identifier names, or `null` when it names nothing the
## bridge can provide.
func _resolve(identifier: String) -> Variant:
	var node := get_node_or_null(NodePath("/root/%s" % identifier))
	if node:
		return node

	# NOTE: Engine singletons are no more visible to `Expression` than autoloads are, so
	# `ResourceLoader.load(...)` reports `Invalid named index` until it is bound here.
	if Engine.has_singleton(identifier):
		return Engine.get_singleton(identifier)

	var classes := _global_classes()
	if classes.has(identifier):
		return load(classes[identifier])

	return null


## _send writes one response line to the peer.
func _send(payload: Dictionary) -> void:
	if not _peer or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return

	_peer.put_data((JSON.stringify(payload) + "\n").to_utf8_buffer())


## _status returns the cheap summary a client can poll.
func _status() -> Dictionary:
	var scene := get_tree().current_scene

	return {
		&"port": _port,
		&"frame": Engine.get_process_frames(),
		&"ticks_msec": Time.get_ticks_msec(),
		&"scene": scene.scene_file_path if scene else "",
		&"reporters": list_reporters(),
	}


## _to_json renders a value as something `JSON.stringify` can encode without losing it.
func _to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return String(value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [value.x, value.y, value.z]
		TYPE_RECT2, TYPE_RECT2I:
			return [value.position.x, value.position.y, value.size.x, value.size.y]
		TYPE_COLOR:
			return [value.r, value.g, value.b, value.a]
		TYPE_TRANSFORM2D:
			return [value.origin.x, value.origin.y, value.get_rotation()]
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(_to_json(item))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				out[String(key)] = _to_json(value[key])
			return out
		TYPE_OBJECT:
			if value is Resource and (value as Resource).resource_path != "":
				return (value as Resource).resource_path
			return str(value)

	return str(value)  # gdlint:ignore=max-returns


## _watchdog answers the request with a timeout error if it is still unanswered when the
## timer expires, and releases the bridge so a stuck command cannot wedge it.
func _watchdog(state: Dictionary) -> void:
	var timer := get_tree().create_timer(TIMEOUT_COMMAND, true, false, true)

	timer.timeout.connect(
		func() -> void:
			if state[&"done"]:
				return

			state[&"done"] = true
			_busy = false
			_fail("timed out after %.1fs" % TIMEOUT_COMMAND)
	)
