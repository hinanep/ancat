## MainMenu 主菜单脚本，嵌入 GameWorld 天空背景上，处理开始/退出按钮与淡入淡出。
##
extends Control

signal start_pressed
signal quit_pressed

@onready var _start_button: TextureButton = $VBoxContainer/StartButton
@onready var _quit_button: TextureButton = $VBoxContainer/QuitButton

var _fade_tween: Tween = null


## 绑定按钮信号。
## @return void
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_start_button.mouse_entered.connect(_on_button_hovered)
	_quit_button.mouse_entered.connect(_on_button_hovered)


## 设置菜单可见性与交互。
## @param menu_visible 是否显示并可交互
## @return void
func set_menu_visible(menu_visible: bool) -> void:
	visible = menu_visible
	_set_input_blocked(menu_visible)
	if menu_visible:
		modulate.a = 1.0


## 设置是否拦截输入；仅按钮区域可点击，不遮挡全屏。
## @param blocked 是否拦截
## @return void
func _set_input_blocked(blocked: bool) -> void:
	var button_filter: Control.MouseFilter = (
		Control.MOUSE_FILTER_STOP if blocked else Control.MOUSE_FILTER_IGNORE
	)
	_start_button.disabled = not blocked
	_quit_button.disabled = not blocked
	_start_button.mouse_filter = button_filter
	_quit_button.mouse_filter = button_filter


## 菜单淡出。
## @param duration 动画时长（秒）
## @return void
func fade_out(duration: float) -> void:
	_kill_fade_tween()
	_set_input_blocked(false)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, 'modulate:a', 0.0, duration)
	await _fade_tween.finished
	visible = false


## 菜单淡入。
## @param duration 动画时长（秒）
## @return void
func fade_in(duration: float) -> void:
	_kill_fade_tween()
	modulate.a = 0.0
	set_menu_visible(true)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, 'modulate:a', 1.0, duration)
	await _fade_tween.finished


## 终止进行中的淡入淡出 tween。
## @return void
func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


## 开始游戏按钮。
## @return void
func _on_start_pressed() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_CLICK)
	_set_input_blocked(false)
	start_pressed.emit()


## 退出按钮。
## @return void
func _on_quit_pressed() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_CLICK)
	quit_pressed.emit()
	get_tree().quit()


## 按钮悬停音效。
## @return void
func _on_button_hovered() -> void:
	AudioManager.play_sfx_random(ResPath.AUDIO.UI_ROLLOVER)
