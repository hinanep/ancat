## SettingsMenu 设置菜单脚本（占位）。
##
extends Control

@onready var _back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	print_debug("SettingsMenu: loaded")
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.mouse_entered.connect(_on_button_hovered)

func _on_back_pressed() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_CLICK)
	SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_sfx_random(ResPath.AUDIO.UI_CLICK)
		SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU)


## 按钮悬停音效。
## @return void
func _on_button_hovered() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_ROLLOVER)
