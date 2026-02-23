extends SceneTree

const RouterService = preload("res://src/router_service.gd")

var _transition_called: bool = false
var _last_transition_path: String = ""
var _missing_route_name: String = ""
var _changed_route_name: String = ""
var _changed_scene_path: String = ""
var _allow_routes: bool = true
var _transition_call_count: int = 0

func _route_entry(route_name: String, scene_path: String) -> RouterService.RouteEntry:
	return RouterService.RouteEntry.new(route_name, scene_path)

func _initialize() -> void:
	var failures: Array[String] = []
	_test_route_not_found_signal(failures)
	_test_transition_callable_and_params(failures)
	_test_middleware_blocks_navigation(failures)
	_test_history_and_go_back(failures)
	_test_default_transition_callable_is_set(failures)

	if failures.is_empty():
		print("PASS gd-router router_service_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_route_not_found_signal(failures: Array[String]) -> void:
	_missing_route_name = ""
	var router := RouterService.new()
	router.route_not_found.connect(Callable(self, "_capture_route_not_found"))
	router.go_to("missing", {})
	if _missing_route_name != "missing":
		failures.append("route_not_found signal not emitted with expected route name")
	router.free()

func _test_transition_callable_and_params(failures: Array[String]) -> void:
	_transition_called = false
	_last_transition_path = ""
	_transition_call_count = 0

	var router := RouterService.new()
	router.set_routes({
		"home": _route_entry("home", "res://src/routes/home_route/home_route.tscn")
	})

	_changed_route_name = ""
	_changed_scene_path = ""
	router.route_changed.connect(Callable(self, "_capture_route_changed"))
	router.transition_callable = Callable(self, "_capture_transition")

	var params: Dictionary[String, Variant] = {"match_id": "abc-123"}
	router.go_to("home", params)

	if not _transition_called:
		failures.append("transition_callable was not called")
	if _last_transition_path != "res://src/routes/home_route/home_route.tscn":
		failures.append("transition_callable received unexpected scene path")
	if _transition_call_count != 1:
		failures.append("Expected exactly one transition call")
	if _changed_route_name != "home":
		failures.append("route_changed signal missing expected route name")
	if _changed_scene_path != "res://src/routes/home_route/home_route.tscn":
		failures.append("route_changed signal missing expected scene path")
	var stored_params: Dictionary[String, Variant] = router.get_params()
	if stored_params.get("match_id", "") != "abc-123":
		failures.append("router params were not stored by go_to")
	if router.get_param("match_id", "") != "abc-123":
		failures.append("get_param should return stored param value")
	if router.get_param("missing_key", "fallback") != "fallback":
		failures.append("get_param should return default for missing key")
	router.free()

func _test_middleware_blocks_navigation(failures: Array[String]) -> void:
	var router := RouterService.new()
	router.set_routes({
		"home": _route_entry("home", "res://src/routes/home_route/home_route.tscn")
	})
	router.transition_callable = Callable(self, "_capture_transition")
	_allow_routes = false
	_transition_called = false
	router.add_middleware(Callable(self, "_route_middleware"))

	router.go_to("home", {"blocked": true})

	if _transition_called:
		failures.append("Expected middleware to block transition")
	if router.get_current_route() != "":
		failures.append("Expected blocked navigation to keep current route empty")
	router.free()
	_allow_routes = true

func _test_history_and_go_back(failures: Array[String]) -> void:
	_transition_call_count = 0
	var router := RouterService.new()
	router.set_routes({
		"home": _route_entry("home", "res://src/routes/home_route/home_route.tscn"),
		"settings": _route_entry("settings", "res://src/routes/settings_route/settings_route.tscn"),
	})
	router.transition_callable = Callable(self, "_capture_transition")

	router.go_to("home")
	router.go_to("settings")
	if router.get_current_route() != "settings":
		failures.append("Expected current route to be settings after second navigation")

	router.go_back()
	if router.get_current_route() != "home":
		failures.append("Expected go_back to navigate to previous route")
	if _transition_call_count != 3:
		failures.append("Expected transitions for go_to(home), go_to(settings), go_back(home)")
	router.free()

func _test_default_transition_callable_is_set(failures: Array[String]) -> void:
	var router := RouterService.new()
	router._enter_tree()
	if not router.transition_callable.is_valid():
		failures.append("Expected default transition_callable to be valid after _enter_tree")
	router.free()

func _capture_route_not_found(route_name: String) -> void:
	_missing_route_name = route_name

func _capture_route_changed(route_name: String, scene_path: String) -> void:
	_changed_route_name = route_name
	_changed_scene_path = scene_path

func _capture_transition(scene_path: String) -> void:
	_transition_called = true
	_last_transition_path = scene_path
	_transition_call_count += 1

func _route_middleware(_route_name: String, _params: Dictionary[String, Variant], next: Callable) -> void:
	if _allow_routes:
		next.call()
