extends SceneTree

const RouterService = preload("res://src/router_service.gd")

var _transition_called: bool = false
var _last_transition_path: String = ""
var _missing_route_name: String = ""
var _changed_route_name: String = ""
var _changed_scene_path: String = ""

func _initialize() -> void:
	var failures: Array[String] = []
	_test_route_not_found_signal(failures)
	_test_transition_callable_and_params(failures)

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

	var router := RouterService.new()
	router.set_routes({
		"home": "res://src/routes/home_route/home_route.tscn"
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
	if _changed_route_name != "home":
		failures.append("route_changed signal missing expected route name")
	if _changed_scene_path != "res://src/routes/home_route/home_route.tscn":
		failures.append("route_changed signal missing expected scene path")
	var stored_params: Dictionary[String, Variant] = router.get_params()
	if stored_params.get("match_id", "") != "abc-123":
		failures.append("router params were not stored by go_to")
	router.free()

func _capture_route_not_found(route_name: String) -> void:
	_missing_route_name = route_name

func _capture_route_changed(route_name: String, scene_path: String) -> void:
	_changed_route_name = route_name
	_changed_scene_path = scene_path

func _capture_transition(scene_path: String) -> void:
	_transition_called = true
	_last_transition_path = scene_path
