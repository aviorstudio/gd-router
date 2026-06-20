class_name CrossfadeRouteTransition
extends "route_transition.gd"

@export_range(0.0, 2.0, 0.01, "or_greater") var duration_s: float = 0.15
@export var slide_pixels: float = 20.0

func start_transition(host: Control, from_screen: Node, to_screen: Node) -> void:
	if host == null or not is_instance_valid(host):
		finish.call_deferred()
		return
	if to_screen is CanvasItem:
		(to_screen as CanvasItem).modulate.a = 0.0
	if to_screen is Control:
		(to_screen as Control).position.y += slide_pixels

	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if from_screen is CanvasItem:
		tween.tween_property(from_screen, "modulate:a", 0.0, duration_s)
	if to_screen is CanvasItem:
		tween.tween_property(to_screen, "modulate:a", 1.0, duration_s)
	if to_screen is Control:
		var control := to_screen as Control
		tween.tween_property(control, "position:y", control.position.y - slide_pixels, duration_s)
	tween.finished.connect(finish, CONNECT_ONE_SHOT)
