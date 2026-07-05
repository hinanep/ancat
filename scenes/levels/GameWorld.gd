## GameWorld 基础关卡脚本，处理关卡基础逻辑。
##
extends Node2D

@onready var _camera: Camera2D = $WorldCamera

func _ready() -> void:
	EventBus.clear_deployed_anchor_cabin_paths()
	_camera.enabled = true
	EventBus.subscribe(_on_event)
	AudioManager.play_bgm(ResPath.AUDIO.BGM_CALM)
	print_debug("GameWorld: level loaded")


func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)
	AudioManager.stop_bgm()


## 响应全局事件，在风暴阶段切换 BGM。
## @param event_type 事件类型
## @param _data 事件数据
## @return void
func _on_event(event_type: EventBus.EventType, _data: Dictionary) -> void:
	match event_type:
		EventBus.EventType.STORM_STARTED:
			AudioManager.play_bgm(ResPath.AUDIO.BGM_STORM)
		EventBus.EventType.STORM_ENDED:
			AudioManager.play_bgm(ResPath.AUDIO.BGM_CALM)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU)
