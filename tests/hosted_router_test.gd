extends SceneTree

const RouterScript = preload("res://addon/src/core/router.gd")
const RouteResultScript = preload("res://addon/src/core/route_result.gd")
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

class ManualTransition extends Resource:
	signal finished
	var call_count: int = 0

	func start_transition(_host: Control, _from_screen: Node, _to_screen: Node) -> void:
		call_count += 1

	func complete() -> void:
		finished.emit()

class InvalidTransition extends Resource:
	func start_transition(_host: Control, _from_screen: Node, _to_screen: Node) -> void:
		pass

class DeferredHost extends Node:
	signal route_mounted(request)
	signal route_mount_failed(request, error_message: String)
	var requests: Array[RefCounted] = []
	var canceled: Array[RefCounted] = []

	func mount_route(request: RefCounted) -> void:
		requests.append(request)

	func cancel_mount(request: RefCounted) -> void:
		canceled.append(request)

	func complete(request: RefCounted) -> void:
		route_mounted.emit(request)

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
	await _test_failed_back_is_transactional(failures)
	await _test_latest_navigation_supersedes_stale_completion(failures)
	await _test_resource_await_ignores_stale_request(failures)
	await _test_shared_transition_ignores_stale_await(failures)
	await _test_failed_mount_disposes_partial_scene(failures)
	await _test_destroyed_host_fails_and_disposes_mount(failures)
	await _test_freed_previous_scene_completes_latest_mount(failures)
	await _test_repeated_replace_and_back(failures)
	# Let canceled async mount continuations observe their invalid generation and
	# release before the SceneTree exits.
	await process_frame
	await process_frame

	if failures.is_empty():
		print("PASS gd-router hosted_router_test reachable=1")
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

	await _wait_result(router.go_to("home", {"level": "level_01"}))

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
	await _wait_for_route(router, "game")
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

	await _wait_result(router.go_to("home"))
	await _wait_result(router.go_to("game"))
	if router.get_current_route() != "game":
		failures.append("Expected current route to be game before back navigation")
	if host.current_screen == null or host.current_screen.name != "GameScreen":
		failures.append("Expected RouteHost to mount GameScreen")

	await _wait_result(router.go_back())
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
	await _wait_result(router.go_to("missing_scene"))
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
	await _wait_for_route(router, "game")
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
	await _wait_result(router.go_to("home"))
	await _wait_result(router.go_to("game"))
	var link := RouteLinkScript.new()
	link.action = 2
	root.add_child(link)
	await process_frame
	link.pressed.emit()
	await _wait_for_route(router, "home")
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
	await _wait_result(router.go_to("home"))
	if not bool(host.get_meta("transition_called", false)):
		failures.append("Expected custom transition resource to be called")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_failed_back_is_transactional(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	await _wait_result(router.go_to("home", {"step": 1}))
	await _wait_result(router.go_to("game", {"step": 2}))
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/missing_screen/missing_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	var before_history: Array[String] = router.get_history()
	var before_params: Dictionary = router.get_params()
	var result: RefCounted = router.go_back({"step": 3})
	await _wait_result(result)
	if result.status != RouteResultScript.Status.FAILED:
		failures.append("Expected failed back navigation to return failed")
	if router.get_history() != before_history or router.get_current_route() != "game":
		failures.append("Expected failed back navigation to leave history and current route unchanged")
	if router.get_params() != before_params:
		failures.append("Expected failed back navigation to leave params unchanged")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_latest_navigation_supersedes_stale_completion(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := DeferredHost.new()
	root.add_child(host)
	router.register_host(host)
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	var slow_result: RefCounted = router.go_to("home")
	var slow_request: RefCounted = host.requests.back()
	var fast_result: RefCounted = router.go_to("game")
	var fast_request: RefCounted = host.requests.back()
	if slow_result.status != RouteResultScript.Status.SUPERSEDED or not host.canceled.has(slow_request):
		failures.append("Expected newer navigation to explicitly supersede and cancel the prior request")
	host.complete(slow_request)
	if router.get_current_route() != "":
		failures.append("Expected stale host completion to leave router state unchanged")
	host.complete(fast_request)
	if fast_result.status != RouteResultScript.Status.SUCCEEDED or router.get_current_route() != "game":
		failures.append("Expected latest host completion to commit game")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_resource_await_ignores_stale_request(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	var slow_result: RefCounted = router.go_to("home")
	var fast_result: RefCounted = router.go_to("game")
	await _wait_result(fast_result)
	await process_frame
	if slow_result.status != RouteResultScript.Status.SUPERSEDED:
		failures.append("Expected a newer request to supersede a stale resource await")
	if fast_result.status != RouteResultScript.Status.SUCCEEDED or router.get_current_route() != "game":
		failures.append("Expected only the latest resource await to mount and commit")
	if host.get_child_count() != 1 or host.current_screen == null or host.current_screen.name != "GameScreen":
		failures.append("Expected stale resource await to create no retained partial scene")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_shared_transition_ignores_stale_await(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	var shared_transition := ManualTransition.new()
	host.transition = shared_transition
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	var slow_result: RefCounted = router.go_to("home")
	await _wait_for_transition_calls(shared_transition, 1)
	var first_screen: Node = host.get_child(0) if host.get_child_count() > 0 else null
	var fast_result: RefCounted = router.go_to("game")
	await _wait_for_transition_calls(shared_transition, 2)
	shared_transition.complete()
	await _wait_result(fast_result)
	await process_frame
	if slow_result.status != RouteResultScript.Status.SUPERSEDED:
		failures.append("Expected slow shared-transition request to be superseded")
	if first_screen != null and is_instance_valid(first_screen):
		failures.append("Expected superseded partial scene to be disposed")
	if router.get_current_route() != "game" or host.current_screen == null or host.current_screen.name != "GameScreen":
		failures.append("Expected only the latest shared-transition await to mount and commit")
	if host.get_child_count() != 1:
		failures.append("Expected one mounted scene after overlapping transitions")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_failed_mount_disposes_partial_scene(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	host.transition = InvalidTransition.new()
	router.set_routes([_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn")])
	var result: RefCounted = router.go_to("home")
	await _wait_result(result)
	await process_frame
	if result.status != RouteResultScript.Status.FAILED or host.get_child_count() != 0 or host.current_screen != null:
		failures.append("Expected failed transition mount to dispose its partial scene")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_destroyed_host_fails_and_disposes_mount(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	var manual_transition := ManualTransition.new()
	host.transition = manual_transition
	router.set_routes([_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn")])
	var result: RefCounted = router.go_to("home")
	await _wait_for_transition_calls(manual_transition, 1)
	host.queue_free()
	await process_frame
	if result.status != RouteResultScript.Status.FAILED:
		failures.append("Expected host destruction to fail the pending navigation")
	if router.get_current_route() != "":
		failures.append("Expected host destruction to leave router state uncommitted")
	router.queue_free()
	await process_frame

func _test_freed_previous_scene_completes_latest_mount(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	await _wait_result(router.go_to("home"))
	var previous_screen: Node = host.current_screen
	var manual_transition := ManualTransition.new()
	host.transition = manual_transition
	var result: RefCounted = router.go_to("game")
	await _wait_for_transition_calls(manual_transition, 1)
	previous_screen.free()
	manual_transition.complete()
	await _wait_result(result)
	if result.status != RouteResultScript.Status.SUCCEEDED or host.current_screen == null or host.current_screen.name != "GameScreen":
		failures.append("Expected latest mount to survive an externally freed previous scene")
	host.queue_free()
	router.queue_free()
	await process_frame

func _test_repeated_replace_and_back(failures: Array[String]) -> void:
	var router := RouterScript.new()
	root.add_child(router)
	var host := _registered_host(router)
	router.set_routes([
		_route("home", "res://tests/fixtures/screens/home_screen/home_screen.tscn"),
		_route("game", "res://tests/fixtures/screens/game_screen/game_screen.tscn"),
	])
	await _wait_result(router.go_to("home"))
	await _wait_result(router.go_to("game"))
	await _wait_result(router.replace("home", {"replace": true}))
	var back_result: RefCounted = router.go_back({"back": true})
	await _wait_result(back_result)
	if back_result.status != RouteResultScript.Status.SUCCEEDED or router.get_history() != ["home"]:
		failures.append("Expected repeated replace/back operations to commit transactionally")
	if router.get_param("back", false) != true:
		failures.append("Expected successful back params to commit")
	host.queue_free()
	router.queue_free()
	await process_frame

func _wait_result(result: RefCounted) -> void:
	if result != null and result.call("is_pending"):
		await result.completed

func _wait_for_route(router: Node, route_name: String) -> void:
	for _frame in range(120):
		if router.call("get_current_route") == route_name:
			return
		await process_frame

func _wait_for_transition_calls(manual_transition: Resource, expected: int) -> void:
	for _frame in range(120):
		if int(manual_transition.get("call_count")) >= expected:
			return
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
