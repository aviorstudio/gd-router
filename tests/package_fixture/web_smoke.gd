extends Control

func _ready() -> void:
	var router := get_node_or_null("/root/GdRouter")
	var label := $Result as Label
	if router == null or not router.has_method("go_to") or not router.has_method("go_back"):
		label.text = "GD Router web smoke FAIL"
		push_error("packaged web export could not reach GdRouter")
		return
	label.text = "GD Router web smoke PASS"
	print("PASS gd-router web_package_smoke reachable=1")
