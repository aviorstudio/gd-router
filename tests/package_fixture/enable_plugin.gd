extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await create_timer(2.0).timeout
	var plugin_path := "res://addons/@aviorstudio_gd-router/plugin.cfg"
	if EditorInterface.is_plugin_enabled(plugin_path):
		push_error("packaged plugin was enabled before the lifecycle test")
		quit(1)
		return
	EditorInterface.set_plugin_enabled(plugin_path, true)
	await create_timer(1.0).timeout
	ProjectSettings.save()
	print("PASS gd-router package_enable reachable=1")
	quit(0)
