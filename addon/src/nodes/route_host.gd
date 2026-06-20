@tool
class_name RouteHost
extends Control

const InstantRouteTransitionScript = preload("../resources/instant_route_transition.gd")
const RouteDiscoveryScript = preload("../discovery/route_discovery.gd")

signal route_mounted(request)
signal route_mount_failed(request, error_message: String)

@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RouteMap") var route_map: Resource = null
@export var initial_route: String = "home"
@export var auto_discover: bool = true
@export_dir var routes_dir: String = "res://src/screens"
@export var route_dir_suffix: String = "_screen"
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RouteTransition") var transition: Resource = null
@export var router_path: NodePath = ^"/root/GdRouter"

var router: Node = null
var current_screen: Node = null

func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	_resolve_router()
	if router == null:
		push_warning("RouteHost: GdRouter autoload was not found.")
		return
	_configure_router_routes()
	router.call("register_host", self)
	var starting_route := _initial_route_name()
	if not starting_route.is_empty() and router.has_method("get_current_route") and router.call("get_current_route") == "":
		router.call("replace", starting_route)

func _exit_tree() -> void:
	if router != null and is_instance_valid(router) and router.has_method("unregister_host"):
		router.call("unregister_host", self)

func mount_route(request: RefCounted) -> void:
	if request == null or request.scene_path.is_empty():
		route_mount_failed.emit(request, "Route request has no scene path.")
		return
	if not ResourceLoader.exists(request.scene_path):
		route_mount_failed.emit(request, "Route scene could not be loaded: %s" % request.scene_path)
		return
	var packed_scene := load(request.scene_path) as PackedScene
	if packed_scene == null:
		route_mount_failed.emit(request, "Route scene could not be loaded: %s" % request.scene_path)
		return
	var next_screen := packed_scene.instantiate()
	if next_screen == null:
		route_mount_failed.emit(request, "Route scene could not be instantiated: %s" % request.scene_path)
		return

	var previous_screen := current_screen
	add_child(next_screen)
	_apply_screen_layout(next_screen)
	current_screen = next_screen

	var active_transition: Resource = transition
	if active_transition == null:
		active_transition = InstantRouteTransitionScript.new()
	if not active_transition.has_method("start_transition") or not active_transition.has_signal("finished"):
		next_screen.queue_free()
		current_screen = previous_screen
		route_mount_failed.emit(request, "Route transition must extend RouteTransition.")
		return
	active_transition.call("start_transition", self, previous_screen, next_screen)
	await active_transition.finished

	if previous_screen != null and is_instance_valid(previous_screen):
		previous_screen.queue_free()
	route_mounted.emit(request)

func _resolve_router() -> void:
	if router != null and is_instance_valid(router):
		return
	router = get_node_or_null(router_path)

func _configure_router_routes() -> void:
	if route_map != null and router.has_method("set_route_map"):
		router.call("set_route_map", route_map)
		return
	if auto_discover and router.has_method("discover_and_set_routes"):
		router.call("discover_and_set_routes", routes_dir, route_dir_suffix)

func _initial_route_name() -> String:
	if not initial_route.is_empty():
		return initial_route
	if route_map != null and "initial_route" in route_map:
		return str(route_map.initial_route)
	return ""

func _apply_screen_layout(screen: Node) -> void:
	if screen is Control:
		var control := screen as Control
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.offset_left = 0.0
		control.offset_top = 0.0
		control.offset_right = 0.0
		control.offset_bottom = 0.0

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if route_map == null and not auto_discover:
		warnings.append("Assign a RouteMap or enable auto_discover so RouteHost has routes to mount.")
	if transition != null and (not transition.has_method("start_transition") or not transition.has_signal("finished")):
		warnings.append("transition must extend RouteTransition and emit finished.")
	if route_map != null:
		_validate_route_map_warnings(warnings)
	elif auto_discover:
		_validate_auto_discover_warnings(warnings)
	return warnings

func _validate_route_map_warnings(warnings: PackedStringArray) -> void:
	if not ("routes" in route_map):
		warnings.append("route_map must be a RouteMap resource.")
		return
	var route_names: Array[String] = []
	for route in route_map.routes:
		if route == null:
			warnings.append("route_map contains a null route entry.")
			continue
		if not ("route_name" in route) or str(route.route_name).strip_edges().is_empty():
			warnings.append("route_map contains a route with no route_name.")
			continue
		route_names.append(str(route.route_name))
		if not ("scene_path" in route) or str(route.scene_path).strip_edges().is_empty():
			warnings.append("Route '%s' has no scene_path." % route.route_name)
		elif not ResourceLoader.exists(str(route.scene_path)):
			warnings.append("Route '%s' scene_path does not exist: %s" % [route.route_name, route.scene_path])
	var starting_route := _initial_route_name()
	if not starting_route.is_empty() and not route_names.has(starting_route):
		warnings.append("Initial route '%s' is not present in route_map." % starting_route)

func _validate_auto_discover_warnings(warnings: PackedStringArray) -> void:
	if routes_dir.strip_edges().is_empty():
		warnings.append("routes_dir is empty; auto_discover cannot find screen routes.")
		return
	if DirAccess.open(routes_dir) == null:
		warnings.append("routes_dir does not exist: %s" % routes_dir)
		return
	var discovered_routes: Array = RouteDiscoveryScript.discover(routes_dir, route_dir_suffix)
	if discovered_routes.is_empty():
		warnings.append("No routes discovered under %s using suffix '%s'." % [routes_dir, route_dir_suffix])
		return
	var route_names: Array[String] = []
	for route in discovered_routes:
		if route != null and "route_name" in route:
			route_names.append(str(route.route_name))
	if not initial_route.is_empty() and not route_names.has(initial_route):
		warnings.append("Initial route '%s' was not discovered under %s." % [initial_route, routes_dir])
