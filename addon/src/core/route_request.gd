class_name RouteRequest
extends RefCounted

var route_name: String = ""
var scene_path: String = ""
var params: Dictionary = {}
var replace: bool = false
var previous_route_name: String = ""
var route: Resource = null

func _init(target_route: Resource = null, route_params: Dictionary = {}, replace_current: bool = false, previous_route: String = "") -> void:
	route = target_route
	params = route_params.duplicate(true)
	replace = replace_current
	previous_route_name = previous_route
	if target_route == null:
		return
	if "route_name" in target_route:
		route_name = target_route.route_name
	if "scene_path" in target_route:
		scene_path = target_route.scene_path
