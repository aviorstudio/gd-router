extends SceneTree

func _initialize() -> void:
	var router := root.get_node_or_null("GdRouter")
	if router == null:
		push_error("packaged GdRouter autoload is missing")
		quit(1)
		return
	if not router.has_method("go_to") or not router.has_method("go_back"):
		push_error("packaged GdRouter smoke API is incomplete")
		quit(1)
		return
	print("PASS gd-router package_smoke reachable=1")
	quit(0)
