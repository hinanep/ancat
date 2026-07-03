## GameWorld 基础关卡脚本，处理关卡基础逻辑。
##
extends Node2D

@onready var _camera: Camera2D = $WorldCamera

func _ready() -> void:
	print_debug("GameWorld: level loaded")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU)
