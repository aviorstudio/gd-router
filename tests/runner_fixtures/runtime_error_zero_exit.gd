extends SceneTree

func _initialize() -> void:
	push_error("intentional runner control error")
	print("PASS runner-control runtime-error")
	quit(0)
