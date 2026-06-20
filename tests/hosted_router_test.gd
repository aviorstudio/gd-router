extends SceneTree

const RouterScript = preload("res://addon/src/core/router.gd")
const RouteDefinitionScript = preload("res://addon/src/resources/route_definition.gd")
const RouteMapScript = preload("res://addon/src/resources/route_map.gd")
const RouteDiscoveryScript = preload("res://addon/src/discovery/route_discovery.gd")
const RouteHostScript = preload("res://addon/src/nodes/route_host.gd")
const RouteLinkScript = preload("res://addon/src/nodes/route_link.gd")
const RouteMapGeneratorScript = preload("res://addon/src/editor/route_map_generator.gd")

class BlockingGuard extends Resource:
	func can_enter(_context: RefCounted) -> bool:
		return false

class RecordingTransition extends Resource:
	signal finished

	func start_transition(host: Control, _from_screen: Node, _to_screen: Node) -> void:
		host.set_meta("transition_called", true)
		call_deferred("_finish")

	func _finish() -> void:
		finished.emit()

var _missing_route_name: String = ""
var _changed_route_name: String = ""
var _changed_scene_path: String = ""
var _changed_params: Dictionary = {}
var _failed_route_name: String = ""
var _failed_scene_path: String = ""
var _failed_error_message: String = ""

func _initialize() -> void:
	var failures: Array[String] = []
	_test_discovers_screen_routes(failures)
	_test_route_map_generator_builds_explicit_map(failures)
	_test_example_route_map_loads(failures)
	_test_transition_presets_load(failures)
	_test_route_host_configuration_warnings(failures)
	_test_missing_route_signal(failures)
	_test_route_guard_blocks_navigation(failures)
	await _test_route_host_mounts_screens_and_params(failures)
	await _test_route_host_uses_route_map_initial_route(failures)
	await _test_history_and_go_back(failures)
	await _test_failed_mount_does_not_change_history(failures)
	await _test_route_link_navigates_by_inspector_data(failures)
	await _test_route_link_back_action(failures)
	await _test_custom_transition_resource_is_called(failures)

	if failures.is_empty():
		print("PASS gd-router hosted_router_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_discovers_screen_routes(failures: Array[String]) -> void:
	var discovered: Array = RouteDiscoveryScript.discover("res://tests/fixtures/screens", "_screen")
	if discovered.size() != 2:
		failures.append("Expected two discovered screen routes")
		return
	var route_names: Array[String] = []
	for route in discovered:
		route_names.append(route.route_name)
	route_names.sort()
	if route_names != ["game", "home"]:
		failures.append("Expected discovered routes to be game and home")

func _test_route_map_generator_builds_explicit_map(failures: Array[String]) -> void:
	var existing_map := RouteMapScript.new()
	existing_map.initial_route = "game"
	var existing_home := _route("home", "res://old_home.tscn")
	existing_home.title = "Start Here"
	existing_home.metadata = {"owned_by": "design"}
	var existing_routes: Array[Resource] = [existing_home]
	existing_map.routes = existing_routes

	var generated_map: Resource = RouteMapGeneratorScript.build_route_map("res://tests/fixtures/screens", "_screen", existing_map)
	if generated_map == null:
		failures.append("Expected RouteMapGenerator to build a RouteMap")
		return
	if generated_map.initial_route != "game":
		failures.append("Expected RouteMapGenerator to preserve a valid existing initial route")
	if generated_map.routes.size() != 2:
		failures.append("Expected RouteMapGenerator to build two routes")
	var generated_home: Resource = generated_map.get_route("home")
	if generated_home == null:
		failures.append("Expected generated RouteMap to contain home route")
		return
	if generated_home.title != "Start Here":
		failures.append("Expected RouteMapGenerator to preserve route title")
	if generated_home.metadata.get("owned_by", "") != "design":
		failures.append("Expected RouteMapGenerator to preserve route metadata")
	if generated_home.scene_path != "res://tests/fixtures/screens/home_screen/home_screen.tscn":
		failures.append("Expected RouteMapGenerator to update discovered scene path")

func _test_example_route_map_loads(failures: Array[String]) -> void:
	var route_map := load("res://examples/app_shell/src/static/config/main_route_map.tres")
	if route_map == null:
		failures.append("Expected example RouteMap resource to load")
		return
	if not "initial_route" in route_map or route_map.initial_route != "home":
		failures.append("Expected example RouteMap initial route to be home")
		return
	if not route_map.has_method("has_route") or not route_map.call("has_route", "home") or not route_map.call("has_route", "game"):
		failures.append("Expected example RouteMap to contain home and game routes")

func _test_transition_presets_load(failures: Array[String]) -> void:
	var instant_transition := load("res://addon/presets/instant_route_transition.tres")
	if instant_transition == null or not instant_transition.has_method("start_transition"):
		failures.append("Expected instant transition preset to load")
	var crossfade_transition := load("res://addon/presets/crossfade_route_transition.tres")
	if crossfade_transition == null or not crossfade_transition.has_method("start_transition"):
		failures.append("Expected crossfade transition preset to load")

func _test_route_host_configuration_warnings(failures: Array[String]) -> void:
	var host := RouteHostScript.new()
	host.auto_discover = false
	var missing_routes_warning := _warnings_text(host)
	if not missing_routes_warning.contains("Assign a RouteMap"):
		failures.append("Expected RouteHost to warn when no RouteMap and auto_discover is off")
	host.auto_discover = true
	host.routes_dir = "res://tests/fixtures/screens"
	host.initial_route = "missing"
	var missing_initial_warning := _warnings_text(host)
	if not missing_initial_warning.contains("Initial route 'missing'"):
		failures.append("Expected RouteHost to warn when initial route is not discovered")
	host.queue_free()

func _test_missing_route_signal(failures: Array[String]) -> void:
	_missing_route_name = ""
	var router := RouterScript.new()
	root.add_child(router)
	router.route_not_found.connect(_capture_route_not_found)
	router.go_to("missing")
	if _missing_route_name != "missing":
		failures.append("Expected route_not_found signal for missing route")
	router.queue_free()

func _test_route_guard_blocks_navigation(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var guarded_route := _route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn")
	guarded_route.guard = BlockingGuard.new()
	router.set_routes([guarded_route])
	router.go_to("home")
	if router.get_current_route() != "":
		failures.append("Expected blocking guard to prevent current route change")
	router.queue_free()

func _test_route_host_mounts_screens_and_params(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	router.route_changed.connect(_capture_route_changed)

	router.go_to("home", {"level": "level_01"})
	await process_frame
	await process_frame

	if host.current_screen == null or host.current_screen.name != "HomeScreen":
		failures.append("Expected RouteHost to mount HomeScreen")
	if router.get_current_route() != "home":
		failures.append("Expected current route to be home")
	if router.get_param("level", "") != "level_01":
		failures.append("Expected route params to be stored")
	if _changed_route_name != "home":
		failures.append("Expected route_changed signal for home")
	if _changed_scene_path != "res://tests/fixtures/screens/home_screen/home_screen.tscn":
		failures.append("Expected route_changed scene path for home")
	if _changed_params.get("level", "") != "level_01":
		failures.append("Expected route_changed params to include level")

	host.queue_free()
	router.queue_free()
	await process_frame

func _test_route_host_uses_route_map_initial_route(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var route_map := RouteMapScript.new()
	route_map.initial_route = "game"
	var routes: Array[Resource] = [
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	]
	route_map.routes = routes
	var host := RouteHostScript.new()
	host.router = router
	host.route_map = route_map
	host.initial_route = ""
	host.auto_discover = false
	root.add_child(host)
	await process_frame
	await process_frame
	if router.get_current_route() != "game":
		failures.append("Expected RouteHost to use RouteMap.initial_route when initial_route is empty")
	if host.current_screen == null or host.current_screen.name != "GameScreen":
		failures.append("Expected RouteHost route map initial route to mount GameScreen")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_history_and_go_back(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])

	router.go_to("home")
	await process_frame
	await process_frame
	router.go_to("game")
	await process_frame
	await process_frame
	if router.get_current_route() != "game":
		failures.append("Expected current route to be game before back navigation")
	if host.current_screen == null or host.current_screen.name != "GameScreen":
		failures.append("Expected RouteHost to mount GameScreen")

	router.go_back()
	await process_frame
	await process_frame
	if router.get_current_route() != "home":
		failures.append("Expected current route to be home after go_back")
	if host.current_screen == null or host.current_screen.name != "HomeScreen":
		failures.append("Expected RouteHost to remount HomeScreen after go_back")

	host.queue_free()
	router.queue_free()
	await process_frame

func _test_failed_mount_does_not_change_history(failures: Array[String]) -> void:
	_failed_route_name = ""
	_failed_scene_path = ""
	_failed_error_message = ""
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("missing_scene", "res://tests/fixtures/screens/missing_screen/missing_screen.tscn"),
	])
	router.route_change_failed.connect(_capture_route_change_failed)
	router.go_to("missing_scene")
	await process_frame
	await process_frame
	if _failed_route_name != "missing_scene":
		failures.append("Expected failed mount to emit route_change_failed")
	if _failed_scene_path != "res://tests/fixtures/screens/missing_screen/missing_screen.tscn":
		failures.append("Expected failed mount signal to include scene path")
	if not _failed_error_message.contains("could not be loaded"):
		failures.append("Expected failed mount signal to include load error message")
	if router.get_current_route() != "":
		failures.append("Expected failed mount to leave current route unchanged")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_route_link_navigates_by_inspector_data(failures: Array[String]) -> void:
	var router := RouterScript.new()
	router.name = "GdRouter"
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	var link := RouteLinkScript.new()
	link.route_name = "game"
	root.add_child(link)
	await process_frame
	link.pressed.emit()
	await process_frame
	await process_frame
	if router.get_current_route() != "game":
		failures.append("Expected RouteLink to navigate to its configured route")
	if host.current_screen == null or host.current_screen.name != "GameScreen":
		failures.append("Expected RouteLink navigation to mount GameScreen")
	link.queue_free()
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_route_link_back_action(failures: Array[String]) -> void:
	var router := RouterScript.new()
	router.name = "GdRouter"
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	router.go_to("home")
	await process_frame
	await process_frame
	router.go_to("game")
	await process_frame
	await process_frame
	var link := RouteLinkScript.new()
	link.action = 2
	root.add_child(link)
	await process_frame
	link.pressed.emit()
	await process_frame
	await process_frame
	if router.get_current_route() != "home":
		failures.append("Expected RouteLink BACK action to navigate to previous route")
	if host.current_screen == null or host.current_screen.name != "HomeScreen":
		failures.append("Expected RouteLink BACK action to remount HomeScreen")
	link.queue_free()
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_custom_transition_resource_is_called(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	host.transition = RecordingTransition.new()
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
	])
	router.go_to("home")
	await process_frame
	await process_frame
	if not bool(host.get_meta("transition_called", false)):
		failures.append("Expected custom transition resource to be called")
	host.queue_free()
	router.queue_free()
	await process_frame

func _registered_host(router: Node) -> Control:
	var host := RouteHostScript.new()
	host.router = router
	host.initial_route = ""
	host.auto_discover = false
	root.add_child(host)
	return host

func _route(route_name: String, scene_path: String) -> Resource:
	var route := RouteDefinitionScript.new()
	route.route_name = route_name
	route.scene_path = scene_path
	return route

func _warnings_text(node: Node) -> String:
	var warnings: PackedStringArray = node.call("_get_configuration_warnings")
	var out := ""
	for warning in warnings:
		out += warning + "\n"
	return out

func _capture_route_not_found(route_name: String) -> void:
	_missing_route_name = route_name

func _capture_route_changed(route_name: String, scene_path: String, params: Dictionary) -> void:
	_changed_route_name = route_name
	_changed_scene_path = scene_path
	_changed_params = params

func _capture_route_change_failed(route_name: String, scene_path: String, error_message: String) -> void:
	_failed_route_name = route_name
	_failed_scene_path = scene_path
	_failed_error_message = error_message
