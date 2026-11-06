##
## MenuRows is a `VBoxContainer` of a menu's rows, each a button with a `FocusHandler`
## child, such as a `KitInputActionButton`. Every row is a focus anchor ranked by its
## place, so the first row that can take focus takes it when the cursor hides.
##

extends VBoxContainer

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	child_order_changed.connect(_rank_rows)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_focus_handler returns `row`'s focus handler, or null if it has none.
func _get_focus_handler(row: Node) -> StdInputCursorFocusHandler:
	return row.get_node_or_null(^"FocusHandler") as StdInputCursorFocusHandler


## _rank_rows gives each row's anchor a lower priority than the rows above it.
func _rank_rows() -> void:
	for row in get_children():
		var handler := _get_focus_handler(row)
		if handler:
			handler.priority = -row.get_index()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_child_entered_tree(row: Node) -> void:
	# NOTE: This runs after the row's `_enter_tree`, which may set `use_as_anchor`, and
	# before the handler enters the tree and registers as an anchor.
	var handler := _get_focus_handler(row)
	if handler:
		handler.use_as_anchor = true
