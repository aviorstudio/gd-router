extends Node

const RouteContextScript = preload("route_context.gd")
const RouteRequestScript = preload("route_request.gd")
const RouteDiscoveryScript = preload("../discovery/route_discovery.gd")

signal navigation_requested(request)
signal route_changed(route_name: String, scene_path: String, params: Dictionary)
signal route_not_found(route_name: String)
signal route_change_failed(route_name: String, scene_path: String, error_message: String)

const DEFAULT_ROUTES_DIR := "res://src/screens"
const DEFAULT_ROUTE_DIR_SUFFIX := "_screen"
const MAX_HISTORY_SIZE := 20

var _routes: Dictionary = {}
var _hosts: Array[Node] = []
var _history: Array[String] = []
var _current_params: Dictionary = {}
var _pending_request: RefCounted = null

func register_host(host: Node) -> void:
	if host == null or _hosts.has(host):
		return
	_hosts.append(host)
	if host.has_signal("route_mounted") and not host.is_connected("route_mounted", Callable(self, "_on_host_route_mounted")):
		host.connect("route_mounted", Callable(self, "_on_host_route_mounted"))
	if host.has_signal("route_mount_failed") and not host.is_connected("route_mount_failed", Callable(self, "_on_host_route_mount_failed")):
		host.connect("route_mount_failed", Callable(self, "_on_host_route_mount_failed"))
	if _pending_request != null:
		var request: RefCounted = _pending_request
		_pending_request = null
		_dispatch_request(request)

func unregister_host(host: Node) -> void:
	_hosts.erase(host)
	if host == null:
		return
	if host.has_signal("route_mounted") and host.is_connected("route_mounted", Callable(self, "_on_host_route_mounted")):
		host.disconnect("route_mounted", Callable(self, "_on_host_route_mounted"))
	if host.has_signal("route_mount_failed") and host.is_connected("route_mount_failed", Callable(self, "_on_host_route_mount_failed")):
		host.disconnect("route_mount_failed", Callable(self, "_on_host_route_mount_failed"))

func set_route_map(route_map: Resource) -> void:
	_routes.clear()
	if route_map == null or not ("routes" in route_map):
		return
	for route in route_map.routes:
		add_route(route)

func set_routes(routes: Array) -> void:
	_routes.clear()
	for route in routes:
		add_route(route)

func add_route(route: Resource) -> void:
	if route == null or not ("route_name" in route) or not ("scene_path" in route):
		return
	if route.route_name.is_empty() or route.scene_path.is_empty():
		return
	_routes[route.route_name] = route

func discover_and_set_routes(routes_dir: String = DEFAULT_ROUTES_DIR, route_dir_suffix: String = DEFAULT_ROUTE_DIR_SUFFIX) -> Array:
	var discovered_routes: Array = RouteDiscoveryScript.discover(routes_dir, route_dir_suffix)
	set_routes(discovered_routes)
	return discovered_routes

func has_route(route_name: String) -> bool:
	return _routes.has(route_name)

func get_route(route_name: String) -> Resource:
	return _routes.get(route_name, null)

func get_route_path(route_name: String) -> String:
	var route: Resource = get_route(route_name)
	if route == null or not ("scene_path" in route):
		return ""
	return route.scene_path

func go_to(route_name: String, params: Dictionary = {}) -> void:
	_navigate(route_name, params, false)

func replace(route_name: String, params: Dictionary = {}) -> void:
	_navigate(route_name, params, true)

func go_back(params: Dictionary = {}) -> void:
	if _history.size() <= 1:
		return
	_history.pop_back()
	var previous_route_name: String = _history.back()
	_navigate(previous_route_name, params, true)

func get_current_route() -> String:
	return _history.back() if not _history.is_empty() else ""

func get_params() -> Dictionary:
	return _current_params.duplicate(true)

func get_param(key: String, default: Variant = null) -> Variant:
	return _current_params.get(key, default)

func _navigate(route_name: String, params: Dictionary, replace_current: bool) -> void:
	var route: Resource = get_route(route_name)
	if route == null:
		push_warning("GdRouter: Unknown route %s" % route_name)
		route_not_found.emit(route_name)
		return

	var copied_params := params.duplicate(true)
	var previous_route_name := get_current_route()
	if not _can_enter(route, copied_params, previous_route_name):
		return

	var request: RefCounted = RouteRequestScript.new(route, copied_params, replace_current, previous_route_name)
	navigation_requested.emit(request)
	_dispatch_request(request)

func _can_enter(route: Resource, params: Dictionary, previous_route_name: String) -> bool:
	if route == null or not ("guard" in route) or route.guard == null:
		return true
	if not route.guard.has_method("can_enter"):
		return true
	var context: RefCounted = RouteContextScript.new(route, params, previous_route_name)
	return bool(route.guard.call("can_enter", context))

func _dispatch_request(request: RefCounted) -> void:
	var host := _primary_host()
	if host == null:
		_pending_request = request
		return
	if not host.has_method("mount_route"):
		_on_host_route_mount_failed(request, "Registered host cannot mount routes.")
		return
	host.call("mount_route", request)

func _primary_host() -> Node:
	while not _hosts.is_empty():
		var host: Node = _hosts.back()
		if is_instance_valid(host):
			return host
		_hosts.pop_back()
	return null

func _on_host_route_mounted(request: RefCounted) -> void:
	_current_params = request.params.duplicate(true)
	if request.replace and not _history.is_empty():
		_history[_history.size() - 1] = request.route_name
	else:
		_history.append(request.route_name)
	while _history.size() > MAX_HISTORY_SIZE:
		_history.pop_front()
	route_changed.emit(request.route_name, request.scene_path, get_params())

func _on_host_route_mount_failed(request: RefCounted, error_message: String) -> void:
	route_change_failed.emit(request.route_name, request.scene_path, error_message)
