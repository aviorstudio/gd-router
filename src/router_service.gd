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

## Typed route definition used by RouterService.
class RouteEntry extends RefCounted:
	var name: String = ""
	var scene_path: String = ""
	var guard: Callable = Callable()
	var metadata: Dictionary[String, Variant] = {}

	func _init(route_name: String = "", route_scene_path: String = "") -> void:
		name = route_name
		scene_path = route_scene_path

## Router runtime configuration.
class RouterConfig extends RefCounted:
	var transition_duration_s: float = RouteTransitionUtil.DEFAULT_FADE_DURATION

var _routes: Dictionary[String, RouteEntry] = {}
var _current_params: Dictionary[String, Variant] = {}
var transition_callable: Callable = Callable()
var _middleware_chain: Array[Callable] = []
var _history: Array[String] = []
var config: RouterConfig = RouterConfig.new()
const MAX_HISTORY_SIZE := 20

func _enter_tree() -> void:
	if not _routes.is_empty():
		return

	var should_auto_discover: bool = bool(ProjectSettings.get_setting(SETTING_AUTO_DISCOVER, DEFAULT_AUTO_DISCOVER))
	if not should_auto_discover:
		return

	var routes_dir: String = str(ProjectSettings.get_setting(SETTING_ROUTES_DIR, DEFAULT_ROUTES_DIR))
	var route_dir_suffix: String = str(ProjectSettings.get_setting(SETTING_ROUTE_DIR_SUFFIX, DEFAULT_ROUTE_DIR_SUFFIX))
	var discovered_routes: Dictionary[String, RouteEntry] = discover_routes(routes_dir, route_dir_suffix)
	if discovered_routes.is_empty():
		if not transition_callable.is_valid():
			transition_callable = Callable(self, "_default_transition")
		return

	set_routes(discovered_routes)
	if not transition_callable.is_valid():
		transition_callable = Callable(self, "_default_transition")

## Replaces router configuration values.
func set_config(new_config: RouterConfig) -> void:
	if new_config == null:
		config = RouterConfig.new()
		return
	config = new_config

## Sets the entire route table with typed route entries.
func set_routes(routes: Dictionary) -> void:
	var copied_routes: Dictionary[String, RouteEntry] = {}
	for route_key: Variant in routes.keys():
		var route_name: String = str(route_key)
		var route: Variant = routes.get(route_key)
		if route == null:
			continue
		if not route is RouteEntry:
			continue
		copied_routes[route_name] = route
	_routes = copied_routes

## Adds or replaces a single route entry.
func add_route(entry: RouteEntry) -> void:
	if entry == null or entry.name.is_empty() or entry.scene_path.is_empty():
		return
	_routes[entry.name] = entry

## Adds a middleware callable with signature `(route_name, params, next) -> void`.
func add_middleware(middleware: Callable) -> void:
	if not middleware.is_valid():
		return
	_middleware_chain.append(middleware)

## Removes a route by name.
func remove_route(route_name: String) -> void:
	if _routes.has(route_name):
		_routes.erase(route_name)

## Returns true when a route name exists in the registry.
func has_route(route_name: String) -> bool:
	return _routes.has(route_name)

## Returns the scene path for a route name, or empty string when missing.
func get_route_path(route_name: String) -> String:
	var route: RouteEntry = _routes.get(route_name, null)
	if route == null:
		return ""
	return route.scene_path

## Auto-discovers route scenes under the configured routes directory.
func discover_routes(routes_dir: String, route_dir_suffix: String = DEFAULT_ROUTE_DIR_SUFFIX) -> Dictionary[String, RouteEntry]:
	var discovered_routes: Dictionary[String, RouteEntry] = {}
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
					discovered_routes[route_name] = RouteEntry.new(route_name, scene_path)
				else:
					push_warning("%s: Skipping route %s, missing scene at %s" % [name, route_name, scene_path])
		entry = dir.get_next()
	dir.list_dir_end()

	return discovered_routes

## Navigates to a route name with optional typed params.
func go_to(route_name: String, params: Dictionary[String, Variant] = {}) -> void:
	var copied_params: Dictionary[String, Variant] = params.duplicate(true)
	var route_entry: RouteEntry = _routes.get(route_name, null)
	if route_entry == null:
		push_error("%s: Unknown route %s" % [name, route_name])
		_on_route_not_found(route_name)
		return
	if not _run_middleware(route_name, copied_params):
		return
	if route_entry.guard.is_valid():
		var route_allowed: Variant = route_entry.guard.call(route_name, copied_params)
		if not bool(route_allowed):
			return

	_current_params = copied_params
	var scene_path: String = route_entry.scene_path

	var resolved_transition: Callable = _get_transition_callable()
	if resolved_transition.is_valid():
		resolved_transition.call(scene_path)
		_on_route_changed(route_name, scene_path)
		return

	_safe_change_scene(scene_path, route_name)

## Returns a deep-copied dictionary of current route params.
func get_params() -> Dictionary[String, Variant]:
	return _current_params.duplicate(true)

## Returns a single current route param value with fallback default.
func get_param(key: String, default: Variant = null) -> Variant:
	return _current_params.get(key, default)

## Navigates to the previous route in history when available.
func go_back() -> void:
	if _history.size() <= 1:
		return
	_history.pop_back()
	var previous: String = _history.pop_back()
	go_to(previous)

## Returns the current route name from history.
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
	return Callable(self, "_default_transition")

func _default_transition(scene_path: String) -> void:
	RouteTransitionUtil.transition_to(scene_path, config.transition_duration_s)

func _run_middleware(route_name: String, params: Dictionary[String, Variant]) -> bool:
	if _middleware_chain.is_empty():
		return true

	for middleware: Callable in _middleware_chain:
		if not middleware.is_valid():
			continue
		var middleware_state: Dictionary[String, bool] = {"proceed": false}
		var next_callable: Callable = func() -> void:
			middleware_state["proceed"] = true
		middleware.call(route_name, params, next_callable)
		if not bool(middleware_state.get("proceed", false)):
			return false

	return true
