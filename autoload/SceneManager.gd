## SceneManager 场景切换管理，支持淡入淡出过渡动画。
##
## 使用示例：
##   SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU)
##   SceneManager.change_scene_to(ResPath.SCENES.GAME_WORLD)
extends CanvasLayer

signal scene_changed(new_scene: Node)
signal scene_change_started(scene_path: String)

var _current_scene: Node = null
var _is_transitioning: bool = false
var _pending_scene_path: String = ""

@onready var _fade_rect: ColorRect = $FadeRect
@onready var _anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	if _fade_rect:
		_fade_rect.visible = false
	if _anim_player:
		_anim_player.animation_finished.connect(_on_transition_finished)
	# 捕获引擎自动加载的主场景，确保后续切换时能正确释放
	if get_tree().current_scene:
		_current_scene = get_tree().current_scene


## 切换到目标场景（带过渡动画）
func change_scene_to(scene_path: String, transition: bool = true) -> void:
	if _is_transitioning:
		push_warning("SceneManager: already transitioning, ignoring request")
		return
	scene_change_started.emit(scene_path)
	if transition:
		_start_transition(scene_path)
	else:
		_switch_scene(scene_path)


## 获取当前场景
func get_current_scene() -> Node:
	return _current_scene


## 开始过渡动画
func _start_transition(scene_path: String) -> void:
	_is_transitioning = true
	_pending_scene_path = scene_path
	_fade_rect.visible = true
	_fade_rect.color = Color(0, 0, 0, 0)
	_anim_player.play("fade_out")


## 切换场景（实际逻辑）
func _switch_scene(scene_path: String) -> void:
	if _current_scene and is_instance_valid(_current_scene):
		_current_scene.queue_free()
	var new_scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(new_scene)
	_current_scene = new_scene
	get_tree().current_scene = new_scene
	scene_changed.emit(new_scene)
	print_debug("SceneManager: switched to %s" % scene_path)


## 过渡动画结束回调
func _on_transition_finished(anim_name: String) -> void:
	if anim_name == "fade_out":
		_switch_scene(_pending_scene_path)
		_pending_scene_path = ""
		_anim_player.play("fade_in")
	elif anim_name == "fade_in":
		_fade_rect.visible = false
		_is_transitioning = false
