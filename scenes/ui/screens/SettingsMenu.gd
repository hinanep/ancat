## SettingsMenu 设置菜单脚本（占位）。
##
extends Control

func _ready() -> void:
	print_debug("SettingsMenu: loaded")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU)
