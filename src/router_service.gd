## Scene router service with optional auto-discovery and route history.
class_name RouterService
extends Node

const RouteTransitionUtil = preload("route_transition_util.gd")

signal route_changed(route_name: String, scene_path: String)
signal route_not_found(route_name: String)

const SETTINGS_PREFIX := "gd_router/"
const SETTING_AUTO_DISCOVER := SETTINGS_PREFIX + "auto_discover"
const SETTING_ROUTES_DIR := SETTINGS_PREFIX + "routes_dir"
const SETTING_ROUTE_DIR_SUFFIX := SETTINGS_PREFIX + "route_dir_suffix"

const DEFAULT_AUTO_DISCOVER := true
const DEFAULT_ROUTES_DIR := "res://src/routes"
const DEFAULT_ROUTE_DIR_SUFFIX := "_route"

var _routes: Dictionary[String, String] = {}
var _current_params: Dictionary[String, Variant] = {}
var transition_callable: Callable = Callable()
var route_guard: Callable = Callable()
var _history: Array[String] = []
const MAX_HISTORY_SIZE := 20

func _enter_tree() -> void:
	if not _routes.is_empty():
		return

	var should_auto_discover: bool = bool(ProjectSettings.get_setting(SETTING_AUTO_DISCOVER, DEFAULT_AUTO_DISCOVER))
	if not should_auto_discover:
		return

	var routes_dir: String = str(ProjectSettings.get_setting(SETTING_ROUTES_DIR, DEFAULT_ROUTES_DIR))
	var route_dir_suffix: String = str(ProjectSettings.get_setting(SETTING_ROUTE_DIR_SUFFIX, DEFAULT_ROUTE_DIR_SUFFIX))
	var discovered_routes: Dictionary[String, String] = discover_routes(routes_dir, route_dir_suffix)
	if discovered_routes.is_empty():
		if not transition_callable.is_valid():
			transition_callable = Callable(RouteTransitionUtil, "transition_to")
		return

	set_routes(discovered_routes)
	if not transition_callable.is_valid():
		transition_callable = Callable(RouteTransitionUtil, "transition_to")

func set_routes(routes: Dictionary[String, String]) -> void:
	var copied_routes: Dictionary[String, String] = {}
	for route_name: String in routes:
		copied_routes[route_name] = routes[route_name]
	_routes = copied_routes

func add_route(route_name: String, scene_path: String) -> void:
	_routes[route_name] = scene_path

func remove_route(route_name: String) -> void:
	if _routes.has(route_name):
		_routes.erase(route_name)

func has_route(route_name: String) -> bool:
	return _routes.has(route_name)

func get_route_path(route_name: String) -> String:
	return _routes.get(route_name, "")

func discover_routes(routes_dir: String, route_dir_suffix: String = DEFAULT_ROUTE_DIR_SUFFIX) -> Dictionary[String, String]:
	var discovered_routes: Dictionary[String, String] = {}
	if routes_dir.is_empty():
		return discovered_routes

	var dir: DirAccess = DirAccess.open(routes_dir)
	if dir == null:
		return discovered_routes

	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = dir.get_next()
			continue
		if dir.current_is_dir() and (route_dir_suffix.is_empty() or entry.ends_with(route_dir_suffix)):
			var route_name: String = entry.trim_suffix(route_dir_suffix)
			if not route_name.is_empty():
				var scene_path: String = routes_dir.path_join(entry).path_join(entry + ".tscn")
				if ResourceLoader.exists(scene_path):
					discovered_routes[route_name] = scene_path
				else:
					push_warning("%s: Skipping route %s, missing scene at %s" % [name, route_name, scene_path])
		entry = dir.get_next()
	dir.list_dir_end()

	return discovered_routes

func go_to(route_name: String, params: Dictionary[String, Variant] = {}) -> void:
	var copied_params: Dictionary[String, Variant] = params.duplicate(true)
	if route_guard.is_valid():
		var allowed: Variant = route_guard.call(route_name, copied_params)
		if not bool(allowed):
			return

	_current_params = copied_params
	var scene_path: String = get_route_path(route_name)
	if scene_path.is_empty():
		push_error("%s: Unknown route %s" % [name, route_name])
		_on_route_not_found(route_name)
		return

	var resolved_transition: Callable = _get_transition_callable()
	if resolved_transition.is_valid():
		resolved_transition.call(scene_path)
		_on_route_changed(route_name, scene_path)
		return

	_safe_change_scene(scene_path, route_name)

func get_params() -> Dictionary[String, Variant]:
	return _current_params.duplicate(true)

func go_back() -> void:
	if _history.size() <= 1:
		return
	_history.pop_back()
	var previous: String = _history.pop_back()
	go_to(previous)

func get_current_route() -> String:
	return _history.back() if not _history.is_empty() else ""

func _safe_change_scene(scene_path: String, route_name: String) -> void:
	var result: int = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_error("%s: Failed to change scene to %s - Error code: %d" % [name, scene_path, result])
		_on_route_change_failed(route_name, scene_path, result)
		return

	_on_route_changed(route_name, scene_path)

func _on_route_not_found(route_name: String) -> void:
	route_not_found.emit(route_name)

func _on_route_changed(route_name: String, scene_path: String) -> void:
	_history.append(route_name)
	while _history.size() > MAX_HISTORY_SIZE:
		_history.pop_front()
	route_changed.emit(route_name, scene_path)

func _on_route_change_failed(_route_name: String, _scene_path: String, _error_code: int) -> void:
	pass

func _get_transition_callable() -> Callable:
	if transition_callable.is_valid():
		return transition_callable
	return Callable(RouteTransitionUtil, "transition_to")
