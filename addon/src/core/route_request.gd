class_name RouteRequest
extends RefCounted

enum Operation {
	PUSH,
	REPLACE,
	BACK,
}

var route_name: String = ""
var scene_path: String = ""
var params: Dictionary = {}
var operation: Operation = Operation.PUSH
var previous_route_name: String = ""
var route: Resource = null
var generation: int = 0
var result: RefCounted = null

func _init(target_route: Resource = null, route_params: Dictionary = {}, request_operation: Operation = Operation.PUSH, previous_route: String = "", request_generation: int = 0, request_result: RefCounted = null) -> void:
	route = target_route
	params = route_params.duplicate(true)
	operation = request_operation
	previous_route_name = previous_route
	generation = request_generation
	result = request_result
	if target_route == null:
		return
	if "route_name" in target_route:
		route_name = target_route.route_name
	if "scene_path" in target_route:
		scene_path = target_route.scene_path
