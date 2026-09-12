class_name RouteResult
extends RefCounted

signal completed(result)

enum Status {
	PENDING,
	SUCCEEDED,
	FAILED,
	SUPERSEDED,
}

var status: Status = Status.PENDING
var route_name: String = ""
var scene_path: String = ""
var error_message: String = ""
var generation: int = 0

func _init(target_route_name: String = "", target_scene_path: String = "", request_generation: int = 0) -> void:
	route_name = target_route_name
	scene_path = target_scene_path
	generation = request_generation

func is_pending() -> bool:
	return status == Status.PENDING

func is_success() -> bool:
	return status == Status.SUCCEEDED

func status_name() -> String:
	return Status.keys()[status].to_lower()

func succeed() -> void:
	_settle(Status.SUCCEEDED, "")

func fail(message: String) -> void:
	_settle(Status.FAILED, message)

func supersede(message: String = "Navigation was superseded by a newer request.") -> void:
	_settle(Status.SUPERSEDED, message)

func _settle(next_status: Status, message: String) -> void:
	if not is_pending():
		return
	status = next_status
	error_message = message
	completed.emit(self)
