## MainMenu 主菜单脚本，处理开始/设置/退出按钮逻辑。
##
extends Control

@onready var _start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var _settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var _quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_start_button.mouse_entered.connect(_on_button_hovered)
	_settings_button.mouse_entered.connect(_on_button_hovered)
	_quit_button.mouse_entered.connect(_on_button_hovered)

func _on_start_pressed() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_CLICK)
	SceneManager.change_scene_to(ResPath.SCENES.GAME_WORLD)

func _on_settings_pressed() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_CLICK)
	SceneManager.change_scene_to(ResPath.SCENES.SETTINGS_MENU)

func _on_quit_pressed() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_CLICK)
	get_tree().quit()


## 按钮悬停音效。
## @return void
func _on_button_hovered() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_ROLLOVER)
