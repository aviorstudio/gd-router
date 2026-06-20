class_name InstantRouteTransition
extends "route_transition.gd"

func start_transition(_host: Control, from_screen: Node, to_screen: Node) -> void:
	if from_screen is CanvasItem:
		(from_screen as CanvasItem).hide()
	if to_screen is CanvasItem:
		(to_screen as CanvasItem).show()
	finish.call_deferred()
