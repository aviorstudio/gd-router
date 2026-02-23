extends SceneTree

const RouteTransitionUtil = preload("res://src/route_transition_util.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_can_instantiate_route_transition_util(failures)

	if failures.is_empty():
		print("PASS gd-router route_transition_util_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_can_instantiate_route_transition_util(failures: Array[String]) -> void:
	var instance := RouteTransitionUtil.new()
	if instance == null:
		failures.append("Expected RouteTransitionUtil.new() to return an instance")
