@tool
class_name RouteLink
extends Button

@export var route_name: String = ""
@export var params: Dictionary = {}
@export var replace_current: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if route_name.is_empty():
		return
	var router := get_node_or_null("/root/GdRouter")
	if router == null:
		push_warning("RouteLink: GdRouter autoload was not found.")
		return
	if replace_current:
		router.call("replace", route_name, params)
	else:
		router.call("go_to", route_name, params)
