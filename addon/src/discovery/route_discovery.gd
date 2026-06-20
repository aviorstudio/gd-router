class_name RouteDiscovery
extends RefCounted

const RouteDefinitionScript = preload("../resources/route_definition.gd")

static func discover(routes_dir: String = "res://src/screens", route_dir_suffix: String = "_screen") -> Array:
	var routes: Array = []
	if routes_dir.is_empty():
		return routes

	var dir := DirAccess.open(routes_dir)
	if dir == null:
		return routes

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = dir.get_next()
			continue
		if dir.current_is_dir() and (route_dir_suffix.is_empty() or entry.ends_with(route_dir_suffix)):
			var route_name := entry.trim_suffix(route_dir_suffix)
			var scene_path := routes_dir.path_join(entry).path_join(entry + ".tscn")
			if not route_name.is_empty() and ResourceLoader.exists(scene_path):
				var route = RouteDefinitionScript.new()
				route.route_name = route_name
				route.scene_path = scene_path
				routes.append(route)
		entry = dir.get_next()
	dir.list_dir_end()
	return routes
