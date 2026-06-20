class_name RouteMap
extends Resource

@export var initial_route: String = "home"
@export var routes: Array[Resource] = []

func get_route(route_name: String) -> Resource:
	for route in routes:
		if route != null and route.route_name == route_name:
			return route
	return null

func has_route(route_name: String) -> bool:
	return get_route(route_name) != null
