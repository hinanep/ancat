## SettingsMenu 设置菜单脚本（占位）。
##
extends Control

@onready var _back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	print_debug("SettingsMenu: loaded")
	_back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU)
