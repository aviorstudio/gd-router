class_name RouteTransition
extends Resource

signal finished

func start_transition(_host: Control, _from_screen: Node, _to_screen: Node) -> void:
	finish.call_deferred()

func finish() -> void:
	finished.emit()
