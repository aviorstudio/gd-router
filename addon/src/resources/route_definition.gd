class_name RouteDefinition
extends Resource

@export var route_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
@export var title: String = ""
@export var metadata: Dictionary = {}
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RouteGuard") var guard: Resource = null
