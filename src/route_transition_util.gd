extends RefCounted
## Crossfade scene transition utilities for router scene changes.
class_name RouteTransitionUtil

const FADE_DURATION: float = 0.15
const OVERLAY_NAME: String = "RouteTransitionOverlay"
const OVERLAY_Z_INDEX: int = 5000

## Transitions to a new scene path with viewport crossfade.
static func transition_to(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var overlay: TextureRect = _create_overlay(tree)
	if overlay == null:
		return
	var next_scene: Node = _instantiate_scene(scene_path)
	if next_scene == null:
		overlay.queue_free()
		return
	var root: Window = tree.root
	root.add_child(next_scene)
	tree.current_scene = next_scene
	next_scene.owner = null
	if next_scene is CanvasItem:
		(next_scene as CanvasItem).modulate.a = 0.0
	_start_crossfade(tree, next_scene, overlay)

## Creates a fullscreen overlay from the current viewport snapshot.
static func _create_overlay(tree: SceneTree) -> TextureRect:
	var root: Window = tree.root
	if root == null:
		return null
	var existing: Node = root.get_node_or_null(OVERLAY_NAME)
	if existing and is_instance_valid(existing):
		existing.queue_free()
	var overlay := TextureRect.new()
	overlay.name = OVERLAY_NAME
	overlay.texture = _capture_viewport_texture(root)
	overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
	overlay.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = mini(OVERLAY_Z_INDEX, RenderingServer.CANVAS_ITEM_Z_MAX)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	root.add_child(overlay)
	return overlay

## Captures current viewport image into an ImageTexture.
static func _capture_viewport_texture(root: Window) -> ImageTexture:
	var image: Image = root.get_texture().get_image()
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

## Instantiates a scene from a path, returning null on load failure.
static func _instantiate_scene(scene_path: String) -> Node:
	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		return null
	return packed_scene.instantiate()

## Runs parallel fade-out/fade-in tween between overlay and next scene.
static func _start_crossfade(tree: SceneTree, next_scene: Node, overlay: TextureRect) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	if next_scene == null or not is_instance_valid(next_scene):
		overlay.queue_free()
		return
	var tween: Tween = overlay.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(overlay, "modulate:a", 0.0, FADE_DURATION)
	if next_scene is CanvasItem:
		tween.tween_property(next_scene, "modulate:a", 1.0, FADE_DURATION)
	tween.finished.connect(_cleanup_transition.bind(tree, overlay), CONNECT_ONE_SHOT)

## Cleans up transition overlay and previous scene references.
static func _cleanup_transition(tree: SceneTree, overlay: TextureRect) -> void:
	_cleanup_previous_scene(tree)
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()

## Frees stale scene nodes left under root after transition.
static func _cleanup_previous_scene(tree: SceneTree) -> void:
	var current: Node = tree.current_scene
	for child: Node in tree.root.get_children():
		if child == current:
			continue
		if child is Window:
			continue
		if child is CanvasLayer and child.name == OVERLAY_NAME:
			continue
		if child.get_parent() == tree.root and child.scene_file_path != "":
			child.queue_free()
