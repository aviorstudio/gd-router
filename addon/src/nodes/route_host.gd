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
var _mount_generation: int = 0
var _pending_generation: int = 0
var _pending_request: RefCounted = null
var _pending_screen: Node = null
var _pending_load_started: bool = false
var _pending_transition: Resource = null
var _pending_transition_callback: Callable = Callable()
var _abandoned_scene_paths: Array[String] = []

func _init() -> void:
	set_process(false)

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
	_cancel_pending_screen()
	if router != null and is_instance_valid(router) and router.has_method("unregister_host"):
		router.call("unregister_host", self)

func mount_route(request: RefCounted) -> void:
	_mount_generation += 1
	var mount_generation := _mount_generation
	_cancel_pending_screen()
	_pending_request = request
	_pending_generation = mount_generation
	_pending_load_started = false
	if request == null or request.scene_path.is_empty():
		_fail_mount(request, "Route request has no scene path.", mount_generation)
		return
	if not ResourceLoader.exists(request.scene_path):
		_fail_mount(request, "Route scene could not be loaded: %s" % request.scene_path, mount_generation)
		return
	var load_error := ResourceLoader.load_threaded_request(request.scene_path, "PackedScene")
	if load_error != OK:
		_fail_mount(request, "Route scene could not be queued for loading: %s" % request.scene_path, mount_generation)
		return
	_pending_load_started = true
	set_process(true)

func _process(_delta: float) -> void:
	_drain_abandoned_loads()
	var request: RefCounted = _pending_request
	var mount_generation := _pending_generation
	if not _mount_is_active(request, mount_generation):
		set_process(not _abandoned_scene_paths.is_empty())
		return
	if _pending_screen != null:
		return
	var load_status := ResourceLoader.load_threaded_get_status(request.scene_path)
	if load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if load_status != ResourceLoader.THREAD_LOAD_LOADED:
		_fail_mount(request, "Route scene could not be loaded: %s" % request.scene_path, mount_generation)
		return
	var packed_scene := ResourceLoader.load_threaded_get(request.scene_path) as PackedScene
	_pending_load_started = false
	if packed_scene == null:
		_fail_mount(request, "Route scene could not be loaded: %s" % request.scene_path, mount_generation)
		return
	var next_screen := packed_scene.instantiate()
	if next_screen == null:
		_fail_mount(request, "Route scene could not be instantiated: %s" % request.scene_path, mount_generation)
		return

	var previous_screen := current_screen
	add_child(next_screen)
	_apply_screen_layout(next_screen)
	_pending_screen = next_screen

	var active_transition: Resource = transition
	if active_transition == null:
		active_transition = InstantRouteTransitionScript.new()
	if not active_transition.has_method("start_transition") or not active_transition.has_signal("finished"):
		_fail_mount(request, "Route transition must extend RouteTransition.", mount_generation)
		return
	_pending_transition = active_transition
	_pending_transition_callback = _on_transition_finished
	active_transition.finished.connect(_pending_transition_callback, CONNECT_ONE_SHOT)
	active_transition.call("start_transition", self, previous_screen, next_screen)

func _complete_mount() -> void:
	var request: RefCounted = _pending_request
	var mount_generation := _pending_generation
	if not _mount_is_active(request, mount_generation):
		return
	var next_screen := _pending_screen
	var previous_screen := current_screen

	if previous_screen != null and is_instance_valid(previous_screen):
		previous_screen.queue_free()
	current_screen = next_screen
	_pending_screen = null
	_pending_request = null
	_clear_pending_transition()
	set_process(not _abandoned_scene_paths.is_empty())
	route_mounted.emit(request)

func cancel_mount(request: RefCounted) -> void:
	if request == null or request != _pending_request:
		return
	_mount_generation += 1
	_cancel_pending_screen()

func _mount_is_active(request: RefCounted, mount_generation: int) -> bool:
	return is_inside_tree() and request != null and request == _pending_request and mount_generation == _mount_generation and request.result.call("is_pending")

func _fail_mount(request: RefCounted, message: String, mount_generation: int) -> void:
	if not _mount_is_active(request, mount_generation):
		return
	_cancel_pending_screen()
	route_mount_failed.emit(request, message)

func _cancel_pending_screen() -> void:
	_clear_pending_transition()
	if _pending_load_started and _pending_request != null and _pending_screen == null and not _pending_request.scene_path.is_empty():
		var path: String = _pending_request.scene_path
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
			if not _abandoned_scene_paths.has(path):
				_abandoned_scene_paths.append(path)
	if _pending_screen != null and is_instance_valid(_pending_screen):
		_pending_screen.queue_free()
	_pending_screen = null
	_pending_request = null
	_pending_generation = 0
	_pending_load_started = false
	set_process(not _abandoned_scene_paths.is_empty())

func _on_transition_finished() -> void:
	_complete_mount()

func _clear_pending_transition() -> void:
	if _pending_transition != null and is_instance_valid(_pending_transition) and not _pending_transition_callback.is_null():
		if _pending_transition.finished.is_connected(_pending_transition_callback):
			_pending_transition.finished.disconnect(_pending_transition_callback)
	_pending_transition = null
	_pending_transition_callback = Callable()

func _drain_abandoned_loads() -> void:
	for index in range(_abandoned_scene_paths.size() - 1, -1, -1):
		var path := _abandoned_scene_paths[index]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
			_abandoned_scene_paths.remove_at(index)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_abandoned_scene_paths.remove_at(index)

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
