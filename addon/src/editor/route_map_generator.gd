@tool
class_name RouteMapGenerator
extends RefCounted

const RouteDiscoveryScript = preload("../discovery/route_discovery.gd")
const RouteMapScript = preload("../resources/route_map.gd")
const RouteDefinitionScript = preload("../resources/route_definition.gd")

const DEFAULT_ROUTES_DIR := "res://src/screens"
const DEFAULT_ROUTE_DIR_SUFFIX := "_screen"
const DEFAULT_ROUTE_MAP_PATH := "res://src/static/config/main_route_map.tres"

static func build_route_map(routes_dir: String = DEFAULT_ROUTES_DIR, route_dir_suffix: String = DEFAULT_ROUTE_DIR_SUFFIX, existing_route_map: Resource = null) -> Resource:
	var discovered_routes: Array = RouteDiscoveryScript.discover(routes_dir, route_dir_suffix)
	var route_map: Resource = RouteMapScript.new()
	route_map.initial_route = _initial_route(discovered_routes, existing_route_map)
	var routes: Array[Resource] = []
	for discovered_route in discovered_routes:
		routes.append(_merged_route(discovered_route, existing_route_map))
	route_map.routes = routes
	return route_map

static func save_route_map(route_map: Resource, route_map_path: String = DEFAULT_ROUTE_MAP_PATH) -> int:
	if route_map == null:
		return ERR_INVALID_PARAMETER
	var dir_path := route_map_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	if dir_error != OK:
		return dir_error
	return ResourceSaver.save(route_map, route_map_path)

static func build_and_save_default() -> int:
	var existing_route_map: Resource = load(DEFAULT_ROUTE_MAP_PATH) if ResourceLoader.exists(DEFAULT_ROUTE_MAP_PATH) else null
	var route_map: Resource = build_route_map(DEFAULT_ROUTES_DIR, DEFAULT_ROUTE_DIR_SUFFIX, existing_route_map)
	return save_route_map(route_map, DEFAULT_ROUTE_MAP_PATH)

static func _merged_route(discovered_route: Resource, existing_route_map: Resource) -> Resource:
	var route: Resource = RouteDefinitionScript.new()
	route.route_name = discovered_route.route_name
	route.scene_path = discovered_route.scene_path
	var existing_route: Resource = _existing_route(existing_route_map, route.route_name)
	if existing_route == null:
		route.title = _title_from_route_name(route.route_name)
		return route
	if "title" in existing_route:
		route.title = existing_route.title
	if "metadata" in existing_route:
		route.metadata = existing_route.metadata.duplicate(true)
	if "guard" in existing_route:
		route.guard = existing_route.guard
	return route

static func _existing_route(existing_route_map: Resource, route_name: String) -> Resource:
	if existing_route_map == null:
		return null
	if existing_route_map.has_method("get_route"):
		return existing_route_map.call("get_route", route_name)
	if not ("routes" in existing_route_map):
		return null
	for route in existing_route_map.routes:
		if route != null and "route_name" in route and route.route_name == route_name:
			return route
	return null

static func _initial_route(discovered_routes: Array, existing_route_map: Resource) -> String:
	if existing_route_map != null and "initial_route" in existing_route_map:
		var existing_initial := str(existing_route_map.initial_route)
		for route in discovered_routes:
			if route != null and "route_name" in route and route.route_name == existing_initial:
				return existing_initial
	for route in discovered_routes:
		if route != null and "route_name" in route and route.route_name == "home":
			return "home"
	if discovered_routes.is_empty():
		return ""
	var first_route: Resource = discovered_routes.front()
	return str(first_route.route_name) if first_route != null and "route_name" in first_route else ""

static func _title_from_route_name(route_name: String) -> String:
	var words := route_name.split("_", false)
	for i in range(words.size()):
		words[i] = words[i].capitalize()
	var title := ""
	for word in words:
		if not title.is_empty():
			title += " "
		title += word
	return title
