@tool
class_name RouteLink
extends Button

enum RouteAction { GO_TO, REPLACE, BACK }

@export var action: RouteAction = RouteAction.GO_TO
@export var route_name: String = ""
@export var params: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var router := get_node_or_null("/root/GdRouter")
	if router == null:
		push_warning("RouteLink: GdRouter autoload was not found.")
		return
	match action:
		RouteAction.BACK:
			router.call("go_back")
		RouteAction.REPLACE:
			if not route_name.is_empty():
				router.call("replace", route_name, params)
		_:
			if not route_name.is_empty():
				router.call("go_to", route_name, params)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if action != RouteAction.BACK and route_name.strip_edges().is_empty():
		warnings.append("RouteLink needs a route_name unless action is BACK.")
	return warnings
