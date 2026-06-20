@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GdRouter"
const AUTOLOAD_SCRIPT := "autoload.gd"
const RouteHostScript = preload("src/nodes/route_host.gd")
const RouteLinkScript = preload("src/nodes/route_link.gd")
const RouteMapScript = preload("src/resources/route_map.gd")
const RouteDefinitionScript = preload("src/resources/route_definition.gd")
const RouteTransitionScript = preload("src/resources/route_transition.gd")
const InstantRouteTransitionScript = preload("src/resources/instant_route_transition.gd")
const CrossfadeRouteTransitionScript = preload("src/resources/crossfade_route_transition.gd")
const RouteGuardScript = preload("src/resources/route_guard.gd")

var _added_autoload: bool = false

func _enter_tree() -> void:
	add_custom_type("RouteHost", "Control", RouteHostScript, null)
	add_custom_type("RouteLink", "Button", RouteLinkScript, null)
	add_custom_type("RouteMap", "Resource", RouteMapScript, null)
	add_custom_type("RouteDefinition", "Resource", RouteDefinitionScript, null)
	add_custom_type("RouteTransition", "Resource", RouteTransitionScript, null)
	add_custom_type("InstantRouteTransition", "Resource", InstantRouteTransitionScript, null)
	add_custom_type("CrossfadeRouteTransition", "Resource", CrossfadeRouteTransitionScript, null)
	add_custom_type("RouteGuard", "Resource", RouteGuardScript, null)

	var key: String = "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(key):
		_added_autoload = false
		return

	var base_dir: String = str(get_script().resource_path).get_base_dir()
	add_autoload_singleton(AUTOLOAD_NAME, base_dir.path_join(AUTOLOAD_SCRIPT))
	_added_autoload = true

func _exit_tree() -> void:
	remove_custom_type("RouteGuard")
	remove_custom_type("CrossfadeRouteTransition")
	remove_custom_type("InstantRouteTransition")
	remove_custom_type("RouteTransition")
	remove_custom_type("RouteDefinition")
	remove_custom_type("RouteMap")
	remove_custom_type("RouteLink")
	remove_custom_type("RouteHost")

	if _added_autoload:
		remove_autoload_singleton(AUTOLOAD_NAME)
