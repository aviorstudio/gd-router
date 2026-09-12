extends SceneTree

func _initialize() -> void:
	print("FAIL: intentional assertion failure before a zero exit")
	print("PASS runner-control overwritten-failure")
	quit(0)
